import * as Ot from "../shared/ot";
import * as Utils from "../shared/utils";

import {PuzzleState} from "../shared/types";
import {Operation} from "../shared/ot";

type Entry = {
  undoable: boolean,
  forward_op: Operation,
  backward_op: Operation,
};

export class UndoRedo {
  initialState: PuzzleState;
  state: PuzzleState;

  constructor(initialState: PuzzleState) {
    this.initialState = Utils.clone(initialState);
    this.state = this.initialState;
  }

  // Here's how we track state: 
  //
  //  [op 1] [op 2] [op 3] [op 4] [op 5] [op 6]
  // ^                           ^             ^
  // |                           |             |
  // initial state             state         latest
  //
  // 'state' is the current state display to the user.
  // Usually, we will have state=latest, unless the user has recently
  // done an 'undo'.
  //
  // Everything to the left of state is in 'stackBackward' and
  // everything to the right of state is in 'stackForward'.
  // In the example, [op 4] is the top of 'stackBackward' and
  // [op 5] is the top of 'stackForward'. 
  //
  // The type of each 'op' is
  //
  // {
  //   undoable: boolean
  //   forward_op: operation
  //   backward_op: operation
  // }
  //
  // 'undoable' will usually (always?) mean a 'local op' and ops from the server will be
  // non-undoable.
  //
  // More invariants:
  //  - All the 'forward_op' ops when composed should go from 'initial state' to 'latest'.
  //  - For each op, 'backward_op' is the inverse of 'forward op'.
  //  - Every op in the right stack will be 'undoable' (it must be, since to get into the
  //    right stack in the first place, it must have been undone by the user)
  //  - No two adjacent ops will be non-undoable.

  stackBackward: Entry[] = [];
  stackForward: Entry[] = [];

  applyOp(op: Operation, undoable: boolean): void {
    // Don't push useless identity operations
    if (Ot.isIdentity(op)) {
      return;
    }
    op = Utils.clone(op);

    // If we do an 'undoable' op, we lose the ability to 'redo' any previously
    // undone ops.
    if (undoable) {
      this.stackForward = [];
    } else {
      this.xformStackForward(op);
    }

    const lastEntry = this.stackBackward[this.stackBackward.length - 1];

    // Update 'stackBackward'
    if ((!undoable) && (lastEntry != null) && (!lastEntry.undoable)) {
      // Two adjacent non-undoable ops: we should merge them
      const prevState = Ot.apply(this.state, lastEntry.backward_op);
      const forward_op = Ot.compose(prevState, lastEntry.forward_op, op);
      const backward_op = Ot.inverse(prevState, forward_op);
      this.stackBackward[this.stackBackward.length - 1] = {
        undoable: false,
        forward_op: forward_op,
        backward_op: backward_op
      };
    } else {
      // Just add the new op to the end of the backward stack
      this.stackBackward.push({
        undoable: undoable,
        forward_op: op,
        backward_op: Ot.inverse(this.state, op)
      });
    }
    
    // update 'state'
    this.state = Ot.apply(this.state, op);
  }

  // Do a redo and return the op applied to 'state'.
  // Returns 'null' if it's impossible to do a redo.
  redo(): Operation | null {
    if (this.stackForward.length === 0) {
      return null;
    }
    const nextEntry = this.stackForward[this.stackForward.length - 1];
    this.stackForward.pop();
    this.stackBackward.push(nextEntry);
    this.state = Ot.apply(this.state, nextEntry.forward_op);
    return Utils.clone(nextEntry.forward_op);
  }

  // Do an undo and return the op applied to 'state'.
  // Returns 'null' if it's impossible to do an undo.
  undo(): Operation | null {
    if (!this.bringUndoableOpToTop()) {
      return null;
    }
    const lastEntry = this.stackBackward[this.stackBackward.length - 1];
    Utils.assert(lastEntry.undoable);
    this.stackBackward.pop();
    this.stackForward.push(lastEntry);
    this.state = Ot.apply(this.state, lastEntry.backward_op);
    return Utils.clone(lastEntry.backward_op);
  }

  // Rearrange 'stackBackward' so that an 'undoable' op is on top.
  // Returns true if successful.
  // Preserves 'state' and 'stackForward'.
  // 'stackBackward' will change, but will still be "equivalent" - just the ops
  // in a different order.
  bringUndoableOpToTop() {
    if (this.stackBackward.length >= 1 && this.stackBackward[this.stackBackward.length - 1].undoable) {
      // already done
      return true;
    }
    if (this.stackBackward.length <= 1) {
      // no undoable op, can't do anything
      return false;
    }

    // Due to invariant, it must be the case that the second-to-last op is undoable.
    // Verify this.
    Utils.assert(this.stackBackward[this.stackBackward.length - 2].undoable, "second-to-last op should be undoable");
    
    // We need to swap the last two entries.
    // Right now, we have:
    //
    //         ?     undoable   not
    //
    //        op2      op1      op0
    //     |------->|------->|------->|
    //   state3   state2   state1   state0
    //
    // op2 may or may not be undoable, but if it is not, we will need to merge
    // it after the swap, in order to preserve the invariant of no two adjacent
    // non-undoable ops.
    const state0 = this.state;
    const op0 = this.stackBackward[this.stackBackward.length - 1];
    const op1 = this.stackBackward[this.stackBackward.length - 2];
    const state1 = Ot.apply(state0, op0.backward_op);
    const state2 = Ot.apply(state1, op1.backward_op);

    // We can choose which order to put the arguments to `xform` here.
    // The choice is basically:
    // if you modify a cell A->B, and someone else modifies a cell later B->C,
    // and you undo, do we want to change that cell back to A?
    // Here, I'm deciding that the answer to that question is 'yes',
    // but we could flip the arguments and get an answer of 'no'.
    // The point is that the left argument "wins" in a conflict.
    const new_op0: Entry = {
      undoable: true,
      backward_op: null as any, forward_op: null as any
    };
    const new_op1: Entry = {
      undoable: false,
      backward_op: null as any, forward_op: null as any
    };

    const xform_result = Ot.xform(state1, op1.backward_op, op0.forward_op);
    new_op0.backward_op = xform_result[0];
    new_op1.forward_op = xform_result[1];

    const op2 = this.stackBackward[this.stackBackward.length - 3];
    if ((op2 != null) && (!op2.undoable)) {
      // we need to merge op2 and new_op1
      //
      //            not         undoable
      //
      //        op2+new_op1       op0
      //     |---------------->|------->|
      //   state3                     state0
      new_op0.forward_op = Ot.inverse(state0, new_op0.backward_op);

      const state3 = Ot.apply(state2, op2.backward_op);
      const combined_op = Ot.compose(state3, op2.forward_op, new_op1.forward_op);
      const combined_op_inv = Ot.inverse(state3, combined_op);

      this.stackBackward.pop();
      this.stackBackward[this.stackBackward.length - 2] = {
        undoable: false,
        forward_op: combined_op,
        backward_op: combined_op_inv
      };
      this.stackBackward[this.stackBackward.length - 1] = new_op0;
    } else {
      //      undoable  not    undoable
      //
      //        op2    new_op1  new_op0
      //     |------->|------->|------->|
      //   state3   state2            state0
      //         ^
      //         |
      //      unmodified
      new_op0.forward_op = Ot.inverse(state0, new_op0.backward_op);
      new_op1.backward_op = Ot.inverse(state2, new_op1.forward_op);

      this.stackBackward[this.stackBackward.length - 2] = new_op1;
      this.stackBackward[this.stackBackward.length - 1] = new_op0;
    }

    return true;
  }

  // tranforms everything in stackForward
  xformStackForward(op: Operation): void {
    //         ------->------>------>
    //        ^       ^      ^      ^
    //     op |       |      |      |
    //        |       |      |      |
    //   state ------->------>------>
    //           [2]     [1]    [0]
    //             stackForward

    let st = this.state;
    let i = this.stackForward.length - 1;
    while (i >= 0) {
      const [f_op_new, op_new] = Ot.xform(st, this.stackForward[i].forward_op, op);
      const st_new = Ot.apply(st, this.stackForward[i].forward_op);
      const f_op_back_new = Ot.inverse(Ot.apply(st, op), f_op_new);

      st = st_new;
      op = op_new;
      this.stackForward[i] = {
        undoable: this.stackForward[i].undoable,
        forward_op: f_op_new,
        backward_op: f_op_back_new
      };

      i--;
    }
  }
}
