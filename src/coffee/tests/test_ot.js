/* @flow */

import * as Ot from "../shared/ot";
import * as OtText from "../shared/ottext";
import * as PuzzleUtils from "../shared/puzzle_utils";
import * as Utils from "../shared/utils";

const take = OtText.take;
const skip = OtText.skip;
const insert = OtText.insert;

function wrapImmutabilityTest(f: any): any {
  return function() {
    const test = arguments[0];
    const args = 2 <= arguments.length ? [].slice.call(arguments, 1) : [];
    const args_cloned = JSON.parse(JSON.stringify(args));
    const res = f.apply(this, args);
    test.deepEqual(args_cloned, args);
    return res;
  };
}

const applyTextOp = wrapImmutabilityTest(OtText.applyTextOp);
const xformText = wrapImmutabilityTest(OtText.xformText);
const composeText = wrapImmutabilityTest(OtText.composeText);
const canonicalized = wrapImmutabilityTest(OtText.canonicalized);
const apply = wrapImmutabilityTest(Ot.apply);
const compose = wrapImmutabilityTest(Ot.compose);
const xform = wrapImmutabilityTest(Ot.xform);
const opEditCellValue = wrapImmutabilityTest(Ot.opEditCellValue);
const opInsertRows = wrapImmutabilityTest(Ot.opInsertRows);
const opInsertCols = wrapImmutabilityTest(Ot.opInsertCols);
const opDeleteRows = wrapImmutabilityTest(Ot.opDeleteRows);
const opDeleteCols = wrapImmutabilityTest(Ot.opDeleteCols);
const opSetBar = wrapImmutabilityTest(Ot.opSetBar);
const inverseText = wrapImmutabilityTest(OtText.inverseText);
const inverse = wrapImmutabilityTest(Ot.inverse);
const isIdentity = wrapImmutabilityTest(Ot.isIdentity);

function makeArbitraryBaseString(op) {
  let i = "0".charCodeAt(0);
  let s = "";
  for (let l = 0; l < op.length; l++) {
    const o: any = op[l];
    if (o[0] < 2) {
      for (let k = 0; k < o[1]; k++) {
        s += String.fromCharCode(i);
        i += 1;
      }
    }
  }
  return s;
};

export const OtTest: any = {
  applyTextOp: function(test) {
    test.equal(applyTextOp(test, "abcd", [take(1), skip(1), take(1), insert("Z"), take(1)]), "acZd");
    test.equal(applyTextOp(test, "abcd", [skip(4), insert("ABCD")]), "ABCD");
    test.done();
  },
  composeText: function(test) {
    var doit;
    doit = function(a, b, c) {
      var c1, s;
      s = makeArbitraryBaseString(a);
      c1 = composeText(test, s, a, b);
      test.deepEqual(c, c1);
      return test.equal(applyTextOp(test, s, c), applyTextOp(test, applyTextOp(test, s, a), b));
    };
    doit([take(4)], [take(4)], [take(4)]);
    doit([take(4)], [insert("YZ"), take(1), skip(2), take(1)], [insert("YZ"), take(1), skip(2), take(1)]);
    doit([take(4), skip(4)], [skip(4)], [skip(8)]);
    doit([take(4), skip(4)], [take(2), insert("AB"), take(2)], [take(2), insert("AB"), take(2), skip(4)]);
    doit([skip(4)], [insert("ABCD")], [skip(4), insert("ABCD")]);
    doit([insert("ABCDE")], [take(2), skip(1), take(2)], [insert("ABDE")]);
    doit([insert("ABCDE")], [take(2), insert("X"), take(2), skip(1)], [insert("ABXCD")]);
    doit([insert("ABCDE")], [take(5), insert("X")], [insert("ABCDEX")]);
    doit([take(1), skip(3), take(1)], [take(1), insert("XYZ"), take(1)], [take(1), skip(3), insert("XYZ"), take(1)]);
    doit([take(3), insert("ABC"), take(3)], [take(2), skip(2), insert("D"), take(3), insert("E"), take(2)], [take(2), skip(1), insert("DBC"), take(1), insert("E"), take(2)]);
    doit([take(1), skip(2), take(5)], [take(6)], [take(1), skip(2), take(5)]);
    test.done();
  },
  xform: function(test) {
    const doit = function(a, b, b1_correct, a1_correct) {
      const s = makeArbitraryBaseString(a);
      const [a1, b1] = xformText(test, s, a, b);
      test.deepEqual(a1, a1_correct);
      test.deepEqual(b1, b1_correct);
      test.deepEqual(composeText(test, s, a, b1), composeText(test, s, b, a1));
    };
    doit([take(4)], [take(4)], [take(4)], [take(4)]);
    doit([skip(4)], [skip(4)], [], []);
    doit([take(4)], [skip(4)], [skip(4)], []);
    doit([skip(4)], [take(4)], [], [skip(4)]);
    doit([insert("ABCD")], [insert("WXYZ")], [take(4), insert("WXYZ")], [insert("ABCD"), take(4)]);
    doit([skip(6), take(2)], [take(2), skip(6)], [skip(2)], [skip(2)]);
    doit([take(2), skip(6)], [skip(6), take(2)], [skip(2)], [skip(2)]);
    doit([take(4), insert("ABCD")], [insert("WXYZ"), take(4)], [insert("WXYZ"), take(8)], [take(8), insert("ABCD")]);
    doit([insert("ABCD"), take(4)], [take(4), insert("WXYZ")], [take(8), insert("WXYZ")], [insert("ABCD"), take(8)]);
    doit([take(4), insert("ABCD")], [skip(4), insert("WXYZ")], [skip(4), take(4), insert("WXYZ")], [insert("ABCD"), take(4)]);
    doit([skip(6), insert("ABCD"), take(2)], [skip(4), insert("WXYZ"), take(4)], [insert("WXYZ"), take(6)], [take(4), skip(2), insert("ABCD"), take(2)]);
    doit([insert("ABCD"), take(4), insert("WXYZ")], [skip(4)], [take(4), skip(4), take(4)], [insert("ABCDWXYZ")]);
    test.done();
  },
  canonicalized: function(test) {
    test.deepEqual(canonicalized(test, [take(0), skip(0)]), []);
    test.deepEqual(canonicalized(test, [take(0), skip(1)]), [skip(1)]);
    test.deepEqual(canonicalized(test, [take(1), skip(0)]), [take(1)]);
    test.deepEqual(canonicalized(test, [take(1), insert(""), skip(1)]), [take(1), skip(1)]);
    test.deepEqual(canonicalized(test, [take(3), take(4)]), [take(7)]);
    test.deepEqual(canonicalized(test, [skip(3), skip(4)]), [skip(7)]);
    test.deepEqual(canonicalized(test, [insert("x"), insert("y")]), [insert("xy")]);
    test.deepEqual(canonicalized(test, [insert("x"), take(1), insert("y")]), [insert("x"), take(1), insert("y")]);
    test.deepEqual(canonicalized(test, [insert("abc"), skip(3)]), [skip(3), insert("abc")]);
    test.deepEqual(canonicalized(test, [skip(2), insert("abc"), skip(3)]), [skip(5), insert("abc")]);
    test.deepEqual(canonicalized(test, [insert("llama"), skip(2), insert("abc"), skip(3)]), [skip(5), insert("llamaabc")]);
    test.done();
  },
  applyGridOp: function(test) {
    const puzz = PuzzleUtils.getEmptyPuzzle(4, 3, "test title");
    test.deepEqual(apply(test, puzz, opEditCellValue(test, 1, 1, "contents", "A")), {
      title: "test title",
      width: 3,
      height: 4,
      across_clues: "1. Clue here",
      down_clues: "1. Clue here",
      col_props: Utils.makeArray(3, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(4, () => PuzzleUtils.getEmptyRowProps()),
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 4,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "A",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ]
      ]
    });
    for (const dir of ['top', 'bottom', 'left', 'right']) {
      const colprops = Utils.makeArray(3, () => PuzzleUtils.getEmptyColProps());
      const rowprops = Utils.makeArray(4, () => PuzzleUtils.getEmptyRowProps());
      colprops[0].topbar = dir === 'top';
      rowprops[0].leftbar = dir === 'left';
      test.deepEqual(apply(test, puzz, opSetBar(test, 0, 0, dir, true)), {
        title: "test title",
        width: 3,
        height: 4,
        across_clues: "1. Clue here",
        down_clues: "1. Clue here",
        col_props: colprops,
        row_props: rowprops,
        grid: [
          [
            {
              open: true,
              number: 1,
              contents: "",
              rightbar: dir === 'right',
              bottombar: dir === 'bottom'
            }, {
              open: true,
              number: 2,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: 3,
              contents: "",
              rightbar: false,
              bottombar: false
            }
          ], [
            {
              open: true,
              number: 4,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }
          ], [
            {
              open: true,
              number: 5,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }
          ], [
            {
              open: true,
              number: 6,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }, {
              open: true,
              number: null,
              contents: "",
              rightbar: false,
              bottombar: false
            }
          ]
        ]
      });
    }
    test.deepEqual(apply(test, puzz, opDeleteRows(test, puzz, 1, 1)), {
      title: "test title",
      width: 3,
      height: 3,
      across_clues: "1. Clue here",
      down_clues: "1. Clue here",
      col_props: Utils.makeArray(3, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(3, () => PuzzleUtils.getEmptyRowProps()),
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ]
      ]
    });
    test.deepEqual(apply(test, puzz, opDeleteCols(test, puzz, 1, 1)), {
      title: "test title",
      width: 2,
      height: 4,
      across_clues: "1. Clue here",
      down_clues: "1. Clue here",
      col_props: Utils.makeArray(2, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(4, () => PuzzleUtils.getEmptyRowProps()),
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 4,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ]
      ]
    });
    test.deepEqual(apply(test, puzz, opInsertRows(test, puzz, 1, 1)), {
      title: "test title",
      width: 3,
      height: 5,
      across_clues: "1. Clue here",
      down_clues: "1. Clue here",
      col_props: Utils.makeArray(3, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(5, () => PuzzleUtils.getEmptyRowProps()),
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 4,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ]
      ]
    });
    test.deepEqual(apply(test, puzz, opInsertCols(test, puzz, 1, 1)), {
      title: "test title",
      width: 4,
      height: 4,
      across_clues: "1. Clue here",
      down_clues: "1. Clue here",
      col_props: Utils.makeArray(4, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(4, () => PuzzleUtils.getEmptyRowProps()),
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 4,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: "",
            rightbar: false,
            bottombar: false
          }
        ]
      ]
    });
    test.done();
  },
  composeGridOp: function(test) {
    var composedOps, i, j, k, l, last, len, op, ops, puzz, versions;
    puzz = PuzzleUtils.getEmptyPuzzle(4, 3, "test title");
    ops = [
      opEditCellValue(test, 0, 0, "contents", "A"), opEditCellValue(test, 3, 0, "contents", "B"), opEditCellValue(test, 0, 2, "contents", "C"), opEditCellValue(test, 3, 2, "contents", "D"), opDeleteRows(test, {
        height: 4
      }, 0, 1), opDeleteCols(test, {
        width: 3
      }, 0, 1), opInsertRows(test, {
        height: 3
      }, 2, 3), opInsertCols(test, {
        width: 2
      }, 1, 3), opEditCellValue(test, 0, 0, "number", 1), opEditCellValue(test, 5, 4, "number", 2), opSetBar(test, 0, 1, 'top', true), opSetBar(test, 2, 0, 'left', true), opSetBar(test, 1, 1, 'right', true), opSetBar(test, 1, 2, 'bottom', true)
    ];
    versions = [puzz];
    for (l = 0, len = ops.length; l < len; l++) {
      op = ops[l];
      last = versions[versions.length - 1];
      versions.push(apply(test, last, op));
    }
    test.deepEqual(versions[versions.length - 1], {
      title: 'test title',
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: true,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: true
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: 'D',
            rightbar: false,
            bottombar: false
          }
        ]
      ],
      width: 5,
      height: 6,
      across_clues: '1. Clue here',
      down_clues: '1. Clue here',
      col_props: [
        {
          topbar: false
        }, {
          topbar: true
        }, {
          topbar: false
        }, {
          topbar: false
        }, {
          topbar: false
        }
      ],
      row_props: [
        {
          leftbar: false
        }, {
          leftbar: false
        }, {
          leftbar: true
        }, {
          leftbar: false
        }, {
          leftbar: false
        }, {
          leftbar: false
        }
      ]
    });
    for (let i = 0; i < ops.length; i++) {
      for (let j = 0; j < ops.length; j++) {
        if (i <= j) {
          op = Ot.identity(versions[i]);
          for (let k = i; k < j; k++) {
            op = compose(test, versions[i], op, ops[k]);
          }
          test.deepEqual(apply(test, versions[i], op), versions[j]);
        }
      }
    }
    test.done();
  },
  xformGridOp: function(test) {
    var doit, i;
    doit = function(base, symmetric, op1, op2, result) {
      const [op1_prime, op2_prime] = xform(test, base, op1, op2);
      const path1 = compose(test, base, op1, op2_prime);
      const path2 = compose(test, base, op2, op1_prime);
      test.deepEqual(path1, path2);
      test.deepEqual(apply(test, base, path1), result);
      test.deepEqual(apply(test, apply(test, base, op1), op2_prime), result);
      test.deepEqual(apply(test, apply(test, base, op2), op1_prime), result);
      if (symmetric) {
        return doit(base, false, op2, op1, result);
      }
    };
    const puzz = PuzzleUtils.getEmptyPuzzle(3, 4, "test title");
    doit(puzz, true, Ot.identity(puzz), Ot.identity(puzz), PuzzleUtils.getEmptyPuzzle(3, 4, "test title"));
    doit(PuzzleUtils.getEmptyPuzzle(2, 2, "test title"), false, {
      "cell-0-0-contents": "A",
      "cell-0-1-contents": "B",
      "cell-0-0-bottombar": false,
      "cell-0-1-rightbar": true,
      "rowprop-0-leftbar": false,
      "colprop-0-topbar": false
    }, {
      "cell-0-0-contents": "C",
      "cell-1-1-contents": "D",
      "cell-0-0-bottombar": true,
      "cell-0-0-rightbar": true,
      "rowprop-0-leftbar": true,
      "rowprop-1-leftbar": true,
      "colprop-0-topbar": true,
      "colprop-1-topbar": true
    }, {
      title: 'test title',
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: 'A',
            rightbar: true,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: 'B',
            rightbar: true,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 3,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'D',
            rightbar: false,
            bottombar: false
          }
        ]
      ],
      width: 2,
      height: 2,
      across_clues: '1. Clue here',
      down_clues: '1. Clue here',
      row_props: [
        {
          leftbar: false
        }, {
          leftbar: true
        }
      ],
      col_props: [
        {
          topbar: false
        }, {
          topbar: true
        }
      ]
    });
    doit(PuzzleUtils.getEmptyPuzzle(5, 2, "test title"), true, {
      rows: [take(1), skip(1), take(2), insert("..."), take(1)]
    }, {
      "cell-0-0-contents": "A",
      "cell-1-0-contents": "B",
      "cell-2-0-contents": "C",
      "cell-3-0-contents": "D",
      "cell-4-0-contents": "E"
    }, {
      title: 'test title',
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: 'A',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 2,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 4,
            contents: 'C',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: 'D',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: 'E',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ]
      ],
      width: 2,
      height: 7,
      across_clues: '1. Clue here',
      down_clues: '1. Clue here',
      col_props: Utils.makeArray(2, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(7, () => PuzzleUtils.getEmptyRowProps()),
    });
    doit(PuzzleUtils.getEmptyPuzzle(2, 5, "test title"), true, {
      cols: [take(1), skip(1), take(2), insert("..."), take(1)]
    }, {
      "cell-0-0-contents": "A",
      "cell-0-1-contents": "B",
      "cell-0-2-contents": "C",
      "cell-0-3-contents": "D",
      "cell-0-4-contents": "E"
    }, {
      title: 'test title',
      grid: [
        [
          {
            open: true,
            number: 1,
            contents: 'A',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 3,
            contents: 'C',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 4,
            contents: 'D',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: 5,
            contents: 'E',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 6,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ]
      ],
      width: 7,
      height: 2,
      across_clues: '1. Clue here',
      down_clues: '1. Clue here',
      col_props: Utils.makeArray(7, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(2, () => PuzzleUtils.getEmptyRowProps()),
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), false, {
      rows: [skip(1), take(2)],
      cols: [take(3), insert("...")],
      "cell-0-0-contents": "A",
      "cell-0-1-contents": "B",
      "cell-0-2-contents": "C",
      "cell-0-3-contents": "D",
      "cell-0-4-contents": "E",
      "cell-0-5-contents": "F",
      "cell-1-0-contents": "G",
      "cell-1-1-contents": "H",
      "cell-1-2-contents": "I",
      "cell-1-3-contents": "J",
      "cell-1-4-contents": "K",
      "cell-1-5-contents": "L"
    }, {
      rows: [take(2), insert(".."), take(1)],
      cols: [take(1), skip(1), take(1)],
      "cell-0-0-contents": "a",
      "cell-0-1-contents": "b",
      "cell-1-0-contents": "c",
      "cell-1-1-contents": "d",
      "cell-2-0-contents": "e",
      "cell-2-1-contents": "f",
      "cell-3-0-contents": "g",
      "cell-3-1-contents": "h"
    }, {
      title: 'test title',
      grid: [
        [
          {
            open: true,
            number: 4,
            contents: 'A',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'C',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'D',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'E',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'F',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: 'e',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'f',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: null,
            contents: 'g',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'h',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: '',
            rightbar: false,
            bottombar: false
          }
        ], [
          {
            open: true,
            number: 5,
            contents: 'G',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'I',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'J',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'K',
            rightbar: false,
            bottombar: false
          }, {
            open: true,
            number: null,
            contents: 'L',
            rightbar: false,
            bottombar: false
          }
        ]
      ],
      width: 5,
      height: 4,
      across_clues: '1. Clue here',
      down_clues: '1. Clue here',
      col_props: Utils.makeArray(5, () => PuzzleUtils.getEmptyColProps()),
      row_props: Utils.makeArray(4, () => PuzzleUtils.getEmptyRowProps()),
    });
    test.done();
  },
  inverse: function(test) {
    var doit;
    doit = function(base, op, res) {
      test.deepEqual(applyTextOp(test, applyTextOp(test, base, op), res), base);
      return test.deepEqual(inverseText(test, base, op), res);
    };
    doit("abcdefghijk", [take(11)], [take(11)]);
    doit("abcdefghijk", [take(2), insert("ABC"), take(3), skip(2), take(1), skip(2), insert("BLAH"), take(1)], [take(2), skip(3), take(3), insert("fg"), take(1), skip(4), insert("ij"), take(1)]);
    test.done();
  },
  isIdentity: function(test) {
    var doit;
    doit = function(b, a) {
      return test.deepEqual(b, isIdentity(test, a));
    };
    doit(true, {});
    doit(false, {
      "cols": [skip(1), take(2)]
    });
    doit(false, {
      "rows": [skip(1), take(2)]
    });
    doit(false, {
      "cell-0-0-contents": "cell-0-0-contents",
      "": ""
    });
    doit(true, compose(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cols": [insert("."), take(3)]
    }, {
      "cols": [skip(1), take(3)]
    }));
    doit(true, compose(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "rows": [insert("."), take(3)]
    }, {
      "rows": [skip(1), take(3)]
    }));
    doit(true, compose(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "across_clues": [insert("."), take(12)]
    }, {
      "across_clues": [skip(1), take(12)]
    }));
    doit(true, compose(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "down_clues": [insert("."), take(12)]
    }, {
      "down_clues": [skip(1), take(12)]
    }));
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cols": [skip(1), take(2)]
    }, {
      "cols": [skip(1), take(2)]
    })[0]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "rows": [skip(1), take(2)]
    }, {
      "rows": [skip(1), take(2)]
    })[0]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "across_clues": [skip(1), take(11)]
    }, {
      "across_clues": [skip(1), take(11)]
    })[0]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "down_clues": [skip(1), take(11)]
    }, {
      "down_clues": [skip(1), take(11)]
    })[0]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cols": [skip(1), take(2)]
    }, {
      "cols": [skip(1), take(2)]
    })[1]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "rows": [skip(1), take(2)]
    }, {
      "rows": [skip(1), take(2)]
    })[1]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "across_clues": [skip(1), take(11)]
    }, {
      "across_clues": [skip(1), take(11)]
    })[1]);
    doit(true, xform(test, PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "down_clues": [skip(1), take(11)]
    }, {
      "down_clues": [skip(1), take(11)]
    })[1]);
    test.done();
  },
  inverseGridOp: function(test) {
    var doit;
    doit = function(base, op, res) {
      test.deepEqual(apply(test, apply(test, base, op), res), base);
      return test.deepEqual(inverse(test, base, op), res);
    };
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cell-0-0-number": 2
    }, {
      "cell-0-0-number": 1
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cols": [skip(1), take(2)]
    }, {
      "cols": [insert("."), take(2)],
      "cell-0-0-contents": "",
      "cell-0-0-number": 1,
      "cell-0-0-open": true,
      "cell-0-0-rightbar": false,
      "cell-0-0-bottombar": false,
      "cell-1-0-contents": "",
      "cell-1-0-number": 4,
      "cell-1-0-open": true,
      "cell-1-0-rightbar": false,
      "cell-1-0-bottombar": false,
      "cell-2-0-contents": "",
      "cell-2-0-number": 5,
      "cell-2-0-open": true,
      "cell-2-0-rightbar": false,
      "cell-2-0-bottombar": false,
      "colprop-0-topbar": false
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "rows": [skip(1), take(2)]
    }, {
      "rows": [insert("."), take(2)],
      "cell-0-0-contents": "",
      "cell-0-0-number": 1,
      "cell-0-0-open": true,
      "cell-0-0-rightbar": false,
      "cell-0-0-bottombar": false,
      "cell-0-1-contents": "",
      "cell-0-1-number": 2,
      "cell-0-1-open": true,
      "cell-0-1-rightbar": false,
      "cell-0-1-bottombar": false,
      "cell-0-2-contents": "",
      "cell-0-2-number": 3,
      "cell-0-2-open": true,
      "cell-0-2-rightbar": false,
      "cell-0-2-bottombar": false,
      "rowprop-0-leftbar": false
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "rows": [insert("."), take(3)],
      "cell-1-0-contents": "A"
    }, {
      "rows": [skip(1), take(3)],
      "cell-0-0-contents": ""
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cols": [insert("."), take(3)],
      "cell-2-1-open": false,
      "across_clues": [insert("X"), take(12)],
      "down_clues": [skip(3), take(11)]
    }, {
      "cols": [skip(1), take(3)],
      "cell-2-0-open": true,
      "across_clues": [skip(1), take(12)],
      "down_clues": [insert("1. "), take(11)]
    });
    doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"), {
      "cell-0-0-rightbar": true,
      "cell-0-0-bottombar": true,
      "rowprop-1-leftbar": true,
      "colprop-1-topbar": true
    }, {
      "cell-0-0-rightbar": false,
      "cell-0-0-bottombar": false,
      "rowprop-1-leftbar": false,
      "colprop-1-topbar": false
    });
    test.done();
  }
};
