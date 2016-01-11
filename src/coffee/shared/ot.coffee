PuzzleUtils = require "./puzzle_utils"
Utils = require "./utils"
OtText = require "./ottext"

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
    # compose the grid ops
    [aRowsOp, aColsOp] = getRowsOpAndColsOp(base, a)
    width1 = OtText.applyTextOp(Utils.repeatString(".", base.width), aColsOp).length
    height1 = OtText.applyTextOp(Utils.repeatString(".", base.height), aRowsOp).length
    [bRowsOp, bColsOp] = getRowsOpAndColsOp({width: width1, height: height1}, b)

    aNew = moveKeyUpdatesOverRowsAndColsOp([bRowsOp, bColsOp], a)

    c = {}
    for key of aNew
        c[key] = aNew[key]
    for key of b
        c[key] = b[key]

    if a.rows? or b.rows?
        c.rows = OtText.composeText Utils.repeatString(".", base.height), aRowsOp, bRowsOp
    if a.cols? or b.cols?
        c.cols = OtText.composeText Utils.repeatString(".", base.width), aColsOp, bColsOp

    # compose the 'clues' text fields
    merge_clue = (name, t) ->
        if name of a and name of b
            c[name] = OtText.composeText t, a[name], b[name]
        else if name of a
            c[name] = a[name]
        else if name of b
            c[name] = b[name]
    merge_clue "across_clues", base["across_clues"]
    merge_clue "down_clues", base["down_clues"]

    return c

inverse = (base, op) ->
    [rowsOp, colsOp] = getRowsOpAndColsOp(base, op)
    rowsOpInv = OtText.inverseText(Utils.repeatString(".", base.height), rowsOp)
    colsOpInv = OtText.inverseText(Utils.repeatString(".", base.width), colsOp)

    rowIndexMap = OtText.getIndexMapForTextOp rowsOp
    colIndexMap = OtText.getIndexMapForTextOp colsOp
    rowIndexMapInv = OtText.getIndexMapForTextOp rowsOpInv
    colIndexMapInv = OtText.getIndexMapForTextOp colsOpInv

    res = {}

    # any cell deleted in the op must be restored in the inverse op
    for i in [0 ... base.height]
        for j in [0 ... base.width]
            if (not (i of rowIndexMap)) or (not (j of colIndexMap))
                for type in ["open", "contents", "number"]
                    res["cell-#{i}-#{j}-#{type}"] = base.grid[i][j][type]

    # any key modified explicitly by the op must be set back to the
    # original in the inverse op
    for key of op
        spl = key.split("-")
        if spl[0] == "cell"
            i = parseInt(spl[1], 10)
            j = parseInt(spl[2], 10)
            type = spl[3]
            if (i of rowIndexMapInv) and (j of colIndexMapInv)
                i1 = rowIndexMapInv[i]
                j1 = colIndexMapInv[j]
                res["cell-#{i1}-#{j1}-#{type}"] = base.grid[i1][j1][type]

    if op.rows?
        res.rows = rowsOpInv
    if op.cols?
        res.cols = colsOpInv

    for t in ['across_clues', 'down_clues']
        if t of op
            res[t] = OtText.inverseText(base[t], op[t])

    return res

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
# This function takes in base, a, and b and returns a list [a1, b1].
# Where applicable, b should be from the "saved updates" and a
# should be a "new" update. For example, a is a new update from a client,
# and b is an update saved on the server that was applied before a.
# Right now, a overrides b when they conflict.
xform = (base, a, b) ->
    # The implementation has to deal with the interplay between inserting
    # and deleting rows and cols.
    # Best to think of this graph:
    #
    #           /\
    #      kb2 /  \ ka2
    #         /    \
    #        /      \
    #       /\   kb1/\
    #  gb1 /  \ka1 /  \ ga1
    #     /    \  /    \
    #    /      \/      \
    #    \      /\      /
    #  ka \ gb1/  \ga1 / kb
    #      \  /    \  /
    #       \/      \/
    #        \      /
    #     ga  \    /  gb
    #          \  /
    #           \/
    # Our inputs a and b can be broken down into:
    #       a = compose(ga, ka)
    #       b = compose(gb, kb)
    # where ga is the grid component (rows/cols) and ka is the cells/keys component
    # so in the bottom diamond, we xform the two grid components
    # in the left and right diamond, we xform a grid op with the keys op
    # and finally we do the keys xform at the top

    [gaRows, gaCols] = getRowsOpAndColsOp(base, a)
    [gbRows, gbCols] = getRowsOpAndColsOp(base, b)

    [gaRows1, gbRows1] = OtText.xformText(Utils.repeatString(".", base.height), gaRows, gbRows)
    [gaCols1, gbCols1] = OtText.xformText(Utils.repeatString(".", base.height), gaCols, gbCols)
    ga1 = [gaRows1, gaCols1]
    gb1 = [gbRows1, gbCols1]

    ka1 = moveKeyUpdatesOverRowsAndColsOp(gb1, a)
    kb1 = moveKeyUpdatesOverRowsAndColsOp(ga1, b)

    ka2 = ka1
    kb2 = {}
    for key of kb1
        if key not of ka1
            kb2[key] = kb1[key]

    for strname in ["across_clues", "down_clues"]
        if strname of a and strname of b
            [ka2[strname], kb2[strname]] = OtText.xformText base[strname], a[strname], b[strname]
        else if strname of a
            ka2[strname] = a[strname]
        else if strname of b
            kb2[strname] = b[strname]

    if a.rows? or b.rows?
        [ka2.rows, kb2.rows] = [gaRows1, gbRows1]
    if a.cols? or b.cols?
        [ka2.cols, kb2.cols] = [gaCols1, gbCols1]

    return [ka2, kb2]

# Returns the state obtained by applying operation a to base.
apply = (base, a) ->
    res = PuzzleUtils.clonePuzzle base

    if a.rows? or a.cols?
        newGridInfo = applyRowAndColOpsToGrid(res, getRowsOpAndColsOp(res, a))
        res.grid = newGridInfo.grid
        res.width = newGridInfo.width
        res.height = newGridInfo.height

    for key of a
        value = a[key]
        components = key.split "-"
        switch components[0]
            when "cell"
                row = parseInt components[1]
                col = parseInt components[2]
                name = components[3]
                res.grid[row][col][name] = value
            when "across_clues"
                res.across_clues = OtText.applyTextOp res.across_clues, value
            when "down_clues"
                res.down_clues = OtText.applyTextOp res.down_clues, value

    return res

# utilities for grid ot

getRowsOpAndColsOp = (puzzle, a) ->
    return [a.rows or OtText.identity(Utils.repeatString(".", puzzle.height)), \
            a.cols or OtText.identity(Utils.repeatString(".", puzzle.width))]

moveKeyUpdatesOverRowsAndColsOp = ([rowsOp, colsOp], changes) ->
    rowIndexMap = OtText.getIndexMapForTextOp rowsOp
    colIndexMap = OtText.getIndexMapForTextOp colsOp

    result = {}

    for key of changes
        if key.indexOf("cell-") == 0
            spl = key.split("-")
            rowIndex = parseInt(spl[1], 10)
            colIndex = parseInt(spl[2], 10)
            rest = spl[3]
            if rowIndex of rowIndexMap and colIndex of colIndexMap
                newKey = "cell-#{rowIndexMap[rowIndex]}-#{colIndexMap[colIndex]}-#{rest}"
                result[newKey] = changes[key]
        else
            result[key] = changes[key]

    return result

applyRowAndColOpsToGrid = (puzzle, [rowsOp, colsOp]) ->
    rowIndexMap = OtText.getIndexMapForTextOp rowsOp
    colIndexMap = OtText.getIndexMapForTextOp colsOp
    
    width = puzzle.width
    height = puzzle.height
    newWidth = OtText.applyTextOp(Utils.repeatString(".", width), colsOp).length
    newHeight = OtText.applyTextOp(Utils.repeatString(".", height), rowsOp).length

    newGrid = for i in [0 .. newHeight-1]
                    for j in [0 .. newWidth-1]
                        null

    for i in [0 .. height - 1]
        if i of rowIndexMap
            for j in [0 .. width - 1]
                if j of colIndexMap
                    newGrid[rowIndexMap[i]][colIndexMap[j]] = puzzle.grid[i][j]

    for i in [0 .. newHeight-1]
        for j in [0 .. newWidth-1]
            if newGrid[i][j] == null
                newGrid[i][j] = PuzzleUtils.getEmptyCell()

    return {width: newWidth, height: newHeight, grid: newGrid}

# Functions to return operations.

# Operation edits "contents", "number", or "open" value for a particular
# cell at (row, col).
opEditCellValue = (row, col, name, value) ->
    res = {}
    res["cell-#{row}-#{col}-#{name}"] = value
    return res

# Returns an operation op such that (apply puzzle, op) has grid of grid2.
# TODO support grids that are not the same size if needed?
opGridDiff = (puzzle, grid2) ->
    grid1 = puzzle.grid
    res = {}
    for i in [0..grid1.length-1]
        for j in [0..grid1[0].length-1]
            for v in ["contents", "number", "open"]
                if grid1[i][j][v] != grid2[i][j][v]
                    res["cell-#{i}-#{j}-#{v}"] = grid2[i][j][v]
    return res

opSpliceRowsOrCols = (originalLen, forRow, index, numToInsert, numToDelete) ->
    res = {}

    res[if forRow then 'rows' else 'cols'] = \
        OtText.opTextSplice(originalLen, index, Utils.repeatString(".", numToInsert), numToDelete)

    return res

# Return an operation that inserts or deletes rows or columns at the specified index
opInsertRows = (puzzle, index, numToInsert) -> opSpliceRowsOrCols puzzle.height, true, index, numToInsert, 0
opInsertCols = (puzzle, index, numToInsert) -> opSpliceRowsOrCols puzzle.width, false, index, numToInsert, 0
opDeleteRows = (puzzle, index, numToDelete) -> opSpliceRowsOrCols puzzle.height, true, index, 0, numToDelete
opDeleteCols = (puzzle, index, numToDelete) -> opSpliceRowsOrCols puzzle.width, false, index, 0, numToDelete

# Returns an operation that applies the text_op to one of the clue fields.
# The parameter 'which' is either 'across' or 'down'.
# The parameter 'text_op' is a text operation as described in ottext.coffee
getClueOp = (which, text_op) ->
    res = {}
    res["#{which}_clues"] = text_op
    return res

assertValidOp = (base, op) ->
    if op.cols?
        newWidth = OtText.assertValidTextOp(Utils.repeatString(".", base.width), op.cols)
    else
        newWidth = base.width

    if op.rows?
        newHeight = OtText.assertValidTextOp(Utils.repeatString(".", base.height), op.rows)
    else
        newHeight = base.height

    for key of op
        if key == "rows" or key == "cols"
            # already handled this case
        else if key == "across_clues"
            OtText.assertValidTextOp(base.across_clues, op[key])
        else if key == "down_clues"
            OtText.assertValidTextOp(base.down_clues, op[key])
        else
            spl = key.split('-')
            Utils.assert spl.length == 4
            Utils.assert spl[0] == "cell"
            Utils.assert Utils.isValidInteger spl[1]
            y = parseInt(spl[1])
            Utils.assert Utils.isValidInteger spl[2]
            x = parseInt(spl[2])
            Utils.assert 0 <= y
            Utils.assert y < newHeight
            Utils.assert 0 <= x
            Utils.assert x < newWidth
            if spl[3] == "number"
                Utils.assert op[key] == null or typeof(op[key]) == 'number'
            else if spl[3] == "contents"
                Utils.assert typeof(op[key]) == 'string'
            else if spl[3] == "open"
                Utils.assert typeof(op[key]) == 'boolean'
            else
                Utils.assert false, "unknown cell property"

# Export stuff

module.exports.identity = identity
module.exports.isIdentity = isIdentity
module.exports.compose = compose
module.exports.inverse = inverse
module.exports.xform = xform
module.exports.apply = apply
module.exports.opEditCellValue = opEditCellValue
module.exports.opGridDiff = opGridDiff
module.exports.getClueOp = getClueOp
module.exports.opInsertRows = opInsertRows
module.exports.opInsertCols = opInsertCols
module.exports.opDeleteRows = opDeleteRows
module.exports.opDeleteCols = opDeleteCols
module.exports.assertValidOp = assertValidOp
