# This file defines the ClientSyncer object, which talks to the server
# and deals with syncing the puzzle state between the client's display
# and the server's copy.
#
# The ClientSyncer contains the authoritative copy that should be
# *displayed* to the user. This copy is stored in the "tip" variable
# below. The app should respond
# to user actions by calling the "localOp" function, and it should register
# a watcher to watch for when the tip changes. The tip may change either
# in respond to a localOp or when a change comes from the main server.
#
# The exposed functions are
#   addWatcher - add a callback which is called (with the new tip/op) whenever
#           the tip is changed.
#   localOp - takes an operation to apply to the tip.
#   setOffline - sets whether offline mode is on (starts in online mode).
#
# Communication with the server and conflict resolution is all internal to
# this object. It uses socket.io to connect to the server. It deals with
# abstract "states" and "operations" and uses the functions defined in
# shared/ot.coffee (e.g., operational transformation functions).
#
# It maintains three states along with two operations between them
#
#                   op_a               op_b
#           root ----------> buffer ----------> tip
#
# The root is the latest state we have received from the server.
# op_a (if non-trivial) is the last operation we sent to the server that
# we are waiting on. (We only have one outstanding operation at once.)
# The buffer is the result of that operation. Finally, op_b encapsulates
# any local changes the user has made since the last operation was sent to
# the server.
#
# When we receive an operation from the server, we check the ID of the
# operation to see if corresponds to op_a. If it does, then we know that
# the operation was received and processed by the server, and we move
# the root up to buffer.
# 
# Otherwise, the operation from the server is from some other client and
# was processed before our oustanding operation. So we have to transform
# op_a and op_b against this new operation, op_c.
#
#                               tip'
#                               / \
#                          c'' /   \ b'
#                             /     \
#                            /       \
#                          tip     buffer'
#                            \      /  \
#                           b \    /    \ a'
#                              \  / c'   \
#                               \/        \
#                              buffer    root'
#                                 \      /
#                                a \    / c
#                                   \  /
#                                    \/
#                                   root
#
# Communication with the server (node/socket_server.coffee) is as follows.
# On the initial socket.io connection, ask for the latest puzzle state
# (using a "hello" packet). The server will respond with this and in the future
# send any updates to the state as it can. The client deals with these updates
# as explained above.
#
# Meanwhile, the client can send any updates to the server using an
# "update" packet. Again, it should only have one outstanding packet at
# a time for simplicity, and the client knows an update has been received
# when it receives back an update with the matching ID.
#
# In the event of a disconnect, socket.io will automatically attempt to
# reconnect. When it does so successfully, a new session with the server
# is started. It starts by sending another "hello" packet - but this time,
# rather than just asking for the latest state, we need to ask for all
# the operations leading up to it, so that we can transform against them.
# Furthermore, if we have an outstanding packet, we don't know if it was
# received, so we re-send it (with the same ID, so the server can dismiss
# it as a duplicate if necessary).

window.ClientSyncer = (puzzleID) ->
    watchers = []

    # The states and operations that we keep track of. These start as null
    # until we receive the first response from the server.
    rootID = null
    root = null
    buffer = null
    tip = null
    op_a = null
    op_b = null

    # The ID of the update that we sent and are waiting on, or null if
    # we are not currently waiting on any update.
    outstandingID = null

    @addWatcher = (watcher) ->
        watchers.push watcher
    notifyWatchers = (newState, op) ->
        for watcher in watchers
            do (watcher) ->
                watcher newState, op

    socket = io.connect()
    connected = false

    socket.on "connecting", () ->
        console.log "socket connecting..."

    # Initial connection
    socket.on "connect", () ->
        console.log "socket connected!"
        if root == null
            # Send a initial "hello" packet asking for the latest state.
            socket.emit "hello", {
                puzzleID : puzzleID
                latest : "yes"
            }
            # A "state" message should be received in response.
        else
            # If root != null then this must be a re-connect.
            socket.emit "hello", {
                puzzleID : puzzleID
                from : rootID
            }
            # Doesn't receive a "state" in response - just a sequence of
            # updates.
            if outstandingID != null
                # We don't know if the last message was received, so resend it
                # just in case.
                resendLastUpdate()
        connected = true

    # Responses from the server.

    # The "state" update is the first one we receive, containing the state of
    # puzzle to start out.
    socket.on "state", (data) ->
        console.debug "received state message"
        rootID = data.stateID
        root = data.puzzle
        buffer = data.puzzle
        tip = data.puzzle
        op_a = Ot.identity data.puzzle
        op_b = Ot.identity data.puzzle

        # Notify the watchers. Here, op is null because this is the initial
        # state to work with - there is no old state to apply an op from.
        notifyWatchers tip, null
    
    # The server continuously sends us "update" packets with updates to be
    # be applied to the root.
    socket.on "update", (data) ->
        console.debug "received update"
        rootID = data.stateID

        # Check if the received update corresponds to the update that *we*
        # sent, or if it corresponds to an update from another client.
        if outstandingID != null and outstandingID == data.opID
            outstandingID = null
            root = buffer
            op_a = Ot.identity root
            if not Ot.isIdentity op_b
                sendUpdate()
        else
            op_c = data.op
            [op_a1, op_c1] = Ot.xform root, op_a, op_c
            [op_b1, op_c2] = Ot.xform buffer, op_b, op_c1

            root = Ot.apply root, op_c
            op_a = op_a1
            buffer = Ot.apply buffer, op_c1
            op_b = op_b1
            tip = Ot.apply tip, op_c2

            notifyWatchers tip, op_c2

    # Receive a local operation
    @localOp = (op) ->
        tip = Ot.apply tip, op
        op_b = Ot.compose buffer, op_b, op

        if outstandingID == null
            sendUpdate()

        notifyWatchers tip, op

    getID = () ->
        return ("0123456789abcdef"[Math.floor Math.random() * 16] for i in [1..48]).join ""

    # Send an update to the server, moving up the "buffer" pointer
    # (helper method called by a few methods above).
    # Store the message in updateMessage, in case we need to re-send it.
    updateMessage = null
    sendUpdate = () ->
        Utils.assert outstandingID == null
        Utils.assert Ot.isIdentity op_a
        op_a = op_b
        buffer = tip
        op_b = Ot.identity buffer
        
        id = getID()
        outstandingID = id
        updateMessage = {
            op : op_a
            opID : id
            rootID : rootID
        }
        console.log updateMessage
        if connected
            socket.emit "update", updateMessage

    resendLastUpdate = () ->
        socket.emit "update", updateMessage
    
    # Handling errors and reconnections
    socket.on "disconnect", () ->
        connected = false
        console.log "socket disconnected!"

    socket.on "reconnecting", () ->
        console.log "socket reconnecting..."

    socket.on "connecting", () ->
        console.log "socket connecting..."

    socket.on "reconnect", () ->
        console.log "socket reconnected!"

    socket.on "connect_failed", () ->
        console.log "socket connect failed! :("

    socket.on "reconnect_failed", () ->
        console.log "socket reconnect failed! :("

    # Offline mode
    isOfflineMode = false
    @setOffline = (offline) ->
        if offline and (not isOfflineMode)
            isOfflineMode = true
            socket.disconnect()
        else if (not offline) and isOfflineMode
            isOfflineMode = false
            socket.socket.reconnect()

    return this
