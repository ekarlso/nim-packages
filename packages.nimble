[Package]
name        = "packages"
version     = "0.0.1"
author      = "Endre Karlson"
description = "Package registry for Nim Lang"
license     = "BSD"

bin = "packages"
srcDir = "src"

[Deps]
Requires: "jester"
Requires: "easy-bcrypt <= 2.0.2"
Requires: "uuid"
Requires: "jwt"
Requires: "docopt"