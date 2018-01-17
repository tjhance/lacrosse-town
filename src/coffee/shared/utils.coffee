# Generic utilities.

assert = (condition, message) ->
    m = message or "Assertion failed"
    if not condition
        throw m

isValidInteger = (s) ->
    isDigit = (c) -> c.charCodeAt(0) >= "0".charCodeAt(0) and c.charCodeAt(0) <= "9".charCodeAt(0)
    s.length > 0 and ([0..s.length-1].every (i) -> (isDigit s[i]) or (i == 0 and s[i] == '-')) and \
        (s.length == 1 or s.charAt(0) != "0")

# from https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/isInteger
isInteger = (value) ->
  return (typeof value == "number" and isFinite(value) and Math.floor(value) == value)

sum = (l) -> l.reduce ((a, b) -> a + b) 0

repeatString = (str, num) ->
    res = ""
    i = 0
    while i < num
        res += str
        i++
    return res

transpose = (matr, width, height) ->
    for i in [0 .. width-1]
        for j in [0 .. height-1]
            matr[j][i]

# returns the submatrix [r1, r2) x [c1, c2)
submatrix = (matr, r1, r2, c1, c2) ->
    res = for i in [r1 ... r2]
            for j in [c1 ... c2]
                matr[i][j]

# Puzzle-related utilities.

clone = (obj) ->
    return JSON.parse JSON.stringify obj

# Deep equals
# From http://stackoverflow.com/questions/201183/how-to-determine-equality-for-two-javascript-objects/16788517#16788517
deepEquals = (x, y) ->
    p = undefined
    # remember that NaN === NaN returns false
    # and isNaN(undefined) returns true
    if isNaN(x) and isNaN(y) and typeof x == 'number' and typeof y == 'number'
        return true
    # Compare primitives and functions.     
    # Check if both arguments link to the same object.
    # Especially useful on step when comparing prototypes
    if x == y
        return true
    # Works in case when functions are created in constructor.
    # Comparing dates is a common scenario. Another built-ins?
    # We can even handle functions passed across iframes
    if typeof x == 'function' and typeof y == 'function' or x instanceof Date and y instanceof Date or x instanceof RegExp and y instanceof RegExp or x instanceof String and y instanceof String or x instanceof Number and y instanceof Number
        return x.toString() == y.toString()
    # At last checking prototypes as good a we can
    if !(x instanceof Object and y instanceof Object)
        return false
    if x.isPrototypeOf(y) or y.isPrototypeOf(x)
        return false
    if x.constructor != y.constructor
        return false
    if x.prototype != y.prototype
        return false
    # Quick checking of one object being a subset of another.
    for p of y
        if y.hasOwnProperty(p) != x.hasOwnProperty(p)
            return false
        else if typeof y[p] != typeof x[p]
            return false
    for p of x
        if y.hasOwnProperty(p) != x.hasOwnProperty(p)
            return false
        else if typeof y[p] != typeof x[p]
            return false
        switch typeof x[p]
            when 'object', 'function'
                if !deepEquals(x[p], y[p])
                    return false
            else
                if x[p] != y[p]
                    return false
                break
    return true

isWhitespace = (c) ->
    return c == ' ' or c == '\n' or c == '\r' or c == '\t'

useHardSpaces = (s) ->
    t = []
    inSpaceRun = true
    spaceRunLen = 1
    for i in [0 ... s.length]
        c = s.charAt(i)
        if c == ' '
            if inSpaceRun
                spaceRunLen++
            else
                inSpaceRun = true
                spaceRunLen = 0
            t.push (if i == s.length - 1 or spaceRunLen % 2 == 1 then '\xA0' else ' ')
        else
            inSpaceRun = false
            t.push c
    return t.join ""

htmlEscape = (s) ->
    s = "" + s
    return s.replace('/&/g', '&amp;').replace(/</g, '&lt;').replace('/>/g', '&gt;')

isValidCursor = (state, cursor) ->
    for key of cursor
        if key != 'anchor' and key != 'focus' and key != 'field_open' and key != 'is_across' and key != 'cell_field'
            return false
    isProperPoint = (point) ->
        for key of point
            if key != 'row' and key != 'col'
                return false
        return isInteger(point.row) \
            and isInteger(point.col) \
            and point.row >= 0 \
            and point.row < state.height \
            and point.col >= 0 \
            and point.col < state.width
    return isProperPoint(cursor.anchor) and \
        isProperPoint(cursor.focus) and \
        typeof(cursor.field_open) == 'string' and \
        typeof(cursor.is_across) == 'boolean' and \
        (typeof(cursor.cell_field) == 'string' or cursor.cell_field == undefined)

# Export stuff

module.exports.assert = assert
module.exports.clone = clone
module.exports.deepEquals = deepEquals
module.exports.isValidInteger = isValidInteger
module.exports.isWhitespace = isWhitespace
module.exports.repeatString = repeatString
module.exports.submatrix = submatrix
module.exports.sum = sum
module.exports.transpose = transpose
module.exports.useHardSpaces = useHardSpaces
module.exports.htmlEscape = htmlEscape
module.exports.isInteger = isInteger
module.exports.isValidCursor = isValidCursor
