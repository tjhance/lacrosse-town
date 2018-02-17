/* @flow */

import * as PuzzleUtils from "./puzzle_utils"
import * as Utils from "./utils"
import * as OtText from "./ottext"

import type {PuzzleState, PuzzleGrid} from './types';
import type {TextOperation} from './ottext';

export opaque type Operation = any;

// Abstract operational transformation functions
// Many of these functions (may) need to know the grid that the operation
// is based on. For those, the base state is passed in as the argument 'base'.
// No arguments are ever mutated.

export function identity(base: PuzzleState): Operation {
  return {};
}

export function isIdentity(a: Operation): boolean {
  return Object.keys(a).length == 0;
}

//        a          b
//      -----> s1 ------>
// base                   s2
//      ---------------->
//             c
// Takes a and b, and returns the composition c
export function compose(base: PuzzleState, a: Operation, b: Operation): Operation {
  // compose the grid ops
  const [aRowsOp, aColsOp] = getRowsOpAndColsOp(base, a);
  const width1 = OtText.applyTextOp(Utils.repeatString(".", base.width), aColsOp).length;
  const height1 = OtText.applyTextOp(Utils.repeatString(".", base.height), aRowsOp).length;
  const [bRowsOp, bColsOp] = getRowsOpAndColsOp({width: width1, height: height1}, b);

  const aNew = moveKeyUpdatesOverRowsAndColsOp([bRowsOp, bColsOp], a);

  const c = {}
  for (const key in aNew) {
    c[key] = aNew[key];
  }
  for (const key in b) {
    c[key] = b[key];
  }

  if (a.rows || b.rows) {
    c.rows = OtText.composeText(Utils.repeatString(".", base.height), aRowsOp, bRowsOp);
  }
  if (a.cols || b.cols) {
    c.cols = OtText.composeText(Utils.repeatString(".", base.width), aColsOp, bColsOp);
  }

  // compose the 'clues' text fields
  const merge_clue = (name, t) => {
    if (name in a && name in b) {
      c[name] = OtText.composeText(t, a[name], b[name]);
    } else if (name in a) {
      c[name] = a[name];
    } else if (name in b) {
      c[name] = b[name]
    }
  };
  merge_clue("across_clues", base["across_clues"]);
  merge_clue("down_clues", base["down_clues"]);

  const removeIfIdentity = (name) => {
    if (c[name] && OtText.isIdentity(c[name])) {
      delete c[name];
    }
  };
  removeIfIdentity('rows');
  removeIfIdentity('cols');
  removeIfIdentity('across_clues');
  removeIfIdentity('down_clues');

  return c;
}

export function inverse(base: PuzzleState, op: Operation): Operation {
  const [rowsOp, colsOp] = getRowsOpAndColsOp(base, op);
  const rowsOpInv = OtText.inverseText(Utils.repeatString(".", base.height), rowsOp);
  const colsOpInv = OtText.inverseText(Utils.repeatString(".", base.width), colsOp);

  const rowIndexMap = OtText.getIndexMapForTextOp(rowsOp);
  const colIndexMap = OtText.getIndexMapForTextOp(colsOp);
  const rowIndexMapInv = OtText.getIndexMapForTextOp(rowsOpInv);
  const colIndexMapInv = OtText.getIndexMapForTextOp(colsOpInv);

  const res = {}

  // any cell deleted in the op must be restored in the inverse op
  for (let i = 0; i < base.height; i++) {
    for (let j = 0; j < base.width; j++) {
      if ((!(i in rowIndexMap)) || (!(j in colIndexMap))) {
        for (const type of ["open", "contents", "number", "rightbar", "bottombar"]) {
          res[`cell-${i}-${j}-${type}`] = base.grid[i][j][type];
        }
      }
    }
  }

  for (let i = 0; i < base.height; i++) {
    if (!(i in rowIndexMap)) {
      for (const type of ["leftbar"]) {
        res[`rowprop-${i}-${type}`] = base.row_props[i][type];
      }
    }
  }

  for (let j = 0; j < base.width; j++) {
    if (!(j in colIndexMap)) {
      for (const type of ["topbar"]) {
        res[`colprop-${j}-${type}`] = base.col_props[j][type];
      }
    }
  }

  // any key modified explicitly by the op must be set back to the
  // original in the inverse op
  for (const key in op) {
    const spl = key.split("-");
    if (spl[0] === "cell") {
      const i = parseInt(spl[1], 10);
      const j = parseInt(spl[2], 10);
      const type = spl[3];
      if ((i in rowIndexMapInv) && (j in colIndexMapInv)) {
        const i1 = rowIndexMapInv[i];
        const j1 = colIndexMapInv[j];
        res[`cell-${i1}-${j1}-${type}`] = base.grid[i1][j1][type];
      }
    } else if (spl[0] === "rowprop") {
      const i = parseInt(spl[1], 10);
      const type = spl[2];
      if (i in rowIndexMapInv) {
        const i1 = rowIndexMapInv[i];
        res[`rowprop-${i1}-${type}`] = base.row_props[i1][type];
      }
    } else if (spl[0] === "colprop") {
      const j = parseInt(spl[1], 10);
      const type = spl[2];
      if (j in colIndexMapInv) {
        const j1 = colIndexMapInv[j];
        res[`colprop-${j1}-${type}`] = base.col_props[j1][type];
      }
    }
  }

  if (op.rows) {
    res.rows = rowsOpInv;
  }
  if (op.cols) {
    res.cols = colsOpInv;
  }

  for (const t of ['across_clues', 'down_clues']) {
    if (t in op) {
      res[t] = OtText.inverseText(base[t], op[t]);
    }
  }

  return res;
}

// The operational transformation.

//             s3
//             /\
//         b1 /  \ a1
//           /    \
//          /      \
//         s1      s2
//          \      /
//         a \    / b
//            \  /
//             \/
//            base

// a o b1 = b o a1
// This function takes in base, a, and b and returns a list [a1, b1].
// Where applicable, b should be from the "saved updates" and a
// should be a "new" update. For example, a is a new update from a client,
// and b is an update saved on the server that was applied before a.
// Right now, a overrides b when they conflict.
export function xform(base: PuzzleState, a: Operation, b: Operation): [Operation, Operation] {
  // The implementation has to deal with the interplay between inserting
  // and deleting rows and cols.
  // Best to think of this graph:

  //           /\
  //      kb2 /  \ ka2
  //         /    \
  //        /      \
  //       /\   kb1/\
  //  gb1 /  \ka1 /  \ ga1
  //     /    \  /    \
  //    /      \/      \
  //    \      /\      /
  //  ka \ gb1/  \ga1 / kb
  //      \  /    \  /
  //       \/      \/
  //        \      /
  //     ga  \    /  gb
  //          \  /
  //           \/
  // Our inputs a and b can be broken down into:
  //       a = compose(ga, ka)
  //       b = compose(gb, kb)
  // where ga is the grid component (rows/cols) and ka is the cells/keys component
  // so in the bottom diamond, we xform the two grid components
  // in the left and right diamond, we xform a grid op with the keys op
  // and finally we do the keys xform at the top
  const [gaRows, gaCols] = getRowsOpAndColsOp(base, a);
  const [gbRows, gbCols] = getRowsOpAndColsOp(base, b);
  const [gaRows1, gbRows1] = OtText.xformText(Utils.repeatString(".", base.height), gaRows, gbRows);
  const [gaCols1, gbCols1] = OtText.xformText(Utils.repeatString(".", base.height), gaCols, gbCols);
  const ga1 = [gaRows1, gaCols1];
  const gb1 = [gbRows1, gbCols1];
  const ka1 = moveKeyUpdatesOverRowsAndColsOp(gb1, a);
  const kb1 = moveKeyUpdatesOverRowsAndColsOp(ga1, b);
  const ka2 = ka1;
  const kb2 = {};
  for (const key in kb1) {
    if (!(key in ka1)) {
      kb2[key] = kb1[key];
    }
  }
  const ref = ["across_clues", "down_clues"];
  for (let k = 0, len = ref.length; k < len; k++) {
    const strname = ref[k];
    if (strname in a && strname in b) {
      const xformRes = OtText.xformText(base[strname], a[strname], b[strname]);
      ka2[strname] = xformRes[0];
      kb2[strname] = xformRes[1];
    } else if (strname in a) {
      ka2[strname] = a[strname];
    } else if (strname in b) {
      kb2[strname] = b[strname];
    }
  }
  if ((a.rows != null) || (b.rows != null)) {
    ka2.rows = gaRows1;
    kb2.rows = gbRows1;
  }
  if ((a.cols != null) || (b.cols != null)) {
    ka2.cols = gaCols1;
    kb2.cols = gbCols1;
  }
  const removeIfIdentity = function(c, name) {
    if (c[name] && OtText.isIdentity(c[name])) {
      return delete c[name];
    }
  };
  removeIfIdentity(ka2, 'rows');
  removeIfIdentity(ka2, 'cols');
  removeIfIdentity(ka2, 'across_clues');
  removeIfIdentity(ka2, 'down_clues');
  removeIfIdentity(kb2, 'rows');
  removeIfIdentity(kb2, 'cols');
  removeIfIdentity(kb2, 'across_clues');
  removeIfIdentity(kb2, 'down_clues');
  return [ka2, kb2];
}

// Returns the state obtained by applying operation a to base.
export function apply(base: PuzzleState, a: Operation): PuzzleState {
  const res = PuzzleUtils.clonePuzzle(base);
  if ((a.rows != null) || (a.cols != null)) {
    const newGridInfo = applyRowAndColOpsToGrid(res, getRowsOpAndColsOp(res, a));
    res.grid = newGridInfo.grid;
    res.width = newGridInfo.width;
    res.height = newGridInfo.height;
    res.row_props = newGridInfo.row_props;
    res.col_props = newGridInfo.col_props;
  }
  for (const key in a) {
    const value = a[key];
    const components = key.split("-");
    switch (components[0]) {
      case "cell": {
        const row = parseInt(components[1]);
        const col = parseInt(components[2]);
        const name = components[3];
        res.grid[row][col][name] = value;
        break;
      }
      case "rowprop": {
        const row = parseInt(components[1]);
        const name = components[2];
        res.row_props[row][name] = value;
        break;
      }
      case "colprop": {
        const col = parseInt(components[1]);
        const name = components[2];
        res.col_props[col][name] = value;
        break;
      }
      case "across_clues":
        res.across_clues = OtText.applyTextOp(res.across_clues, value);
        break;
      case "down_clues":
        res.down_clues = OtText.applyTextOp(res.down_clues, value);
    }
  }
  return res;
}

// utilities for grid ot
function getRowsOpAndColsOp(puzzle: {width: number, height: number}, a) {
  return [a.rows || OtText.identity(Utils.repeatString(".", puzzle.height)), a.cols || OtText.identity(Utils.repeatString(".", puzzle.width))];
}

function moveKeyUpdatesOverRowsAndColsOp([rowsOp, colsOp], changes) {
  const rowIndexMap = OtText.getIndexMapForTextOp(rowsOp);
  const colIndexMap = OtText.getIndexMapForTextOp(colsOp);
  const result = {};
  for (const key in changes) {
    if (key.indexOf("cell-") === 0) {
      const spl = key.split("-");
      const rowIndex = parseInt(spl[1], 10);
      const colIndex = parseInt(spl[2], 10);
      const rest = spl[3];
      if (rowIndex in rowIndexMap && colIndex in colIndexMap) {
        const newKey = `cell-${rowIndexMap[rowIndex]}-${colIndexMap[colIndex]}-${rest}`;
        result[newKey] = changes[key];
      }
    } else if (key.indexOf("rowprop-") === 0) {
      const spl = key.split("-");
      const rowIndex = parseInt(spl[1], 10);
      const rest = spl[2];
      if (rowIndex in rowIndexMap) {
        const newKey = `rowprop-${rowIndexMap[rowIndex]}-${rest}`;
        result[newKey] = changes[key];
      }
    } else if (key.indexOf("colprop-") === 0) {
      const spl = key.split("-");
      const colIndex = parseInt(spl[1], 10);
      const rest = spl[2];
      if (colIndex in colIndexMap) {
        const newKey = `colprop-${colIndexMap[colIndex]}-${rest}`;
        result[newKey] = changes[key];
      }
    } else {
      result[key] = changes[key];
    }
  }
  return result;
}

function applyRowAndColOpsToGrid(puzzle: PuzzleState, [rowsOp, colsOp]) {
  const rowIndexMap = OtText.getIndexMapForTextOp(rowsOp);
  const colIndexMap = OtText.getIndexMapForTextOp(colsOp);
  
  const width = puzzle.width;
  const height = puzzle.height;
  const newWidth = OtText.applyTextOp(Utils.repeatString(".", width), colsOp).length;
  const newHeight = OtText.applyTextOp(Utils.repeatString(".", height), rowsOp).length;

  // $FlowFixMe
  const newGrid: Array<Array<PuzzleCell>> = Utils.makeMatrix(newHeight, newWidth, () => null);
  // $FlowFixMe
  const newRowProps: Array<RowProps> = Utils.makeArray(newHeight, () => null);
  // $FlowFixMe
  const newColProps: Array<ColProps> = Utils.makeArray(newWidth, () => null);

  for (let i = 0; i < height; i++) {
    if (i in rowIndexMap) {
      for (let j = 0; j < width; j++) {
        if (j in colIndexMap) {
          newGrid[rowIndexMap[i]][colIndexMap[j]] = puzzle.grid[i][j];
        }
      }
    }
  }
  for (let i = 0; i < height; i++) {
    if (i in rowIndexMap) {
      newRowProps[rowIndexMap[i]] = puzzle.row_props[i];
    }
  }
  for (let j = 0; j < width; j++) {
    if (j in colIndexMap) {
      newColProps[colIndexMap[j]] = puzzle.col_props[j];
    }
  }

  for (let i = 0; i < newHeight; i++) {
    for (let j = 0; j < newWidth; j++) {
      if (newGrid[i][j] === null) {
        newGrid[i][j] = PuzzleUtils.getEmptyCell();
      }
    }
  }
  for (let i = 0; i < newHeight; i++) {
    newRowProps[i] = PuzzleUtils.getEmptyRowProps();
  }
  for (let j = 0; j < newWidth; j++) {
    newColProps[j] = PuzzleUtils.getEmptyColProps();
  }

  return {
    width: newWidth,
    height: newHeight,
    grid: newGrid,
    row_props: newRowProps,
    col_props: newColProps,
  };
}

// Functions to return operations.

// Operation edits "contents", "number", or "open" value for a particular
// cell at (row, col).
export function opEditCellValue(row: number, col: number, name: string,
    value: string|number|boolean|null): Operation {
  const res = {};
  res[`cell-${row}-${col}-${name}`] = value;
  return res;
}

// Returns an operation op such that (apply puzzle, op) has grid of grid2.
// TODO support grids that are not the same size if needed?
export function opGridDiff(puzzle: PuzzleState, grid2: PuzzleGrid): Operation {
  const grid1 = puzzle.grid;
  const res = {};
  for (let i = 0; i < grid1.length; i++) {
    for (let j = 0; j < grid1[0].length; j++) {
      for (const v of ["contents", "number", "open", "rightbar", "bottombar"]) {
        if (grid1[i][j][v] !== grid2[i][j][v]) {
          res[`cell-${i}-${j}-${v}`] = grid2[i][j][v];
        }
      }
    }
  }
  return res;
}

export function opSpliceRowsOrCols(
    originalLen: number,
    forRow: boolean,
    index: number,
    numToInsert: number,
    numToDelete: number): Operation {
  const res = {};
  res[forRow ? 'rows' : 'cols'] = OtText.opTextSplice(originalLen, index, Utils.repeatString(".", numToInsert), numToDelete);
  return res;
}

export function opSetBar(row: number, col: number,
    dir: 'left' | 'right' | 'top' | 'bottom', value: boolean): Operation {
  const res = {};
  if (dir === 'left' || dir === 'right') {
    if (dir === 'left') {
      col -= 1;
    }
    if (col === -1) {
      res[`rowprop-${row}-leftbar`] = value;
    } else {
      res[`cell-${row}-${col}-rightbar`] = value;
    }
  } else if (dir === 'top' || dir === 'bottom') {
    if (dir === 'top') {
      row -= 1;
    }
    if (row === -1) {
      res[`colprop-${col}-topbar`] = value;
    } else {
      res[`cell-${row}-${col}-bottombar`] = value;
    }
  } else {
    throw new Error("invalid direction");
  }
  return res;
}

// Return an operation that inserts or deletes rows or columns at the specified index
export function opInsertRows(puzzle: PuzzleState, index: number, numToInsert: number): Operation {
  return opSpliceRowsOrCols(puzzle.height, true, index, numToInsert, 0);
}

export function opInsertCols(puzzle: PuzzleState, index: number, numToInsert: number): Operation {
  return opSpliceRowsOrCols(puzzle.width, false, index, numToInsert, 0);
}

export function opDeleteRows(puzzle: PuzzleState, index: number, numToDelete: number): Operation {
  return opSpliceRowsOrCols(puzzle.height, true, index, 0, numToDelete);
};

export function opDeleteCols(puzzle: PuzzleState, index: number, numToDelete: number): Operation {
  return opSpliceRowsOrCols(puzzle.width, false, index, 0, numToDelete);
}

// Returns an operation that applies the text_op to one of the clue fields.
// The parameter 'which' is either 'across' or 'down'.
// The parameter 'text_op' is a text operation as described in ottext.coffee
export function getClueOp(which: 'across' | 'down', text_op: TextOperation): Operation {
  const res = {};
  res[`${which}_clues`] = text_op;
  return res;
};

export function assertValidOp(base: PuzzleState, op: Operation): void {
  let newWidth, newHeight;
  if (op.cols != null) {
    newWidth = OtText.assertValidTextOp(Utils.repeatString(".", base.width), op.cols);
  } else {
    newWidth = base.width;
  }
  if (op.rows != null) {
    newHeight = OtText.assertValidTextOp(Utils.repeatString(".", base.height), op.rows);
  } else {
    newHeight = base.height;
  }
  for (const key in op) {
    if (key === "rows" || key === "cols") {
      // already handled this case
    } else if (key === "across_clues") {
      OtText.assertValidTextOp(base.across_clues, op[key]);
    } else if (key === "down_clues") {
      OtText.assertValidTextOp(base.down_clues, op[key]);
    } else {
      const spl = key.split('-');
      if (spl[0] === "cell") {
        Utils.assert(spl.length === 4);
        Utils.assert(Utils.isValidInteger(spl[1]));
        const y = parseInt(spl[1], 10);
        Utils.assert(Utils.isValidInteger(spl[2]));
        const x = parseInt(spl[2], 10);
        Utils.assert(0 <= y);
        Utils.assert(y < newHeight);
        Utils.assert(0 <= x);
        Utils.assert(x < newWidth);
        if (spl[3] === "number") {
          Utils.assert(op[key] === null || typeof op[key] === 'number');
        } else if (spl[3] === "contents") {
          Utils.assert(typeof op[key] === 'string');
        } else if (spl[3] === "open" || spl[3] === "rightbar" || spl[3] === "bottombar") {
          Utils.assert(typeof op[key] === 'boolean');
        } else {
          Utils.assert(false, "unknown cell property");
        }
      } else {
        Utils.assert(spl.length === 3);
        Utils.assert(spl[0] === "rowprop" || spl[0] === "colprop");
        const isRow = spl[0] === "rowprop";
        Utils.assert(Utils.isValidInteger(spl[1]));
        const index = parseInt(spl[1], 10);
        Utils.assert(0 <= index);
        Utils.assert(index <= (isRow ? newHeight : newWidth));
        if (isRow) {
          Utils.assert(spl[2] === "leftbar");
        } else {
          Utils.assert(spl[2] === "topbar");
        }
        Utils.assert(typeof op[key] === 'boolean');
      }
    }
  }
}
