./node_modules/grunt-cli/bin/grunt -v ts
./node_modules/grunt-cli/bin/grunt -v browserify

# generate a config file using the info passed in through environment variables
config=config/temp-config-heroku.json
echo "{\"production\": true, \"db\": \"$DATABASE_URL\", \"port\": \"$PORT\"}" > $config

# start the server
NODE_ENV=production node src/compiled/node/server.js $config
