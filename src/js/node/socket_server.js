/* @flow */

// This is the server side of the puzzle syncing process. (The client side is in
// client/state.js.)
//
// We maintain a bucket (a ServerSyncer object) of socket connections for each
// puzzle. For each new connection, we wait for the "hello" packet. This packet
// tells us which puzzle the connection is for, and then we put it in that bucket
// (creating it if necessary).
//
// The ServerSyncer's job is actually pretty easy compared to the clients.
// It just has to receive updates from clients, save them, and send them back
// out. For each puzzle, the server maintains a sequence of operations leading up
// to the latest state. When the server receives a new operation from a client,
// it checks which version of the puzzle the operation is rooted at. It then
// transforms the new operation up so that it is rooted at the latest puzzle.
// It then saves this new operation and broadcasts it to all the connected
// clients.

// TODO clean up broken connections
// TODO check that received messages are well-formed
// TODO handle errors

import * as db from "./db";
import * as Ot from "../shared/ot";

import type {PuzzleState} from "../shared/types";

// Takes a single argument, the listener socket.
export function init(socket_listener: any) {
  // Initialize an empty list of buckets.
  const connection_buckets = {}

  socket_listener.on("connection", (socket) => {
    console.debug("New connection");

    // On each new connection, wait for the "hello" packet to be received.
    socket.on("hello", (data) => {
      // Now we know which puzzle the connection is for. Add the connection
      // to the bucket.
      if (!(data.puzzleID in connection_buckets)) {
        connection_buckets[data.puzzleID] = new ServerSyncer(data.puzzleID, () => {
          // This callback is called when the bucket is ready to delete itself.
          delete connection_buckets[data.puzzleID];
          console.debug(`Deleted bucket ${data.puzzleID}`);
        });
        console.debug(`Created bucket ${data.puzzleID}`);
      }
      console.debug(`Adding connection to bucket ${data.puzzleID}`);
      connection_buckets[data.puzzleID].addConnection(socket, data);
    });
  });
}

// Each ServerSyncer bucket needs to execute a bunch of things in series.
// This is an object to help with that - you push tasks, and they get
// executed in the order pushed (FIFO queue). 
// Each task pushed is a function which takes a callback - call the callback
// when the task is complete.
class AsyncQueue {
  bottom: any = null;
  top: any = null;

  push(fn) {
    if (this.top === null) {
      this.top = this.bottom = {
        fn: fn,
        next: null,
      };
      this.call(fn);
    } else {
      if (!this.bottom) {
        throw new Error('invariant error: bottom should be non-null');
      }
      this.bottom.next = {
        fn: fn,
        next: null,
      };
      this.bottom = this.bottom.next;
    }
  }
  
  call(fn) {
    fn(() => {
      if (!this.top) {
        throw new Error('invariant error: top should be non-null');
      }

      this.top = this.top.next;
      if (this.top === null) {
        this.bottom = null;
      } else {
        this.call(this.top.fn);
      }
    });
  }
}

class ServerSyncer {
  latestStateID: number;
  latestState: PuzzleState;

  // list of objects:
  //   socket: socket.io object
  //   id: unique id, shared with the clients
  //   cursor: current cursor
  connections = [];
  
  // All important tasks are done through the queue.
  queue = new AsyncQueue();

  // Used to assign ids to the connected clients 
  idCounter = 1;

  puzzleID: string;

  constructor(puzzleID, callbackOnClose) {
    this.puzzleID = puzzleID;

    // Start by loading in the latest puzzle state from memory.
    this.queue.push((callback) => {
      db.loadPuzzleLatestState(puzzleID, (puzzle) => {
        if (puzzle === null) {
          // puzzle does not exist
          for (const conn of this.connections) {
            conn.socket.disconnect();
          }
          callbackOnClose();
        } else {
          this.latestState = puzzle.state;
          this.latestStateID = puzzle.stateID;
          callback();
        }
      });
    });
  }

  addConnection(socket, data) {
    const conn = {
      socket: socket,
      id: this.idCounter,
      cursor: null,
    };
    this.idCounter += 1;

    // For the new connection, you need to
    //   - Add it to the connections list.
    //   - If it asks for the lastest state, just send it the latest state.
    //   - If it asks for all operations from a given state, fetch those
    //   operations and send them.
    // All atomically, of course (that's what the AsyncQueue is for...)
    // (For example, you don't want to add it to the connection list before
    // sending these operations - or else it might send updates in the wrong
    // order.)
    this.queue.push((callback) => {
      this.connections.push(conn);

      if (data.latest === "yes") {
        // NOTE: unused currently; clients always start with
        // a state.
        socket.emit("state", {
          stateID: this.latestStateID,
          puzzle: this.latestState,
        });
        callback();
      } else {
        db.getOpsToLatest(this.puzzleID, data.from, (ops) => {
          let i = data.from + 1
          for (const op of ops) {
            socket.emit("update", {
              stateID: i,
              opID: op.opID,
              op: op.op,
            });
            i++;
          }
          socket.emit("update_cursor", {
            cursor_updates: this.connections.map((conn) => {
              return {id: conn.id, cursor: conn.cursor};
            }),
          });
          callback();
        });
      }
    });

    // What to do when you receive an "update" packet from the client.
    socket.on("update", (update_data) => {
      console.debug(`Received update ${update_data.opID} rooted at ${update_data.rootID}`);

      this.queue.push((callback) => {
        this.doesOpExist(update_data.opID, (exists) => {
          if (exists) {
            // If the operation has already been received, ignore it.
            // We're done here.
            callback();
          } else {
            // Otherwise, it's a new update that we have to process.
            // First, load the puzzle state that the operation is rooted at.
            // Then, load the operations that lead from that state to the
            // latest state.
            db.loadPuzzleState(this.puzzleID, update_data.rootID, (rootState) => {
              db.getOpsToLatest(this.puzzleID, update_data.rootID, (ops) => {
                let newOp = update_data.op;
                // TODO check for rootState being null
                // $FlowFixMe
                let newState: PuzzleState = rootState;
                // Transform the new operation against the operations
                // that already exist.
                for (const op of ops) {
                  const [a1, _] = Ot.xform(newState, newOp, op.op);
                  newState = Ot.apply(newState, op.op);
                  newOp = a1;
                }
                // TODO check for null
                newState = Ot.apply(this.latestState, newOp);
                // Save the new (transformed) op and the new state.
                db.saveOp(this.puzzleID, update_data.opID, newOp, newState, () => {
                  conn.cursor = update_data.cursor;

                  // Tell all the connections about the new update.
                  this.broadcast("update", {
                    stateID: this.latestStateID + 1,
                    opID: update_data.opID,
                    op: newOp,
                    cursor_updates: [
                      {
                        user_id: conn.id,
                        cursor: conn.cursor,
                      }
                    ],
                  });
                  this.latestState = newState;
                  this.latestStateID++;
                  callback();
                });
              });
            });
          }
        });
      });
    });

    socket.on("cursor_update", (update_data) => {
      conn.cursor = update_data.cursor;
      this.broadcast_except(conn, "update_cursor", {
        cursor_updates: [
          {
            user_id: conn.id,
            cursor: conn.cursor,
          }
        ]
      });
    });
  }

  doesOpExist(opID, callback) {
    db.getOpSeq(this.puzzleID, opID, (op) => {
      callback(op !== null);
    });
  }

  broadcast(msg, data) {
    this.broadcast_except(null, msg, data);
  }

  broadcast_except(connExc, msg, data) {
    for (const conn of this.connections) {
      if (conn !== connExc) {
        conn.socket.emit(msg, data);
      }
    }
  }
}
