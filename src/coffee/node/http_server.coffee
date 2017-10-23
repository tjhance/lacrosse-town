# The HTTP server.

Api = require "./api"
Db = require "./db"
FindMatches = require "./find_matches"
Utils = require "../shared/utils"
PuzzleUtils = require "../shared/puzzle_utils"

exports.init = (config, callback) ->
    express = require "express"
    app = express()

    # compression
    app.use express.compress()

    # Set up logging.
    app.use express.logger()

    # Need this to parse the body of POST requests.
    app.use express.bodyParser()

    # Serve static content from the static/ directory.
    # (javascript, CSS, etc.)
    STATIC_ROOT = "#{__dirname}/../../static/"
    app.use "/static", express.static STATIC_ROOT

    # These next few requests use `sendAppWithData`, which renders
    # a basic 'app' page: with one configureable variable, a JS object
    # called PAGE_DATA.
    # The 'app' routes itself via the URL.

    # /new/
    app.get /\/new/, (req, res) ->
        sendAppWithData(res, null)

    # /puzzle/${puzzle id}
    app.get /^\/puzzle\/(.*)/, (req, res) ->
        puzzleID = req.params[0]
        Db.loadPuzzleLatestState puzzleID, (puzzle) ->
            if puzzle == null
                res.status(404).send('Puzzle not found')
            else
                data =
                    puzzle: puzzle.state
                    stateID: puzzle.stateID
                sendAppWithData(res, data)

    # /new/ POST request
    # Creates a new puzzle with a random ID and saves it, then redicts to
    # the puzzle page.
    app.post /\/new/, (req, res) ->
        if req.body? and req.body.title?
            puzzle = PuzzleUtils.getEmptyPuzzle 15, 15, req.body.title
            Db.createPuzzle puzzle, (puzzleID) ->
                res.redirect "/puzzle/#{puzzleID}"

    app.post /^\/find-matches\/.*/, FindMatches.handle
    app.post /^\/api/, Api.handle

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

# TODO need a template system...

APP_TEMPLATE = '<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Lacross Town - Collaborative Crossword Solving Editor</title>

    <!-- favicon -->
    <link rel="shortcut icon" type="image/x-icon" href="/static/images/favicon.ico" />

    <!-- stylesheets -->
    <link rel="stylesheet" type="text/css" href="/static/css/style.css" />

    <!-- javascript libraries -->
	<script type="text/javascript" src="/static/lib/js/jquery/jquery.js"></script>
    <script type="text/javascript" src="/socket.io/socket.io.js"></script>
    <script type="text/javascript" src="/static/lib/js/react/react.js"></script>

    <!-- non-static data for the page -->
    <script type="text/javascript">
        var PAGE_DATA = JSON.parse(decodeURIComponent("REPLACE_ME"));
    </script>

    <!-- javascript app code -->
    <script type="text/javascript" src="/static/bundle.js"></script>
  </head>
  <body>
    <div class="view-container"></div>
    <script type="text/javascript">
        window.initApp();
    </script>
  </body>
</html>'

sendAppWithData = (res, data) ->
    jsonData = JSON.stringify(data)
    encodedData = encodeURIComponent(jsonData)
    html = APP_TEMPLATE.replace('REPLACE_ME', encodedData)
    res.header("Content-Type", "text/html")
    res.send(html)
