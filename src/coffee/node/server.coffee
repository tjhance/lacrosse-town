# Initialize everything.

log4js = require 'log4js'
async = require 'async'
npm = require 'npm'

log4js.replaceConsole()

async.waterfall [
    (callback) ->
        npm.load {}, (err) -> callback err

    (callback) ->
        db = require './db'
        db.init () ->
            console.info 'Initialized database'
            callback()

    (callback) ->
        http_server = require './http_server'
        http_server.init () ->
            callback()
    
    () ->
        null
]
