# Tests the OT-related functions, including OtText functions

Ot = require "../src/coffee/shared/ot"
OtText = require "../src/coffee/shared/ottext"
PuzzleUtils = require "../src/coffee/shared/puzzle_utils"

# These are the functions we are going to test. Some of them we will wrap
# in a test that their arguments are immutable; if we are accidentally
# mutating arguments, that could lead to difficult-to-find bugs.

take = OtText.take
skip = OtText.skip
insert = OtText.insert

wrapImmutabilityTest = (f) ->
    (test, args...) ->
        args_cloned = JSON.parse (JSON.stringify args)
        res = f.apply this, args
        test.deepEqual args_cloned, args
        return res

applyTextOp = wrapImmutabilityTest OtText.applyTextOp
xformText = wrapImmutabilityTest OtText.xformText
composeText = wrapImmutabilityTest OtText.composeText
canonicalized = wrapImmutabilityTest OtText.canonicalized
apply = wrapImmutabilityTest Ot.apply
compose = wrapImmutabilityTest Ot.compose
xform = wrapImmutabilityTest Ot.xform
opEditCellValue = wrapImmutabilityTest Ot.opEditCellValue
opInsertRows = wrapImmutabilityTest Ot.opInsertRows
opInsertCols = wrapImmutabilityTest Ot.opInsertCols
opDeleteRows = wrapImmutabilityTest Ot.opDeleteRows
opDeleteCols = wrapImmutabilityTest Ot.opDeleteCols

# Helpers

# Given a text operation, return a string of the appropriate length
# that could have been used as a base string for that operation
makeArbitraryBaseString = (op) ->
    i = "0".charCodeAt()
    s = ""
    for o in op
        if o[0] < 2 # INSERT or TAKE
            for k in [0 ... o[1]]
                s += String.fromCharCode i
                i += 1
    return s

# The tests

exports.OtTest =
    applyTextOp: (test) ->
        test.equal (applyTextOp test, "abcd", [take(1), skip(1), take(1), insert("Z"), take(1)]), "acZd"
        test.equal (applyTextOp test, "abcd", [skip(4), insert("ABCD")]), "ABCD"

        test.done()

    composeText: (test) ->
        doit = (a, b, c) ->
            s = makeArbitraryBaseString a
            c1 = composeText test, s, a, b
            test.deepEqual c, c1
            test.equal (applyTextOp test, s, c), (applyTextOp test, (applyTextOp test, s, a), b)

        doit [take(4)], [take(4)], [take(4)]
        doit [take(4)], [insert("YZ"), take(1), skip(2), take(1)], [insert("YZ"), take(1), skip(2), take(1)]
        doit [take(4), skip(4)], [skip(4)], [skip(8)]
        doit [take(4), skip(4)], [take(2), insert("AB"), take(2)], [take(2), insert("AB"), take(2), skip(4)]
        doit [skip(4)], [insert("ABCD")], [skip(4), insert("ABCD")]
        doit [insert("ABCDE")], [take(2), skip(1), take(2)], [insert("ABDE")]
        doit [insert("ABCDE")], [take(2), insert("X"), take(2), skip(1)], [insert("ABXCD")]
        doit [insert("ABCDE")], [take(5), insert("X")], [insert("ABCDEX")]
        doit [take(1), skip(3), take(1)], [take(1), insert("XYZ"), take(1)],
                    [take(1), skip(3), insert("XYZ"), take(1)]
        doit [take(3), insert("ABC"), take(3)], [take(2), skip(2), insert("D"), take(3), insert("E"), take(2)],
                    [take(2), skip(1), insert("DBC"), take(1), insert("E"), take(2)]
        doit [take(1), skip(2), take(5)], [take(6)], [take(1), skip(2), take(5)]

        test.done()

    xform: (test) ->
        doit = (a, b, b1_correct, a1_correct) ->
            s = makeArbitraryBaseString a
            [a1, b1] = xformText test, s, a, b
            test.deepEqual a1, a1_correct
            test.deepEqual b1, b1_correct
            test.deepEqual (composeText test, s, a, b1), (composeText test, s, b, a1)

        doit [take(4)], [take(4)], [take(4)], [take(4)]
        doit [skip(4)], [skip(4)], [], []
        doit [take(4)], [skip(4)], [skip(4)], []
        doit [skip(4)], [take(4)], [], [skip(4)]

        doit [insert("ABCD")], [insert("WXYZ")],
            [take(4), insert("WXYZ")], [insert("ABCD"), take(4)]

        doit [skip(6), take(2)], [take(2), skip(6)],
                [skip(2)], [skip(2)]

        doit [take(2), skip(6)], [skip(6), take(2)],
                [skip(2)], [skip(2)]

        doit [take(4), insert("ABCD")], [insert("WXYZ"), take(4)],
                [insert("WXYZ"), take(8)], [take(8), insert("ABCD")]

        doit [insert("ABCD"), take(4)], [take(4), insert("WXYZ")],
                [take(8), insert("WXYZ")], [insert("ABCD"), take(8)]

        doit [take(4), insert("ABCD")], [skip(4), insert("WXYZ")],
                [skip(4), take(4), insert("WXYZ")], [insert("ABCD"), take(4)]

        doit [skip(6), insert("ABCD"), take(2)], [skip(4), insert("WXYZ"), take(4)],
                [insert("WXYZ"), take(6)], [take(4), skip(2), insert("ABCD"), take(2)]

        doit [insert("ABCD"), take(4), insert("WXYZ")], [skip(4)],
                    [take(4), skip(4), take(4)], [insert("ABCDWXYZ")]

        test.done()

    canonicalized: (test) ->
        test.deepEqual (canonicalized test, [take(0), skip(0)]), []
        test.deepEqual (canonicalized test, [take(0), skip(1)]), [skip(1)]
        test.deepEqual (canonicalized test, [take(1), skip(0)]), [take(1)]
        test.deepEqual (canonicalized test, [take(1), insert(""), skip(1)]), [take(1), skip(1)]
        test.deepEqual (canonicalized test, [take(3), take(4)]), [take(7)]
        test.deepEqual (canonicalized test, [skip(3), skip(4)]), [skip(7)]
        test.deepEqual (canonicalized test, [insert("x"), insert("y")]), [insert("xy")]
        test.deepEqual (canonicalized test, [insert("x"), take(1), insert("y")]),
                    [insert("x"), take(1), insert("y")]
        test.deepEqual (canonicalized test, [insert("abc"), skip(3)]),
                    [skip(3), insert("abc")]
        test.deepEqual (canonicalized test, [skip(2), insert("abc"), skip(3)]),
                    [skip(5), insert("abc")]
        test.deepEqual (canonicalized test, [insert("llama"), skip(2), insert("abc"), skip(3)]),
                    [skip(5), insert("llamaabc")]

        test.done()

    applyGridOp: (test) ->
        puzz = PuzzleUtils.getEmptyPuzzle(4, 3, "test title")

        test.deepEqual(apply(test, puzz, opEditCellValue(test, 1, 1, "contents", "A")), {
            title: "test title",
            width: 3,
            height: 4,
            across_clues: "1. Clue here",
            down_clues: "1. Clue here",
            grid: [
                [
                    { open: true, number: 1, contents: "" },
                    { open: true, number: 2, contents: "" },
                    { open: true, number: 3, contents: "" },
                ],
                [
                    { open: true, number: 4, contents: "" },
                    { open: true, number: null, contents: "A" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 5, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 6, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ]
             ]
          })

        test.deepEqual(apply(test, puzz, opDeleteRows(test, puzz, 1, 1)), {
            title: "test title",
            width: 3,
            height: 3,
            across_clues: "1. Clue here",
            down_clues: "1. Clue here",
            grid: [
                [
                    { open: true, number: 1, contents: "" },
                    { open: true, number: 2, contents: "" },
                    { open: true, number: 3, contents: "" },
                ],
                [
                    { open: true, number: 5, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 6, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ]
             ]
          })

        test.deepEqual(apply(test, puzz, opDeleteCols(test, puzz, 1, 1)), {
            title: "test title",
            width: 2,
            height: 4,
            across_clues: "1. Clue here",
            down_clues: "1. Clue here",
            grid: [
                [
                    { open: true, number: 1, contents: "" },
                    { open: true, number: 3, contents: "" },
                ],
                [
                    { open: true, number: 4, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 5, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 6, contents: "" },
                    { open: true, number: null, contents: "" },
                ]
             ]
          })

        test.deepEqual(apply(test, puzz, opInsertRows(test, puzz, 1, 1)), {
            title: "test title",
            width: 3,
            height: 5,
            across_clues: "1. Clue here",
            down_clues: "1. Clue here",
            grid: [
                [
                    { open: true, number: 1, contents: "" },
                    { open: true, number: 2, contents: "" },
                    { open: true, number: 3, contents: "" },
                ],
                [
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 4, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 5, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 6, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ]
             ]
          })

        test.deepEqual(apply(test, puzz, opInsertCols(test, puzz, 1, 1)), {
            title: "test title",
            width: 4,
            height: 4,
            across_clues: "1. Clue here",
            down_clues: "1. Clue here",
            grid: [
                [
                    { open: true, number: 1, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: 2, contents: "" },
                    { open: true, number: 3, contents: "" },
                ],
                [
                    { open: true, number: 4, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 5, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ],
                [
                    { open: true, number: 6, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                    { open: true, number: null, contents: "" },
                ]
             ]
          })

        test.done()

    composeGridOp: (test) ->
        puzz = PuzzleUtils.getEmptyPuzzle(4, 3, "test title")

        ops = [
            opEditCellValue(test, 0, 0, "contents", "A"),
            opEditCellValue(test, 3, 0, "contents", "B"),
            opEditCellValue(test, 0, 2, "contents", "C"),
            opEditCellValue(test, 3, 2, "contents", "D"),
            opDeleteRows(test, {height: 4}, 0, 1),
            opDeleteCols(test, {width: 3}, 0, 1),
            opInsertRows(test, {height: 3}, 2, 3),
            opInsertCols(test, {width: 2}, 1, 3),
            opEditCellValue(test, 0, 0, "number", 1),
            opEditCellValue(test, 5, 4, "number", 2)
         ]

        versions = [puzz]
        for op in ops
            last = versions[versions.length - 1]
            versions.push(apply(test, last, op))

        test.deepEqual(versions[versions.length - 1],
            {
              title: 'test title',
              grid: [
                 [ { open: true, number: 1, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' } ],
                 [ { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' } ],
                 [ { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' } ],
                 [ { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' } ],
                 [ { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' } ],
                 [ { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: null, contents: '' },
                   { open: true, number: 2, contents: 'D' } ] ],
              width: 5,
              height: 6,
              across_clues: '1. Clue here',
              down_clues: '1. Clue here' })

        composedOps = \
            for i in [0 .. ops.length]
                for j in [0 .. ops.length]
                    # compose the ops from i to j
                    if i <= j
                        op = Ot.identity(versions[i])
                        for k in [i ... j]
                            op = compose test, versions[i], op, ops[k]
                        test.deepEqual(apply(test, versions[i], op), versions[j])
                        op
                    else
                        null

        test.done()

    xformGridOp: (test) ->
        doit = (base, symmetric, op1, op2, result) ->
            [op1_prime, op2_prime] = xform test, base, op1, op2
            path1 = compose test, base, op1, op2_prime
            path2 = compose test, base, op2, op1_prime
            test.deepEqual(path1, path2)
            test.deepEqual(apply(test, base, path1), result)
            test.deepEqual(apply(test, apply(test, base, op1), op2_prime), result)
            test.deepEqual(apply(test, apply(test, base, op2), op1_prime), result)

            if symmetric
                doit(base, false, op2, op1, result)

        doit(PuzzleUtils.getEmptyPuzzle(3, 4, "test title"),
             true,
             Ot.identity(),
             Ot.identity(),
             PuzzleUtils.getEmptyPuzzle(3, 4, "test title"))

        doit(PuzzleUtils.getEmptyPuzzle(2, 2, "test title"),
             false,
             {
                "cell-0-0-contents": "A",
                "cell-0-1-contents": "B",
             },
             {
                "cell-0-0-contents": "C",
                "cell-1-1-contents": "D",
             },
             {
               title: 'test title',
               grid: [
                  [ { open: true, number: 1, contents: 'A' },
                    { open: true, number: 2, contents: 'B' } ],
                  [ { open: true, number: 3, contents: '' },
                    { open: true, number: null, contents: 'D' } ] ],
               width: 2,
               height: 2,
               across_clues: '1. Clue here'
               down_clues: '1. Clue here'
             })

        # test inserting/deleting rows
        doit(PuzzleUtils.getEmptyPuzzle(5, 2, "test title"),
             true, # this test case is symmetric
             {
                # delete second row, insert 3 after fourth row
                rows: [take(1), skip(1), take(2), insert("..."), take(1)]
             },
             {
                # modify something in each row
                "cell-0-0-contents": "A",
                "cell-1-0-contents": "B",
                "cell-2-0-contents": "C",
                "cell-3-0-contents": "D",
                "cell-4-0-contents": "E"
             },
             {
                title: 'test title',
                grid: [
                     [ { open: true, number: 1, contents: 'A' },
                       { open: true, number: 2, contents: '' } ],
                     [ { open: true, number: 4, contents: 'C' },
                       { open: true, number: null, contents: '' } ],
                     [ { open: true, number: 5, contents: 'D' },
                       { open: true, number: null, contents: '' } ],
                     [ { open: true, number: null, contents: '' },
                       { open: true, number: null, contents: '' } ],
                     [ { open: true, number: null, contents: '' },
                       { open: true, number: null, contents: '' } ],
                     [ { open: true, number: null, contents: '' },
                       { open: true, number: null, contents: '' } ],
                     [ { open: true, number: 6, contents: 'E' },
                       { open: true, number: null, contents: '' } ] ],
                width: 2,
                height: 7,
                across_clues: '1. Clue here',
                down_clues: '1. Clue here' })

        # test inserting/deleting cols
        doit(PuzzleUtils.getEmptyPuzzle(2, 5, "test title"),
             true, # this test case is symmetric
             {
                # delete second row, insert 3 after fourth row
                cols: [take(1), skip(1), take(2), insert("..."), take(1)]
             },
             {
                # modify something in each row
                "cell-0-0-contents": "A",
                "cell-0-1-contents": "B",
                "cell-0-2-contents": "C",
                "cell-0-3-contents": "D",
                "cell-0-4-contents": "E"
             },
             {
               title: 'test title',
               grid: [
                  [ { open: true, number: 1, contents: 'A' },
                    { open: true, number: 3, contents: 'C' },
                    { open: true, number: 4, contents: 'D' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: 5, contents: 'E' } ],
                  [ { open: true, number: 6, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' } ] ],
               width: 7,
               height: 2,
               across_clues: '1. Clue here',
               down_clues: '1. Clue here' })

        # test where both insert and delete
        doit(PuzzleUtils.getEmptyPuzzle(3, 3, "test title"),
             false, # this test case is symmetric
             {
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
                "cell-1-5-contents": "L",
             },
             {
                rows: [take(2), insert(".."), take(1)]
                cols: [take(1), skip(1), take(1)]
                "cell-0-0-contents": "a",
                "cell-0-1-contents": "b",
                "cell-1-0-contents": "c",
                "cell-1-1-contents": "d",
                "cell-2-0-contents": "e",
                "cell-2-1-contents": "f",
                "cell-3-0-contents": "g",
                "cell-3-1-contents": "h",
             },
             {
               title: 'test title',
               grid: [
                  [ { open: true, number: 4, contents: 'A' },
                    { open: true, number: null, contents: 'C' },
                    { open: true, number: null, contents: 'D' },
                    { open: true, number: null, contents: 'E' },
                    { open: true, number: null, contents: 'F' } ],
                  [ { open: true, number: null, contents: 'e' },
                    { open: true, number: null, contents: 'f' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' } ],
                  [ { open: true, number: null, contents: 'g' },
                    { open: true, number: null, contents: 'h' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' },
                    { open: true, number: null, contents: '' } ],
                  [ { open: true, number: 5, contents: 'G' },
                    { open: true, number: null, contents: 'I' },
                    { open: true, number: null, contents: 'J' },
                    { open: true, number: null, contents: 'K' },
                    { open: true, number: null, contents: 'L' } ] ],
               width: 5,
               height: 4,
               across_clues: '1. Clue here',
               down_clues: '1. Clue here' })

        test.done()
