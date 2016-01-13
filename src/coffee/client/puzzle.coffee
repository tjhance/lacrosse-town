###
This is the main react element for the puzzle page.

It takes two callback arguments
    requestOp: Calls this function with a single op representing a change to
        the puzzle state.
    onToggleOffline: Calls this function whenever the user toggles offline-mode.

It also has two functions which should be called:
    setPuzzleState: call this initially to set the puzzle state
    applyOpToPuzzleState: call this with an op to update it.

The user of this class should call `applyOpToPuzzleState` for any op which is applied.
This includes both ops from the server AND ops from the user. That means that when
this object calls `requestOp`, `applyOpToPuzzleState` should be called immediately after.

The React element responds to most user-input commands by creating an op and
calling `requestOp`.

The most important state object is `puzzle`, which is the current state of the puzzle
to be displayed (e.g., a grid containing information about which cells are black,
what letters are in them, etc.).
There is also `grid_focus`, which describes the focus state of the grid: which
cell the grid is focused on, if any.
###

ClipboardUtils = require('./clipboard_utils')
FindMatchesDialog = require('./find_matches_dialog').FindMatchesDialog
Ot = require('../shared/ot')
Utils = require('../shared/utils')
PuzzleUtils = require('../shared/puzzle_utils')
EditableTextField = require('./text_field_handler').EditableTextField
KeyboardUtils = require('./keyboard_utils')

PuzzlePage = React.createClass
    getInitialState: () ->
        puzzle: null
        
        # If this is true, then maintain rotational symmetry of white/blackness
        # when the user toggles a single square.
        maintainRotationalSymmetry: true

        # Controls the offlineMode property of the ClientSyncer. When in offline
        # mode, don't sync with the server.
        offlineMode: false

        # When the user uses the feature to auto-match a word,
        # this object contains info about where the word is and what the pattern is.
        findMatchesInfo: null

        # Information on how the user is focused on the grid. Contains a row and
        # column for the primary cell the user is focused on. The 'is_across'
        # field determines whether the user is secondarily focused on the
        # across-word of that cell, or the down-word.
        # The 'field_open' is for when the user has an input field open for
        # editting a cell - necessary when editting the number, or when entering
        # contents of more than a single letter.
        # grid_focus can also be null if the user isn't focused on the grid.
        grid_focus: @defaultGridFocus()

    defaultGridFocus: () ->
        focus: {row: 0, col: 0}
        anchor: {row: 0, col: 0}
        is_across: true
        field_open: "none" # "none" or "number" or "contents"

    width: () ->
        @state.puzzle.width
    height: () ->
        @state.puzzle.height

    # Returns a grid of the the CSS classes for styling the cell
    getCellClasses: () ->
        grid = @state.puzzle.grid
        grid_focus = @state.grid_focus

        isLineFree = (r1, c1, r2, c2) ->
            if r1 == r2
                if c1 == c2
                    return true
                if c2 < c1 then [c1, c2] = [c2, c1]
                return [c1 .. c2].every((col) -> grid[r1][col].open) && \
                    [c1 .. c2-1].every((col) -> not grid[r1][col].rightbar)
            else
                if r2 < r1 then [r1, r2] = [r2, r1]
                return [r1 .. r2].every((row) -> grid[row][c1].open) && \
                    [r1 .. r2-1].every((row) -> not grid[row][c1].bottombar)
                

        getCellClass = (row, col) =>
            if grid_focus == null
                # no selection, just return the default selection based on whether
                # or not the cell is open or closed
                return (if grid[row][col].open then "open_cell" else "closed_cell")
            else if (grid_focus.focus.row == grid_focus.anchor.row and \
                     grid_focus.focus.col == grid_focus.anchor.col)
                # highlight every cell in the selected cell's row or column (depending on
                # the `is_across` field
                if grid[row][col].open
                    focus = grid_focus
                    if focus.focus.row == row and focus.focus.col == col
                        return "open_cell_highlighted"
                    else if (\
                        (focus.is_across and focus.focus.row == row and
                            isLineFree(row, col, row, focus.focus.col)) or \
                        ((not focus.is_across) and focus.focus.col == col and \
                            isLineFree(row, col, focus.focus.row, col)))
                        return "open_cell_highlighted_intermediate"
                    else
                        return "open_cell"
                else
                    if (grid_focus.focus.row == row and grid_focus.focus.col == col)
                        return "closed_cell_highlighted"
                    else
                        return "closed_cell"
            else
                # selection is more than one cell
                row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row)
                row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row)
                col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col)
                col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col)
                if (row1 <= row and row <= row2 and col1 <= col and col <= col2)
                    return (if grid[row][col].open then "open_cell_highlighted" else "closed_cell_highlighted")
                else
                    return (if grid[row][col].open then "open_cell" else "closed_cell")

        for i in [0 ... @height()]
            for j in [0 ... @width()]
                getCellClass(i, j)

    getBars: () ->
        grid = @state.puzzle.grid
        row_props = @state.puzzle.row_props
        col_props = @state.puzzle.col_props

        getCellBars = (row, col) =>
            return {
                top: (row == 0 && col_props[col].topbar) || (row > 0 && grid[row-1][col].bottombar)
                bottom: grid[row][col].bottombar
                left: (col == 0 && row_props[row].leftbar) || (col > 0 && grid[row][col-1].rightbar)
                right: grid[row][col].rightbar
            }

        for i in [0 ... @height()]
            for j in [0 ... @width()]
                getCellBars(i, j)

    # Ensures that the grid_focus is in a valid state even after the puzzle
    # state was modified.
    fixFocus: (puzzle, grid_focus) ->
        if grid_focus == null
            return null
        row = grid_focus.focus.row
        col = grid_focus.focus.col
        row1 = grid_focus.anchor.row
        col1 = grid_focus.anchor.col
        height = puzzle.grid.length
        width = puzzle.grid[0].length
        if not (row >= 0 and row < height and col >= 0 and col < width and \
                row1 >= 0 and row1 < height and col1 >= 0 and col1 < width)
            null
        else
            grid_focus

    setPuzzleState: (puzzle_state) ->
        this.puzzle_state = puzzle_state
        this.setState
            puzzle: puzzle_state
            initial_puzzle: puzzle_state
            grid_focus: this.fixFocus(puzzle_state, this.state.grid_focus)

    applyOpToPuzzleState: (op) ->
        this.puzzle_state = Ot.apply(this.puzzle_state, op)
        this.setState
            puzzle: this.puzzle_state
            grid_focus: this.fixFocus(this.puzzle_state, this.state.grid_focus)
        if op.across_clues?
            this.refs.acrossClues.takeOp op.across_clues
        if op.down_clues?
            this.refs.downClues.takeOp op.down_clues

    # Actions corresponding to keypresses

    moveGridCursor: (shiftHeld, drow, dcol) ->
        if @state.grid_focus
            col1 = @state.grid_focus.focus.col + dcol
            row1 = @state.grid_focus.focus.row + drow

            col1 = Math.min(@width() - 1, Math.max(0, col1))
            row1 = Math.min(@height() - 1, Math.max(0, row1))

            if shiftHeld
                # move the focus but leave the anchor where it is
                @setState
                    grid_focus:
                        focus:
                            row: row1
                            col: col1
                        anchor:
                            row: @state.grid_focus.anchor.row
                            col: @state.grid_focus.anchor.col
                        is_across: drow == 0
                        field_open: "none"
            else
                # normal arrow key press, just move the focus by 1
                # in the resulting grid_focus, we should have focus=anchor
                @setState
                    grid_focus:
                        focus:
                            row: row1
                            col: col1
                        anchor:
                            row: row1
                            col: col1
                        is_across: drow == 0
                        field_open: "none"
            return true
        return false

    typeLetter: (keyCode) ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            c = String.fromCharCode keyCode
            @props.requestOp Ot.opEditCellValue \
                grid_focus.focus.row, grid_focus.focus.col, "contents", c
            if grid_focus.is_across and grid_focus.focus.col < @width() - 1
                grid_focus.focus.col += 1
            else if (not grid_focus.is_across) and grid_focus.focus.row < @height() - 1
                grid_focus.focus.row += 1
        @setState { grid_focus: @collapseGridFocus grid_focus }

    doSpace: () ->
        if @state.grid_focus
            if @state.grid_focus.is_across
                @moveGridCursor false, 0, 1
            else
                @moveGridCursor false, 1, 0

    doDelete: () ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            grid_focus.cell_field = "none"
            g = @state.puzzle.grid
            if (grid_focus.focus.row == grid_focus.anchor.row and \
                  grid_focus.focus.col == grid_focus.anchor.col)
                # The simplest behavior for 'delete' would be to always delete the
                # contents of the cell. However, this has suboptimal behavior if you're
                # typing out a word and then a typo. If you type a letter, your selection
                # immediately moves to the next cell, which means that if you hit 'delete'
                # right after that, you would expect to delete the letter you just typed
                # but you wouldn't.
                # So, we have this special behavior: if your cell is empty then
                # we delete the contents of the previous cell (either previous in the row
                # or previous in the column).
                # Also, we *always* move the selection back one cell if we can.
                row = grid_focus.focus.row
                col = grid_focus.focus.col
                if g[row][col].open and g[row][col].contents != ""
                    @props.requestOp Ot.opEditCellValue \
                        grid_focus.focus.row, grid_focus.focus.col, "contents", ""
                    if grid_focus.is_across and grid_focus.focus.col > 0
                        grid_focus.focus.col -= 1
                    else if (not grid_focus.is_across) and grid_focus.focus.row > 0
                        grid_focus.focus.row -= 1
                else
                    if grid_focus.is_across
                        row1 = row
                        col1 = col - 1
                    else
                        row1 = row - 1
                        col1 = col
                    if row1 >= 0 and col1 >= 0
                        if g[row1][col1].open and g[row1][col1].contents != ""
                            @props.requestOp Ot.opEditCellValue \
                                row1, col1, "contents", ""
                        grid_focus.focus.col = col1
                        grid_focus.focus.row = row1
                grid_focus = @collapseGridFocus grid_focus
            else
                # If you're selecting more than one cell, then we just delete the contents
                # of all those cells, but we don't move the selection at all.
                row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row)
                row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row)
                col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col)
                col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col)
                op = Ot.identity(@state.puzzle)
                for row in [row1..row2]
                    for col in [col1..col2]
                        if g[row][col].open and g[row][col].contents != ""
                            op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "contents", "")
                @props.requestOp op

            @setState { grid_focus: grid_focus }

    doDeleteAll: () ->
        grid_focus = @state.grid_focus
        if grid_focus == null
            return
        g = @state.puzzle.grid

        row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row)
        row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row)
        col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col)
        col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col)
        op = Ot.identity(@state.puzzle)
        for row in [row1..row2]
            for col in [col1..col2]
                op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "contents", "")
                op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "number", null)
                op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "open", true)
                if row < row2
                    op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "bottombar", false)
                if col < col2
                    op = Ot.compose(@state.puzzle, op, Ot.opEditCellValue row, col, "rightbar", false)
        @props.requestOp op

    # Perform an automatic renumbering.
    renumber: () ->
        @setState { grid_focus: @removeCellField(@state.grid_focus) }
        @props.requestOp Ot.opGridDiff @state.puzzle, PuzzleUtils.getNumberedGrid @state.puzzle.grid

    # Returns true if renumbering the grid would be a non-trivial operation,
    # that is, if there are any cells which would be re-numbered
    needToRenumber: () ->
        op = Ot.opGridDiff @state.puzzle, PuzzleUtils.getNumberedGrid @state.puzzle.grid
        return Ot.isIdentity(op)

    toggleOpenness: () ->
        if @state.grid_focus != null
            grid_focus = Utils.clone @state.grid_focus
            row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row)
            row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row)
            col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col)
            col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col)
            g = @state.puzzle.grid

            isEveryCellClosed = true
            for row in [row1..row2]
                for col in [col1..col2]
                    if g[row][col].open
                        isEveryCellClosed = false

            grid_focus.field_open = "none"
            @setState { grid_focus: grid_focus }

            oldValue = not isEveryCellClosed
            newValue = isEveryCellClosed
            op = Ot.identity(@state.puzzle)
            # want to change every cell of 'open' value `oldValue` to have
            # 'open' value `newValue`
            for row in [row1..row2]
                for col in [col1..col2]
                    if g[row][col].open == oldValue
                        op = Ot.compose @state.puzzle, op, \
                            Ot.opEditCellValue row, col, "open", newValue
                        if @state.maintainRotationalSymmetry
                            op = Ot.compose @state.puzzle, op, \
                                (Ot.opEditCellValue (@height() - 1 - row), (@width() - 1 - col), "open", newValue)

            @props.requestOp op

    toggleBars: (keyCode) ->
        if @state.grid_focus != null
            dir = {37: 'left', 38: 'top', 39: 'right', 40: 'bottom'}[keyCode]
            grid_focus = Utils.clone @state.grid_focus
            row1 = Math.min(grid_focus.focus.row, grid_focus.anchor.row)
            row2 = Math.max(grid_focus.focus.row, grid_focus.anchor.row)
            col1 = Math.min(grid_focus.focus.col, grid_focus.anchor.col)
            col2 = Math.max(grid_focus.focus.col, grid_focus.anchor.col)
            if dir == 'left'
                cells = ([r, col1] for r in [row1 .. row2])
            else if dir == 'right'
                cells = ([r, col2] for r in [row1 .. row2])
            else if dir == 'top'
                cells = ([row1, c] for c in [col1 .. col2])
            else if dir == 'bottom'
                cells = ([row2, c] for c in [col1 .. col2])
            allOn = true
            for cell in cells
                if not @getBar(cell[0], cell[1], dir)
                    allOn = false
            op = Ot.identity(@state.puzzle)
            for cell in cells
                op = Ot.compose(@state.puzzle, op, Ot.opSetBar(cell[0], cell[1], dir, (not allOn)))
            @props.requestOp op

    getBar: (row, col, dir) ->
        if dir == 'top' || dir == 'bottom'
            if dir == 'top'
                row -= 1
            if row == -1
                return @state.puzzle.col_props[col].topbar
            else
                return @state.puzzle.grid[row][col].bottombar
        else if dir == 'left' || dir == 'right'
            if dir == 'left'
                col -= 1
            if col == -1
                return @state.puzzle.row_props[row].leftbar
            else
                return @state.puzzle.grid[row][col].rightbar
        else
            throw new Error("invalid dir " + dir)

    # Stuff relating to the input fields.
    openCellField: (type) ->
        grid_focus = @collapseGridFocus @state.grid_focus
        if grid_focus != null and \
                @state.puzzle.grid[grid_focus.focus.row][grid_focus.focus.col].open
            grid_focus.field_open = type
            @setState { grid_focus: grid_focus }
    removeCellField: (grid_focus) ->
        if grid_focus != null
            grid_focus = @collapseGridFocus grid_focus
            grid_focus.field_open = "none"
        return grid_focus

    # Given a grid_focus object, sets the anchor to be the focus and returns
    # the new object.
    collapseGridFocus: (grid_focus) ->
        if grid_focus != null
            grid_focus = Utils.clone grid_focus
            grid_focus.anchor =
                row: grid_focus.focus.row
                col: grid_focus.focus.col
        return grid_focus

    onCellFieldKeyPress: (event, row, col) ->
        v = event.target.value
        keyCode = event.keyCode

        grid_focus = @collapseGridFocus @state.grid_focus
        if grid_focus == null
            return

        if keyCode == 27 # Escape
            grid_focus = @removeCellField(grid_focus)
        else if keyCode == 13 # Enter
            v = v or ""
            if grid_focus.field_open == "number"
                if v == ""
                    value = null
                else if Utils.isValidInteger v
                    value = parseInt v
                else
                    return
                name = "number"
            else if grid_focus.field_open == "contents"
                value = v
                name = "contents"
            else
                return

            @props.requestOp Ot.opEditCellValue row, col, name, value

            grid_focus = @removeCellField(grid_focus)

        @setState { grid_focus: grid_focus }

    # Handle a keypress by dispatching to the correct method (above).
    handleKeyPress: (event) ->
        if (if KeyboardUtils.usesCmd() then event.metaKey else event.ctrlKey)
            if event.keyCode == 66 # B
                @toggleOpenness()
                event.preventDefault()
            else if event.keyCode == 73 # I
                @openCellField "number"
                event.preventDefault()
            else if event.keyCode == 85 # U
                @openCellField "contents"
                event.preventDefault()
            else if event.keyCode == 71 # G
                @openMatchFinder()
                event.preventDefault()
            else if event.keyCode >= 37 && event.keyCode <= 40
                event.preventDefault()
                @toggleBars(event.keyCode)
        else
            shiftHeld = event.shiftKey
            if event.keyCode == 37 # LEFT
                if @moveGridCursor shiftHeld, 0, -1 then event.preventDefault()
            else if event.keyCode == 38 # UP
                if @moveGridCursor shiftHeld, -1, 0 then event.preventDefault()
            else if event.keyCode == 39 # RIGHT
                if @moveGridCursor shiftHeld, 0, 1 then event.preventDefault()
            else if event.keyCode == 40 # DOWN
                if @moveGridCursor shiftHeld, 1, 0 then event.preventDefault()
            else if event.keyCode >= 65 and event.keyCode <= 90 # A-Z
                @typeLetter event.keyCode
                event.preventDefault()
            else if event.keyCode == 8 # backspace
                @doDelete()
                event.preventDefault()
            else if event.keyCode == 32 # space
                @doSpace()
                event.preventDefault()

    # Focus on a cell when it is clicked on, or toggle its
    # acrossness/downness if it already has focus.
    onCellClick: (row, col) ->
        # this sucks
        $('div[contenteditable=true]').blur()
        window.getSelection().removeAllRanges()

        grid_focus = if @state.grid_focus == null then @defaultGridFocus() else Utils.clone @state.grid_focus

        grid_focus = @removeCellField(grid_focus)

        if grid_focus != null and grid_focus.focus.row == row and grid_focus.focus.col == col
            grid_focus.is_across = not grid_focus.is_across
        else
            grid_focus.focus.row = row
            grid_focus.focus.col = col

            grid = @state.puzzle.grid
            grid_focus.is_across = (not grid[row][col].open) or (col > 0 and grid[row][col-1].open and not grid[row][col-1].rightbar) or (col < @state.puzzle.width - 1 and grid[row][col+1].open and not grid[row][col].rightbar)
        this.setState { grid_focus: @collapseGridFocus grid_focus }

    blur: () ->
        @setState { grid_focus: null }
    gridNode: () ->
        return React.findDOMNode(this.refs.grid)

    # Offline mode
    toggleOffline: (event) ->
        checked = event.target.checked
        @setState { offlineMode: checked }
        @props.onToggleOffline checked

    toggleMaintainRotationalSymmetry: (event) ->
        checked = event.target.checked
        @setState { maintainRotationalSymmetry: checked }

    clueEdited: (name, local_text_op) ->
        @props.requestOp(Ot.getClueOp(name, local_text_op))

    clueStylingData: (is_across) ->
        # compute the answer length, in cells, of each clue number
        answerLengths = {}
        if is_across
            gridForCalculatingLengths = @state.puzzle.grid
        else
            gridForCalculatingLengths = Utils.transpose(@state.puzzle.grid, @width(), @height())
        for line in gridForCalculatingLengths
            number = null
            count = null
            for cell in line
                if cell.open
                    if cell.number != null
                        if number == null
                            number = cell.number
                            count = 1
                        else
                            count++
                    else
                        if number != null
                            count++

                    if (if is_across then cell.rightbar else cell.bottombar)
                         if number != null
                             answerLengths[number] = count
                             number = null
                else
                    if number != null
                        answerLengths[number] = count
                        number = null

            if number != null
                answerLengths[number] = count
                number = null

        if @state.grid_focus == null or \
                @state.grid_focus.focus.row != @state.grid_focus.anchor.row or
                @state.grid_focus.focus.col != @state.grid_focus.anchor.col or
                (not @state.puzzle.grid[@state.grid_focus.focus.row][@state.grid_focus.focus.col].open)
            return {
                primaryNumber: null,
                secondaryNumber: null,
                answerLengths: answerLengths
             }
        row = @state.grid_focus.focus.row
        col = @state.grid_focus.focus.col
        while true
            row1 = if is_across then row else row - 1
            col1 = if is_across then col - 1 else col
            if row1 >= 0 and col1 >= 0 and @state.puzzle.grid[row1][col1].open and \
                    not @state.puzzle.grid[row1][col1][if is_across then 'rightbar' else 'bottombar']
                row = row1
                col = col1
            else
                break
        s = {
            primaryNumber: null,
            secondaryNumber: null,
            answerLengths: answerLengths
         }

        if @state.puzzle.grid[row][col].number != null
            keyName = if @state.grid_focus.is_across == is_across then 'primaryNumber' else 'secondaryNumber'
            s[keyName] = @state.puzzle.grid[row][col].number

        return s

    openMatchFinder: () ->
        if @state.grid_focus == null or \
                @state.grid_focus.focus.row != @state.grid_focus.anchor.row or \
                @state.grid_focus.focus.col != @state.grid_focus.anchor.col
            return

        row = @state.grid_focus.focus.row
        col = @state.grid_focus.focus.col
        g = @state.puzzle.grid

        if not g[row][col].open
            return

        # get the contiguous run of open cells containing the selection
        cells = []
        if @state.grid_focus.is_across
            c1 = col
            c2 = col
            while c1 > 0 and g[row][c1 - 1].open and not g[row][c1 - 1].rightbar
                c1--
            while c2 < @width() - 1 and g[row][c2 + 1].open and not g[row][c2].rightbar
                c2++
            for i in [c1 .. c2]
                cells.push([row, i])
        else
            r1 = row
            r2 = row
            while r1 > 0 and g[r1 - 1][col].open and not g[r1 - 1][col].bottombar
                r1--
            while r2 < @height() - 1 and g[r2 + 1][col].open and not g[r2][col].bottombar
                r2++
            for i in [r1 .. r2]
                cells.push([i, col])

        contents = []
        pattern = ""
        for [r, c] in cells
            contents.push(g[r][c].contents)
            if g[r][c].contents == ""
                pattern += "."
            else
                pattern += g[r][c].contents

        firstCell = g[cells[0][0]][cells[0][1]]
        clueTitle = (if firstCell.number != null then firstCell.number else "?") + " " + \
                    (if @state.grid_focus.is_across then "Across" else "Down")
        if firstCell.number != null
            clueText = @clueTextForNumber(@state.grid_focus.is_across, firstCell.number)
        else
            clueText = ""

        @setState
            findMatchesInfo:
                is_across: @state.grid_focus.is_across
                cells: cells
                contents: contents
                pattern: pattern.toLowerCase()
                clueTitle: clueTitle
                clueText: clueText
                savedGridFocus: Utils.clone @state.grid_focus

    # Looks at the the text of one of the clue fields to find the clue for a given
    # number. Returns the text of that clue. If it can't be found, returns "".
    clueTextForNumber: (is_across, number) ->
        # get the text of the clues
        text = this.refs[if is_across then "acrossClues" else "downClues"].getText()
        # split it into lines
        lines = text.split('\n')
        for line in lines
            parsed = parseClueLine(line)
            if parsed.number == number
                return parsed.secondPart.trim()
        return ""

    closeMatchFinder: () ->
        # close the match-finder panel, and also restore the grid_focus to whatever it was
        # before entering the match-finding state
        grid_focus = if @state.findMatchesInfo.savedGridFocus? then @state.findMatchesInfo.savedGridFocus else null
        @setState
            findMatchesInfo: null
            grid_focus: grid_focus

    # If the user selects a word in the match-finder dialog, we enter that word
    # into the grid here.
    # Note that the board could have changed since the dialog was opened, and maybe
    # the word doesn't match anymore. In that case, we fail.
    onMatchFinderChoose: (word) ->
        if not @state.findMatchesInfo
            return

        fail = () ->
            console.trace()
            alert('Unable to enter "' + word + '" into the grid; maybe the grid has been modified?')

        info = @state.findMatchesInfo
        g = @state.puzzle.grid

        # Check that all the cells are still open
        for i in [0 .. info.cells.length - 1]
            [r, c] = info.cells[i]
            if not (0 <= r and r < @height() and 0 <= c and c < @width() and g[r][c].open)
                fail()
                return
            if i < info.cells.length - 1 and g[r][c][if info.is_across then 'rightbar' else 'bottombar']
                fail()
                return

        # Check that the previous and subsequent cells are not open
        prevR = info.cells[0][0]
        prevC = info.cells[0][1]
        nextR = info.cells[info.cells.length - 1][0]
        nextC = info.cells[info.cells.length - 1][1]
        if info.is_across
            prevC--
            nextC++
        else
            prevR--
            nextR++
        if (prevR >= 0 and prevR < @height() and prevC >= 0 and prevC < @width() and g[prevR][prevC].open and not g[prevR][prevC][if info.is_across then 'rightbar' else 'bottombar']) or \
           (nextR >= 0 and nextR < @height() and nextC >= 0 and nextC < @width() and g[nextR][nextC].open and not g[info.cells[info.cells.length - 1][0]][info.cells[info.cells.length - 1][1]][if info.is_across then 'rightbar' else 'bottombar'])
            fail()
            return
        
        # Make the list of updates to make
        updates = []
        wordPos = 0
        for [r, c] in info.cells
            cell = g[r][c]
            if cell.contents == ""
                # cell contents are empty, so take the next letter of the match word.
                if wordPos >= word.length
                    fail()
                    return
                nextLetter = word.substring(wordPos, wordPos + 1)
                wordPos++
                updates.push({ row: r, col: c, contents: nextLetter.toUpperCase() })
            else
                # cell is not empty:
                # check that contents of the cell match what the match word says they should be
                if word.substring(wordPos, wordPos + cell.contents.length).toLowerCase() != \
                        cell.contents.toLowerCase()
                    fail()
                    return
                wordPos += cell.contents.length
        if wordPos != word.length
            # If there isn't enough room for the whole match word, fail.
            fail()
            return

        # Now we have verified everything is OK and we have a list of updates.
        # So now we just construct the op and apply it.
        op = Ot.identity(@state.puzzle)
        for update in updates
            op = Ot.compose(@state.puzzle, op, \
                    Ot.opEditCellValue(update.row, update.col, "contents", update.contents))

        @props.requestOp op

        @closeMatchFinder()

    # setting dimensions
    onSetDimensions: (width, height) ->
        # NOTE: this actually has one pretty annoying consequence: if the dimensions
        # are, say, 15x15 and two users set them to 20x20 at the same time, each user
        # will add 5 rows and 5 cols, so the dimension will end up at 25x25 when they
        # probably just wanted 20x20. I guess this is a symptom of the row/col OT
        # being overly sophisticated? Well, we could fix this at the OT layer. (TODO)

        op = Ot.identity(@state.puzzle)

        if width < @width()
            op = Ot.compose(@state.puzzle, op,
                    Ot.opDeleteCols(@state.puzzle, width, @width() - width))
        else if width > @width()
            op = Ot.compose(@state.puzzle, op,
                    Ot.opInsertCols(@state.puzzle, @width(), width - @width()))

        if height < @height()
            op = Ot.compose(@state.puzzle, op,
                    Ot.opDeleteRows(@state.puzzle, height, @height() - height))
        else if height > @height()
            op = Ot.compose(@state.puzzle, op,
                    Ot.opInsertRows(@state.puzzle, @height(), height - @height()))

        @props.requestOp op

    # Copy/cut/paste stuff

    doCopy: (event) ->
        if @state.grid_focus == null
            return

        # Get the submatrix to copy
        row1 = Math.min(@state.grid_focus.focus.row, @state.grid_focus.anchor.row)
        row2 = Math.max(@state.grid_focus.focus.row, @state.grid_focus.anchor.row)
        col1 = Math.min(@state.grid_focus.focus.col, @state.grid_focus.anchor.col)
        col2 = Math.max(@state.grid_focus.focus.col, @state.grid_focus.anchor.col)
        submatr = Utils.submatrix(@state.puzzle.grid, row1, row2 + 1, col1, col2 + 1)
 
        # Copy it to clipboard
        ClipboardUtils.copyGridToClipboard(event, col2 - col1 + 1, row2 - row1 + 1, submatr)

    doCut: (event) ->
        if @state.grid_focus == null
            return
        @doCopy(event)
        @doDeleteAll()

    doPaste: (event) ->
        if @state.grid_focus == null
            return

        submatr = ClipboardUtils.getGridFromClipboard(event)
        if submatr?
            # get the upper-left corner
            row1 = Math.min(@state.grid_focus.focus.row, @state.grid_focus.anchor.row)
            col1 = Math.min(@state.grid_focus.focus.col, @state.grid_focus.anchor.col)

            @pasteGridAt(row1, col1, submatr)

            event.preventDefault()

    pasteGridAt: (row, col, grid) ->
        base = @state.puzzle
        op = Ot.identity(base)

        # make sure the grid is big enough; if not, expand it
        if col + grid.width >= @width()
            op = Ot.compose(base, op, Ot.opInsertCols(base, @width(), col + grid.width - @width()))
        if row + grid.height >= @height()
            op = Ot.compose(base, op, Ot.opInsertRows(base, @height(), row + grid.height - @height()))

        for i in [0 ... grid.height]
            for j in [0 ... grid.width]
                op = Ot.compose(base, op,
                        Ot.opEditCellValue(row + i, col + j, "contents", grid.grid[i][j].contents))
                op = Ot.compose(base, op,
                        Ot.opEditCellValue(row + i, col + j, "number", grid.grid[i][j].number))
                op = Ot.compose(base, op,
                        Ot.opEditCellValue(row + i, col + j, "open", grid.grid[i][j].open))
                op = Ot.compose(base, op,
                        Ot.opSetBar(row + i, col + j, 'right', grid.grid[i][j].rightbar))
                op = Ot.compose(base, op,
                        Ot.opSetBar(row + i, col + j, 'bottom', grid.grid[i][j].bottombar))
        @props.requestOp op

        # select the region that was just pasted in
        @setState
            grid_focus:
                focus: { row: row + grid.height - 1, col: col + grid.width - 1 }
                anchor: { row: row, col: col }
                is_across: @state.grid_focus.is_across
                field_open: "none"

    render: ->
        if @state.puzzle == null
            <div className="puzzle_container">
              Loading puzzle...
            </div>
        else
            <div className="puzzle_container">
                <div className="puzzle_title">
                    <h1 className="puzzle_title_header">{@state.puzzle.title}</h1>
                </div>
                <div className="puzzle_container_column">
                    <div className="puzzle_container_box_grid">
                        {@renderPuzzleGrid()}
                    </div>
                    <div className="puzzle_container_box_panel puzzle_container_panel">
                        <PuzzlePanel
                            findMatchesInfo={@state.findMatchesInfo}
                            onMatchFinderChoose={@onMatchFinderChoose}
                            onMatchFinderChoose={@onMatchFinderChoose}
                            onMatchFinderClose={@closeMatchFinder}
                            renumber={@renumber}
                            width={@state.puzzle.width}
                            height={@state.puzzle.height}
                            onSetDimensions={@onSetDimensions}
                            needToRenumber={@needToRenumber()}
                            toggleMaintainRotationalSymmetry={@toggleMaintainRotationalSymmetry}
                            maintainRotationalSymmetry={@state.maintainRotationalSymmetry}
                            />
                        {@renderToggleOffline()}
                    </div>
                </div>
                <div className="puzzle_container_column">
                    <div className="puzzle_container_box_across">
                        {@renderPuzzleClues('across')}
                    </div>
                    <div className="puzzle_container_box_down">
                        {@renderPuzzleClues('down')}
                    </div>
                </div>
            </div>

    renderPuzzleGrid: ->
        <div className="puzzle_grid">
          <PuzzleGrid
              ref="grid"
              grid={@state.puzzle.grid}
              grid_focus={@state.grid_focus}
              cell_classes={@getCellClasses()}
              bars={@getBars()}
              onCellClick={@onCellClick}
              onCellFieldKeyPress={@onCellFieldKeyPress}
            />
        </div>

    renderPuzzleClues: (type) ->
        <div>
            <div className="clue_box_title">
                <strong>{if type == "across" then "Across" else "Down"} clues:</strong>
            </div>
            <CluesEditableTextField
                  defaultText={if type == "across" then @state.initial_puzzle.across_clues else @state.initial_puzzle.down_clues}
                  produceOp={(op) => @clueEdited(type, op)}
                  stylingData={@clueStylingData(type == "across")}
                  ref={if type == "across" then "acrossClues" else "downClues"} />
        </div>

    renderToggleOffline: ->
        return null

        # This is just for debugging, so it's commented out right now:

        #<div className="offline_mode" style={{'display': 'none'}}>
        #    <input type="checkbox"
        #            defaultChecked={false}
        #            onChange={@toggleOffline} />
        #        Offline mode
        #</div>

PuzzlePanel = React.createClass
    render: ->
        meta = KeyboardUtils.getMetaKeyName()
        if @props.findMatchesInfo
            <FindMatchesDialog
                clueTitle={@props.findMatchesInfo.clueTitle}
                clueText={@props.findMatchesInfo.clueText}
                pattern={@props.findMatchesInfo.pattern}
                onSelect={@props.onMatchFinderChoose}
                onClose={@props.onMatchFinderClose} />
        else
            <div>
                <DimensionWidget
                    width={@props.width}
                    height={@props.height}
                    onSet={@props.onSetDimensions}
                    />
                <div className="reassign-numbers-container">
                  <input type="button" value="Re-assign numbers" onClick={@props.renumber}
                        title="Sets the numbers in the grid based off of the locations of the black cells, according to standard crossword rules."
                        className="lt-button" disabled={@props.needToRenumber} />
                </div>
                <div className="rotational-symmetry-container">
                  <input type="checkbox"
                          className="lt-checkbox"
                          defaultChecked={@props.maintainRotationalSymmetry}
                          onChange={@props.toggleMaintainRotationalSymmetry} />
                      <label className="lt-checkbox-label">Maintain rotational symmetry</label>
                </div>
                <div>
                      <h2 className="instructions-header">Tips for solving:</h2>
                      <ul>
                        <li>Arrow keys to move around.</li>
                        <li>Type any letter to enter it into the selected cell.</li>
                        <li><span className="keyboard-shortcut">BACKSPACE</span>
                            {" "}to empty a cell.
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+G</span>
                            {" "}to search a dictionary for matches of a partially-filled in answer.
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+U</span>
                            {" "}to enter arbitrary text into a cell (not restricted to a single letter).
                            </li>
                        <li><span className="keyboard-shortcut">{meta}+Z</span>{" "}and{" "}<span className="keyboard-shortcut">{meta}+SHIFT+Z</span>
                            {" "}to undo and redo.
                            </li>
                      </ul>
                      <h2 className="instructions-header">Tips for editing the grid (or for solving diagramless crosswords):</h2>
                      <ul>
                        <li><span className="keyboard-shortcut">{meta}+B</span>
                            {" "}to toggle a cell between black/white.
                            </li>
                        <li>Use the 'Re-assign numbers' button to fill in numbers, inferring them from
                            {" "}the positions of the black cells.</li>
                        <li><span className="keyboard-shortcut">{meta}+I</span>
                            {" "}to manually edit the number of the cell.
                            </li>
                        <li>Put the clues in the text field on the right. The application will automatically
                            associate lines that start with a number (e.g., "1.") with the corresponding
                            cells on the grid.
                            </li>
                        <li>Hold <span className="keyboard-shortcut">{meta}</span>{" "}and use the arrow keys to add walls between cells.</li>
                        <li>Hold{" "}<span className="keyboard-shortcut">SHIFT</span>{" "}and use the arrow keys to select a rectangular region.</li>
                        <li><span className="keyboard-shortcut">{meta}+X</span>{" "}to cut.</li>
                        <li><span className="keyboard-shortcut">{meta}+C</span>{" "}to copy.</li>
                        <li><span className="keyboard-shortcut">{meta}+V</span>{" "}to paste.</li>
                      </ul>
                </div>
            </div>

DimensionWidget = React.createClass
    # props:
    #   width
    #   height
    #   onSet(width, height)
    getInitialState: () ->
        isEditing: false

    mixins: [React.addons.PureRenderMixin]

    render: () ->
        if @state.isEditing
            <div className="dimension-panel">
                <span className="dimension-panel-edit-1">Width:</span>
                <span className="dimension-panel-edit-2"><input type="text" defaultValue={@props.width} onKeyDown={@onKeyDown} ref={@widthInputFun} className="dont-bubble-keydown" size="4" /></span>
                <span className="dimension-panel-edit-3">Height:</span>
                <span className="dimension-panel-edit-4"><input type="text" defaultValue={@props.height} onKeyDown={@onKeyDown} ref={@heightInputFun} className="dont-bubble-keydown" size="4" /></span>
                <span className="dimension-panel-edit-5"><input type="button" className="lt-button" value="Submit" onClick={@onSubmit} /></span>
            </div>
        else
            <div className="dimension-panel">
                <span className="dimension-panel-static-1">Width:</span>
                <span className="dimension-panel-static-2">{@props.width}</span>
                <span className="dimension-panel-static-3">Height:</span>
                <span className="dimension-panel-static-4">{@props.height}</span>
                <span className="dimension-panel-static-5"><input type="button" className="lt-button" value="Edit" onClick={@onClickEdit} /></span>
            </div>

    widthInputFun: (elem) ->
        if elem? and (not @widthInput?)
            # when creating this field, focus on it
            node = React.findDOMNode(elem)

            # code to focus on the input element 'node' at the END
            # from http://stackoverflow.com/questions/1056359/set-mouse-focus-and-move-cursor-to-end-of-input-using-jquery
            node.focus()
            if node.setSelectionRange
                len = $(node).val().length * 2
                node.setSelectionRange(len, len)
            else
                $(node).val($(node).val())

        @widthInput = elem


    heightInputFun: (elem) ->
        @heightInput = elem

    onClickEdit: () ->
        @setState
            isEditing: true

    onSubmit: () ->
        widthStr = React.findDOMNode(@widthInput).value
        heightStr = React.findDOMNode(@heightInput).value
        if (not Utils.isValidInteger(widthStr)) or (not Utils.isValidInteger(heightStr))
            return
        width = parseInt(widthStr, 10)
        height = parseInt(heightStr, 10)
        if width <= 0 or height <= 0 or width >= 200 or height >= 200
            return
        @props.onSet(width, height)
        @setState
            isEditing: false

    onCancelEdit: () ->
        @setState
            isEditing: false

    onKeyDown: (event) ->
        if event.which == 13 # enter
            @onSubmit()
            event.preventDefault()
        else if event.which == 27 # escape
            @onCancelEdit()
            event.preventDefault()

PuzzleGrid = React.createClass
    shouldComponentUpdate: (nextProps, nextState) -> not Utils.deepEquals(@props, nextProps)

    render: ->
        <table className="puzzle_grid_table"><tbody>
            { for row in [0 ... @props.grid.length]
               do (row) =>
                <PuzzleGridRow
                    key={"puzzle-grid-row-"+row}
                    row={row}
                    grid_row={@props.grid[row]}
                    cell_classes={@props.cell_classes[row]}
                    bars={@props.bars[row]}
                    grid_focus={
                        if @props.grid_focus? and @props.grid_focus.focus.row == row then @props.grid_focus else null
                    }
                    onCellFieldKeyPress={(event, col) => @props.onCellFieldKeyPress(event, row, col)}
                    onCellClick={(col) => @props.onCellClick(row, col)}
                />
            }
        </tbody></table>

PuzzleGridRow = React.createClass
    shouldComponentUpdate: (nextProps, nextState) -> not Utils.deepEquals(@props, nextProps)

    render: ->
        <tr className="puzzle_grid_row">
            { for col in [0 ... @props.grid_row.length]
               do (col) =>
                <PuzzleGridCell
                    key={"puzzle-grid-col-"+col}
                    row={@props.row}
                    col={col}
                    grid_cell={@props.grid_row[col]}
                    cell_class={@props.cell_classes[col]}
                    bars={@props.bars[col]}
                    grid_focus={
                        if @props.grid_focus? and @props.grid_focus.focus.col == col then @props.grid_focus else null
                    }
                    onCellFieldKeyPress={(event) => @props.onCellFieldKeyPress(event, col)}
                    onCellClick={(event) => @props.onCellClick(col)}
                />
            }
        </tr>

PuzzleGridCell = React.createClass
    shouldComponentUpdate: (nextProps, nextState) -> not Utils.deepEquals(@props, nextProps)

    render: ->
        cell = @props.grid_cell

        <td onClick={@props.onCellClick}
            className={"puzzle_grid_cell " + @props.cell_class}>
        {

            if cell.open
                <div>
                  {if @props.bars.left then <div className="left-bar">{'\xA0'}</div>}
                  {if @props.bars.right then <div className="right-bar">{'\xA0'}</div>}
                  {if @props.bars.top then <div className="top-bar">{'\xA0'}</div>}
                  {if @props.bars.bottom then <div className="bottom-bar">{'\xA0'}</div>}
                  <div style={{position: 'relative', height: '100%', width: '100%'}}>
                    <div className="cell_number">
                        {if cell.number != null then cell.number else ""}
                    </div>
                  </div>
                  <div className="cell_contents">
                    {if cell.contents == "" then "\xA0" else cell.contents}
                  </div>
                </div>
            else
                <div>{"\xA0"}</div>
        }
        {
            if @props.grid_focus? and @props.grid_focus.field_open != "none"
                <div style={{position: 'relative'}}>
                  <div className="cellField">
                    <input type="text" id="cellFieldInput"
                              defaultValue={@getCellFieldInitialValue()}
                              ref={@onCellFieldCreate}
                              className="dont-bubble-keydown"
                              onKeyDown={@props.onCellFieldKeyPress} />
                  </div>
                </div>
        }
        </td>

    onCellFieldCreate: (field) ->
        if field?
            node = React.findDOMNode(field)
            node.focus()
            if node.setSelectionRange
              node.setSelectionRange(0, $(node).val().length * 2)

    getCellFieldInitialValue: () ->
        if @props.grid_focus != null
            cell = @props.grid_cell
            if @props.grid_focus.field_open == "number"
                return if cell.number == null then "" else cell.number.toString()
            else if @props.grid_focus.field_open == "contents"
                return cell.contents
        else
            return null

CluesEditableTextField = EditableTextField (lines, stylingData) ->
    i = -1
    for line in lines
        i += 1
        childElem = document.createElement('div')
        if line.length > 0
            parsed = parseClueLine line
            if parsed.firstPart.length > 0
                el = document.createElement('b')
                $(el).text(Utils.useHardSpaces(parsed.firstPart))
                childElem.appendChild el
            if parsed.secondPart.length > 0
                el = document.createTextNode(Utils.useHardSpaces(parsed.secondPart))
                childElem.appendChild el

            $(childElem).addClass('clue-line')

            # clues-highlight-{primary,secondary} classes are for visual styling
            # node-in-view signals to EditableTextField that the node should be scrolled into view.
            if parsed.number and parsed.number == stylingData.primaryNumber
                $(childElem).addClass('clues-highlight-primary')
                $(childElem).addClass('node-in-view')
            if parsed.number and parsed.number == stylingData.secondaryNumber
                $(childElem).addClass('clues-highlight-secondary')
                $(childElem).addClass('node-in-view')

            # display the length of the answer next to the clue, (where the length is
            # calculated based on the cells)
            if parsed.number and parsed.number of stylingData.answerLengths
                $(childElem).addClass('display-answer-length-next-to-line')
                $(childElem).attr('data-answer-length', '(' + stylingData.answerLengths[parsed.number] + ')')

        else
            childElem.appendChild(document.createElement('br'))
        childElem

# Takes a line and parses it assuming it is of the form
# X. clue
# return an object
# { number, firstPart, secondPart }
# If it can't be parsed as such, number is null, firstPart is empty, and secondPart is the entire contents
parseClueLine = (line) ->
    i = 0
    while i < line.length and Utils.isWhitespace(line.charAt(i))
        i += 1
    j = i
    while j < line.length and line.charAt(j) >= '0' and line.charAt(j) <= '9'
        j += 1
    if j > i and j < line.length and line.charAt(j) == '.'
        return {
            number: parseInt(line.substring(i, j))
            firstPart: line.substring(0, j+1)
            secondPart: line.substring(j+1, line.length)
          }
    else
        return {
            number: null
            firstPart: ''
            secondPart: line
          }


module.exports.PuzzlePage = PuzzlePage
