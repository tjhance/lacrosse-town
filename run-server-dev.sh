#!/bin/bash

set -e

npm install
nvm use 6.10.0

grunt babel
grunt browserify

nodemon --ignore node_modules -V src/compiled/node/server.js config/development.json
