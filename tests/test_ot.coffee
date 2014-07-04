# Tests the OT-related functions, including OtText functions

Ot = require "../src/coffee/shared/ot"
OtText = require "../src/coffee/shared/ottext"

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

        doit [take(4), insert("ABCD")], [insert("WXYZ"), skip(4)],
                [insert("WXYZ"), skip(4), take(4)], [take(4), insert("ABCD")]

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

        test.done()
