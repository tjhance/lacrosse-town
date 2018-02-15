/* @flow */

// Generic utilities.

export function assert(condition: boolean, message: ?string): void {
  const m = message || "Assertion failed";
  if (!condition) {
    throw m;
  }
}

export function isValidInteger(s): boolean {
  const isDigit = (c) => c.charCodeAt(0) >= "0".charCodeAt(0) && c.charCodeAt(0) <= "9".charCodeAt(0);
  for (let i = 0; i < s.length; i++) {
    if (!(isDigit(s[i]) || (i == 0 && s[i] == '-'))) {
      return false;
    }
  }
  return s.length > 0 && (s.length == 1 || s.charAt(0) != "0");
}

// from https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/isInteger
export function isInteger(value): boolean {
  return (typeof value == "number" && isFinite(value) && Math.floor(value) == value);
}

export function sum(l: Array<number>) {
  return l.reduce(((a, b) => a + b), 0);
}

export function repeatString(str: string, num: number): string {
  let res = ""
  for (let i = 0; i < num; i++) {
    res += str
  }
  return res
}

export function transpose<T>(matr: Array<Array<T>>, width: number, height: number): Array<Array<T>> {
  const res = [];
  for (let i = 0; i < width; i++) {
    const row = [];
    for (let j = 0; j < height; j++) {
      row.push(matr[j][i]);
    }
    res.push(row);
  }
  return res;
}

// returns the submatrix [r1, r2) x [c1, c2)
export function submatrix<T>(matr: Array<Array<T>>, r1: number, r2: number, c1: number, c2: number) {
  const res = [];
  for (let i = r1; i <= r2; i++) {
    const row = [];
    for (let j = c1; j <= c2; j++) {
      row.push(matr[i][j]);
    }
    res.push(row);
  }
  return res;
}

// Puzzle-related utilities.

export function clone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}

// Deep equals
// From http://stackoverflow.com/questions/201183/how-to-determine-equality-for-two-javascript-objects/16788517#16788517
export function deepEquals(x, y): boolean {
  // remember that NaN === NaN returns false
  // and isNaN(undefined) returns true
  if (isNaN(x) && isNaN(y) && typeof x === 'number' && typeof y === 'number') {
    return true;
  }
  // Compare primitives and functions.     
  // Check if both arguments link to the same object.
  // Especially useful on step when comparing prototypes
  if (x === y) {
    return true;
  }
  // Works in case when functions are created in constructor.
  // Comparing dates is a common scenario. Another built-ins?
  // We can even handle functions passed across iframes
  if ((typeof x === 'function' && typeof y === 'function') || (x instanceof Date && y instanceof Date) || (x instanceof RegExp && y instanceof RegExp) || (x instanceof String && y instanceof String) || (x instanceof Number && y instanceof Number)) {
    return x.toString() == y.toString();
  }
  // At last checking prototypes as good a we can
  if (!(x instanceof Object && y instanceof Object))
    return false;
  if (x.isPrototypeOf(y) || y.isPrototypeOf(x))
    return false;
  if (x.constructor !== y.constructor)
    return false;
  if (x.prototype !== y.prototype)
    return false;
  // Quick checking of one object being a subset of another.
  for (const p in y) {
    if (y.hasOwnProperty(p) !== x.hasOwnProperty(p))
      return false;
    else if (typeof y[p] !== typeof x[p])
      return false;
  }
  for (const p in x) {
    if (y.hasOwnProperty(p) !== x.hasOwnProperty(p))
      return false;
    else if (typeof y[p] !== typeof x[p])
      return false;
    else if (typeof x[p] === 'object' || typeof x[p] === 'function') {
      if (!deepEquals(x[p], y[p]))
        return false;
    } else {
      if (x[p] != y[p])
        return false;
    }
  }
  return true;
}

export function isWhitespace(c: string): boolean {
  return c === ' ' || c === '\n' || c === '\r' || c === '\t';
}

export function useHardSpaces(s: string): string {
  const t = [];
  let inSpaceRun = true;
  let spaceRunLen = 1;
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i);
    if (c === ' ') {
      if (inSpaceRun) {
        spaceRunLen++;
      } else {
        inSpaceRun = true;
        spaceRunLen = 0;
      }
      t.push(i === s.length - 1 || spaceRunLen % 2 === 1 ? '\xA0' : ' ');
    } else {
      inSpaceRun = false;
      t.push(c);
    }
  }
  return t.join("");
}

export function htmlEscape(s: string): string {
  s = "" + s; // make sure it's a string
  return s.replace('/&/g', '&amp;').replace(/</g, '&lt;').replace('/>/g', '&gt;');
}

export function isValidCursor(state, cursor) {
  for (const key in cursor) {
    if (key !== 'anchor' && key !== 'focus' && key !== 'field_open' && key !== 'is_across' && key !== 'cell_field') {
      return false
    }
  }
  const isProperPoint = (point) => {
    for (const key in point) {
      if (key !== 'row' && key !== 'col') {
        return false
      }
    }
    return (isInteger(point.row)
      && isInteger(point.col)
      && point.row >= 0
      && point.row < state.height
      && point.col >= 0
      && point.col < state.width);
  }
  return (isProperPoint(cursor.anchor) &&
    isProperPoint(cursor.focus) &&
    typeof(cursor.field_open) === 'string' &&
    typeof(cursor.is_across) === 'boolean' &&
    (typeof(cursor.cell_field) === 'string' || cursor.cell_field === undefined));
}
