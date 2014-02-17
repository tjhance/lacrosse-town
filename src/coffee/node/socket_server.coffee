# This is the server side of the puzzle syncing process. (The client side is in
# client/state.coffee.)
#
# We maintain a bucket (a ServerSyncer object) of socket connections for each
# puzzle. For each new connection, we wait for the "hello" packet. This packet
# tells us which puzzle the connection is for, and then we put it in that bucket
# (creating it if necessary).
#
# The ServerSyncer's job is actually pretty easy compared to the clients.
# It just has to receive updates from clients, save them, and send them back
# out. For each puzzle, the server maintains a sequence of operations leading up
# to the latest state. When the server receives a new operation from a client,
# it checks which version of the puzzle the operation is rooted at. It then
# transforms the new operation up so that it is rooted at the latest puzzle.
# It then saves this new operation and broadcasts it to all the connected
# clients.

# TODO clean up broken connections
# TODO check that received messages are well-formed
# TODO handle errors

db = require "./db"
Ot = require "../shared/ot"

# Takes a single argument, the listener socket.
exports.init = (socket_listener) ->
    # Initialize an empty list of buckets.
    connection_buckets = {}

    socket_listener.on "connection", (socket) ->
        console.debug "New connection"

        # On each new connection, wait for the "hello" packet to be received.
        socket.on "hello", (data) ->
            # Now we know which puzzle the connection is for. Add the connection
            # to the bucket.
            if data.puzzleID not of connection_buckets
                connection_buckets[data.puzzleID] = new ServerSyncer data.puzzleID, () ->
                    # This callback is called when the bucket is ready to delete itself.
                    delete connection_buckets[data.puzzleID]
                    console.debug "Deleted bucket #{data.puzzleID}"
                console.debug "Created bucket #{data.puzzleID}"
            console.debug "Adding connection to bucket #{data.puzzleID}"
            connection_buckets[data.puzzleID].addConnection socket, data

# Each ServerSyncer bucket needs to execute a bunch of things in series.
# This is an object to help with that - you push tasks, and they get
# executed in the order pushed (FIFO queue). 
# Each task pushed is a function which takes a callback - call the callback
# when the task is complete.
AsyncQueue = () ->
    top = null
    bottom = null

    @push = (fn) ->
        if top == null
            top = bottom = {
                fn : fn
                next : null
            }
            call fn
        else
            bottom.next = {
                fn : fn
                next : null
            }
            bottom = bottom.next
    
    call = (fn) ->
        fn () ->
            top = top.next
            if top == null
                bottom = null
            else
                call top.fn

    return this

ServerSyncer = (puzzleID, callbackOnClose) ->
    latestStateID = null
    latestState = null

    # list of objects:
    #   socket: socket.io object
    #   maybe other fields later?
    connections = []
    
    # All important tasks are done through the queue.
    queue = new AsyncQueue()

    # Start by loading in the latest puzzle state from memory.
    queue.push (callback) ->
        db.loadPuzzleLatestState puzzleID, (puzzle) ->
            if puzzle == null
                # puzzle does not exist
                for conn in connections
                    conn.disconnect()
                callbackOnClose()
            else
                latestState = puzzle.state
                latestStateID = puzzle.stateID
                callback()

    @addConnection = (socket, data) ->
        conn = {
            socket : socket
        }

        # For the new connection, you need to
        #   - Add it to the connections list.
        #   - If it asks for the lastest state, just send it the latest state.
        #   - If it asks for all operations from a given state, fetch those
        #     operations and send them.
        # All atomically, of course (that's what the AsyncQueue is for...)
        # (For example, you don't want to add it to the connection list before
        # sending these operations - or else it might send updates in the wrong
        # order.)
        queue.push (callback) ->
            connections.push conn

            if data.latest == "yes"
                socket.emit "state", {
                    stateID : latestStateID
                    puzzle : latestState
                }
                callback()
            else
                db.getOpsToLatest puzzleID, data.from, (ops) ->
                    i = data.from
                    for op in ops
                        socket.emit "update", {
                            stateID : i
                            opID : op.opID
                            op : op.op
                        }
                        i++
                    callback()

        # What to do when you receive an "update" packet from the client.
        socket.on "update", (update_data) ->
            console.debug "Received update #{update_data.opID} rooted at #{update_data.rootID}"

            queue.push (callback) ->
                doesOpExist update_data.opID, (exists) ->
                    if exists
                        # If the operation has already been received, ignore it.
                        # We're done here.
                        callback()
                    else
                        # Otherwise, it's a new update that we have to process.
                        # First, load the puzzle state that the operation is rooted at.
                        # Then, load the operations that lead from that state to the
                        # latest state.
                        db.loadPuzzleState puzzleID, update_data.rootID, (rootState) ->
                            db.getOpsToLatest puzzleID, update_data.rootID, (ops) ->
                                newOp = update_data.op
                                newState = rootState
                                # Transform the new operation against the operations
                                # that already exist.
                                for op in ops
                                    x = Ot.xform newState, newOp, op.op
                                    newState = Ot.apply newState, op.op
                                    newOp = x.a1
                                newState = Ot.apply latestState, newOp
                                # Save the new (transformed) op and the new state.
                                db.saveOp puzzleID, update_data.opID, newOp, newState, () ->
                                    # Tell all the connections about the new update.
                                    broadcast "update", {
                                        stateID : latestStateID
                                        opID : update_data.opID
                                        op: newOp
                                    }
                                    latestState = newState
                                    latestStateID++
                                    callback()

    doesOpExist = (opID, callback) ->
        db.getOpSeq puzzleID, opID, (op) ->
            callback op != null

    broadcast = (msg, data) ->
        for conn in connections
            do (conn) ->
                conn.socket.emit msg, data

    return this
