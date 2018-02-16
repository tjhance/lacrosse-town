/* @flow */

import * as Crypto from "crypto";
import type {Config} from './types';
import type {PuzzleState} from '../shared/types';
import type {Operation} from '../shared/ot';

let client: any = null;

export function init(config: Config, callback: () => void) {
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

export function createPuzzle(puzzle: PuzzleState, callback: (string) => void): void {
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

export function loadPuzzleLatestState(puzzleID: string, callback: (null | {state: PuzzleState, stateID: number}) => void): void {
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

export function loadPuzzleState(puzzleID: string, seq: number, callback: (PuzzleState | null) => void): void {
  client.query("SELECT state, seq FROM states WHERE puzzleID=$1 AND seq=$2", [puzzleID, seq], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback((result.rows.length === 0 ? null : result.rows[0].state));
    }
  });
};

export function getOpsToLatest(puzzleID: string, baseStateID: string,
        callback: ({op: Operation, opID: string}[]) => void): void {
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

export function getOpSeq(puzzleID: string, opID: string, callback: (number | null) => void): void {
  client.query("SELECT seq FROM states WHERE puzzleID=$1 AND opID=$2", [puzzleID, opID], function(err, result) {
    if (err) {
      console.error(err);
    } else {
      callback((result.rows.length === 0 ? null : result.rows[0].seq));
    }
  });
}

export function saveOp(puzzleID: string, opID: string, op: Operation, state: PuzzleState, callback:() => void): void {
  client.query("WITH puzz AS ( SELECT latest FROM puzzles WHERE puzzleID=$1 ), insert1 AS ( INSERT INTO states (puzzleID, seq, state, opID, op) VALUES ($1, (SELECT latest+1 FROM puzz), $2, $3, $4) ) UPDATE puzzles SET latest=(SELECT latest+1 FROM puzz) WHERE puzzleID=$1", [puzzleID, state, opID, op], function(err) {
    if (err) {
      console.error(err);
    } else {
      callback();
    }
  });
}
