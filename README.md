# Nim package registry

A package registry for Nim Lang.

It consists of two parts, a API and a one page app built in angularjs.

# API

## Install

To install the nimble app run the following:

```bash
nimble install -y
```

## Running the app

You can also run the app by just using *nim*.

```bash
nim c --run src/package.nim
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