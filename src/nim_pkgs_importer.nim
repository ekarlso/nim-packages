import docopt, json, os, re, strutils, tables

from httpclient import nil


let doc = """
Utility to import existing packages.json file.

Usage:
    nim_pkgs_importer --token=<token>  [-f FILE] [--registry-url=<url>]

    -f              JSON Packages file [default: ./packages.json].
    --token         Auth Token.
    --registry-url  Registry URL.

Options:
    -h, --help      Help message
"""

let args = docopt(doc, version="nim_pkgs_importer 0.0.1")

var
    pkgPath: string = "packages.json"
    pkgData: string
    url: string = "http://127.0.0.1:5000"
    token = $args["--token"]

if args["-f"]:
    pkgPath = $args["FILE"]
    if not existsFile(pkgPath):
        quit("Packages file $# specified, but doesn't exist.." % pkgPath)

if args["--registry-url"]:
    url = $args["--registry-url"]

if existsFile(pkgPath):
    pkgData = readFile(pkgPath)
else:
    pkgData = httpclient.getContent("https://raw.githubusercontent.com/nim-lang/packages/master/packages.json")

let
    data = parseJson(pkgData)
    licenses = httpclient.getContent(url & "/licenses")

var existingLicenses = newSeq[string]()
for license in parseJson(licenses):
    existingLicenses.add(license["name"].str)

for n in data:
    let
        name = $n["name"].str
        headers: string = "Content-Type:application/json\c\LAuthorization:Bearer $#" % token

    echo("Package:  " & $name)

    var resp = httpclient.get(url & "/packages/$#" % name)

    if resp.status.startsWith("404"):
        var
            packageJson = newJObject()
            releaseJson = newJObject()

        echo("Package $# doesn't exist, creating" % name)
        for i in @["name", "description", "license", "web", "maintainer", "tags", "repository"]:
            if n.hasKey(i):
                packageJson[i] = n[i]
            else:
                packageJson[i] = %"N/A"
            packageJson["repository"] = n["url"]

        let
            license = n["license"].str

        if license notin existingLicenses:
            echo("License $# missing, creating" % license)
            let licenseJson = %{"name": %license}
            resp = httpclient.post(url & "/licenses", headers, $licenseJson)
            if not resp.status.startsWith("201"):
                quit("Failed creating license... aborting")
            existingLicenses.add(license)

        resp = httpclient.post(url & "/packages", headers, $packageJson)
        if not resp.status.startsWith("201"):
            quit("Failed creating package... aborting")
    else:
        echo("Package $# exists, skipping..")
