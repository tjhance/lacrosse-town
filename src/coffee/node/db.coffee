# TODO error handling

Crypto = require "crypto"

client = null

exports.init = (config, callback) ->
    pg = require "pg"
    conString = config.db

    pg.connect conString, (err, cl, done) ->
        if err
            console.error "Error initializing database:"
            console.error err
        else
            client = cl
            callback()

getRandomID = () ->
    (Crypto.randomBytes 48).toString "hex"

exports.createPuzzle = (puzzle, callback) ->
    puzzleID = getRandomID()
    client.query "INSERT INTO states (puzzleID, seq, state) VALUES ($1, 0, $2)",
        [ puzzleID, JSON.stringify puzzle ]
        (err) ->
            if err
                console.error err
            else
                client.query "INSERT INTO puzzles (puzzleID, latest) VALUES ($1, 0)",
                    [ puzzleID ]
                    (err) ->
                        if err
                            console.error err
                        else
                            callback(puzzleID)

exports.loadPuzzleLatestState = (puzzleID, callback) ->
    client.query """SELECT state, seq FROM states WHERE puzzleID=$1 AND
                    seq=(SELECT latest FROM puzzles WHERE puzzleID=$1)""",
        [ puzzleID ]
        (err, result) ->
            if err
                console.error err
            else
                callback (if result.rows.length == 0 then null else {
                    state: result.rows[0].state
                    stateID: result.rows[0].seq
                })

exports.loadPuzzleState = (puzzleID, seq, callback) ->
    client.query "SELECT state, seq FROM states WHERE puzzleID=$1 AND seq=$2",
        [ puzzleID, seq ]
        (err, result) ->
            if err
                console.error err
            else
                callback (if result.rows.length == 0 then null else result.rows[0].state)

exports.getOpsToLatest = (puzzleID, baseStateID, callback) ->
    client.query """SELECT op, opID FROM states WHERE puzzleID=$1 AND
                    seq > $2 AND
                    seq <= (SELECT latest FROM puzzles WHERE puzzleID=$1)
                    ORDER BY seq""",
        [ puzzleID, baseStateID ]
        (err, result) ->
            if err
                console.error err
            else
                callback ({
                    op: r.op
                    opID: r.opID
                } for r in result.rows)

exports.getOpSeq = (puzzleID, opID, callback) ->
    client.query "SELECT seq FROM states WHERE puzzleID=$1 AND opID=$2",
        [ puzzleID, opID]
        (err, result) ->
            if err
                console.error err
            else
                callback (if result.rows.length == 0 then null else result.rows[0].seq)

exports.saveOp = (puzzleID, opID, op, state, callback) ->
    client.query """
        WITH puzz AS (
                SELECT latest FROM puzzles WHERE puzzleID=$1
            ), insert1 AS (
                INSERT INTO states (puzzleID, seq, state, opID, op)
                            VALUES ($1, (SELECT latest+1 FROM puzz), $2, $3, $4)
            ) UPDATE puzzles SET latest=(SELECT latest+1 FROM puzz) WHERE puzzleID=$1""",
        [ puzzleID, state, opID, op ],
        (err) ->
            if err
                console.error err
            else
                callback()
