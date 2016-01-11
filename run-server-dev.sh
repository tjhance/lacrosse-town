#!/bin/bash

npm install

grunt browserify

nodemon --ignore node_modules -V src/coffee/node/server.coffee config/development.json
