#!/bin/bash

npm install

grunt babel
#grunt browserify

nodemon --ignore node_modules -V src/compiled/node/server.js config/development.json
