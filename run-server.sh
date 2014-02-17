cd `dirname $0`/src
npm install
coffee --compile --output static/js/ coffee/client/
coffee --compile --output static/js-shared/ coffee/shared/
nodemon coffee/node/server.coffee
