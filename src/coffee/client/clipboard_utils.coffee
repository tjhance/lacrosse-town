# Utilities for copying and pasting grids.

PuzzleUtils = require "../shared/puzzle_utils"

# Copies the given puzzle grid to the clipboard
copyGridToClipboard = (event, width, height, grid) ->
    if event.clipboardData
        gridHtml = PuzzleUtils.staticHtmlForGrid(width, height, grid)

        # make a newline- and tab-separated matrix from the contents
        # for black cells, use '.'
        gridText = (((if c.open then (c.contents or "") else ".") for c in row).join("\t") for row in grid).join("\n")

        event.clipboardData.setData("text/html", gridHtml)
        event.clipboardData.setData("text/plain", gridText)

        event.preventDefault()

getGridFromClipboard = (event) ->
    if event.clipboardData
        html = event.clipboardData.getData("text/html")
        if html?
            # parse the HTML to a DOM node we can manipulate
            parsedNode = safelyParseHtml(html)
            nodes = allNodes parsedNode

            # traverse all the nodes
            width = null
            height = null
            cells = []
            for node in nodes
                if node.getAttribute?
                    # When copying a grid, we add all of these custom data-crossword- attributes
                    # to the HTML. We can just parse them out here.
                    if node.getAttribute('data-crossword-width')?
                        width = parseInt(node.getAttribute('data-crossword-width'), 10)
                    if node.getAttribute('data-crossword-height')?
                        height = parseInt(node.getAttribute('data-crossword-height'), 10)

                    x = node.getAttribute('data-crossword-cell-x')
                    y = node.getAttribute('data-crossword-cell-y')
                    if x? and y?
                        open = node.getAttribute('data-crossword-cell-open') == "true"
                        number = node.getAttribute('data-crossword-cell-number')
                        number = parseInt(number, 10)
                        if (not number) and number != 0
                            number = null
                        contents = node.getAttribute('data-crossword-cell-contents') or ""
                        cells.push({ x: x, y: y, open: open, number: number, contents: contents })

            if width and height
                grid = for i in [0 ... height]
                            for j in [0 ... width]
                                PuzzleUtils.getEmptyCell()
                for cell in cells
                    x = cell.x
                    y = cell.y
                    if 0 <= x and x < width and 0 <= y and y < height
                        grid[y][x] = { open: cell.open, number: cell.number, contents: cell.contents }

                return { width: width, height: height, grid: grid }

    return null

# This safely parses HTML to a DOM without allowing script injection
safelyParseHtml = (html) ->
  parser = new DOMParser()
  doc = parser.parseFromString(html, "text/html")
  return doc.body

# Given a node, return a list containing it and all its descendants
allNodes = (node) ->
    res = []
    recurse = (n) ->
        res.push(n)
        for i in [0 ... n.childNodes.length]
            recurse(n.childNodes[i])
    recurse(node)
    return res

module.exports.copyGridToClipboard = copyGridToClipboard
module.exports.getGridFromClipboard = getGridFromClipboard
