// The HTTP server.

const express = require("express");
const compression = require("compression");
const morgan = require("morgan"); // previously 'logger'
const bodyParser = require("body-parser");

import * as http from "http";
import * as socket_io from "socket.io";

import * as Api from "./api";
import * as Db from "./db";
import * as FindMatches from "./find_matches";
import * as PuzzleUtils from "../shared/puzzle_utils";
import * as SocketServer from "./socket_server";

import {Config} from './types';

export function init(config: Config, callback: () => void) {
  const app = express();

  // compression
  app.use(compression());

  // Set up logging.
  app.use(morgan('tiny'));

  // Need this to parse the body of POST requests.
  app.use(bodyParser.urlencoded({extended: false}));

  // Serve static content from the static/ directory.
  // (javascript, CSS, etc.)
  const STATIC_ROOT = `${__dirname}/../../static/`;
  app.use("/static", express.static(STATIC_ROOT));

  // These next few requests use `sendAppWithData`, which renders
  // a basic 'app' page: with one configureable variable, a JS object
  // called PAGE_DATA.
  // The 'app' routes itself via the URL.

  // /new/
  app.get(/\/new/, function(req:any, res:any) {
    return sendAppWithData(res, null, config);
  });
  app.get('/', function(req:any, res:any) {
    return sendAppWithData(res, null, config);
  });

  // /puzzle/${puzzle id}
  app.get(/^\/puzzle\/(.*)/, function(req:any, res:any) {
    const puzzleID = req.params[0];
    return Db.loadPuzzleLatestState(puzzleID, function(puzzle) {
      if (puzzle === null) {
        return res.status(404).send('Puzzle not found');
      } else {
        const data = {
          puzzle: puzzle.state,
          stateID: puzzle.stateID,
        };
        return sendAppWithData(res, data, config);
      }
    });
  });

  // /new/ POST request
  // Creates a new puzzle with a random ID and saves it, then redicts to
  // the puzzle page.
  app.post(/\/new/, function(req:any, res:any) {
    if ((req.body != null) && (req.body.title != null)) {
      const puzzle = PuzzleUtils.getEmptyPuzzle(15, 15, req.body.title);
      return Db.createPuzzle(puzzle, function(puzzleID) {
        return res.redirect(`/puzzle/${puzzleID}`);
      });
    }
  });

  app.post(/^\/find-matches\/.*/, FindMatches.handle);
  app.post(/^\/api/, Api.handle);

  // Set up the socket.io server, which the puzzle view talks to in order to
  // sync the puzzles.

  const server = (http.Server as any)(app);
  const socket_listener = socket_io.listen(server);
  SocketServer.init(socket_listener);

  // Start listening.
  const port = config.port;
  server.listen(port);
  console.info(`Initialized webserver on port ${port}`);

  return callback();
}

// TODO need a template system...
function getHtml(encodedData: string, config: Config) {
  const reactType = config.production ? 'production.min' : 'development';

  return `<!doctype html>
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
    <script type="text/javascript" src="/static/lib/js/react/react.` + reactType + `.js"></script>
    <script type="text/javascript" src="/static/lib/js/react/react-dom.` + reactType + `.js"></script>
    <script type="text/javascript" src="/static/lib/js/ua-parser.js"></script>
    <script type="text/javascript">
      var require = function(name) { return {'react': React, 'react-dom': ReactDOM }[name]; };
    </script>

    <!-- non-static data for the page -->
    <script type="text/javascript">
        var PAGE_DATA = JSON.parse(decodeURIComponent("` + encodedData + `"));
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
</html>`;
}

function sendAppWithData(res:any, data:any, config:any) {
  const jsonData = JSON.stringify(data);
  const encodedData = encodeURIComponent(jsonData);
  const html = getHtml(encodedData, config);
  res.header("Content-Type", "text/html");
  return res.send(html);
}
