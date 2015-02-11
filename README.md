# Nim package registry

A package registry for Nim Lang.

It consists of two parts, a API and a one page app built in angularjs.

# API

## Bootstrap Database

sqlite packages.sqlite < schema.sql

## Install

To install the nimble app run the following:

```bash
nimble install -y
```

## Running the app

Run the compiled app

```
./src/nim_pkgs.nim
```

You can also run the app by just using *nim*.

```bash
nim c --run src/nim_pkgs.nim
```

# Angular App

You will *nodejs* installed for this to work.

To get *nodejs* see https://github.com/creationix/nvm

## Install bower and gulp

```bash
npm install -g bower gulp
```

## Install all node_module deps

```bash
npm install
```

## Run the development server

This will start a development server that will proxy all calls to the backend
*nim* service on port *5000*. It will also build the app.

gulp serve

# Example usage
http --verify=no post https://nim-pkg.svcs.io/auth/signup email=john@doe.name password=secret displayName="John Doe"
http --verify=no post https://nim-pkg.svcs.io/auth/login email=john@doe.name password=secret

