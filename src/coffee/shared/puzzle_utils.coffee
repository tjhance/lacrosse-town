# Some puzzle utilities

if require?
    Utils = require "./utils"
else
    Utils = @Utils

# Returns an empty puzzle object.
getEmptyPuzzle = (height, width, title) ->
    Utils.assert width > 0, "width is not positive"
    Utils.assert height > 0, "height is not positive"
    return {
        title: if title? then title else ""
        grid: getNumberedGrid ((getEmptyCell() for i in [0..width-1]) for j in [0..height-1])
        width: width,
        height: height,
        across_clues: "1. Clue here"
        down_clues: "1. Clue here"
    }

getEmptyCell = () ->
    {
        open: true
        number: null
        contents: ""
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

# Returns html for a grid.
staticHtmlForGrid = (width, height, grid) ->
    '<table data-crossword-width="' + Utils.htmlEscape(width) + '" data-crossword-height="' + Utils.htmlEscape(height) + '" style="border-width: 0 0 1px 1px; border-spacing: 0; border-collapse: collapse; border-style: solid; font-family: sans-serif;">' + (
        for i in [0 ... height]
            '<tr>' + (
                for j in [0 ... width]
                    cell = grid[i][j]
                    if cell.open
                        open = true
                        number = cell.number
                        contents = cell.contents
                    else
                        open = false
                        number = null
                        contents = null
                    '<td data-crossword-cell-open="' + open + '"' + \
                        " data-crossword-cell-y=\"#{i}\" data-crossword-cell-x=\"#{j}\"" + \
                        (if number? then ' data-crossword-cell-number="' + \
                                Utils.htmlEscape(number) + '"' else '') + \
                        (if contents? then ' data-crossword-cell-contents="' + \
                                Utils.htmlEscape(contents) + '"' else '') + \
                        " style=\"margin: 0; border-width: 1px 1px 0 0; border-style: solid; border-color: black; padding: 0px; width: 30px; height: 30px; background-clip: padding-box; vertical-align: middle; text-align: center; background-color: #{if open then 'white' else 'black'}\"" + \
                        '><div style="display: block; border: 0px;">' + \
                        (if number? then '<div style="position: relative; width: 100%; height: 100%;"><div style="position: absolute; top: -5px; left: 0px; font-size: 9px;">' + Utils.htmlEscape(number) + '</div></div>' else '') + \
                        '<div style="font-weight: bold">' + Utils.htmlEscape(Utils.useHardSpaces(contents or " ")) + '</div>' + \
                        '</div></td>'
            ).join('') + '</tr>'
    ).join('') + '</table>'

if module?
    exports = module.exports
else
    exports = @PuzzleUtils = {}

exports.getEmptyCell = getEmptyCell
exports.getEmptyPuzzle = getEmptyPuzzle
exports.getNumberedGrid = getNumberedGrid
exports.clonePuzzle = clonePuzzle
exports.staticHtmlForGrid = staticHtmlForGrid
