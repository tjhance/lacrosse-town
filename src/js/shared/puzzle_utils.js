/* @flow */

// Some puzzle utilities

import * as Utils from "./utils";
import type {PuzzleState, PuzzleGrid, PuzzleCell, ColProps, RowProps} from './types';

// Returns an empty puzzle object.
export function getEmptyPuzzle(height: number, width: number, title: string): PuzzleState {
  Utils.assert(width > 0, "width is not positive");
  Utils.assert(height > 0, "height is not positive");
  return {
    title: title ? title : "",
    grid: getNumberedGrid(Utils.makeMatrix(height, width, (i, j) => getEmptyCell())),
    width: width,
    height: height,
    across_clues: "1. Clue here",
    down_clues: "1. Clue here",
    col_props: Utils.makeArray(width, () => getEmptyColProps()),
    row_props: Utils.makeArray(height, () => getEmptyRowProps()),
  }
}

export function getEmptyCell(): PuzzleCell {
  return {
    open: true,
    number: null,
    contents: "",
    rightbar: false,
    bottombar: false,
  };
}

export function getEmptyRowProps(): RowProps {
  return {
    leftbar: false,
  };
}

export function getEmptyColProps(): ColProps {
  return {
    topbar: false,
  };
}

// Take a grid and returns one numbered correctly according to which squares are
// open (i.e., white).
// Operates only on a grid (what's in the 'grid' field of a puzzle object) not
// the whole puzzle object.
export function getNumberedGrid(grid: PuzzleGrid): PuzzleGrid {
  const height = grid.length;
  const width = grid[0].length;
  const isOpen = (i, j) =>
        i >= 0 && i < height && j >= 0 && j < width && grid[i][j].open;
  const blockedLeft = (i, j) =>
        !(i >= 0 && i < height && j >= 1 && j < width && grid[i][j].open && grid[i][j-1].open && !grid[i][j-1].rightbar);
  const blockedTop = (i, j) =>
        !(i >= 1 && i < height && j >= 0 && j < width && grid[i][j].open && grid[i-1][j].open && !grid[i-1][j].bottombar);
  let current_number = 0;
  const getNumber = (i, j) => {
    if (isOpen(i, j) && (
            (blockedLeft(i, j) && !blockedLeft(i, j + 1)) ||
            (blockedTop(i, j) && !blockedTop(i + 1, j)))) {
       current_number += 1;
       return current_number;
    } else {
      return null;
    }
  };
  return Utils.makeMatrix(height, width, (i, j) => {
    return {
      open: grid[i][j].open,
      number: getNumber(i, j),
      contents: grid[i][j].contents,
      rightbar: grid[i][j].rightbar,
      bottombar: grid[i][j].bottombar,
    }
  });
}

// Clone objects
export function clonePuzzle(puzzle: PuzzleState): PuzzleState {
  return Utils.clone(puzzle);
}

// Returns html for a grid.
export function staticHtmlForGrid(width: number, height: number, grid: PuzzleGrid): string {
  return '<table data-crossword-width="' + Utils.htmlEscape(width) + '" data-crossword-height="' + Utils.htmlEscape(height) + '" style="border-width: 0 0 1px 1px; border-spacing: 0; border-collapse: collapse; border-style: solid; font-family: sans-serif;">' +
        Utils.makeArray(height, (i) => {
            return '<tr>' +
                Utils.makeArray(width, (j) => {
                    const cell = grid[i][j];
                    let open, number, contents, rightBar, bottomBar;
                    if (cell.open) {
                      open = true;
                      number = cell.number;
                      contents = cell.contents;
                      rightBar = j < width-1 && cell.rightbar;
                      bottomBar = i < height-1 && cell.bottombar;
                    } else {
                      open = false;
                      number = null;
                      contents = null;
                      rightBar = false;
                      bottomBar = false;
                    }
                    return '<td data-crossword-cell-open="' + String(open) + '"' +
                        ` data-crossword-cell-y="${i}" data-crossword-cell-x="${j}"` +
                        (typeof(number) === 'number' ? ' data-crossword-cell-number="' +
                                Utils.htmlEscape(number) + '"' : '') +
                        (typeof(contents) === 'string' ? ' data-crossword-cell-contents="' +
                                Utils.htmlEscape(contents) + '"' : '') +
                        (rightBar ? ' data-right-bar="true"' : '') +
                        (bottomBar ? ' data-bottom-bar="true"' : '') +
                        ` style="margin: 0; border-width: 1px ${rightBar ? '3px' : '1px'} ${bottomBar ? '3px' : '1px'} 1px; border-style: solid; border-color: black; padding: 0px; width: 30px; height: 30px; background-clip: padding-box; vertical-align: middle; text-align: center; : background-color: ${open ? 'white' : 'black'}"` +
                        '><div style="display: block; border: 0px;">' +
                        (typeof(number) === 'number' ? '<div style="position: relative; width: 100%; height: 100%;"><div style="position: absolute; top: -5px; left: 0px; font-size: 9px;">' + Utils.htmlEscape(number) + '</div></div>' : '') +
                        '<div style="font-weight: bold">' + Utils.htmlEscape(Utils.useHardSpaces(contents || " ")) + '</div>' +
                        '</div></td>';
            }).join('') + '</tr>';
    }).join('') + '</table>';
}
