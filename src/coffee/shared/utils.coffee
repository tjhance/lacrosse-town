# Generic utilities.

assert = (condition, message) ->
    m = message or "Assertion failed"
    if not condition
        throw m

isValidInteger = (s) ->
    isDigit = (c) -> c.charCodeAt(0) >= "0".charCodeAt(0) and c.charCodeAt(0) <= "9".charCodeAt(0)
    s.length > 0 and ([0..s.length-1].every (i) -> (isDigit s[i]) or (i == 0 and s[i] == '-'))

sum = (l) -> l.reduce ((a, b) -> a + b) 0

# Puzzle-related utilities.

# Returns an empty puzzle object.
getEmptyPuzzle = (height, width, title) ->
    assert width > 0, "width is not positive"
    assert height > 0, "height is not positive"
    getSquare = () ->
        {
            open: true
            number: null
            contents: ""
        }
    return {
        title: if title? then title else ""
        grid: getNumberedGrid ((getSquare() for i in [0..width-1]) for j in [0..height-1])
        across_clues: "blah\nmeh\n"
        down_clues: "chicken\nteehee\n"
    }

# Take a grid and returns one numbered correctly according to which squares are
# open (i.e., white).
# Operates only on a grid (what's in the 'grid' field of a puzzle object) not
# the whole puzzle object.
getNumberedGrid = (grid) ->
    height = grid.length
    width = grid[0].length
    isOpen = (i, j) ->
        i >= 0 and i < height and j >= 0 and j < width and grid[i][j].open
    current_number = 0
    getNumber = (i, j) ->
        if (isOpen i, j) and (
                ((isOpen i+1, j) and not (isOpen i-1, j)) or
                ((isOpen i, j+1) and not (isOpen i, j-1)))
               current_number += 1
               current_number
        else
            null
    (({
        open: grid[i][j].open
        number: getNumber i, j
        contents: grid[i][j].contents
    } for j in [0..width-1]) for i in [0..height-1])

# Clone objects
clonePuzzle = (puzzle) ->
    return clone puzzle

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

# Export stuff

if module?
    exports = module.exports
else
    exports = @Utils = {}

exports.assert = assert
exports.deepEquals = deepEquals
exports.isValidInteger = isValidInteger
exports.sum = sum
exports.getEmptyPuzzle = getEmptyPuzzle
exports.getNumberedGrid = getNumberedGrid
exports.clonePuzzle = clonePuzzle
exports.clone = clone
