/* @flow */

import * as PuzzleUtils from "../shared/puzzle_utils";
import * as Db from "./db";

export function handle(req: any, res: any) {
  const params = JSON.parse(req.body['params']);
  if (params.type === "new") {
    return handleNew(req, function(responseData) {
      return res.send(JSON.stringify(responseData));
    });
  }
}

function handleNew(req, callback) {
  // TODO this is duplicated
  const puzzle = PuzzleUtils.getEmptyPuzzle(15, 15, req.body.title);
  return Db.createPuzzle(puzzle, function(puzzleID) {
    return callback({
      success: true,
      url: "http://" + req.headers.host + `/puzzle/${puzzleID}`,
    });
  });
}
