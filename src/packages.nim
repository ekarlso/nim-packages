import asyncdispatch, hashes, future, jester, json, marshal, db_sqlite, sequtils, strutils, os, re, tables

from asynchttpserver import Http404

type
    Release = object
        version: string
        uri: string
        downMethod: string

    Package = object
        id: int64
        name: string
        description: string
        web: string
        maintainer: string
        license: string
        tags: seq[string]
        releases: seq[Release]

    License = object
        name: string
        description: string

    Tag = object
        id: int64
        name: string

    HttpException = object of Exception
        code: HttpCode


proc hash(x: Tag): THash =
    result = x.name.hash
    result = !$result


template newHttpExc*(httpCode: HttpCode, message: string): expr =
    var e = newException(HTTPException, message)
    e.code = httpCode
    e


proc checkKeys(j: JsonNode, keys: varargs[string]) =
    for i in keys:
        if not j.hasKey(i):
            let msg = "Missing key '$#'" % i
            raise newHttpExc(Http400, msg)


proc isValidPackageName(name: string) =
    echo ("Checking " & $name)
    if name =~ re".*\@.*":
        let msg = "'@' is not allowed in package name."
        raise newHttpExc(Http400, msg)


proc connect(): TDBConn =
    return db_sqlite.open("packages.sqlite", "nim_pkg", "nim_pkg", "nim_pkg")


proc getTags(conn: TDBConn): seq[string] =
    var tags = newSeq[string]()
    let q = db_sqlite.sql("SELECT name FROM tags")
    for r in db_sqlite.rows(conn, q):
        tags.add($r[0])
    return tags


proc getTagsByPackage(conn: TDBConn, id: int64): seq[Tag] =
    var tags = newSeq[Tag]()

    let q = db_sqlite.sql("SELECT id, name FROM tags LEFT JOIN packages_tags ON tags.id = packages_tags.tag_id WHERE packages_tags.pkg_id = ?")
    for r in db_sqlite.rows(conn, q, id):
        let tag = Tag(
            id: parseInt($r[0]),
            name: $r[1]
        )
        tags.add(tag)
    return tags


proc getOrCreateTag(conn: TDBConn, name: string): Tag =
    var tag: Tag

    let q = db_sqlite.sql("SELECT id, name FROM tags WHERE name = ?")
    let r = db_sqlite.getRow(conn, q, name)

    # id will be "" if there's no row found
    if r[0] == "":
        let q = db_sqlite.sql("INSERT INTO tags (name) VALUES(?)")
        let id = db_sqlite.insertId(conn, q, name)
        tag = Tag(name: name, id: id)
    else:
        tag = Tag(name: r[1], id: parseInt(r[0]))
    return tag

proc getLicenses(conn: TDBConn): seq[License] =
    var licenses = newSeq[License]()

    let q = db_sqlite.sql("SELECT name, description FROM licenses")
    for r in db_sqlite.rows(conn, q):
        var license = License(
            name: $r[0]
        )
        if $r[1] != nil:
            license.description = $r[1]
        licenses.add(license)

    return licenses


proc getLicense(conn: TDBConn, name: string): License =
    let query = db_sqlite.sql("SELECT name, description FROM licenses WHERE name = ?")

    let r = db_sqlite.getRow(conn, query, name)

    var license = License(
        name: $r[0],
    )

    if $r[1] != nil:
        license.description = $r[1]

    return license


proc createLicense(conn: TDBConn, license: var License): License =
    let q = db_sqlite.sql("INSERT INTO licenses (name, description) VALUES(?, ?)")

    # FIXME(ekarlso): Remove once https://github.com/Araq/Nim/issues/1866 is fixed.
    var description: string = license.description
    if description == nil:
        description = ""

    let id = db_sqlite.insertId(conn, q, license.name, description)

    return license


proc deleteLicense(conn: TDBConn, name: string): int64 =
    let q = db_sqlite.sql("DELETE FROM licenses WHERE name = ?")
    return db_sqlite.execAffectedRows(conn, q, name)


proc setPackageTags(conn: TDBConn, pkg: Package) =
    # Set tags to whatever pkg.tags is.

    let newTags = newTable[string, Tag](pkg.tags.map((s: string) => getOrCreateTag(conn, s)).map((t: Tag) => (t.name, t)))
    let oldTags = newTable[string, Tag](getTagsByPackage(conn, pkg.id).map((t: Tag) => (t.name, t)))

    # Create
    for t in toSeq(newTags.values).filterIt(oldTags.hasKey(it.name) == false):
        let q = sql("INSERT INTO packages_tags (pkg_id, tag_id) VALUES(?, ?)")
        discard insertId(conn, q, pkg.id, t.id)

    # Delete
    for t in toSeq(oldTags.values).filterIt(newTags.hasKey(it.name) == false):
        let q = sql("DELETE FROM packages_tags (pkg_id, tag_id) VALUES(?, ?)")
        discard execAffectedRows(conn, q, pkg.id, t.id)


proc getPackageReleases(conn: TDBConn, id: int64): seq[Release] =
    var rels = newSeq[Release]()

    let q = db_sqlite.sql("SELECT id, pkg_id, version, method, uri FROM releases")
    for r in db_sqlite.rows(conn, q, id):
        let release = Release(
            version: $r[2],
            uri: $r[3],
            downMethod: $r[4]
        )
        rels.add(release)

    return rels


proc createPackage(conn: TDBConn, pkg: var Package): Package =
    let query = db_sqlite.sql("INSERT INTO packages (name, description, license, web, maintainer) VALUES (?, ?, ?, ?, ?)")

    # FIXME(ekarlso): Remove once https://github.com/Araq/Nim/issues/1866 is fixed.
    var description: string = pkg.description
    if description == nil:
        description = ""

    let id = db_sqlite.insertId(conn, query, pkg.name, description, pkg.license, pkg.web, pkg.maintainer)
    pkg.id = id

    setPackageTags(conn, pkg)
    return pkg


proc getPackages(conn: TDBConn): seq[Package] =
    var pkgs = newSeq[Package]()

    let query = db_sqlite.sql("SELECT id, name, description, license, web, maintainer FROM packages")

    for r in db_sqlite.rows(conn, query):
        var pkg = Package(
            id: parseInt($r[0]),
            name: $r[1],
            license: $r[3],
            web: $r[4],
            maintainer: $r[5],
        )

        if $r[2] != nil:
            pkg.description = $r[2]

        pkg.tags = newSeq[string]()
        for t in getTagsByPackage(conn, pkg.id):
            pkg.tags.add(t.name)

        let rels = getPackageReleases(conn, pkg.id)
        pkg.releases = rels

        pkgs.add(pkg)
    return pkgs


proc getPackage(conn: TDBConn, pkgId: int): Package =
    let query = db_sqlite.sql("SELECT id, name, description, license, web, maintainer FROM packages WHERE id = ?")

    let r = db_sqlite.getRow(conn, query, pkgId)

    var pkg = Package(
        id: parseInt($r[0]),
        name: $r[1],
        license: $r[3],
        web: $r[4],
        maintainer: $r[5],
    )

    if $r[2] != nil:
        pkg.description = $r[2]

    pkg.tags = newSeq[string]()
    for t in getTagsByPackage(conn, pkg.id):
        pkg.tags.add(t.name)

    let rels = getPackageReleases(conn, pkg.id)
    pkg.releases = rels

    return pkg


proc bodyToPackage(j): Package =
    checkKeys(j, "name", "license", "web", "maintainer")
    isValidPackageName(j["name"].str)

    var pkg = Package(
        name: j["name"].str,
        license: j["license"].str,
        web: j["web"].str,
        maintainer: j["maintainer"].str
    )

    if j.hasKey("description"):
        pkg.description = j["description"].str
    else:
        pkg.description = nil

    var tags = newSeq[string]()
    if j.hasKey("tags"):
        for t in j["tags"].elems:
            tags.add(t.str)
    pkg.tags = tags

    var releases = newSeq[Release]()
    if j.hasKey("releases"):
        for i in j["releases"].elems:
            var release = Release(
                version: i["version"].str,
                uri: i["uri"].str,
                downMethod: i["method"].str
            )

            releases.add(release)

    pkg.releases = releases
    return pkg


proc releaseToJObject(r: Release): JsonNode =
    var o = newJObject()
    o["version"] = %r.version
    o["uri"] = %r.uri
    o["method"] = %r.downMethod
    return o

proc tagsToJson(tagSeq: seq[string]): JsonNode =
    # Set the tags
    var tags = newJArray()
    for t in tagSeq:
        tags.add(%t)
    return tags


proc packageToObject(pkg: Package): JsonNode =
    var o = newJObject()

    o["id"] = %pkg.id
    o["name"] = %pkg.name
    o["license"] = %pkg.license
    o["web"] = %pkg.web
    o["maintainer"] = %pkg.maintainer


    if pkg.description != nil:
        o["description"] = %pkg.description
    else:
        o["description"] = newJNull()

    o["tags"] = tagsToJson(pkg.tags)

    var releases = newJArray()
    for r in pkg.releases:
        var ro = releaseToJObject(r)
        releases.add(ro)
    o["releases"] = releases

    return o


proc bodyToLicense(j: JsonNode): License =
    checkKeys(j, "name")

    var license = License(
        name: $j["name"].str
    )

    if j.hasKey("description"):
        license.description = j["description"].str
    else:
        license.description = nil
    return license


proc licenseToJObject(l: License): JsonNode =
    var o = newJObject()
    o["name"] = %l.name

    if l.description != nil:
        o["description"] = %l.description
    else:
        o["description"] = newJNull()

    return o


var db = connect()
db_sqlite.exec(db, db_sqlite.sql("PRAGMA foreign_keys = ON;"))
var settings = newSettings(staticDir = getCurrentDir())

routes:
    get "/licenses":
        let lics = getLicenses(db)

        var jarray = newJArray()
        for i in lics:
            let obj = licenseToJObject(i)
            jarray.add(obj)
        resp($jarray, "application/json")

    post "/licenses":
        var body = parseJson($request.body)

        var license: License
        let headers = {"content-type": "application/json"}

        var errorCode: HttpCode = Http500
        var errorMsg: string

        try:
            license = bodyToLicense(body)
            license = createLicense(db, license)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            errorCode = e.code
            errorMsg = e.msg
        except Exception:
            errorMsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if errorMsg != nil:
            let c = $errorCode
            let data = %{
                "message": %errorMsg,
                "code": %c
            }
            halt(errorCode, headers, $data)

        let obj = licenseToJObject(license)
        resp(Http201, headers, $obj)

    post "/licenses/@licenseName/delete":
        let rows = deleteLicense(db, @"licenseName")

        let headers = {"content-type": "application/json"}
        if rows == 0:
            halt(Http404, headers, "")
        resp(Http200, "")

    get "/packages":
        let pkgs = getPackages(db)

        var pkg_array = newJArray()

        for pkg in pkgs:
            let pkg_obj = packageToObject(pkg)
            pkg_array.add(pkg_obj)

        resp($pkg_array, "application/json")

    get "/packages/@pkgId":
        let pkg = getPackage(db, parseInt(@"pkgId"))

        let obj = packageToObject(pkg)
        resp($obj, "application/json")

    post "/packages":
        var body = parseJson($request.body)

        var pkg: Package
        let headers = {"content-type": "application/json"}

        var errorCode: HttpCode = Http500
        var errorMsg: string

        try:
            pkg = bodyToPackage(body)
            pkg = createPackage(db, pkg)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            errorCode = e.code
            errorMsg = e.msg
        except Exception:
            errorMsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if errorMsg != nil:
            let c = $errorCode
            let data = %{
                "message": %errorMsg,
                "code": %c
            }
            halt(errorCode, headers, $data)


        let obj = packageToObject(pkg)
        resp(Http201, headers, $obj)

    get "/tags":
        let tags = getTags(db)
        let jtags = tagsToJson(tags)
        resp($jtags, "application/json")

runForever()
