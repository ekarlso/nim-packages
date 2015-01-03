import asyncdispatch, jester, json, marshal, db_sqlite, strutils, os

type
    Release = object
        version: string
        uri: string
        downMethod: string

    Package = object
        id: int64
        name: string
        description: string
        license: string
        web: string
        maintainer: string
        tags: seq[string]
        releases: seq[Release]


proc connect(): TDBConn =
    return db_sqlite.open("packages.sqlite", "nim_pkg", "nim_pkg", "nim_pkg")



proc getPackageTags(conn: TDBConn, id: int64): seq[string] =
    var tags = newSeq[string]()

    let q = db_sqlite.sql("SELECT value FROM tags WHERE pkg_id = ?")
    for r in db_sqlite.rows(conn, q, id):
        tags.add($r[0])
    return tags


proc setPackageTags(conn: TDBConn, pkg: Package): int {.discardable.} =
    let q = db_sqlite.sql("INSERT INTO tags (pkg_id, value) VALUES (?, ?)")

    for t in pkg.tags:
        let id = db_sqlite.insertId(conn, q, pkg.id, t)
        echo($id)


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


proc populatePackageData(conn: TDBConn, pkg: var Package): Package {.discardable.} =
    let tags = getPackageTags(conn, pkg.id)
    pkg.tags = tags

    let rels = getPackageReleases(conn, pkg.id)
    pkg.releases = rels
    return pkg


proc createPackage(conn: TDBConn, pkg: var Package): Package =
    let query = db_sqlite.sql("INSERT INTO packages (name, description, license, web, maintainer) VALUES (?, ?, ?, ?, ?)")

    let id = db_sqlite.insertId(conn, query, pkg.name, pkg.description, pkg.license, pkg.web, pkg.maintainer)
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

        let tags = getPackageTags(conn, pkg.id)
        pkg.tags = tags

        let rels = getPackageReleases(conn, pkg.id)
        pkg.releases = rels

        pkgs.add(pkg)
    return pkgs


proc getPackage(conn: TDBConn, pkgId: int): Package =
    let query = db_sqlite.sql("SELECT id, name, description, license, web, maintainer FROM packages WHERE id = ?")

    let r = db_sqlite.getRow(conn, query, pkgId)

    echo ("FOO")

    var pkg = Package(
        id: parseInt($r[0]),
        name: $r[1],
        license: $r[3],
        web: $r[4],
        maintainer: $r[5],
    )

    if $r[2] != nil:
        pkg.description = $r[2]

    populatePackageData(conn, pkg)
    return pkg


proc bodyToPackage(j): Package =
    var pkg = Package(
        name: j["name"].str,
        license: j["license"].str,
        web: j["web"].str,
        maintainer: j["maintainer"].str
    )

    if j.hasKey("description"):
        pkg.description = j["description"].str

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

    # Set the tags
    var tags = newJArray()
    for t in pkg.tags:
        tags.add(%t)
    o["tags"] = tags

    var releases = newJArray()
    for r in pkg.releases:
        var ro = releaseToJObject(r)
        releases.add(ro)
    o["releases"] = releases

    return o


var db = connect()
var settings = newSettings(staticDir = getCurrentDir())

routes:
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
        var pkg = bodyToPackage(body)

        let created = createPackage(db, pkg)

        let obj = packageToObject(created)
        resp($obj, "application/json")

runForever()
