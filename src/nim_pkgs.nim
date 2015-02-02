import asyncdispatch, hashes, future, jester, json, marshal, db_sqlite, sequtils, strutils, os, re, tables

import easy_bcrypt, jester
from asynchttpserver import Http404
from httpclient import newAsyncHttpClient, get, getContent

import docopt
import jwt
import uuid

from times import nil

type
    DbError = object of Exception
    DbNotFound = object of DBerror

    Release = object
        id: int64
        version: string
        uri: string
        downloadMethod: string

    Package = object
        id: int64
        name: string
        description: string
        web: string
        license: string
        tags: seq[string]
        repository: string

    License = object
        id: int64
        name: string
        description: string

    Tag = object
        id: int64
        name: string

    User = object
        id: int64
        email: string
        password: string
        displayName: string
        github: string

    HttpException = object of Exception
        code: HttpCode

let doc = """
Packages index api / server a'la crates.io.

Usage:
    nim_pkgs [-c FILE]

    -c              JSON Config file [default: ./nim-pkgs.json]

Options:
    -h, --help      Help message
"""

let args = docopt(doc, version="nim-packages 0.0.1")

var
  cfg: JsonNode
  cfgFile: string

if args["-c"]:
  cfgFile = $args["FILE"]
else:
  cfgFile = getCurrentDir() & "/nim-pkgs.json"

if not existsFile(cfgFile):
  quit("Config file $# not found... exiting." % cfgFile)

echo("Reading config...")

let cfgContents = readFile(cfgFile)
cfg = parseJson(cfgContents)

if not cfg.hasKey("secret"):
  quit("Missing 'secret' setting")

if not cfg.hasKey("github_secret"):
  quit("Missing 'github_secret' setting")

if not cfg.hasKey("url"):
  quit("Missing 'url' setting")

const
    GITHUB_ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token"
    GITHUB_USERS_API_URL = "https://api.github.com/user"

let
  staticDir =  if cfg.hasKey("static_dir"): cfg["static_dir"].str else: getCurrentDir() & "/dist"
  port = if cfg.hasKey("port") and cfg["port"].kind == JInt: cfg["port"].num else: 5000
  tokenExpireTime = if cfg.hasKey("token_expire_seconds"): cfg["token_expire_seconds"].num else: 7200


proc assertFound(row: TRow) =
    if row[0] == "":
        raise newException(DbNotFound, "Row not found")


proc rowToPackage(row: TRow): Package =
    result = Package(
        id: parseInt($row[0]),
        name: $row[1],
        license: $row[3],
        web: $row[4],
        repository: $row[5]
    )
    if $row[2] != nil:
        result.description = $row[2]


proc rowToLicense(row: TRow): License =
    result = License(
        name: $row[1]
    )

    if $row[1] != nil:
        result.description = $row[1]


proc rowToUser(row: TRow): User =
    result = User(
        id: parseInt($row[0]),
        email: $row[1],
        password: $row[2],
        displayName: $row[3],
        github: $row[4]
    )


proc rowToTag(row: TRow): Tag =
    result = Tag(
        id: parseInt($row[0]),
        name: $row[1]
    )


proc mkFilters(col: string, values: string): string =
    echo("mkFilters")
    var filters = newSeq[string]()
    for v in values.split(","):
        let nf = "$# LIKE '%$#%'" % [col, v]
        filters.add(nf)
    result = join(filters, " OR ")


template newHttpExc*(httpCode: HttpCode, message: string): expr =
    var e = newException(HTTPException, message)
    e.code = httpCode
    e


proc mkQueryString(elements: openarray[tuple[key, value: string]]): string =
    result = ""
    let len = elements.len
    for i, v in elements:
        result.add(v.key & "=" & v.value)
        if (i < len -1):
            result.add("&")


proc queryToSringTable(s: string): StringTableRef =
    let data = s.split("&").map((s: string) => (s.split("="))).map((i: seq[string]) => (i[0], i[1]))
    result = newStringTable(data)


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
    return db_sqlite.open("packages.sqlite", "nim_pkgs", "nim_pkgs", "nim_pkgs")


proc getUser(conn: TDBConn, email: string): User =
    let query = sql("SELECT id, email, password, display_name, github FROM users WHERE email = ?")
    let row = getRow(conn, query, email)
    result = rowToUser(row)


proc getTags(conn: TDBConn): seq[Tag] =
    result = newSeq[Tag]()
    let q = db_sqlite.sql("SELECT id, name FROM tags")
    for r in db_sqlite.rows(conn, q):
        let tag = rowToTag(r)
        result.add(tag)


proc getTagsByPackage(conn: TDBConn, id: int64): seq[Tag] =
    result = newSeq[Tag]()

    let query = db_sqlite.sql("SELECT id, name FROM tags LEFT JOIN packages_tags ON tags.id = packages_tags.tag_id WHERE packages_tags.package_id = ?")
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


proc setPackageTags(conn: TDBConn, package: Package) =
    # Set tags to whatever package.tags is.

    let newTags = newTable[string, Tag](package.tags.map((s: string) => getOrCreateTag(conn, s.toLower)).map((t: Tag) => (t.name, t)))
    let oldTags = newTable[string, Tag](getTagsByPackage(conn, package.id).map((t: Tag) => (t.name, t)))

    # Create
    for tag in toSeq(newTags.values).filterIt(oldTags.hasKey(it.name) == false):
        let query = sql("INSERT INTO packages_tags (package_id, tag_id) VALUES(?, ?)")
        discard insertId(conn, query, package.id, tag.id)

    # Delete
    for tag in toSeq(oldTags.values).filterIt(newTags.hasKey(it.name) == false):
        let query = sql("DELETE FROM packages_tags (package_id, tag_id) VALUES(?, ?)")
        discard execAffectedRows(conn, query, package.id, tag.id)


proc getPackageReleases(conn: TDBConn, packageId: int64): seq[Release] =
    result = newSeq[Release]()

    var
        st = "SELECT id, package_id, version, method, uri FROM releases"

    if packageId != -1:
        st &= " WHERE package_id = $#" % $packageId

    let query = db_sqlite.sql(st)
    for row in db_sqlite.rows(conn, query):
        let release = Release(
            version: $row[2],
            uri: $row[3],
            downloadMethod: $row[4]
        )
        result.add(release)


proc createRelease(conn: TDBConn, packageId: int64, release: var Release) =
    let query = sql("INSERT INTO releases (package_id, version, method, uri) VALUES (?, ?, ?, ?)")
    release.id = insertId(conn, query, $packageId, release.version, release.downloadMethod, release.uri)


proc populatePackageData(conn: TDBConn, package: var Package) =
    # Helper to populate additional package data.
    if package.tags == nil:
        package.tags = newSeq[string]()
        for tag in getTagsByPackage(conn, package.id):
            package.tags.add(tag.name)


proc createPackage(conn: TDBConn, package: var Package, owner: User) =
    let query = db_sqlite.sql("INSERT INTO packages (name, description, license, web, repository) VALUES (?, ?, ?, ?, ?)")

    let id = db_sqlite.insertId(conn, query, package.name, package.description, package.license, package.web, package.repository)
    package.id = id

    discard db_sqlite.insertId(conn, db_sqlite.sql("INSERT INTO packages_users (package_id, user_id, kind) VALUES(?, ?, ?)"), $package.id, $owner.id, "admin")

    if package.tags != nil:
        setPackageTags(conn, package)


proc getPackages(conn: TDBConn): seq[Package] =
    result = newSeq[Package]()

    let query = db_sqlite.sql("SELECT id, name, description, license, web, repository FROM packages")

    for row in db_sqlite.rows(conn, query):
        var package = Package(
            id: parseInt($row[0]),
            name: $row[1],
            license: $row[3],
            web: $row[4],
            repository: $row[5]
        )

        if $row[2] != nil:
            package.description = $row[2]

        populatePackageData(conn, package)
        result.add(package)


proc getPackage(conn: TDBConn, packageId: int = -1, packageName: string = ""): Package =
    var
        st = "SELECT id, name, description, license, web, repository FROM packages WHERE "
        filters = newSeq[string]()

    if packageName != nil:
        filters.add(" name = '$#'" % $packagename)

    if packageId != -1:
        filters.add(" id = $#" % $packageId)

    let filter = join(filters, " OR ")

    let query = db_sqlite.sql(st & filter)
    let row = db_sqlite.getRow(conn, query)

    assertFound(row)

    result = Package(
        id: parseInt($row[0]),
        name: $row[1],
        license: $row[3],
        web: $row[4],
        repository: $row[5]
    )

    if $row[2] != nil:
        result.description = $row[2]

    populatePackageData(conn, result)



proc `%`(r: Release): JsonNode =
    result = newJObject()
    result["version"] = %r.version
    result["uri"] = %r.uri
    result["method"] = %r.downloadMethod


proc jsonToRelease(j: JsonNode): Release =
    checkKeys(j, "method", "version", "uri")

    result = Release(
        downloadMethod: j["method"].str,
        version: j["version"].str,
        uri: j["uri"].str
    )


proc `%`(tags: seq[Tag]): JsonNode =
    # Turn a seq of tags into a json array of tags
    result = newJArray()
    for tag in tags:
        result.add(%tag.name)


proc `%`(package: Package): JsonNode =
    result = newJObject()

    result["id"] = %package.id
    result["name"] = %package.name
    result["license"] = %package.license
    result["web"] = %package.web
    result["repository"] = %package.repository

    if package.description != nil:
        result["description"] = %package.description
    else:
        result["description"] = newJNull()

    if package.tags != nil:
        result["tags"] = %(package.tags.map((s: string) => (Tag(name: s))))


proc jsonToPackage(j: JsonNode): Package =
    checkKeys(j, "name", "license", "web")
    isValidPackageName(j["name"].str)

    result = Package(
        name: j["name"].str,
        license: j["license"].str,
        web: j["web"].str,
    )

    if j.hasKey("description"):
        result.description = j["description"].str
    else:
        result.description = nil

    if j.hasKey("repository"):
        result.repository = j["repository"].str

    if j.hasKey("tags"):
        var tags = newSeq[string]()
        for t in j["tags"].elems:
            tags.add(t.str)
        result.tags = tags


proc `%`(l: License): JsonNode =
    result = newJObject()

    result["name"] = %l.name

    if l.description != nil:
        result["description"] = %l.description
    else:
        result["description"] = newJNull()


proc jsonToLicense(j: JsonNode): License =
    checkKeys(j, "name")

    result = License(
        name: $j["name"].str
    )

    if j.hasKey("description"):
        result.description = j["description"].str
    else:
        result.description = nil


proc `%`(user: User): JsonNode =
    result = newJObject()
    result["displayName"] = %user.displayName
    result["email"] = %user.email
    result["id"] = %user.id


proc errorJObject(code: HttpCode, msg: string): JsonNode =
    let c = $code
    result = %{
        "message": %msg,
        "code": %c
    }


# Create JWT token
proc createToken(user: User, extraClaims: JsonNode = newJObject()): JsonNode =
  var
    secret = cfg["secret"].str
    jti: Tuuid
    iat = times.toSeconds(times.getTime()).int
    exp = iat + tokenExpireTime

    # Typical claims.
    claims = %{
      "sub": %user.email,
      "iss": cfg["url"],
      "iat": %iat,
      "nbf": %iat,
      "exp": %exp
    }

    headers = %{
      "alg": %"HS256",
      "typ": %"JWT"
    }

  for key, val in extraClaims:
    claims[key] = val

  uuid.uuid_generate_random(jti)
  claims["jti"] = %jti.toHex

  let t = %{"header": headers, "claims": claims}
  var token = jwt.toJWT(t)

  jwt.sign(token, secret)
  result = %{"token": %token}


proc verifyToken(token: JWT) =
  var secret = cfg["secret"].str

  if not token.verify(secret):
    echo("ERROR: Token invalid")
    raise newHttpExc(Http401, "Invalid token")


proc unpackToken(headers: StringTableRef): JWT =
  if not headers.hasKey("Authorization"):
    raise newHttpExc(Http401, "Invalid Authorization header.")

  let parts = headers["Authorization"].split(" ")
  if parts.len != 2:
    echo("ERROR: Token parts was not 2")
    raise newHttpExc(Http401, "Invalid Authorization header.")

  let tokenB64 = $parts[1]
  result = tokenB64.toJWT


echo("Connecting to DB")
var db = connect()
db_sqlite.exec(db, db_sqlite.sql("PRAGMA foreign_keys = ON;"))

var settings = newSettings(staticDir = staticDir, port = Port(port))

routes:
    get "/licenses":
        let lics = getLicenses(db)

        var jarray = newJArray()
        for i in lics:
            jarray.add(%i)
        resp($jarray, "application/json")

    post "/licenses":
        var token = unpackToken(request.headers)
        verifyToken(token)

        var
            body = parseJson($request.body)
            license: License
            headers = {"content-type": "application/json"}
            ec: HttpCode = Http500
            emsg: string

        try:
            license = jsonToLicense(body)
            license = createLicense(db, license)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            ec = e.code
            emsg = e.msg
        except Exception:
            emsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if emsg != nil:
            let error = errorJObject(ec, emsg)
            halt(ec, headers, $error)

        let obj = %license
        resp(Http201, headers, $obj)

    post "/licenses/@licenseName/delete":
        var token = unpackToken(request.headers)
        verifyToken(token)

        let
            rows = deleteLicense(db, @"licenseName")
            headers = {"content-type": "application/json"}
        if rows == 0:
            halt(Http404, headers, "")
        resp(Http200, "")

    get "/packages":
        var
            packages = newSeq[Package]()
            statement: string = "SELECT p.id, p.name, p.description, p.license, p.web, p.repository FROM packages AS p"

            queryKey: string
            queryVal: string
            filters = newSeq[string]()
            joinFilters = @["tag", "user_id"]

        echo("Parsing join filters")
        for k, v in request.params.pairs:
            if k in joinFilters:
                if queryKey == nil:
                    queryKey = k
                    queryVal = v

                else:
                    let error = errorJObject(Http400, "Only one filter parameter currently allowed.")
                    halt(Http400, {"content-type": "application/json"}, $error)

        case queryKey:
            of "tag":
                statement &= " LEFT JOIN packages_tags ON p.id = packages_tags.package_id INNER JOIN tags ON packages_tags.tag_id = tags.id"
                let tagFilters = mkFilters("tags.name", queryVal)
                filters.add(tagFilters)
            of "user_id":
                statement &= " LEFT JOIN packages_users ON p.id = packages_users.package_id INNER JOIN users ON packages_users.user_id = users.id"
                filters.add("users.id = $#" % queryVal)
            of nil:
                discard
            else:
                let error = errorJObject(Http400, "Invalid query parameter $#" % queryKey)
                halt(Http400, $error)

        echo("Adding name filter")
        if request.params.hasKey("name"):
            let nameFilters = mkFilters("p.name", request.params["name"])
            filters.add(nameFilters)

        if filters.len >= 1:
            statement &= " WHERE " & join(filters, " OR ")

        statement &= " GROUP BY (p.id)"
        var
            query = sql(statement)
            dbRows = toSeq(rows(db, query))


        for row in dbRows:
            var package: Package = rowToPackage(row)
            populatePackageData(db, package)
            packages.add(package)

        var package_array = newJArray()

        for package in packages:
            let package_obj = %package
            package_array.add(package_obj)

        resp($package_array, "application/json")

    get "/packages/@packageId":
        var
            packageName: string
            packageId: int
            package: Package
            headers = {"content-type": "application/json"}

        # Allow GET /packages/foo /packages/123
        try:
            packageId = parseInt(@"packageId")
        except ValueError:
            packageName = @"packageId"

        var
            ec: HttpCode = Http500
            emsg: string

        try:
            package = getPackage(db, packageId = packageId, packageName = packageName)
        except DbNotFound:
            ec = Http404
            emsg = getCurrentExceptionMsg()
        except Exception:
            emsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if emsg != nil:
            let error = errorJObject(ec, emsg)
            halt(ec, headers, $error)

        let obj = %package
        resp($obj, "application/json")

    post "/packages":
        var token = unpackToken(request.headers)
        verifyToken(token)

        let
            body = parseJson($request.body)
            headers = {"content-type": "application/json"}
            userEmail = token.claims["sub"].node.str

        var
            package: Package
            user: User
            ec: HttpCode = Http500
            emsg: string

        try:
            user = getUser(db, userEmail)
            package = jsonToPackage(body)
            createPackage(db, package, user)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            ec = e.code
            emsg = e.msg
        except Exception:
            emsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if emsg != nil:
            let error = errorJObject(ec, emsg)
            halt(ec, headers, $error)

        let obj = %package
        resp(Http201, headers, $obj)

    post "/packages/@packageId/releases":
        var token = unpackToken(request.headers)
        verifyToken(token)

        let
            body = parseJson($request.body)
            headers = {"content-type": "application/json"}

        var
            packageId: int
            packageName: string
            package: Package
            release: Release
            ec: HttpCode = Http500
            emsg: string

        # Allow GET /packages/foo /packages/123
        try:
            packageId = parseInt(@"packageId")
        except ValueError:
            packageName = @"packageId"

        try:
            package = getPackage(db, packageId, packageName)
            release = body.jsonToRelease
            createRelease(db, package.id, release)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            ec = e.code
            emsg = e.msg
        except Exception:
            emsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if emsg != nil:
            let error = errorJObject(ec, emsg)
            halt(ec, headers, $error)

        let obj = %release
        resp(Http201, headers, $obj)

    get "/packages/@packageId/releases":
        let
            headers = {"content-type": "application/json"}

        var
            packageId: int
            packageName: string
            package: Package
            releases: seq[Release]
            ec: HttpCode = Http500
            emsg: string
            objects = newJArray()

        # Allow GET /packages/foo /packages/123
        try:
            packageId = parseInt(@"packageId")
        except ValueError:
            packageName = @"packageId"

        try:
            package = getPackage(db, packageId, packageName)
            releases = getPackageReleases(db, package.id)
        except HTTPException:
            let e = (ref HTTPException)(getCurrentException())
            ec = e.code
            emsg = e.msg
        except Exception:
            emsg = "Internal error happened, contact admins!"
            echo("ERROR" & getCurrentExceptionMsg())

        if emsg != nil:
            let error = errorJObject(ec, emsg)
            halt(ec, headers, $error)

        for r in releases:
            objects.add(%r)
        resp(Http201, headers, $objects)

    get "/tags":
        let tags = getTags(db)
        let jtags = %tags
        resp($jtags, "application/json")

    post "/auth/signup":
        let body = parseJson($request.body)

        let hashed = $hashPw(body["password"].str, genSalt(12))

        var user = User(
            displayName: body["displayName"].str,
            email: body["email"].str,
            password: hashed
        )

        let query = sql("INSERT INTO users (email, password, display_name) VALUES (?, ?, ?)")
        user.id = insertId(db, query, user.email, hashed, user.displayName)

        var data = createToken(user)
        data["user"] = %user
        resp(Http200, $data)

    post "/auth/login":
        let
            body = parseJson($request.body)
            email = body["email"].str
            password = body["password"].str

        var
            user: User
            data: JsonNode

        user = getUser(db, email)
        let salt = loadPasswordSalt(user.password)
        if hashPw(password, salt) != salt:
            # TODO(ekarlso): Fix better error
            halt(Http400)

        data = createToken(user)
        data["user"] = %user
        resp(Http200, $data)

    post "/auth/github":
        var
            user: User
            dbQuery: TSqlQuery
            data: JsonNode
            dbRow: TRow

        let
            client = newAsyncHttpClient()
            body = parseJson($request.body)
            params = {
                "client_id": body["clientId"].str,
                "redirect_uri": body["redirectUri"].str,
                "code": body["code"].str,
                "client_secret": cfg["github_secret"].str
            }

        let query = mkQueryString(params)
        var cresp = await client.get(GITHUB_ACCESS_TOKEN_URL & "?" & query)
        cresp = await client.get(GITHUB_USERS_API_URL & "?" & cresp.body)

        let profile = parseJson(cresp.body)

        if request.headers.hasKey("Authorization"):
            echo("Linking accounts")

        # Existing account
        dbQuery = sql("SELECT id, email, password, display_name, github FROM users WHERE github = ?")
        dbRow = getRow(db, dbQuery, profile["id"])

        if dbRow[0] != "":
            user = rowToUser(dbRow)

            data = createToken(user)
            data["user"] = %user
            halt(Http200, $data)

        # Create new entry
        user = User(
            displayName: profile["name"].str,
            email: profile["email"].str,
            github: $profile["id"].num
        )

        dbQuery = sql("INSERT INTO users (email, display_name, github) VALUES (?, ?, ?)")
        user.id = insertId(db, dbQuery, user.email, user.displayName, user.github)

        data = createToken(user)
        data["user"] = %user
        resp(Http200, $data)

    post "/auth/tokens":
        let
            token = unpackToken(request.headers)
            body = parseJson($request.body)
            userEmail = token.claims["sub"].node.str
            headers = {"content-type": "application/json"}

        verifyToken(token)

        var
            user: User
            createdToken: JsonNode
            requestedClaims = body["claims"]
            validClaims = @["exp", "pkg"]

        user = getUser(db, userEmail)
        for key, value in requestedClaims:
            if key notin validClaims:
                raise newHttpExc(Http400, "Claim $# is not allowed." % key)

        createdToken = createToken(user, requestedClaims)
        resp(Http200, headers, $createdToken)

    get "/profile":
        var
            user: User
            token = unpackToken(request.headers)

        verifyToken(token)

        let sub = token.claims["sub"].node
        user = getUser(db, sub.str)

        let json = %user
        resp(Http200, $json)

runForever()
