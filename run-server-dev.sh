#!/bin/bash

npm install

grunt cjsx
grunt coffee
#coffee --compile --output static/js/ coffee/client/
#coffee --compile --output static/js-shared/ coffee/shared/

nodemon --ignore node_modules -V src/coffee/node/server.coffee config/development.json
