/* @flow */

// The HTTP server.

const express = require("express");

import * as http from "http";
import * as socket_io from "socket.io";

import * as Api from "./api";
import * as Db from "./db";
import * as FindMatches from "./find_matches";
import * as Utils from "../shared/utils";
import * as PuzzleUtils from "../shared/puzzle_utils";
import * as SocketServer from "./socket_server";

import type {Config} from './types';

export function init(config: Config, callback: () => void) {
  const app = express();

  // compression
  app.use(express.compress());

  // Set up logging.
  app.use(express.logger());

  // Need this to parse the body of POST requests.
  app.use(express.bodyParser());

  // Serve static content from the static/ directory.
  // (javascript, CSS, etc.)
  const STATIC_ROOT = `${__dirname}/../../static/`;
  app.use("/static", express.static(STATIC_ROOT));

  // These next few requests use `sendAppWithData`, which renders
  // a basic 'app' page: with one configureable variable, a JS object
  // called PAGE_DATA.
  // The 'app' routes itself via the URL.

  // /new/
  app.get(/\/new/, function(req, res) {
    return sendAppWithData(res, null);
  });
  app.get('/', function(req, res) {
    return sendAppWithData(res, null);
  });

  // /puzzle/${puzzle id}
  app.get(/^\/puzzle\/(.*)/, function(req, res) {
    const puzzleID = req.params[0];
    return Db.loadPuzzleLatestState(puzzleID, function(puzzle) {
      if (puzzle === null) {
        return res.status(404).send('Puzzle not found');
      } else {
        const data = {
          puzzle: puzzle.state,
          stateID: puzzle.stateID,
        };
        return sendAppWithData(res, data);
      }
    });
  });

  // /new/ POST request
  // Creates a new puzzle with a random ID and saves it, then redicts to
  // the puzzle page.
  app.post(/\/new/, function(req, res) {
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

  // $FlowFixMe
  const server = http.Server(app);
  const socket_listener = socket_io.listen(server);
  SocketServer.init(socket_listener);

  // Start listening.
  const port = config.port;
  server.listen(port);
  console.info(`Initialized webserver on port ${port}`);

  return callback();
}

// TODO need a template system...
const APP_TEMPLATE = `<!doctype html>
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
    <script type="text/javascript" src="/static/lib/js/ua-parser.js"></script>

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
</html>`;

function sendAppWithData(res, data) {
  const jsonData = JSON.stringify(data);
  const encodedData = encodeURIComponent(jsonData);
  const html = APP_TEMPLATE.replace('REPLACE_ME', encodedData);
  res.header("Content-Type", "text/html");
  return res.send(html);
}
