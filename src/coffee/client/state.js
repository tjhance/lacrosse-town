/* @flow */

// This file defines the ClientSyncer object, which talks to the server
// and deals with syncing the puzzle state between the client's display
// and the server's copy.

// The ClientSyncer contains the authoritative copy that should be
// *displayed* to the user. This copy is stored in the "tip" variable
// below. The app should respond
// to user actions by calling the "localOp" function, and it should register
// a watcher to watch for when the tip changes. The tip may change either
// in respond to a localOp or when a change comes from the main server.

// The exposed functions are
//   addWatcher - add a callback which is called (with the new tip/op) whenever
//           the tip is changed.
//   localOp - takes an operation to apply to the tip.
//   setOffline - sets whether offline mode is on (starts in online mode).
//   loadInitialData - sets the initial state of the puzzle
//       (the initial puzzle state is embedded in the page)

// Communication with the server and conflict resolution is all internal to
// this object. It uses socket.io to connect to the server. It deals with
// abstract "states" and "operations" and uses the functions defined in
// shared/ot.coffee (e.g., operational transformation functions).

// It maintains three states along with two operations between them

//                   op_a               op_b
//           root ----------> buffer ----------> tip

// The root is the latest state we have received from the server.
// op_a (if non-trivial) is the last operation we sent to the server that
// we are waiting on. (We only have one outstanding operation at once.)
// The buffer is the result of that operation. Finally, op_b encapsulates
// any local changes the user has made since the last operation was sent to
// the server.

// When we receive an operation from the server, we check the ID of the
// operation to see if corresponds to op_a. If it does, then we know that
// the operation was received and processed by the server, and we move
// the root up to buffer.

// Otherwise, the operation from the server is from some other client and
// was processed before our oustanding operation. So we have to transform
// op_a and op_b against this new operation, op_c.

//                               tip'
//                               / \
//                          c'' /   \ b'
//                             /     \
//                            /       \
//                          tip     buffer'
//                            \      /  \
//                           b \    /    \ a'
//                              \  / c'   \
//                               \/        \
//                              buffer    root'
//                                 \      /
//                                a \    / c
//                                   \  /
//                                    \/
//                                   root

// Communication with the server (node/socket_server.coffee) is as follows.
// On the initial socket.io connection, ask for the latest puzzle state
// (using a "hello" packet). The server will respond with all updates from
// the client's version to the latest version. It will keep sending updates
// as more updates come in from the other clients.

// (There is also the capability to start without any initial state, and
// ask the server for the state to start with, but this is currently
// unused.)

// Meanwhile, the client can send any updates to the server using an
// "update" packet. Again, it should only have one outstanding packet at
// a time for simplicity, and the client knows an update has been received
// when it receives back an update with the matching ID.

// In the event of a disconnect, socket.io will automatically attempt to
// reconnect. When it does so successfully, a new session with the server
// is started. It starts by sending another "hello" packet - but this time,
// rather than just asking for the latest state, we need to ask for all
// the operations leading up to it, so that we can transform against them.
// Furthermore, if we have an outstanding packet, we don't know if it was
// received, so we re-send it (with the same ID, so the server can dismiss
// it as a duplicate if necessary).

import * as Ot from '../shared/ot';
import * as Utils from '../shared/utils';
import {UndoRedo} from './undo_redo';

import type {PuzzleState, Cursor} from '../shared/types';
import type {Operation} from '../shared/ot';

declare var io;

type InitialData = {
  stateID: string;
  puzzle: PuzzleState;
};

type Watcher = (PuzzleState, Operation | null, {[number]: Cursor}) => void;

export class ClientSyncer {
  watchers: Watcher[] = [];

  puzzleID: string;

  // The states and operations that we keep track of. These start as null
  // until we receive the first response from the server.
  rootID: string;
  root: PuzzleState;
  buffer: PuzzleState;
  tip: PuzzleState;
  op_a: Operation;
  op_b: Operation;

  cursor_a: Cursor | null = null;
  cursor_b: Cursor | null = null;

  // The ID of the update that we sent and are waiting on, or null if
  // we are not currently waiting on any update.
  outstandingID = null;

  // Object to track state for undo/redo operations.
  undoRedo: UndoRedo;

  cursors = {};

  connected: boolean = false;

  socket: any;

  constructor(puzzleID: string, data: InitialData) {
    this.puzzleID = puzzleID;

    this.rootID = data.stateID;
    this.root = data.puzzle;
    this.buffer = data.puzzle;
    this.tip = data.puzzle;
    this.op_a = Ot.identity(data.puzzle);
    this.op_b = Ot.identity(data.puzzle);

    this.undoRedo = new UndoRedo(this.root);

    this.socket = io.connect();
    this.addSocketListeners();
  }

  addWatcher(watcher: Watcher): void {
    this.watchers.push(watcher);
  }

  notifyWatchers(newState: PuzzleState, op: Operation | null): void {
    for (let j = 0; j < this.watchers.length; j++) {
      const watcher = this.watchers[j];
      watcher(newState, op, this.cursors);
    }
  }

  addSocketListeners(): void {
    this.socket.on("connecting", () => {
      console.log("socket connecting...");
    });

    // Initial connection
    this.socket.on("connect", () => {
      console.log("socket connected!");
      if (this.root === null) {
        // THIS PATH IS CURRENTLY UNUSED

        // Send a initial "hello" packet asking for the latest state.
        this.socket.emit("hello", {
          puzzleID: this.puzzleID,
          latest: "yes"
        });
      } else {
        // If root != null then this must be a re-connect.
        // A "state" message should be received in response.
        this.socket.emit("hello", {
          puzzleID: this.puzzleID,
          from: this.rootID
        });
        // Doesn't receive a "state" in response - just a sequence of
        // updates.
        if (this.outstandingID !== null) {
          // We don't know if the last message was received, so resend it
          // just in case.
          this.resendLastUpdate();
        }
      }
      this.connected = true;
    });
   
    // The server continuously sends us "update" packets with updates to be
    // be applied to the root.
    this.socket.on("update", (data) => {
      console.debug("received update");
      this.rootID = data.stateID;

      let update = false;
      let notify = false;
      if (data.cursor_updates) {
        this._process_cursor_updates(data.cursor_updates);
        notify = true;
      }

      // TODO technically, we should xform the cursor here, but it should
      // hardly matter since the grid is pretty static.

      let op_a1 = null, op_b1 = null, op_c1 = null, op_c2 = null;

      // Check if the received update corresponds to the update that *we*
      // sent, or if it corresponds to an update from another client.
      if (this.outstandingID !== null && this.outstandingID === data.opID) {
        this.outstandingID = null;
        this.root = this.buffer;
        this.op_a = Ot.identity(this.root);
        if (!Ot.isIdentity(this.op_b)) {
          this.sendUpdate();
        }
      } else {
        const op_c = data.op;
        [op_a1, op_c1] = Ot.xform(this.root, this.op_a, op_c);
        [op_b1, op_c2] = Ot.xform(this.buffer, this.op_b, op_c1);
        this.root = Ot.apply(this.root, op_c);
        this.op_a = op_a1;
        this.buffer = Ot.apply(this.buffer, op_c1);
        this.op_b = op_b1;
        this.tip = Ot.apply(this.tip, op_c2);
        this.undoRedo.applyOp(op_c2, false); // false -> non-undoable operation
        notify = true;
      }

      if (notify) {
        this.notifyWatchers(this.tip, op_c2);
      }
    });

    this.socket.on("update_cursor", (data) => {
      this._process_cursor_updates(data.cursor_updates);
      this.notifyWatchers(this.tip, null);
    });
   
    // Handling errors and reconnections
    this.socket.on("disconnect", () => {
      this.connected = false;
      console.log("socket disconnected!");
    });
    this.socket.on("reconnecting", () => {
      console.log("socket reconnecting...");
    });
    this.socket.on("connecting", () => {
      console.log("socket connecting...");
    });
    this.socket.on("reconnect", () => {
      console.log("socket reconnected!");
    });
    this.socket.on("connect_failed", () => {
      console.log("socket connect failed! :(");
    });
    this.socket.on("reconnect_failed", () => {
      console.log("socket reconnect failed! :(");
    });
  }

  // Receive a local operation
  localOp(op: Operation, cursor: Cursor): void {
    if (op) {
      this.undoRedo.applyOp(op, true); // true -> undoable operation
      this._localOp(op, cursor);
    } else if (cursor) {
      // cursor update only
      if (cursor && !Utils.isValidCursor(this.tip, cursor)) {
        console.log('warning, bad cursor', this.tip, cursor);
      }

      if (this.outstandingID !== null) {
        this.cursor_b = cursor;
      } else {
        this.sendLoneCursor(cursor);
      }
    }
  }

  // Try to do an 'undo' operation. Return true if successful.
  undo(): boolean {
    const op = this.undoRedo.undo();
    if (op != null) {
      this._localOp(op, null);
      return true;
    } else {
      return false;
    }
  }

  // Try to do a 'redo' operation. Return true if successful.
  redo(): boolean {
    const op = this.undoRedo.redo();
    if (op != null) {
      this._localOp(op, null);
      return true;
    } else {
      return false;
    }
  }

  _localOp(op: Operation, cursor: Cursor | null): void {
    Ot.assertValidOp(this.tip, op);
    this.tip = Ot.apply(this.tip, op);
    this.op_b = Ot.compose(this.buffer, this.op_b, op);
    if (cursor) {
      this.cursor_b = cursor;
    }
    if (this.cursor_b && !Utils.isValidCursor(this.tip, this.cursor_b)) {
      console.log('warning, bad cursor', this.tip, this.cursor_b);
      this.cursor_b = null;
    }
    if (this.outstandingID === null) {
      this.sendUpdate();
    }
    this.notifyWatchers(this.tip, op);
  }

  _process_cursor_updates(updates: {user_id: number, cursor: Cursor}[]) {
    for (let j = 0; j < updates.length; j++) {
      const update = updates[j];
      if (update.cursor === null) {
        delete this.cursors[update.user_id];
      } else {
        this.cursors[update.user_id] = update.cursor;
      }
    }
  }

  _makeRandomID(): string {
    let result = "";
    for (let i = 0; i < 48; i++) {
      result += "0123456789abcdef"[Math.floor(Math.random() * 16)];
    }
    return result;
  }

  // Send an update to the server, moving up the "buffer" pointer
  // (helper method called by a few methods above).
  // Store the message in updateMessage, in case we need to re-send it.

  updateMessage = null;

  sendUpdate(): void {
    Utils.assert(this.outstandingID === null);
    Utils.assert(Ot.isIdentity(this.op_a));
    this.op_a = this.op_b;
    this.cursor_a = this.cursor_b;
    this.buffer = this.tip;
    this.op_b = Ot.identity(this.buffer);

    const id = this._makeRandomID();
    this.outstandingID = id;
    this.updateMessage = {
      op: this.op_a,
      cursor: this.cursor_a,
      opID: id,
      rootID: this.rootID
    };
    if (this.connected) {
      this.socket.emit("update", this.updateMessage);
    }
  }

  sendLoneCursor(cursor: Cursor): void {
    this.socket.emit("cursor_update", {
      cursor: cursor
    });
  }

  resendLastUpdate(): void {
    this.socket.emit("update", this.updateMessage);
  }

  // Offline mode
  isOfflineMode = false;
  setOffline(offline: boolean): void {
    if (offline && (!this.isOfflineMode)) {
      this.isOfflineMode = true;
      this.socket.disconnect();
    } else if ((!offline) && this.isOfflineMode) {
      this.isOfflineMode = false;
      this.socket.socket.reconnect();
    }
  }
}
