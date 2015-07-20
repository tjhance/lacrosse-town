# The HTTP server.

Db = require "./db"
Utils = require "../shared/utils"
PuzzleUtils = require "../shared/puzzle_utils"

exports.init = (config, callback) ->
    express = require "express"
    app = express()

    # Set up logging.
    app.use express.logger()

    # Need this to parse the body of POST requests.
    app.use express.bodyParser()

    # Serve static content from the static/ directory.
    # (javascript, CSS, etc.)
    STATIC_ROOT = "#{__dirname}/../../static/"
    app.use "/static", express.static STATIC_ROOT

    # /new/
    # Just return index.html.
    # AngularJS will load the correct template.
    app.get /\/new/, (req, res) ->
        res.sendfile "index.html", {root:STATIC_ROOT}

    # /puzzle/${puzzle id}
    # Again, just return index.html.
    app.get /^\/puzzle\/.*/, (req, res) ->
        res.sendfile "index.html", {root:STATIC_ROOT}

    # /new/ POST request
    # Creates a new puzzle with a random ID and saves it, then redicts to
    # the puzzle page.
    app.post /\/new/, (req, res) ->
        if req.body? and req.body.title?
            puzzle = PuzzleUtils.getEmptyPuzzle 15, 15, req.body.title
            Db.createPuzzle puzzle, (puzzleID) ->
                res.redirect "/puzzle/#{puzzleID}"

    # Set up the socket.io server, which the puzzle view talks to in order to
    # sync the puzzles.
    server = (require "http").Server app
    socket_listener = (require "socket.io").listen server
    socket_server = require "./socket_server"
    socket_server.init socket_listener

    # Start listening.
    port = config.port
    server.listen port
    console.info "Initialized webserver on port #{port}"

    callback()
