cd `dirname $0`/src
npm install

grunt cjsx
grunt coffee
#coffee --compile --output static/js/ coffee/client/
#coffee --compile --output static/js-shared/ coffee/shared/

nodemon -V coffee/node/server.coffee
