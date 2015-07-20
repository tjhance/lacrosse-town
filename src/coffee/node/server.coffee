# Initialize everything.

log4js = require 'log4js'
async = require 'async'
npm = require 'npm'
fs = require 'fs'

log4js.replaceConsole()

# Read the config file from the command-line argument
if process.argv.length != 3
    console.log "Expected: one argument, config filename (e.g. 'config/development.json')"
    process.exit(1)
configFilename = process.argv[2]
config = JSON.parse(fs.readFileSync(configFilename))

async.waterfall [
    (callback) ->
        npm.load {}, (err) -> callback err

    (callback) ->
        db = require './db'
        db.init config, () ->
            console.info 'Initialized database'
            callback()

    (callback) ->
        http_server = require './http_server'
        http_server.init config, () ->
            callback()
    
    () ->
        null
]
