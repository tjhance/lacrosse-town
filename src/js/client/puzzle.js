/* @flow */

/*
This is the main react element for the puzzle page.

It takes two callback arguments
    requestOp: Calls this function with a single op representing a change to
        the puzzle state.
    onToggleOffline: Calls this function whenever the user toggles offline-mode.

It also has two functions which should be called:
    setPuzzleState: call this initially to set the puzzle state
    applyOpToPuzzleState: call this with an op to update it.

The user of this class should call `applyOpToPuzzleState` for any op which is applied.
This includes both ops from the server AND ops from the user. That means that when
this object calls `requestOp`, `applyOpToPuzzleState` should be called immediately after.

The React element responds to most user-input commands by creating an op and
calling `requestOp`.

The most important state object is `puzzle`, which is the current state of the puzzle
to be displayed (e.g., a grid containing information about which cells are black,
what letters are in them, etc.).
There is also `grid_focus`, which describes the focus state of the grid: which
cell the grid is focused on, if any.
*/

import * as React from 'react';
import * as ReactDom from 'react-dom';

import * as ClipboardUtils from './clipboard_utils';
import {FindMatchesDialog} from './find_matches_dialog';
import * as Ot from '../shared/ot';
import * as Utils from '../shared/utils';
import * as PuzzleUtils from '../shared/puzzle_utils';
import {EditableTextField} from './text_field_handler';
import * as KeyboardUtils from './keyboard_utils';

import type {PuzzleState, PuzzleGrid, PuzzleCell, Cursor} from '../shared/types';
import type {PastedGrid} from './clipboard_utils';
import type {Operation} from '../shared/ot';
import type {TextOperation} from '../shared/ottext';

declare var $;

type GridFocus = {
  focus: { row: number, col: number },
  anchor: { row: number, col: number },
  is_across: boolean,
  field_open: "none" | "number" | "contents",
};

type Props = {
  requestOp: (Operation | null, GridFocus | null) => void;
  onToggleOffline: (boolean) => void;
};

type FindMatchesInfo = {
  is_across: boolean;
  cells: [number, number][],
  contents: string[],
  pattern: string,
  clueTitle: string,
  clueText: string,
  savedGridFocus: GridFocus,
};

type State = {
  puzzle: PuzzleState,
  initial_puzzle: PuzzleState,
  maintainRotationalSymmetry: boolean,
  offlineMode: boolean,
  findMatchesInfo: FindMatchesInfo | null,
  grid_focus: GridFocus | null,
  cursors: {[string]: Cursor}
};

type ClueStylingData = {
  primaryNumber: number | null,
  secondaryNumber: number | null,
  answerLengths: {[number]: number},
};

export class PuzzlePage extends React.Component<Props, State> {
	constructor(props: Props) {
    super(props);

    this.state = {
      // $FlowFixMe
      puzzle: null,
      // $FlowFixMe
      initial_puzzle: null,

      // If this is true, then maintain rotational symmetry of white/blackness
      // when the user toggles a single square.
      maintainRotationalSymmetry: true,

      // Controls the offlineMode property of the ClientSyncer. When in offline
      // mode, don't sync with the server.
      offlineMode: false,

      // When the user uses the feature to auto-match a word,
      // this object contains info about where the word is and what the pattern is.
      findMatchesInfo: null,

      // Information on how the user is focused on the grid. Contains a row and
      // column for the primary cell the user is focused on. The 'is_across'
      // field determines whether the user is secondarily focused on the
      // across-word of that cell, or the down-word.
      // The 'field_open' is for when the user has an input field open for
      // editting a cell - necessary when editting the number, or when entering
      // contents of more than a single letter.
      // grid_focus can also be null if the user isn't focused on the grid.
      grid_focus: this.defaultGridFocus(),

      // Map of the other users' cursors.
      cursors: {}
    };
  }

  defaultGridFocus(): GridFocus {
    return {
      focus: {
        row: 0,
        col: 0
      },
      anchor: {
        row: 0,
        col: 0
      },
      is_across: true,
      field_open: "none" // "none" or "number" or "contents"
    };
  }

  width(): number {
    return this.state.puzzle.width;
  }

  height(): number {
    return this.state.puzzle.height;
  }

  // Returns a grid of the the CSS classes for styling the cell
  getCellClasses() {
    const grid = this.state.puzzle.grid;
    const grid_focus = this.state.grid_focus;
    const isLineFree = function(r1, c1, r2, c2) {
      var ref1, ref2;
      if (r1 === r2) {
        if (c1 === c2) {
          return true;
        }
        if (c2 < c1) {
          [c1, c2] = [c2, c1];
        }
        for (let col = c1; col <= c2; col++) {
          if (!grid[r1][col].open || (col < c2 && grid[r1][col].rightbar)) {
            return false;
          }
        }
        return true;
      } else {
        if (r2 < r1) {
          [r1, r2] = [r2, r1];
        }
        for (let row = r1; row <= r2; row++) {
          if (!grid[row][c1].open || (row < r2 && grid[row][c1].bottombar)) {
            return false;
          }
        }
        return true;
      }
    };

    const getCellClass = (row, col) => {
      if (grid_focus === null) {
        // no selection, just return the default selection based on whether
        // or not the cell is open or closed
        return (grid[row][col].open ? "open_cell" : "closed_cell");
      } else if (
          grid_focus.focus.row === grid_focus.anchor.row &&
          grid_focus.focus.col === grid_focus.anchor.col) {
        // highlight every cell in the selected cell's row or column (depending on
        // the `is_across` field
        if (grid[row][col].open) {
          const focus = grid_focus;
          if (focus.focus.row === row && focus.focus.col === col) {
            return "open_cell_highlighted";
          } else if (
              (focus.is_across && focus.focus.row === row &&
                  isLineFree(row, col, row, focus.focus.col)) ||
              ((!focus.is_across) && focus.focus.col === col &&
                  isLineFree(row, col, focus.focus.row, col))) {
            return "open_cell_highlighted_intermediate";
          } else {
            return "open_cell";
          }
        } else {
          if (grid_focus.focus.row === row && grid_focus.focus.col === col) {
            return "closed_cell_highlighted";
          } else {
            return "closed_cell";
          }
        }
      } else {
        // selection is more than one cell
        const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
        const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
        const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
        const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);
        if (row1 <= row && row <= row2 && col1 <= col && col <= col2) {
          return (grid[row][col].open ? "open_cell_highlighted" : "closed_cell_highlighted");
        } else {
          return (grid[row][col].open ? "open_cell" : "closed_cell");
        }
      }
    };

    return Utils.makeMatrix(this.height(), this.width(), (i, j) => {
      return getCellClass(i, j);
    });
  }

  getBars() {
    const grid = this.state.puzzle.grid;
    const row_props = this.state.puzzle.row_props;
    const col_props = this.state.puzzle.col_props;

    const getCellBars = (row, col) => {
      return {
        top: (row === 0 && col_props[col].topbar) || (row > 0 && grid[row - 1][col].bottombar),
        bottom: grid[row][col].bottombar,
        left: (col === 0 && row_props[row].leftbar) || (col > 0 && grid[row][col - 1].rightbar),
        right: grid[row][col].rightbar
      };
    };

    return Utils.makeMatrix(this.height(), this.width(), (i, j) => {
      return getCellBars(i, j);
    });
  }

  // Ensures that the grid_focus is in a valid state even after the puzzle
  // state was modified.
  fixFocus(puzzle: PuzzleState, grid_focus: GridFocus | null): GridFocus | null {
    if (grid_focus === null) {
      return null;
    }

    const row = grid_focus.focus.row;
    const col = grid_focus.focus.col;
    const row1 = grid_focus.anchor.row;
    const col1 = grid_focus.anchor.col;
    const height = puzzle.grid.length;
    const width = puzzle.grid[0].length;

    if (!(row >= 0 && row < height && col >= 0 && col < width &&
          row1 >= 0 && row1 < height && col1 >= 0 && col1 < width)) {
      return null;
    } else {
      return grid_focus;
    }
  }

  requestOpAndFocus(op: Operation | null, focus: GridFocus | null) {
    if (op || focus) {
      this.props.requestOp(op, focus);
    }
    if (focus) {
      return this.setState({
        grid_focus: focus
      });
    }
  }

  requestFocus(focus: GridFocus | null) {
    return this.requestOpAndFocus(null, focus);
  }

  requestOp(op: Operation) {
    return this.requestOpAndFocus(op, null);
  }

  // Store puzzle_state on the object directly
  // (in addition to as state)
  // This makes things easier to reason about since we can update this
  // immediately, whereas the state updates are asynchronous.
  puzzle_state: PuzzleState;

  setPuzzleState(puzzle_state: PuzzleState) {
    this.puzzle_state = puzzle_state;
    return this.setState({
      puzzle: puzzle_state,
      initial_puzzle: puzzle_state,
      grid_focus: this.fixFocus(puzzle_state, this.state.grid_focus)
    });
  }

  applyOpToPuzzleState(op: Operation) {
    this.puzzle_state = Ot.apply(this.puzzle_state, op);
    this.setState({
      puzzle: this.puzzle_state,
      grid_focus: this.fixFocus(this.puzzle_state, this.state.grid_focus)
    });
    // $FlowFixMe
    if (op.across_clues != null) {
      this.refs.acrossClues.takeOp(op.across_clues);
    }
    // $FlowFixMe
    if (op.down_clues != null) {
      return this.refs.downClues.takeOp(op.down_clues);
    }
  }

  setCursors(cursors: {[string]: Cursor}) {
    return this.setState({
      cursors: cursors
    });
  }

  // Actions corresponding to keypresses
  moveGridCursor(shiftHeld: boolean, drow: -1 | 0 | 1, dcol: -1 | 0 | 1) {
    const grid_focus = this.state.grid_focus;
    if (grid_focus) {
      let col1 = grid_focus.focus.col + dcol;
      let row1 = grid_focus.focus.row + drow;
      col1 = Math.min(this.width() - 1, Math.max(0, col1));
      row1 = Math.min(this.height() - 1, Math.max(0, row1));
      if (shiftHeld) {
        // move the focus but leave the anchor where it is
        this.requestFocus({
          focus: {
            row: row1,
            col: col1
          },
          anchor: {
            row: grid_focus.anchor.row,
            col: grid_focus.anchor.col
          },
          is_across: drow === 0,
          field_open: "none"
        });
      } else {
        // normal arrow key press, just move the focus by 1
        // in the resulting grid_focus, we should have focus=anchor
        this.requestFocus({
          focus: {
            row: row1,
            col: col1
          },
          anchor: {
            row: row1,
            col: col1
          },
          is_across: drow === 0,
          field_open: "none"
        });
      }
      return true;
    }
    return false;
  }

  typeLetter(keyCode: number) {
    const grid_focus = Utils.clone(this.state.grid_focus);
    let op = null;
    if (grid_focus !== null) {
      const c = String.fromCharCode(keyCode);
      op = Ot.opEditCellValue(grid_focus.focus.row, grid_focus.focus.col, "contents", c);
      if (grid_focus.is_across && grid_focus.focus.col < this.width() - 1) {
        grid_focus.focus.col += 1;
      } else if ((!grid_focus.is_across) && grid_focus.focus.row < this.height() - 1) {
        grid_focus.focus.row += 1;
      }
    }
    return this.requestOpAndFocus(op, this.collapseGridFocus(grid_focus));
  }

  doSpace() {
    if (this.state.grid_focus) {
      if (this.state.grid_focus.is_across) {
        return this.moveGridCursor(false, 0, 1);
      } else {
        return this.moveGridCursor(false, 1, 0);
      }
    }
  }

  doDelete() {
    let grid_focus = Utils.clone(this.state.grid_focus);
    if (grid_focus !== null) {
      grid_focus.field_open = "none";
      let op = null;
      const g = this.state.puzzle.grid;
      if (grid_focus.focus.row === grid_focus.anchor.row &&
          grid_focus.focus.col === grid_focus.anchor.col) {
        // The simplest behavior for 'delete' would be to always delete the
        // contents of the cell. However, this has suboptimal behavior if you're
        // typing out a word and then a typo. If you type a letter, your selection
        // immediately moves to the next cell, which means that if you hit 'delete'
        // right after that, you would expect to delete the letter you just typed
        // but you wouldn't.
        // So, we have this special behavior: if your cell is empty then
        // we delete the contents of the previous cell (either previous in the row
        // or previous in the column).
        // Also, we *always* move the selection back one cell if we can.
        const row = grid_focus.focus.row;
        const col = grid_focus.focus.col;
        if (g[row][col].open && g[row][col].contents !== "") {
          op = Ot.opEditCellValue(grid_focus.focus.row, grid_focus.focus.col, "contents", "");
          if (grid_focus.is_across && grid_focus.focus.col > 0) {
            grid_focus.focus.col -= 1;
          } else if ((!grid_focus.is_across) && grid_focus.focus.row > 0) {
            grid_focus.focus.row -= 1;
          }
        } else {
          let row1, col1;
          if (grid_focus.is_across) {
            row1 = row;
            col1 = col - 1;
          } else {
            row1 = row - 1;
            col1 = col;
          }
          if (row1 >= 0 && col1 >= 0) {
            if (g[row1][col1].open && g[row1][col1].contents !== "") {
              op = Ot.opEditCellValue(row1, col1, "contents", "");
            }
            grid_focus.focus.col = col1;
            grid_focus.focus.row = row1;
          }
        }
        grid_focus = this.collapseGridFocus(grid_focus);
      } else {
        // If you're selecting more than one cell, then we just delete the contents
        // of all those cells, but we don't move the selection at all.
        const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
        const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
        const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
        const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);
        op = Ot.identity(this.state.puzzle);
        for (let row = row1; row <= row2; row++) {
          for (let col = col1; col <= col2; col++) {
            if (g[row][col].open && g[row][col].contents !== "") {
              op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "contents", ""));
            }
          }
        }
      }
      return this.requestOpAndFocus(op, grid_focus);
    }
  }

  doDeleteAll() {
    const grid_focus = this.state.grid_focus;
    if (grid_focus === null) {
      return;
    }
    const g = this.state.puzzle.grid;
    const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
    const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
    const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
    const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);
    let op = Ot.identity(this.state.puzzle);
    for (let row = row1; row <= row2; row++) {
      for (let col = col1; col <= col2; col++) {
        op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "contents", ""));
        op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "number", null));
        op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "open", true));
        if (row < row2) {
          op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "bottombar", false));
        }
        if (col < col2) {
          op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "rightbar", false));
        }
      }
    }
    return this.requestOp(op);
  }

  // Perform an automatic renumbering.
  renumber() {
    const focus = this.removeCellField(this.state.grid_focus);
    const op = Ot.opGridDiff(this.state.puzzle,
        PuzzleUtils.getNumberedGrid(this.state.puzzle.grid));
    this.requestOpAndFocus(op, focus);
  }

  // Returns true if renumbering the grid would be a non-trivial operation,
  // that is, if there are any cells which would be re-numbered
  needToRenumber() {
    const op = Ot.opGridDiff(this.state.puzzle,
        PuzzleUtils.getNumberedGrid(this.state.puzzle.grid));
    return Ot.isIdentity(op);
  }

  toggleOpenness() {
    if (this.state.grid_focus !== null) {
      const grid_focus = Utils.clone(this.state.grid_focus);
      const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
      const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
      const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
      const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);
      const g = this.state.puzzle.grid;
      let isEveryCellClosed = true;
      for (let row = row1; row <= row2; row++) {
        for (let col = col1; col <= col2; col++) {
          if (g[row][col].open) {
            isEveryCellClosed = false;
          }
        }
      }
      grid_focus.field_open = "none";
      const oldValue = !isEveryCellClosed;
      const newValue = isEveryCellClosed;
      let op = Ot.identity(this.state.puzzle);

      // want to change every cell of 'open' value `oldValue` to have
      // 'open' value `newValue`
      for (let row = row1; row <= row2; row++) {
        for (let col = col1; col <= col2; col++) {
          if (g[row][col].open === oldValue) {
            op = Ot.compose(this.state.puzzle, op, Ot.opEditCellValue(row, col, "open", newValue));
            if (this.state.maintainRotationalSymmetry) {
              op = Ot.compose(
                  this.state.puzzle,
                  op,
                  Ot.opEditCellValue(
                    this.height() - 1 - row,
                    this.width() - 1 - col, "open", newValue));
            }
          }
        }
      }
      return this.requestOpAndFocus(op, grid_focus);
    }
  }

  toggleBars(keyCode: number) {
    if (this.state.grid_focus !== null) {
      const dir = {
        '37': 'left',
        '38': 'top',
        '39': 'right',
        '40': 'bottom'
      }[keyCode];
      const grid_focus = Utils.clone(this.state.grid_focus);
      const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
      const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
      const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
      const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);

      const cells = [];
      if (dir === 'left') {
        for (let r = row1; r <= row2; r++) {
          cells.push([r, col1]);
        }
      } else if (dir === 'right') {
        for (let r = row1; r <= row2; r++) {
          cells.push([r, col2]);
        }
      } else if (dir === 'top') {
        for (let c = col1; c <= col2; c++) {
          cells.push([row1, c]);
        }
      } else if (dir === 'bottom') {
        for (let c = col1; c <= col2; c++) {
          cells.push([row2, c]);
        }
      }

      let allOn = true;
      for (let k = 0; k < cells.length; k++) {
        const cell = cells[k];
        if (!this.getBar(cell[0], cell[1], dir)) {
          allOn = false;
        }
      }

      let op = Ot.identity(this.state.puzzle);
      for (let l = 0; l < cells.length; l++) {
        const cell = cells[l];
        op = Ot.compose(this.state.puzzle, op, Ot.opSetBar(cell[0], cell[1], dir, !allOn));
      }

      return this.requestOp(op);
    }
    return null;
  }

  getBar(row: number, col: number, dir: 'top' | 'bottom' | 'left' | 'right') {
    if (dir === 'top' || dir === 'bottom') {
      if (dir === 'top') {
        row -= 1;
      }
      if (row === -1) {
        return this.state.puzzle.col_props[col].topbar;
      } else {
        return this.state.puzzle.grid[row][col].bottombar;
      }
    } else if (dir === 'left' || dir === 'right') {
      if (dir === 'left') {
        col -= 1;
      }
      if (col === -1) {
        return this.state.puzzle.row_props[row].leftbar;
      } else {
        return this.state.puzzle.grid[row][col].rightbar;
      }
    } else {
      throw new Error("invalid dir " + dir);
    }
  }

  // Stuff relating to the input fields.

  openCellField(type: 'number' | 'contents') {
    const grid_focus = this.collapseGridFocus(this.state.grid_focus);
    if (grid_focus !== null && this.state.puzzle.grid[grid_focus.focus.row][grid_focus.focus.col].open) {
      grid_focus.field_open = type;
      return this.requestFocus(grid_focus);
    }
  }

  removeCellField(grid_focus: GridFocus | null): GridFocus | null {
    if (grid_focus !== null) {
      grid_focus = this.collapseGridFocus(grid_focus);
      if (!grid_focus) {
        throw new Error("removeCellField should get truthy grid_focus");
      }
      grid_focus.field_open = "none";
    }
    return grid_focus;
  }

  // Given a grid_focus object, sets the anchor to be the focus and returns
  // the new object.
  collapseGridFocus(grid_focus: GridFocus | null): GridFocus | null {
    if (grid_focus !== null) {
      grid_focus = Utils.clone(grid_focus);
      grid_focus.anchor = {
        row: grid_focus.focus.row,
        col: grid_focus.focus.col
      };
    }
    return grid_focus;
  }

  onCellFieldKeyPress(event: any, row: number, col: number) {
    let v = event.target.value;
    const keyCode = event.keyCode;
    let grid_focus = this.collapseGridFocus(this.state.grid_focus);
    if (grid_focus === null) {
      return;
    }
    let op = null;
    if (keyCode === 27) { // Escape
      grid_focus = this.removeCellField(grid_focus);
    } else if (keyCode === 13) { // Enter
      v = v || "";
      let name = null;
      let value = null;
      if (grid_focus.field_open === "number") {
        if (v === "") {
          value = null;
        } else if (Utils.isValidInteger(v)) {
          value = parseInt(v);
        } else {
          return;
        }
        name = "number";
      } else if (grid_focus.field_open === "contents") {
        value = v;
        name = "contents";
      } else {
        return;
      }
      op = Ot.opEditCellValue(row, col, name, value);
      grid_focus = this.removeCellField(grid_focus);
    }
    return this.requestOpAndFocus(op, grid_focus);
  }

  // Handle a keypress by dispatching to the correct method (above).
  handleKeyPress(event: KeyboardEvent) {
    var shiftHeld;
    if ((KeyboardUtils.usesCmd() ? event.metaKey : event.ctrlKey)) {
      if (event.keyCode === 66) { // B
        this.toggleOpenness();
        return event.preventDefault();
      } else if (event.keyCode === 73) { // I
        this.openCellField("number");
        return event.preventDefault();
      } else if (event.keyCode === 85) { // U
        this.openCellField("contents");
        return event.preventDefault();
      } else if (event.keyCode === 71) { // G
        this.openMatchFinder();
        return event.preventDefault();
      } else if (event.keyCode >= 37 && event.keyCode <= 40) {
        event.preventDefault();
        return this.toggleBars(event.keyCode);
      }
    } else {
      shiftHeld = event.shiftKey;
      if (event.keyCode === 37) { // LEFT
        if (this.moveGridCursor(shiftHeld, 0, -1)) {
          return event.preventDefault();
        }
      } else if (event.keyCode === 38) { // UP
        if (this.moveGridCursor(shiftHeld, -1, 0)) {
          return event.preventDefault();
        }
      } else if (event.keyCode === 39) { // RIGHT
        if (this.moveGridCursor(shiftHeld, 0, 1)) {
          return event.preventDefault();
        }
      } else if (event.keyCode === 40) { // DOWN
        if (this.moveGridCursor(shiftHeld, 1, 0)) {
          return event.preventDefault();
        }
      } else if (event.keyCode >= 65 && event.keyCode <= 90) { // A-Z
        this.typeLetter(event.keyCode);
        return event.preventDefault();
      } else if (event.keyCode === 8) { // backspace
        this.doDelete();
        return event.preventDefault();
      } else if (event.keyCode === 32) { // space
        this.doSpace();
        return event.preventDefault();
      }
    }
  }

  // Focus on a cell when it is clicked on, or toggle its
  // acrossness/downness if it already has focus.
  onCellClick(row: number, col: number): void {
    // this sucks
    $('div[contenteditable=true]').blur();
    window.getSelection().removeAllRanges();

    let grid_focus = this.state.grid_focus === null ?
        this.defaultGridFocus() : Utils.clone(this.state.grid_focus);
    grid_focus = this.removeCellField(grid_focus);

    if (!grid_focus) {
      throw new Error("should have a focus object");
    }

    if (grid_focus !== null && grid_focus.focus.row === row && grid_focus.focus.col === col) {
      grid_focus.is_across = !grid_focus.is_across;
    } else {
      grid_focus.focus.row = row;
      grid_focus.focus.col = col;
      const grid = this.state.puzzle.grid;
      grid_focus.is_across = ((!grid[row][col].open) ||
          (col > 0 && grid[row][col - 1].open && !grid[row][col - 1].rightbar) ||
          (col < this.state.puzzle.width - 1 && grid[row][col + 1].open &&
              !grid[row][col].rightbar));
    }
    this.requestFocus(this.collapseGridFocus(grid_focus));
  }

  blur(): void {
    this.setState({
      grid_focus: null
    });
  }

  gridNode(): HTMLElement {
    const node = ReactDom.findDOMNode(this.refs.grid);
    if (!(node instanceof HTMLElement)) {
      throw new Error("PuzzlePage.gridNode expected HTMLElement");
    }
    return node;
  }

  // Offline mode
  toggleOffline(event: any): void {
    const checked = event.target.checked;
    this.setState({
      offlineMode: checked
    });
    this.props.onToggleOffline(checked);
  }

  toggleMaintainRotationalSymmetry(event: any): void {
    const checked = event.target.checked;
    this.setState({
      maintainRotationalSymmetry: checked
    });
  }

  clueEdited(name: 'across' | 'down', local_text_op: TextOperation): void {
    this.requestOp(Ot.getClueOp(name, local_text_op));
  }

  clueStylingData(is_across: boolean): ClueStylingData {
    // compute the answer length, in cells, of each clue number
    const answerLengths = {};
    let gridForCalculatingLengths;
    if (is_across) {
      gridForCalculatingLengths = this.state.puzzle.grid;
    } else {
      gridForCalculatingLengths = Utils.transpose(this.state.puzzle.grid, this.width(), this.height());
    }

    for (let k = 0; k < gridForCalculatingLengths.length; k++) {
      const line = gridForCalculatingLengths[k];
      let number = null;
      let count = 0;
      for (let l = 0; l <  line.length; l++) {
        const cell = line[l];
        if (cell.open) {
          if (cell.number !== null) {
            if (number === null) {
              number = cell.number;
              count = 1;
            } else {
              count++;
            }
          } else {
            if (number !== null) {
              count++;
            }
          }
          if ((is_across ? cell.rightbar : cell.bottombar)) {
            if (number !== null) {
              answerLengths[number] = count;
              number = null;
            }
          }
        } else {
          if (number !== null) {
            answerLengths[number] = count;
            number = null;
          }
        }
      }
      if (number !== null) {
        answerLengths[number] = count;
        number = null;
      }
    }
    if (this.state.grid_focus === null ||
        this.state.grid_focus.focus.row !== this.state.grid_focus.anchor.row ||
        this.state.grid_focus.focus.col !== this.state.grid_focus.anchor.col ||
        (!this.state.puzzle.grid[this.state.grid_focus.focus.row][this.state.grid_focus.focus.col].open)) {
      return {
        primaryNumber: null,
        secondaryNumber: null,
        answerLengths: answerLengths
      };
    }

    let row = this.state.grid_focus.focus.row;
    let col = this.state.grid_focus.focus.col;
    while (true) {
      const row1 = is_across ? row : row - 1;
      const col1 = is_across ? col - 1 : col;
      if (row1 >= 0 && col1 >= 0 &&
          this.state.puzzle.grid[row1][col1].open &&
          !this.state.puzzle.grid[row1][col1][is_across ? 'rightbar' : 'bottombar']) {
        row = row1;
        col = col1;
      } else {
        break;
      }
    }

    const s: ClueStylingData = {
      primaryNumber: null,
      secondaryNumber: null,
      answerLengths: answerLengths
    };
    if (this.state.puzzle.grid[row][col].number !== null) {
      const keyName = this.state.grid_focus.is_across === is_across ?
          'primaryNumber' : 'secondaryNumber';
      s[keyName] = this.state.puzzle.grid[row][col].number;
    }
    return s;
  }

  openMatchFinder(): void {
    const grid_focus = this.state.grid_focus;
    if (grid_focus === null ||
        grid_focus.focus.row !== grid_focus.anchor.row ||
        grid_focus.focus.col !== grid_focus.anchor.col) {
      return;
    }

    const row = grid_focus.focus.row;
    const col = grid_focus.focus.col;
    const g = this.state.puzzle.grid;
    if (!g[row][col].open) {
      return;
    }

    // get the contiguous run of open cells containing the selection
    const cells = [];
    if (grid_focus.is_across) {
      let c1 = col;
      let c2 = col;
      while (c1 > 0 && g[row][c1 - 1].open && !g[row][c1 - 1].rightbar) {
        c1--;
      }
      while (c2 < this.width() - 1 && g[row][c2 + 1].open && !g[row][c2].rightbar) {
        c2++;
      }
      for (let i = c1; i <= c2; i++) {
        cells.push([row, i]);
      }
    } else {
      let r1 = row;
      let r2 = row;
      while (r1 > 0 && g[r1 - 1][col].open && !g[r1 - 1][col].bottombar) {
        r1--;
      }
      while (r2 < this.height() - 1 && g[r2 + 1][col].open && !g[r2][col].bottombar) {
        r2++;
      }
      for (let i = r1; i <= r2; i++) {
        cells.push([i, col]);
      }
    }

    const contents = [];
    let pattern = "";
    for (let m = 0; m < cells.length; m++) {
      const [r, c] = cells[m];
      contents.push(g[r][c].contents);
      if (g[r][c].contents === "") {
        pattern += ".";
      } else {
        pattern += g[r][c].contents;
      }
    }

    const firstCell = g[cells[0][0]][cells[0][1]];
    const clueTitle =
        (firstCell.number !== null ? firstCell.number : "?") + " " +
        (grid_focus.is_across ? "Across" : "Down");

    let clueText;
    if (firstCell.number !== null) {
      clueText = this.clueTextForNumber(grid_focus.is_across, firstCell.number);
    } else {
      clueText = "";
    }

    return this.setState({
      findMatchesInfo: {
        is_across: grid_focus.is_across,
        cells: cells,
        contents: contents,
        pattern: pattern.toLowerCase(),
        clueTitle: clueTitle,
        clueText: clueText,
        savedGridFocus: Utils.clone(grid_focus)
      }
    });
  }

  // Looks at the the text of one of the clue fields to find the clue for a given
  // number. Returns the text of that clue. If it can't be found, returns "".
  clueTextForNumber(is_across: boolean, number: number) {
    // get the text of the clues
    const ref = this.refs[is_across ? "acrossClues" : "downClues"];
    if (ref == null) {
      return "";
    }
    const text = ref.getText();
    // split it into lines
    const lines = text.split('\n');
    for (let k = 0; k < lines.length; k++) {
      const line = lines[k];
      const parsed = parseClueLine(line);
      if (parsed.number === number) {
        return parsed.secondPart.trim();
      }
    }
    return "";
  }

  closeMatchFinder() {
    if (!this.state.findMatchesInfo) {
      return;
    }

    // close the match-finder panel, and also restore the grid_focus to whatever it was
    // before entering the match-finding state
    const grid_focus = this.state.findMatchesInfo.savedGridFocus != null ?
        this.state.findMatchesInfo.savedGridFocus : null;
    this.setState({
      findMatchesInfo: null
    });
    this.requestFocus(grid_focus);
  }

  // If the user selects a word in the match-finder dialog, we enter that word
  // into the grid here.
  // Note that the board could have changed since the dialog was opened, and maybe
  // the word doesn't match anymore. In that case, we fail.
  onMatchFinderChoose(word: string) {
    if (!this.state.findMatchesInfo) {
      return;
    }
    const fail = function() {
      return alert('Unable to enter "' + word +
          '" into the grid; maybe the grid has been modified?');
    };
    const info = this.state.findMatchesInfo;
    const g = this.state.puzzle.grid;
// Check that all the cells are still open
    for (let i = 0; i < info.cells.length; i++) {
      const [r, c] = info.cells[i];
      if (!(0 <= r && r < this.height() && 0 <= c && c < this.width() && g[r][c].open)) {
        fail();
        return;
      }
      if (i < info.cells.length - 1 && g[r][c][info.is_across ? 'rightbar' : 'bottombar']) {
        fail();
        return;
      }
    }
    // Check that the previous and subsequent cells are not open
    let prevR = info.cells[0][0];
    let prevC = info.cells[0][1];
    let nextR = info.cells[info.cells.length - 1][0];
    let nextC = info.cells[info.cells.length - 1][1];
    if (info.is_across) {
      prevC--;
      nextC++;
    } else {
      prevR--;
      nextR++;
    }
    if ((prevR >= 0 && prevR < this.height() && prevC >= 0 && prevC < this.width() &&
         g[prevR][prevC].open && !g[prevR][prevC][info.is_across ? 'rightbar' : 'bottombar']) ||
        (nextR >= 0 && nextR < this.height() && nextC >= 0 && nextC < this.width() &&
        g[nextR][nextC].open &&
        !g[info.cells[info.cells.length - 1][0]][info.cells[info.cells.length - 1][1]][info.is_across ? 'rightbar' : 'bottombar'])) {
      fail();
      return;
    }

    // Make the list of updates to make
    const updates = [];
    let wordPos = 0;
    for (let l = 0; l < info.cells.length; l++) {
      const [r, c] = info.cells[l];
      const cell = g[r][c];
      if (cell.contents === "") {
        // cell contents are empty, so take the next letter of the match word.
        if (wordPos >= word.length) {
          fail();
          return;
        }
        const nextLetter = word.substring(wordPos, wordPos + 1);
        wordPos++;
        updates.push({
          row: r,
          col: c,
          contents: nextLetter.toUpperCase()
        });
      } else {
        // cell is not empty:
        // check that contents of the cell match what the match word says they should be
        if (word.substring(wordPos, wordPos + cell.contents.length).toLowerCase() !== cell.contents.toLowerCase()) {
          fail();
          return;
        }
        wordPos += cell.contents.length;
      }
    }
    if (wordPos !== word.length) {
      // If there isn't enough room for the whole match word, fail.
      fail();
      return;
    }

    // Now we have verified everything is OK and we have a list of updates.
    // So now we just construct the op and apply it.
    let op = Ot.identity(this.state.puzzle);
    for (let m = 0; m <  updates.length; m++) {
      const update = updates[m];
      op = Ot.compose(this.state.puzzle, op,
          Ot.opEditCellValue(update.row, update.col, "contents", update.contents));
    }
    this.requestOp(op);
    this.closeMatchFinder();
  }

  // setting dimensions
  onSetDimensions(width: number, height: number) {
    // NOTE: this actually has one pretty annoying consequence: if the dimensions
    // are, say, 15x15 and two users set them to 20x20 at the same time, each user
    // will add 5 rows and 5 cols, so the dimension will end up at 25x25 when they
    // probably just wanted 20x20. I guess this is a symptom of the row/col OT
    // being overly sophisticated? Well, we could fix this at the OT layer. (TODO)
    let op = Ot.identity(this.state.puzzle);
    if (width < this.width()) {
      op = Ot.compose(this.state.puzzle, op, Ot.opDeleteCols(this.state.puzzle, width, this.width() - width));
    } else if (width > this.width()) {
      op = Ot.compose(this.state.puzzle, op, Ot.opInsertCols(this.state.puzzle, this.width(), width - this.width()));
    }
    if (height < this.height()) {
      op = Ot.compose(this.state.puzzle, op, Ot.opDeleteRows(this.state.puzzle, height, this.height() - height));
    } else if (height > this.height()) {
      op = Ot.compose(this.state.puzzle, op, Ot.opInsertRows(this.state.puzzle, this.height(), height - this.height()));
    }
    this.requestOp(op);
  }

  // Copy/cut/paste stuff
  doCopy(event: any) {
    const grid_focus = this.state.grid_focus;
    if (grid_focus === null) {
      return;
    }

    // Get the submatrix to copy
    const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
    const row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row);
    const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
    const col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col);
    const submatr = Utils.submatrix(this.state.puzzle.grid, row1, row2 + 1, col1, col2 + 1);

    // Copy it to clipboard
    ClipboardUtils.copyGridToClipboard(event, col2 - col1 + 1, row2 - row1 + 1, submatr);
  }

  doCut(event: any) {
    if (this.state.grid_focus === null) {
      return;
    }
    this.doCopy(event);
    this.doDeleteAll();
  }

  doPaste(event: any) {
    const grid_focus = this.state.grid_focus;
    if (grid_focus === null) {
      return;
    }
    const submatr = ClipboardUtils.getGridFromClipboard(event);
    if (submatr != null) {
      // get the upper-left corner
      const row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row);
      const col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col);
      this.pasteGridAt(row1, col1, submatr);
      return event.preventDefault();
    }
  }

  pasteGridAt(row: number, col: number, grid: PastedGrid) {
    const base = this.state.puzzle;
    let op = Ot.identity(base);
    // make sure the grid is big enough; if not, expand it
    if (col + grid.width >= this.width()) {
      op = Ot.compose(base, op, Ot.opInsertCols(base, this.width(), col + grid.width - this.width()));
    }
    if (row + grid.height >= this.height()) {
      op = Ot.compose(base, op, Ot.opInsertRows(base, this.height(), row + grid.height - this.height()));
    }
    for (let i = 0; i < grid.height; i++) {
      for (let j = 0; j < grid.width; j++) {
        op = Ot.compose(base, op, Ot.opEditCellValue(row + i, col + j, "contents", grid.grid[i][j].contents));
        op = Ot.compose(base, op, Ot.opEditCellValue(row + i, col + j, "number", grid.grid[i][j].number));
        op = Ot.compose(base, op, Ot.opEditCellValue(row + i, col + j, "open", grid.grid[i][j].open));
        op = Ot.compose(base, op, Ot.opSetBar(row + i, col + j, 'right', grid.grid[i][j].rightbar));
        op = Ot.compose(base, op, Ot.opSetBar(row + i, col + j, 'bottom', grid.grid[i][j].bottombar));
      }
    }
    // select the region that was just pasted in
    focus = {
      focus: {
        row: row + grid.height - 1,
        col: col + grid.width - 1
      },
      anchor: {
        row: row,
        col: col
      },
      is_across: this.state.grid_focus ? this.state.grid_focus.is_across : true,
      field_open: "none"
    };
    this.requestOpAndFocus(op, focus);
  }

  render() {
    if (this.state.puzzle === null) {
      return <div className="puzzle_container">
              Loading puzzle...
            </div>;
    } else {
      const acrossClueStylingData = this.clueStylingData(true);
      const downClueStylingData = this.clueStylingData(false);

      const selectedClueText = (stylingData, type) => {
        let number = null;
        let prevelance = null;
        if (stylingData.primaryNumber !== null) {
          number = stylingData.primaryNumber;
          prevelance = "primary";
        }
        if (stylingData.secondaryNumber !== null) {
          number = stylingData.secondaryNumber;
          prevelance = "secondary";
        }
        if (number !== null) {
          // TODO depending on this is bad :\
          // (we aren't guaranteed to update when the text changes, so we
          // need to re-architect something)
          const text = this.clueTextForNumber(type === 'Across', number);
          return [`${number} ${type}.`, text, prevelance];
        } else {
          return null;
        }
      };

      let selectedClueTextData = [];
      selectedClueTextData.push(selectedClueText(acrossClueStylingData, 'Across'));
      selectedClueTextData.push(selectedClueText(downClueStylingData, 'Down'));
      selectedClueTextData = selectedClueTextData.filter((a) => a !== null);

      return (
        <div className="puzzle_container">
          <div className="puzzle_title">
              <h1 className="puzzle_title_header">{this.state.puzzle.title}</h1>
          </div>
          <div className="puzzle_container_column">
              <div className="puzzle_container_box_grid">
                  {this.renderPuzzleGrid()}
              </div>
              <div className="puzzle_container_box_panel puzzle_container_panel">
                  <PuzzlePanel
                      selectedClueTextData={selectedClueTextData}
                      findMatchesInfo={this.state.findMatchesInfo}
                      onMatchFinderChoose={this.onMatchFinderChoose.bind(this)}
                      onMatchFinderChoose={this.onMatchFinderChoose.bind(this)}
                      onMatchFinderClose={this.closeMatchFinder.bind(this)}
                      renumber={this.renumber.bind(this)}
                      width={this.state.puzzle.width}
                      height={this.state.puzzle.height}
                      onSetDimensions={this.onSetDimensions.bind(this)}
                      needToRenumber={this.needToRenumber()}
                      toggleMaintainRotationalSymmetry={this.toggleMaintainRotationalSymmetry.bind(this)}
                      maintainRotationalSymmetry={this.state.maintainRotationalSymmetry} />
                  {this.renderToggleOffline()}
              </div>
          </div>
          <div className="puzzle_container_column">
              <div className="puzzle_container_box_across">
                  {this.renderPuzzleClues('across', acrossClueStylingData)}
              </div>
              <div className="puzzle_container_box_down">
                  {this.renderPuzzleClues('down', downClueStylingData)}
              </div>
          </div>
        </div>
      );
    }
  }

  renderPuzzleGrid() {
    return (
      <div className="puzzle_grid">
        <PuzzleGridComponent
            ref="grid"
            grid={this.state.puzzle.grid}
            grid_focus={this.state.grid_focus}
            cell_classes={this.getCellClasses()}
            cursorInfos={this.getCursorInfos()}
            bars={this.getBars()}
            onCellClick={this.onCellClick.bind(this)}
            onCellFieldKeyPress={this.onCellFieldKeyPress.bind(this)} />
      </div>
    );
  }

  renderPuzzleClues(type: 'across' | 'down', stylingData: any) {
    return (
      <div>
        <div className="clue_box_title">
            <strong>{(type === "across" ? "Across" : "Down")} clues:</strong>
        </div>
        <CluesEditableTextField
            defaultText={type === "across" ?
              this.state.initial_puzzle.across_clues :
              this.state.initial_puzzle.down_clues}
            produceOp={(op) => { return this.clueEdited(type, op); }}
            stylingData={stylingData}
            ref={type === "across" ? "acrossClues" : "downClues"} />
      </div>
    );
  }

  getCursorInfos() {
    const res = Utils.makeMatrix(this.height(), this.width(), () => []);
    for (const id in this.state.cursors) {
      const cursor = this.state.cursors[id];
      if (cursor.focus) {
        res[cursor.focus.row][cursor.focus.col].push({
          id: id,
          across: cursor.is_across
        });
      }
    }
    return res;
  }

  renderToggleOffline() {
    // This is just for debugging, so it's commented out right now:
    //
    //<div className="offline_mode" style={{'display': 'none'}}>
    //    <input type="checkbox"
    //            defaultChecked={false}
    //            onChange={@toggleOffline} />
    //        Offline mode
    //</div>
  }
}

class PuzzlePanel extends React.Component<any> {
  render() {
    const meta = KeyboardUtils.getMetaKeyName();
    if (this.props.findMatchesInfo) {
      return <FindMatchesDialog
          clueTitle={this.props.findMatchesInfo.clueTitle}
          clueText={this.props.findMatchesInfo.clueText}
          pattern={this.props.findMatchesInfo.pattern}
          onSelect={this.props.onMatchFinderChoose}
          onClose={this.props.onMatchFinderClose} />;
    } else {
      return <div>
                <SelectedClueTextWidget data={this.props.selectedClueTextData} />
                <DimensionWidget
                    width={this.props.width}
                    height={this.props.height}
                    onSet={this.props.onSetDimensions} />
                <div className="reassign-numbers-container">
                  <input
                      type="button"
                      value="Re-assign numbers"
                      onClick={this.props.renumber}
                      title="Sets the numbers in the grid based off of the locations of the black cells, according to standard crossword rules."
                      className="lt-button"
                      disabled={this.props.needToRenumber} />
                </div>
                <div className="rotational-symmetry-container">
                  <input
                      type="checkbox"
                      className="lt-checkbox"
                      defaultChecked={this.props.maintainRotationalSymmetry}
                      onChange={this.props.toggleMaintainRotationalSymmetry} />
                  <label className="lt-checkbox-label">Maintain rotational symmetry</label>
                </div>
                <div>
                      <h2 className="instructions-header">Tips for solving:</h2>
                      <ul>
                        <li>Arrow keys to move around.</li>
                        <li>Type any letter to enter it into the selected cell.</li>
                        <li><span className="keyboard-shortcut">BACKSPACE</span>
                            {" "}to empty a cell.
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+G</span>
                            {" "}to search a dictionary for matches of a partially-filled in answer.
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+U</span>
                            {" "}to enter arbitrary text into a cell (not restricted to a single letter).
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+Z</span>{" "}and{" "}<span className="keyboard-shortcut">{meta}+SHIFT+Z</span>
                            {" "}to undo and redo.
                            </li>
                      </ul>
                      <h2 className="instructions-header">Tips for editing the grid (or for solving diagramless crosswords):</h2>
                      <ul>
                        <li><span className="keyboard-shortcut">{meta}+B</span>
                            {" "}to toggle a cell between black/white.
                            </li>
                        <li>Use the 'Re-assign numbers' button to fill in numbers, inferring them from
                            {" "}the positions of the black cells.</li>
                        <li><span className="keyboard-shortcut">{meta}+I</span>
                            {" "}to manually edit the number of the cell.
                            </li>
                        <li>Put the clues in the text field on the right. The application will automatically
                            associate lines that start with a number (e.g., "1.") with the corresponding
                            cells on the grid.
                            </li>
                        <li>Hold <span className="keyboard-shortcut">{meta}</span>{" "}and use the arrow keys to add walls between cells.</li>
                        <li>Hold{" "}<span className="keyboard-shortcut">SHIFT</span>{" "}and use the arrow keys to select a rectangular region.</li>
                        <li><span className="keyboard-shortcut">{meta}+X</span>{" "}to cut.</li>
                        <li><span className="keyboard-shortcut">{meta}+C</span>{" "}to copy.</li>
                        <li><span className="keyboard-shortcut">{meta}+V</span>{" "}to paste.</li>
                      </ul>
                </div>
            </div>;
    }
  }
}

type DimensionWidgetProps = {
  width: number,
  height: number,
  onSet: (number, number) => void,
};

type DimensionWidgetState = {
  isEditing: boolean,
};

class DimensionWidget extends React.Component<DimensionWidgetProps, DimensionWidgetState> {
  constructor(props) {
    super(props);
    this.state = {
      isEditing: false
    };
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.deepEquals(this.props, nextProps) ||
           !Utils.deepEquals(this.state, nextState);
  }

  render() {
    if (this.state.isEditing) {
      return (
        <div className="dimension-panel">
          <span className="dimension-panel-edit-1">Width:</span>
          <span className="dimension-panel-edit-2">
            <input
                type="text"
                defaultValue={this.props.width}
                onKeyDown={this.onKeyDown.bind(this)}
                ref={this.widthInputFun.bind(this)}
                className="dont-bubble-keydown"
                size="4" />
          </span>
          <span className="dimension-panel-edit-3">Height:</span>
          <span className="dimension-panel-edit-4">
            <input
                type="text"
                defaultValue={this.props.height}
                onKeyDown={this.onKeyDown.bind(this)}
                ref={this.heightInputFun.bind(this)}
                className="dont-bubble-keydown"
                size="4" />
          </span>
          <span className="dimension-panel-edit-5">
            <input
              type="button"
              className="lt-button"
              value="Submit"
              onClick={this.onSubmit.bind(this)} />
          </span>
        </div>
      );
    } else {
      return (
        <div className="dimension-panel">
          <span className="dimension-panel-static-1">Width:</span>
          <span className="dimension-panel-static-2">{this.props.width}</span>
          <span className="dimension-panel-static-3">Height:</span>
          <span className="dimension-panel-static-4">{this.props.height}</span>
          <span className="dimension-panel-static-5">
            <input
                type="button"
                className="lt-button"
                value="Edit"
                onClick={this.onClickEdit.bind(this)} />
          </span>
        </div>
      );
    }
  }

  widthInput: any;
  heightInput: any;

  widthInputFun(elem) {
    if ((elem != null) && (this.widthInput == null)) {
      // when creating this field, focus on it
      const node = ReactDom.findDOMNode(elem);
      if (!(node instanceof HTMLInputElement)) {
        throw new Error("widthInputFun: expected HTMLInputElement");
      }
      // code to focus on the input element 'node' at the END
      // from http://stackoverflow.com/questions/1056359/set-mouse-focus-and-move-cursor-to-end-of-input-using-jquery
      node.focus();
      if (node.setSelectionRange) {
        const len = $(node).val().length * 2;
        node.setSelectionRange(len, len);
      } else {
        $(node).val($(node).val());
      }
    }
    this.widthInput = elem;
  }

  heightInputFun(elem) {
    return this.heightInput = elem;
  }

  onClickEdit() {
    this.setState({
      isEditing: true
    });
  }

  onSubmit() {
    const widthInput = ReactDom.findDOMNode(this.widthInput);
    const heightInput = ReactDom.findDOMNode(this.heightInput);
    if (!(widthInput instanceof HTMLInputElement) ||
        !(heightInput instanceof HTMLInputElement)) {
      throw new Error("expected HTMLInputElement in DimensionWidget.onSubmit");
    }

    const widthStr = widthInput.value;
    const heightStr = heightInput.value;

    if ((!Utils.isValidInteger(widthStr)) || (!Utils.isValidInteger(heightStr))) {
      return;
    }
    const width = parseInt(widthStr, 10);
    const height = parseInt(heightStr, 10);
    if (width <= 0 || height <= 0 || width >= 200 || height >= 200) {
      return;
    }
    this.props.onSet(width, height);
    this.setState({
      isEditing: false
    });
  }

  onCancelEdit() {
    this.setState({
      isEditing: false
    });
  }

  onKeyDown(event) {
    if (event.which === 13) { // enter
      this.onSubmit();
      event.preventDefault();
    } else if (event.which === 27) { // escape
      this.onCancelEdit();
      event.preventDefault();
    }
  }
}

type PuzzleGridProps = any;
type PuzzleGridState = { }

class PuzzleGridComponent extends React.Component<PuzzleGridProps, PuzzleGridState> {
  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.deepEquals(this.props, nextProps);
  }

  render() {
    return (
      <table className="puzzle_grid_table"><tbody>
        {Utils.makeArray(this.props.grid.length, (row) => {
          return (
            <PuzzleGridRow
                key={"puzzle-grid-row-" + row}
                row={row}
                grid_row={this.props.grid[row]}
                cell_classes={this.props.cell_classes[row]}
                cursorInfos={this.props.cursorInfos[row]}
                bars={this.props.bars[row]}
                grid_focus={(this.props.grid_focus != null) && this.props.grid_focus.focus.row === row ? this.props.grid_focus : null}
                onCellFieldKeyPress={
                    (event, col) => { this.props.onCellFieldKeyPress(event, row, col); }}
                onCellClick={(col) => { this.props.onCellClick(row, col); }} />
          );
        })}
      </tbody></table>
    );
  }
}

type PuzzleGridRowProps = any;
type PuzzleGridRowState = { }

class PuzzleGridRow extends React.Component<PuzzleGridRowProps, PuzzleGridRowState> {
  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.deepEquals(this.props, nextProps);
  }

  render() {
    return (
      <tr className="puzzle_grid_row">
        {Utils.makeArray(this.props.grid_row.length, (col) => {
          return (
            <PuzzleGridCell
                key={"puzzle-grid-col-" + col}
                row={this.props.row}
                col={col}
                grid_cell={this.props.grid_row[col]}
                cell_class={this.props.cell_classes[col]}
                cursorInfo={this.props.cursorInfos[col]}
                bars={this.props.bars[col]}
                grid_focus={(this.props.grid_focus != null) && this.props.grid_focus.focus.col === col ? this.props.grid_focus : null}
                onCellFieldKeyPress={(event) => { this.props.onCellFieldKeyPress(event, col); }}
                onCellClick={(event) => { this.props.onCellClick(col); }} />
          );
        })}
      </tr>
    );
  }
}

type PuzzleGridCellProps = any;
type PuzzleGridCellState = { }

class PuzzleGridCell extends React.Component<PuzzleGridCellProps, PuzzleGridCellState> {
  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.deepEquals(this.props, nextProps);
  }

  render() {
    const cell = this.props.grid_cell;
    return (
      <td
          onClick={this.props.onCellClick}
          className={"puzzle_grid_cell " + this.props.cell_class}>
        {(cell.open ?
            <div>
              {(this.props.bars.left ? <div className="left-bar">{'\xA0'}</div> : void 0)}
              {(this.props.bars.right ? <div className="right-bar">{'\xA0'}</div> : void 0)}
              {(this.props.bars.top ? <div className="top-bar">{'\xA0'}</div> : void 0)}
              {(this.props.bars.bottom ? <div className="bottom-bar">{'\xA0'}</div> : void 0)}
              {(this.props.cursorInfo.length > 0 ? <CursorInfos info={this.props.cursorInfo} /> : void 0)}
              <div style={{ position: 'relative', height: '100%', width: '100%' }}>
                <div className="cell_number">
                    {(cell.number !== null ? cell.number : "")}
                </div>
              </div>
              <div className="cell_contents">
                {(cell.contents === "" ? "\xA0" : cell.contents)}
              </div>
            </div>
          :
            <div>{"\xA0"}</div>
        )}
        {((this.props.grid_focus != null) && this.props.grid_focus.field_open !== "none" ?
          <div style={{ position: 'relative' }}>
            <div className="cellField">
              <input
                  type="text"
                  id="cellFieldInput"
                  defaultValue={this.getCellFieldInitialValue()}
                  ref={this.onCellFieldCreate.bind(this)}
                  className="dont-bubble-keydown"
                  onKeyDown={this.props.onCellFieldKeyPress} />
            </div>
          </div> : undefined)
        }
      </td>
    );
  }

  onCellFieldCreate(field) {
    if (field != null) {
      const node = ReactDom.findDOMNode(field);
      if (!(node instanceof HTMLInputElement)) {
        throw new Error("onCellFieldCreate: expected HTMLInputElement");
      }
      node.focus();
      if (node.setSelectionRange) {
        node.setSelectionRange(0, $(node).val().length * 2);
      }
    }
  }

  getCellFieldInitialValue() {
    if (this.props.grid_focus !== null) {
      const cell = this.props.grid_cell;
      if (this.props.grid_focus.field_open === "number") {
        if (cell.number === null) {
          return "";
        } else {
          return cell.number.toString();
        }
      } else if (this.props.grid_focus.field_open === "contents") {
        return cell.contents;
      }
    } else {
      return null;
    }
  }
}

type CursorInfosProps = any;
type CursorInfosState = { }

class CursorInfos extends React.Component<CursorInfosProps, CursorInfosState> {
  // todo awesomeness here
  render() {
    return (
      <div className="cursor-marker">
        {'\xA0'}
      </div>
    );
  }
}

type SelectedClueTextWidgetProps = any;
type SelectedClueTextWidgetState = { }

class SelectedClueTextWidget extends
    React.Component<SelectedClueTextWidgetProps, SelectedClueTextWidgetState> {

  render() {
    return <div className="selected-clue-text-widget">{this.renderMain()}</div>;
  }

  renderMain() {
    if (this.props.data.length === 0) {
      return <div>&nbsp;</div>;
    } else {
      return (
        <div className="selected-clue-text-display">
          {Utils.makeArray(this.props.data.length, (i) => {
            const datum = this.props.data[i];
            return (
              <div
                  key={"sctd-" + i}
                  className={"selected-clue-text-display-item selected-clue-text-display-item-" + datum[2] + (this.props.data.length === 2 ? " selected-clue-text-display-item-" + i : "")}>
                <strong>{datum[0]}</strong>{" " + datum[1]}
              </div>
            );
          })}
        </div>
      );
    }
  }
}

const CluesEditableTextField = EditableTextField(function(lines, stylingData) {
  let i = -1;
  const results = [];
  for (let k = 0; k < lines.length; k++) {
    const line = lines[k];
    i += 1;
    const childElem = document.createElement('div');
    if (line.length > 0) {
      const parsed = parseClueLine(line);
      if (parsed.firstPart.length > 0) {
        const el = document.createElement('b');
        $(el).text(Utils.useHardSpaces(parsed.firstPart));
        childElem.appendChild(el);
      }
      if (parsed.secondPart.length > 0) {
        const el = document.createTextNode(Utils.useHardSpaces(parsed.secondPart));
        childElem.appendChild(el);
      }
      $(childElem).addClass('clue-line');
      // clues-highlight-{primary,secondary} classes are for visual styling
      // node-in-view signals to EditableTextField that the node should be scrolled into view.
      if (parsed.number && parsed.number === stylingData.primaryNumber) {
        $(childElem).addClass('clues-highlight-primary');
        $(childElem).addClass('node-in-view');
      }
      if (parsed.number && parsed.number === stylingData.secondaryNumber) {
        $(childElem).addClass('clues-highlight-secondary');
        $(childElem).addClass('node-in-view');
      }
      // display the length of the answer next to the clue, (where the length is
      // calculated based on the cells)
      if (parsed.number && parsed.number in stylingData.answerLengths) {
        $(childElem).addClass('display-answer-length-next-to-line');
        $(childElem).attr('data-answer-length', '(' + stylingData.answerLengths[parsed.number] + ')');
      }
    } else {
      childElem.appendChild(document.createElement('br'));
    }
    results.push(childElem);
  }
  return results;
});

// Takes a line and parses it assuming it is of the form
// X. clue
// return an object
// { number, firstPart, secondPart }
// If it can't be parsed as such, number is null, firstPart is empty, and secondPart is the entire contents
function parseClueLine(line) {
  let i = 0;
  while (i < line.length && Utils.isWhitespace(line.charAt(i))) {
    i += 1;
  }
  let j = i;
  while (j < line.length && line.charAt(j) >= '0' && line.charAt(j) <= '9') {
    j += 1;
  }
  if (j > i && j < line.length && line.charAt(j) === '.') {
    return {
      number: parseInt(line.substring(i, j)),
      firstPart: line.substring(0, j + 1),
      secondPart: line.substring(j + 1, line.length)
    };
  } else {
    return {
      number: null,
      firstPart: '',
      secondPart: line
    };
  }
}
