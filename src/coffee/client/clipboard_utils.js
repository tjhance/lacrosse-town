/* @flow */

// Utilities for copying and pasting grids.

import * as PuzzleUtils from "../shared/puzzle_utils";
import * as Utils from "../shared/utils";
import type {PuzzleGrid} from "../shared/types";

declare class ClipboardEvent extends Event {
  clipboardData: DataTransfer,
}

// Copies the given puzzle grid to the clipboard
export function copyGridToClipboard(event: ClipboardEvent,
      width: number, height: number, grid: PuzzleGrid) {
  if (event.clipboardData) {
    const gridHtml = PuzzleUtils.staticHtmlForGrid(width, height, grid);

    // make a newline- and tab-separated matrix from the contents
    // for black cells, use '.'
		const gridText = grid.map((row) => {
			return row.map((c) => {
				return c.open ? (c.contents || "") : ".";
			}).join("\t");
		}).join("\n");

    event.clipboardData.setData("text/html", gridHtml);
    event.clipboardData.setData("text/plain", gridText);

    event.preventDefault();
  }
}

export function getGridFromClipboard(event: ClipboardEvent) {
  if (event.clipboardData) {
    const html = event.clipboardData.getData("text/html");
    if (html != null) {
      // parse the HTML to a DOM node we can manipulate
      const parsedNode = safelyParseHtml(html);
      if (!parsedNode) {
        return null;
      }
      const nodes = allNodes(parsedNode);
      // traverse all the nodes
      let width = null;
      let height = null;
      const cells = [];
      for (let k = 0; k < nodes.length; k++) {
        const node = nodes[k];
        if (node instanceof HTMLElement) {
          // When copying a grid, we add all of these custom data-crossword- attributes
          // to the HTML. We can just parse them out here.
          if (node.getAttribute('data-crossword-width') != null) {
            width = parseInt(node.getAttribute('data-crossword-width'), 10);
          }
          if (node.getAttribute('data-crossword-height') != null) {
            height = parseInt(node.getAttribute('data-crossword-height'), 10);
          }
          const x = node.getAttribute('data-crossword-cell-x');
          const y = node.getAttribute('data-crossword-cell-y');
          if ((x != null) && (y != null)) {
            const open = node.getAttribute('data-crossword-cell-open') === "true";
            let number = node.getAttribute('data-crossword-cell-number');
            number = parseInt(number, 10);
            const rightbar = node.getAttribute('data-right-bar') === "true";
            const bottombar = node.getAttribute('data-bottom-bar') === "true";
            if ((!number) && number !== 0) {
              number = null;
            }
            const contents = node.getAttribute('data-crossword-cell-contents') || "";
            cells.push({
              x: Number(x),
              y: Number(y),
              open: open,
              number: number,
              contents: contents,
              rightbar: rightbar,
              bottombar: bottombar
            });
          }
        }
      }
      if (width && height) {
        const grid = Utils.makeMatrix(height, width, () => PuzzleUtils.getEmptyCell());
        for (let i = 0; i < cells.length; i++) {
          const cell = cells[i];
          const x = cell.x;
          const y = cell.y;
          if (0 <= x && x < width && 0 <= y && y < height) {
            grid[y][x] = {
              open: cell.open,
              number: cell.number,
              contents: cell.contents,
              rightbar: cell.rightbar,
              bottombar: cell.bottombar
            };
          }
        }
        return {
          width: width,
          height: height,
          grid: grid
        };
      }
    }
  }
  return null;
}

// This safely parses HTML to a DOM without allowing script injection
function safelyParseHtml(html: string): Node | null {
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, "text/html");
  return doc.body;
}

// Given a node, return a list containing it and all its descendants
function allNodes(node: Node): Node[] {
  const res = [];
  const recurse = (n) => {
    res.push(n);
    const results = [];
    for (let i = 0; i < n.childNodes.length; i++) {
      results.push(recurse(n.childNodes[i]));
    }
    return results;
  };
  recurse(node);
  return res;
}
