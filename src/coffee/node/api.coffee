PuzzleUtils = require "../shared/puzzle_utils"
Db = require "./db"

exports.handle = (req, res) ->
    params = JSON.parse req.body['params']

    if params.type == "new"
        handleNew req, (responseData) ->
            res.send JSON.stringify responseData

handleNew = (req, callback) ->
    # TODO this is duplicated
    puzzle = PuzzleUtils.getEmptyPuzzle 15, 15, req.body.title
    Db.createPuzzle puzzle, (puzzleID) ->
        callback {success: true, url: "http://" + req.headers.host + "/puzzle/#{puzzleID}"}
