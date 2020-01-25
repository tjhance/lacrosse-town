#!/bin/bash

set -e

npm install

grunt ts
grunt browserify

nodemon --ignore node_modules -V src/compiled/node/server.js config/development.json
