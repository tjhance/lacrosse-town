# Utilities for copying and pasting grids.

# Copies the given puzzle grid to the clipboard
copy = (event, width, height, grid) ->
    if event.clipboardData
        gridHtml = PuzzleUtils.staticHtmlForGrid(width, height, grid)

        # make a newline- and tab-separated matrix from the contents
        # for black cells, use '.'
        gridText = (((if c.open then (c.contents or "") else ".") for c in row).join("\t") for row in grid).join("\n")

        event.clipboardData.setData("text/html", gridHtml)
        event.clipboardData.setData("text/plain", gridText)

        event.preventDefault()

paste = () ->
    false

window.ClipboardUtils = {
    copy: copy,
    paste: paste
}
