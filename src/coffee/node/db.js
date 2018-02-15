/* @flow */

import * as Crypto from "crypto";

let client = null;

export function init(config, callback) {
  var conString, pg;
  pg = require("pg");
  conString = config.db;
  pg.connect(conString, function(err, cl, done) {
    if (err) {
      console.error("Error initializing database:");
      console.error(err);
    } else {
      client = cl;
      callback();
    }
  });
}

export function getRandomID() {
  return (Crypto.randomBytes(48)).toString("hex");
}

export function createPuzzle(puzzle, callback) {
  const puzzleID = getRandomID();
  client.query("INSERT INTO states (puzzleID, seq, state) VALUES ($1, 0, $2)", [puzzleID, JSON.stringify(puzzle)], function(err) {
    if (err) {
      console.error(err);
    } else {
      client.query("INSERT INTO puzzles (puzzleID, latest) VALUES ($1, 0)", [puzzleID], function(err) {
        if (err) {
          console.error(err);
        } else {
          callback(puzzleID);
        }
      });
    }
  });
}

export function loadPuzzleLatestState(puzzleID, callback) {
  client.query("SELECT state, seq FROM states WHERE puzzleID=$1 AND seq=(SELECT latest FROM puzzles WHERE puzzleID=$1)", [puzzleID], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback((result.rows.length === 0 ? null : {
        state: result.rows[0].state,
        stateID: result.rows[0].seq
      }));
    }
  });
}

export function loadPuzzleState(puzzleID, seq, callback) {
  client.query("SELECT state, seq FROM states WHERE puzzleID=$1 AND seq=$2", [puzzleID, seq], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback((result.rows.length === 0 ? null : result.rows[0].state));
    }
  });
};

export function getOpsToLatest(puzzleID, baseStateID, callback) {
  client.query("SELECT op, opID FROM states WHERE puzzleID=$1 AND seq > $2 AND seq <= (SELECT latest FROM puzzles WHERE puzzleID=$1) ORDER BY seq", [puzzleID, baseStateID], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback(result.rows.map((r) => {
        return {
          op: r.op,
          opID: r.opID
        };
      }));
    }
  });
}

export function getOpSeq(puzzleID, opID, callback) {
  client.query("SELECT seq FROM states WHERE puzzleID=$1 AND opID=$2", [puzzleID, opID], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback((result.rows.length === 0 ? null : result.rows[0].seq));
    }
  });
}

export function saveOp(puzzleID, opID, op, state, callback) {
  client.query("WITH puzz AS ( SELECT latest FROM puzzles WHERE puzzleID=$1 ), insert1 AS ( INSERT INTO states (puzzleID, seq, state, opID, op) VALUES ($1, (SELECT latest+1 FROM puzz), $2, $3, $4) ) UPDATE puzzles SET latest=(SELECT latest+1 FROM puzz) WHERE puzzleID=$1", [puzzleID, state, opID, op], function(err) {
    if (err) {
      console.error(err);
    } else {
      callback();
    }
  });
}
