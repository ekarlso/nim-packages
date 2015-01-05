import httpclient, json, parseopt
import os

let path = "packages.json"
var pkgData: string

if existsFile(path):
    pkgData = readFile(path)
else:
    pkgData = getContent("https://raw.githubusercontent.com/nim-lang/packages/master/packages.json")

let data = parseJson(pkgData)

for n in data:
    let j = newJObject()

    let name = $n["name"]
    echo("Doing package " & $name)

    for i in @["name", "url", "tags", "description", "license", "web", "maintainer"]:
        if n.hasKey(i):
            j[i] = n[i]
        else:
            j[i] = %"N/A"

    echo ($j)
    try:
        let headers: string = "Content-Type:application/json;\c\L"
        let resp = postContent("http://127.0.0.1:5000/packages", headers, $j)
    except:
        let msg = getCurrentExceptionMsg()
        echo ($msg)
