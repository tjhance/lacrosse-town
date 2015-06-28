# Some puzzle utilities

if require?
    Utils = require "./utils"
else
    Utils = @Utils

# Returns an empty puzzle object.
getEmptyPuzzle = (height, width, title) ->
    Utils.assert width > 0, "width is not positive"
    Utils.assert height > 0, "height is not positive"
    getSquare = () ->
        {
            open: true
            number: null
            contents: ""
        }
    return {
        title: if title? then title else ""
        grid: getNumberedGrid ((getSquare() for i in [0..width-1]) for j in [0..height-1])
        across_clues: "1. Clue here"
        down_clues: "1. Clue here"
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
    return Utils.clone puzzle

if module?
    exports = module.exports
else
    exports = @PuzzleUtils = {}

exports.getEmptyPuzzle = getEmptyPuzzle
exports.getNumberedGrid = getNumberedGrid
exports.clonePuzzle = clonePuzzle
