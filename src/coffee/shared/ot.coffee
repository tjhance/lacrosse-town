if require?
    Utils = require "./utils"
else
    Utils = @Utils

# Abstract operational transformation functions
# Many of these functions (may) need to know the grid that the operation
# is based on. For those, the base state is passed in as the argument 'base'.
# No arguments are ever mutated.

identity = (base) ->
    {}
isIdentity = (a) ->
    Object.keys(a).length == 0

#        a          b
#      -----> s1 ------>
# base                   s2
#      ---------------->
#             c
# Takes a and b, and returns the composition c
compose = (base, a, b) ->
    c = {}
    for key of a
        c[key] = a[key]
    for key of b
        c[key] = b[key]
    return c

# The operational transformation.
#
#             s3
#             /\
#         b1 /  \ a1
#           /    \
#          /      \
#         s1      s2
#          \      /
#         a \    / b
#            \  /
#             \/
#            base
#
# a o b1 = b o a1
# This function takes in base, a, and b and returns an object with a1 and b1.
# Where applicable, b should be from the "saved updates" and a
# should be a "new" update. For example, a is a new update from a client,
# and b is an update saved on the server that was applied before a.
# Right now, a overrides b when they conflict.
xform = (base, a, b) ->
    a1 = a
    b1 = {}
    for key of b
        if key not of a
            b1[key] = b[key]
    return {
        a1: a1
        b1: b1
    }

# Returns the state obtained by applying operation a to base.
apply = (base, a) ->
    res = Utils.clonePuzzle base
    applyInPlace res, a
    return res

# Applies the operation a by MUTATING the input state.
applyInPlace = (res, a) ->
    for key of a
        value = a[key]
        components = key.split "-"
        if components[0] == "cell"
            row = parseInt components[1]
            col = parseInt components[2]
            name = components[3]
            res.grid[row][col][name] = value

# Functions to return operations.

# Operation edits "contents", "number", or "open" value for a particular
# cell at (row, col).
opEditCellValue = (row, col, name, value) ->
    res = {}
    res["cell-#{row}-#{col}-#{name}"] = value
    return res

# Returns an operation op such that (apply puzzle, op) has grid of grid2.
# TODO support grids that are not the same size.
opGridDiff = (puzzle, grid2) ->
    grid1 = puzzle.grid
    res = {}
    for i in [0..grid1.length-1]
        for j in [0..grid1[0].length-1]
            for v in ["contents", "number", "open"]
                if grid1[i][j][v] != grid2[i][j][v]
                    res["cell-#{i}-#{j}-#{v}"] = grid2[i][j][v]
    return res

# Export stuff

if module?
    exports = module.exports
else
    exports = @Ot = {}

exports.identity = identity
exports.isIdentity = isIdentity
exports.compose = compose
exports.xform = xform
exports.apply = apply
exports.applyInPlace = applyInPlace
exports.opEditCellValue = opEditCellValue
exports.opGridDiff = opGridDiff
