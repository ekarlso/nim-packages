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
        id: int64
        name: string
        description: string

    Tag = object
        id: int64
        name: string

    HttpException = object of Exception
        code: HttpCode


proc rowToPackage(row: TRow): Package =
    result = Package(
        id: parseInt($row[0]),
        name: $row[1],
        web: $row[3],
        maintainer: $row[4],
        license: $row[5]
    )
    if $row[1] != nil:
        result.description = $row[2]


proc rowToLicense(row: TRow): License =
    result = License(
        name: $row[1]
    )

    if $row[1] != nil:
        result.description = $row[1]


proc rowToTag(row: TRow): Tag =
    result = Tag(
        id: parseInt($row[0]),
        name: $row[1]
    )


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
    if name =~ re".*\@.*":
        let msg = "'@' is not allowed in package name."
        raise newHttpExc(Http400, msg)


proc connect(): TDBConn =
    return db_sqlite.open("packages.sqlite", "nim_pkg", "nim_pkg", "nim_pkg")


proc getTags(conn: TDBConn): seq[Tag] =
    result = newSeq[Tag]()
    let q = db_sqlite.sql("SELECT id, name FROM tags")
    for r in db_sqlite.rows(conn, q):
        let tag = rowToTag(r)
        result.add(tag)


proc getTagsByPackage(conn: TDBConn, id: int64): seq[Tag] =
    result = newSeq[Tag]()

    let query = db_sqlite.sql("SELECT id, name FROM tags LEFT JOIN packages_tags ON tags.id = packages_tags.tag_id WHERE packages_tags.pkg_id = ?")
    for row in db_sqlite.rows(conn, query, id):
        let tag = Tag(
            id: parseInt($row[0]),
            name: $row[1]
        )
        result.add(tag)


proc getOrCreateTag(conn: TDBConn, name: string): Tag =
    var tag: Tag

    let query = db_sqlite.sql("SELECT id, name FROM tags WHERE name = ?")
    let row = db_sqlite.getRow(conn, query, name)

    # id will be "" if there's no row found
    if row[0] == "":
        let query = db_sqlite.sql("INSERT INTO tags (name) VALUES(?)")
        let id = db_sqlite.insertId(conn, query, name)
        tag = Tag(name: name, id: id)
    else:
        tag = Tag(name: row[1], id: parseInt(row[0]))
    return tag


proc getLicenses(conn: TDBConn): seq[License] =
    result = newSeq[License]()

    let query = db_sqlite.sql("SELECT name, description FROM licenses")
    for row in db_sqlite.rows(conn, query):
        var license = License(
            name: $row[0]
        )
        if $row[1] != nil:
            license.description = $row[1]
        result.add(license)


proc getLicense(conn: TDBConn, name: string): License =
    let query = db_sqlite.sql("SELECT name, description FROM licenses WHERE name = ?")

    let row = db_sqlite.getRow(conn, query, name)

    result = License(
        name: $row[0],
    )

    if $row[1] != nil:
        result.description = $row[1]


proc createLicense(conn: TDBConn, license: var License): License =
    let query = db_sqlite.sql("INSERT INTO licenses (name, description) VALUES(?, ?)")

    let id = db_sqlite.insertId(conn, query, license.name, license.description)

    result = license
    result.id = id


proc deleteLicense(conn: TDBConn, name: string): int64 =
    let query = db_sqlite.sql("DELETE FROM licenses WHERE name = ?")
    return db_sqlite.execAffectedRows(conn, query, name)


proc setPackageTags(conn: TDBConn, pkg: Package) =
    # Set tags to whatever pkg.tags is.

    let newTags = newTable[string, Tag](pkg.tags.map((s: string) => getOrCreateTag(conn, s)).map((t: Tag) => (t.name, t)))
    let oldTags = newTable[string, Tag](getTagsByPackage(conn, pkg.id).map((t: Tag) => (t.name, t)))

    # Create
    for tag in toSeq(newTags.values).filterIt(oldTags.hasKey(it.name) == false):
        let query = sql("INSERT INTO packages_tags (pkg_id, tag_id) VALUES(?, ?)")
        discard insertId(conn, query, pkg.id, tag.id)

    # Delete
    for tag in toSeq(oldTags.values).filterIt(newTags.hasKey(it.name) == false):
        let query = sql("DELETE FROM packages_tags (pkg_id, tag_id) VALUES(?, ?)")
        discard execAffectedRows(conn, query, pkg.id, tag.id)



proc getPackageReleases(conn: TDBConn, id: int64): seq[Release] =
    result = newSeq[Release]()

    let query = db_sqlite.sql("SELECT id, pkg_id, version, method, uri FROM releases")
    for row in db_sqlite.rows(conn, query, id):
        let release = Release(
            version: $row[2],
            uri: $row[3],
            downMethod: $row[4]
        )
        result.add(release)

proc createRelease(conn: TDBConn, packageId: int64, release: Release) =
    let query = sql("INSERT INTO releases (pkg_id, version, method, uri) VALUES (?, ?, ?, ?, ?)")

    let id = insertId(conn, query, $packageId, release.version, release.downMethod, release.uri)


proc populatePackageData(conn: TDBConn, pkg: var Package) =
    # Helper to populate additional package data.
    if pkg.tags == nil:
        pkg.tags = newSeq[string]()
        for tag in getTagsByPackage(conn, pkg.id):
            pkg.tags.add(tag.name)

    if pkg.releases != nil:
        let rels = getPackageReleases(conn, pkg.id)
        pkg.releases = rels


proc createPackage(conn: TDBConn, pkg: var Package): Package =
    let query = db_sqlite.sql("INSERT INTO packages (name, description, license, web, maintainer) VALUES (?, ?, ?, ?, ?)")

    let id = db_sqlite.insertId(conn, query, pkg.name, pkg.description, pkg.license, pkg.web, pkg.maintainer)
    pkg.id = id

    if pkg.tags != nil:
        setPackageTags(conn, pkg)
    return pkg


proc getPackages(conn: TDBConn): seq[Package] =
    result = newSeq[Package]()

    let query = db_sqlite.sql("SELECT id, name, description, license, web, maintainer FROM packages")

    for row in db_sqlite.rows(conn, query):
        var pkg = Package(
            id: parseInt($row[0]),
            name: $row[1],
            license: $row[3],
            web: $row[4],
            maintainer: $row[5],
        )

        if $row[2] != nil:
            pkg.description = $row[2]

        populatePackageData(conn, pkg)
        result.add(pkg)


proc getPackage(conn: TDBConn, pkgId: int): Package =
    let query = db_sqlite.sql("SELECT id, name, description, license, web, maintainer FROM packages WHERE id = ?")

    let row = db_sqlite.getRow(conn, query, pkgId)

    result = Package(
        id: parseInt($row[0]),
        name: $row[1],
        license: $row[3],
        web: $row[4],
        maintainer: $row[5],
    )

    if $row[2] != nil:
        result.description = $row[2]


proc bodyToPackage(j): Package =
    checkKeys(j, "name", "license", "web", "maintainer")
    isValidPackageName(j["name"].str)

    result = Package(
        name: j["name"].str,
        license: j["license"].str,
        web: j["web"].str,
        maintainer: j["maintainer"].str
    )

    if j.hasKey("description"):
        result.description = j["description"].str
    else:
        result.description = nil

    if j.hasKey("tags"):
        var tags = newSeq[string]()
        for t in j["tags"].elems:
            tags.add(t.str)
        result.tags = tags

    if j.hasKey("releases"):
        var releases = newSeq[Release]()
        for i in j["releases"].elems:
            let release = Release(
                version: i["version"].str,
                uri: i["uri"].str,
                downMethod: i["method"].str
            )

            releases.add(release)
        result.releases = releases


proc releaseToJson(r: Release): JsonNode =
    result = newJObject()
    result["version"] = %r.version
    result["uri"] = %r.uri
    result["method"] = %r.downMethod


proc tagsToJson(tags: seq[Tag]): JsonNode =
    # Turn a seq of tags into a json array of tags
    result = newJArray()
    for tag in tags:
        result.add(%tag.name)


proc packageToJson(pkg: Package): JsonNode =
    result = newJObject()

    result["id"] = %pkg.id
    result["name"] = %pkg.name
    result["license"] = %pkg.license
    result["web"] = %pkg.web
    result["maintainer"] = %pkg.maintainer

    if pkg.description != nil:
        result["description"] = %pkg.description
    else:
        result["description"] = newJNull()

    if pkg.tags != nil:
        result["tags"] = tagsToJson(pkg.tags.map((s: string) => (Tag(name: s))))

    if pkg.releases != nil:
        var releases = newJArray()
        for r in pkg.releases:
            var ro = releaseToJson(r)
            releases.add(ro)
        result["releases"] = releases
    else:
        result["releases"] = newJNull()


proc bodyToLicense(j: JsonNode): License =
    checkKeys(j, "name")

    result = License(
        name: $j["name"].str
    )

    if j.hasKey("description"):
        result.description = j["description"].str
    else:
        result.description = nil


proc licenseToJObject(l: License): JsonNode =
    result = newJObject()

    result["name"] = %l.name

    if l.description != nil:
        result["description"] = %l.description
    else:
        result["description"] = newJNull()


proc errorJObject(code: HttpCode, msg: string): JsonNode =
    let c = $code
    result = %{
        "message": %msg,
        "code": %c
    }


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
            let error = errorJObject(errorCode, errorMsg)
            halt(errorCode, headers, $error)

        let obj = licenseToJObject(license)
        resp(Http201, headers, $obj)

    post "/licenses/@licenseName/delete":
        let rows = deleteLicense(db, @"licenseName")

        let headers = {"content-type": "application/json"}
        if rows == 0:
            halt(Http404, headers, "")
        resp(Http200, "")

    get "/packages":
        var
            pkgs = newSeq[Package]()
            dbRows: seq[TRow]
            queryKey: string
            queryVal: string
            query: TSqlQuery
            statement: string = "SELECT p.id, p.name, p.description, p.license, p.web, p.maintainer FROM packages AS p"

        for k, v in request.params.pairs:
            if queryKey == nil:
                queryKey = k
                queryVal = v
            else:
                let error = errorJObject(Http400, "Only one filter parameter currently allowed.")
                halt(Http400, {"content-type": "application/json"}, $error)

        case queryKey:
            of "tag":
                statement &= " LEFT JOIN packages_tags ON p.id = packages_tags.pkg_id INNER JOIN tags ON packages_tags.tag_id = tags.id WHERE tags.name = ?"
                query = sql(statement)
                dbRows = toSeq(rows(db, query, queryVal))
            of nil:
                query = sql(statement)
                dbRows = toSeq(rows(db, query))
            else:
                let error = errorJObject(Http400, "Invalid query parameter $#" % queryKey)
                halt(Http400, $error)

        for row in dbRows:
            var pkg: Package = rowToPackage(row)
            populatePackageData(db, pkg)
            pkgs.add(pkg)

        var pkg_array = newJArray()

        for pkg in pkgs:
            let pkg_obj = packageToJson(pkg)
            pkg_array.add(pkg_obj)

        resp($pkg_array, "application/json")

    get "/packages/@pkgId":
        let pkg = getPackage(db, parseInt(@"pkgId"))

        let obj = packageToJson(pkg)
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
            let error = errorJObject(errorCode, errorMsg)
            halt(errorCode, headers, $error)

        let obj = packageToJson(pkg)
        resp(Http201, headers, $obj)

    get "/tags":
        let tags = getTags(db)
        let jtags = tagsToJson(tags)
        resp($jtags, "application/json")

runForever()
