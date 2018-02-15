import * as Utils from './utils';

// An operation on a string is a list of instructions.
// Take i: take the next i characters (i.e., leave them unchanged)
// Skip i: skip the next i characters (i.e., delete them)
// Insert s: insert the string s

// For example, [take 1, skip 1, take 1, insert "Z", take 1] applied to "abcd"
// yields        "a"     del "b" "c"     "Z"         "d"
// that is "acZd".

// The sum of of the take and skip lengths MUST equal the total length of the
// string applied to.

// Here is the "algebraic data type", represented as a pair:
// (Shame we aren't using Haskell -.-)
const TAKE = 0;
const SKIP = 1;
const INSERT = 2;

export function take(i: number) {
  return [TAKE, i];
}

export function skip(i: number) {
  return [SKIP, i];
}

export function insert(i: string) {
  return [INSERT, i];
}

export function identity(s: string) {
  return [take(s.length)];
};

export function isIdentity(op): boolean {
  return op.length === 0 || (op.length === 1 && op[0][0] === TAKE);
};

// Takes a string and an operation (a list of instructions) and returns the
// result of applying them (as in the above example).
export function applyTextOp(s, op) {
  let index = 0;
  const res = [];
  for (k = 0, len = op.length; k < len; k++) {
    const inst = op[k];
    const v = inst[1];
    switch (inst[0]) {
      case TAKE:
        res.push(s.slice(index, index + v));
        index += v;
        break;
      case SKIP:
        index += v;
        break;
      case INSERT:
        res.push(v);
        break;
    }
  }
  return res.join("");
};

// Given two strings, return the instruction list that turns the first into the
// second. Does so by executing DP to find the longest common substring between
// the two. Then it uses take on those characters, skipping and inserting
// everything else.
// TODO figure out: do we actually need this?
export function text_diff2(text1: string, text2: string) {
	const dp = Utils.makeArray(text1.length, text2.length, () => [0, null]);

	const mymax = (a, b) => (a[0] > b[0] ? a : b);

	let i = text1.length;
	while (i >= 0) {
		let j = text2.length;
		while (j >= 0) {
			if (i < text1.length) {
				dp[i][j] = mymax(dp[i][j], [dp[i+1][j][0], 0]);
      }
			if (j < text2.length) {
				dp[i][j] = mymax(dp[i][j], [dp[i][j+1][0], 1]);
      }
			if (i < text1.length && j < text2.length && text1[i] === text2[j]) {
				dp[i][j] = mymax(dp[i][j], [dp[i+1][j+1][0] + 1, 2]);
			}
			j--;
		}
		i--;
	}
	
	const ans = []
	i = 0;
	let j = 0;
	while (i < text1.length && j < text2.length) {
    // Assume the next three instructions are
    // take a1, skip a2, insert a3
    // Compute a1, a2, a3, then add the non-trivial ones to ans.
    let a1 = 0; a2 = 0; a3 = "";
    while (dp[i][j] && dp[i][j][1] === 2) {
      a1++; i++; j++;
    }
    while (dp[i][j] && dp[i][j][1] !== 2) {
      if (dp[i][j][1] === 0) {
        a2++; i++;
      } else {
        a3 += text2[j]; j++;
      }
    }
    if (a1 > 0) ans.push(take(a1));
    if (a2 > 0) ans.push(skip(a2));
    if (a3 !== "") ans.push(insert(a3));
  }

	return ans;
}

// This is a helper function for below. The idea is that we are trying to build
// a lists of instructions. This takes a lists, and an instruction to add
// (or null). It also merges consecutive instructions of the same type.
// It also ensures that when 'skip' and 'insert' are consecutive, the skip is
// always first.
// Mutuates its input.
function appendInst(l, i) {
  if (l.length > 0 && l[l.length - 1][0] === i[0]) {
    return l[l.length - 1][1] += i[1];
  } else if (l.length > 0 && l[l.length - 1][0] === INSERT && i[0] === SKIP) {
    if (l.length > 1 && l[l.length - 2][0] === SKIP) {
      return l[l.length - 2][1] += i[1];
    } else {
      l.push(l[l.length - 1]);
      return l[l.length - 2] = i;
    }
  } else {
    return l.push(i);
  }
}

// Returns [m1, m2] such that l1 o m1 = l2 o m2
// Base state s is an argument but currently ignored.
export function xformText(s, l1, l2) {
  // Copy the lists, because we are going to mutate them.
  l1 = l1.slice();
  l2 = l2.slice();
  // Indices which track our current position in the list:
  let i1 = 0;
  let i2 = 0;
  // The result lists that we are going to build
  const m1 = [];
  const m2 = [];
  while (i1 < l1.length || i2 < l2.length) {
    // If there are two INSERTs at the same spot, the one from the left 
    // operation (that is, l1) goes first. This is an arbitrary decision,
    // but we must be consistent.
    if (i1 < l1.length && l1[i1][0] === INSERT) {
      s = l1[i1][1];
      appendInst(m1, take(s.length));
      appendInst(m2, insert(s));
      i1++;
    } else if (i2 < l2.length && l2[i2][0] === INSERT) {
      s = l2[i2][1];
      appendInst(m1, insert(s));
      appendInst(m2, take(s.length));
      i2++;
    } else {
      // Now, i1 and i2 each point to a Take or a Skip.
      // (By the invariant, the sums of lengths should always match, we
      // cannot have a Take or a Skip if the other is empty.)
      amt = Math.min(l1[i1][1], l2[i2][1]);
      if (l1[i1][0] === TAKE) {
        appendInst(m1, (l2[i2][0] === SKIP ? skip : take)(amt));
      }
      if (l2[i2][0] === TAKE) {
        appendInst(m2, (l1[i1][0] === SKIP ? skip : take)(amt));
      }
      if (l1[i1][1] === amt) {
        i1++;
      } else {
        l1[i1][1] -= amt;
      }
      if (l2[i2][1] === amt) {
        i2++;
      } else {
        l2[i2][1] -= amt;
      }
    }
  }
  return [m2, m1];
}

export function xformRange(s, op, range) {
  let [start, end] = range;
  let i = 0;
  let pos = 0;
  while (i < op.length) {
    if (op[i][0] === TAKE) {
      pos += op[i][1];
      i++;
    } else {
      const delCount = 0;
      const insCount = 0;
      if (op[i][0] === SKIP) {
        const delCount = op[i][1];
        i++;
      }
      if (i < op.length && op[i][0] === INSERT) {
        const insCount = op[i][1].length;
        i++;
      }
      const spliceStart = pos;
      const spliceEnd = pos + delCount;
      if (spliceStart <= start && spliceEnd >= end) {
        start = spliceStart;
        end = spliceStart;
      } else if (spliceEnd <= start) {
        start += insCount - delCount;
        end += insCount - delCount;
      } else if (spliceStart >= end) {
        break;
      } else if (spliceStart >= start && spliceEnd <= end) {
        end += insCount - delCount;
      } else if (spliceEnd < end) {
        start = spliceStart + insCount;
        end += insCount - delCount;
      } else {
        end = spliceEnd;
      }
      pos += insCount;
    }
  }
  return [start, end];
}

// Compose the two operations, returning l1 o l2
export function composeText(s, l1, l2) {
  // Copy the lists, because we are going to mutate them.
  l1 = l1.slice();
  l2 = l2.slice();
  // Indices which track our current position in the list:
  let i1 = 0;
  let i2 = 0;
  // The result list that we are going to build
  const m = [];
  while (i2 < l2.length || i1 < l1.length) {
    if (i1 < l1.length && l1[i1][0] === SKIP) {
      appendInst(m, skip(l1[i1][1]));
      i1++;
    } else {
      const type2 = l2[i2][0];
      if (type2 === INSERT) {
        appendInst(m, insert(l2[i2][1]));
        i2++;
      } else if (type2 === TAKE) {
        const type1 = l1[i1][0];
        if (type1 === TAKE) {
          const amt = Math.min(l1[i1][1], l2[i2][1]);
          appendInst(m, take(amt));
          if (l1[i1][1] === amt) {
            i1++;
          } else {
            l1[i1][1] -= amt;
          }
          if (l2[i2][1] === amt) {
            i2++;
          } else {
            l2[i2][1] -= amt; // INSERT
          }
        } else {
          const amt = Math.min(l1[i1][1].length, l2[i2][1]);
          appendInst(m, insert(l1[i1][1].slice(0, amt)));
          if (l1[i1][1].length === amt) {
            i1++;
          } else {
            l1[i1][1] = l1[i1][1].slice(amt);
          }
          if (l2[i2][1] === amt) {
            i2++;
          } else {
            l2[i2][1] -= amt;
          }
        }
      } else if (type2 === SKIP) {
        const type1 = l1[i1][0];
        if (type1 === TAKE) {
          const amt = Math.min(l1[i1][1], l2[i2][1]);
          appendInst(m, skip(amt));
          if (l1[i1][1] === amt) {
            i1++;
          } else {
            l1[i1][1] -= amt;
          }
          if (l2[i2][1] === amt) {
            i2++;
          } else {
            l2[i2][1] -= amt; // INSERT
          }
        } else {
          amt = Math.min(l1[i1][1].length, l2[i2][1]);
          // Don't add an op, gets cancelled out
          if (l1[i1][1].length === amt) {
            i1++;
          } else {
            l1[i1][1] = l1[i1][1].slice(amt);
          }
          if (l2[i2][1] === amt) {
            i2++;
          } else {
            l2[i2][1] -= amt;
          }
        }
      }
    }
  }
  return m;
}

export function inverseText(base, l) {
  const m = [];
  let pos = 0;
  for (k = 0, len = l.length; k < len; k++) {
    const [type, val] = l[k];
    if (type === TAKE) {
      appendInst(m, take(val));
      pos += val;
    } else if (type === SKIP) {
      deletedText = base.substring(pos, pos + val);
      appendInst(m, insert(deletedText));
      pos += val;
    } else if (type === INSERT) {
      appendInst(m, skip(val.length));
    }
  }
  return m;
}

export function toString(op): string {
  const opToString = function(o) {
    switch (o[0]) {
      case TAKE:
        return `take ${o[1]}`;
      case SKIP:
        return `skip ${o[1]}`;
      case INSERT:
        return `insert ${o[1]}`;
    }
  };
  return `[${op.map((o) => opToString(o))}]`;
}

export function canonicalized(op) {
  const ans = [];
  for (let k = 0, len = op.length; k < len; k++) {
    let [type, val] = op[k];
    if (val) { // positive integer or non-empty string
      appendInst(ans, [type, val]);
    }
  }
  return ans;
}

// Returns an "index map" for the op
// e.g. if the second character of a string becomes the fourth character
// after an op is applied, the returned map will map 2 -> 4
// (if the second character is deleted, 2 will not be in the map)
export function getIndexMapForTextOp(op) {
  const res = {};
  let srcPos = 0;
  let dstPos = 0;
  for (let k = 0, len = op.length; k < len; k++) {
    let [type, val] = op[k];
    if (type === TAKE) {
      for (let i = 0; i < val; i++) {
        res[srcPos + i] = dstPos + i;
      }
      srcPos += val;
      dstPos += val;
    } else if (type === SKIP) {
      srcPos += val;
    } else if (type === INSERT) {
      dstPos += val.length;
    } else {
      Utils.assert("bad op type");
    }
  }
  return res;
}

// Returns a text op that does a splice at the given `index`, removing
// `numToDelete` characters and inserting the `toInsert` string
export function opTextSplice(totalLen: number, index: number, toInsert: string, numToDelete: number) {
  return canonicalized([take(index), skip(numToDelete), insert(toInsert), take(totalLen - index - numToDelete)]);
};

// Asserts that the op is valid and applies to the given string.
// Returns the length of the resulting string after application.
export function assertValidTextOp(s: string, op): void {
  let oldLength = 0;
  let newLength = 0;
  let prevType = -1;
  for (let k = 0, len = op.length; k < len; k++) {
    const o = op[k];
    Utils.assert(o[0] === TAKE || o[0] === SKIP || o[0] === INSERT);
    switch (o[0]) {
      case TAKE:
        Utils.assert(Utils.isInteger(o[1]) && o[1] >= 1);
        oldLength += o[1];
        newLength += o[1];
        break;
      case SKIP:
        Utils.assert(Utils.isInteger(o[1]) && o[1] >= 1);
        oldLength += o[1];
        break;
      case INSERT:
        Utils.assert(typeof o[1] === 'string' && o[1].length >= 1);
        newLength += o[1].length;
    }
    if (prevType !== -1) {
      curType = o[0];
      Utils.assert(
          (prevType === TAKE && curType !== TAKE) ||
          (prevType === SKIP && curType !== SKIP) ||
          (prevType === INSERT && curType === TAKE));
    }
    prevType = o[0];
  }
  Utils.assert(oldLength === s.length);
  return newLength;
}
