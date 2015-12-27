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
This includes both ops from the server AND ops from the user. Tha means that when
this object calls `requestOp`, `applyOpToPuzzleState` should be called immediately after.

The React element responds to most user-input commands by creating an op and
calling `requestOp`.

The most important state object is `puzzle`, which is the current state of the puzzle
to be displayed (e.g., a grid containing information about which cells are black,
what letters are in them, etc.).
There is also `grid_focus`, which describes the focus state of the grid: which
cell the grid is focused on, if any.
###

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
                        (focus.is_across and focus.focus.row == row and \
                            ([col..focus.focus.col].every (col1) -> grid[row][col1].open)) or \
                        ((not focus.is_across) and focus.focus.col == col and \
                            ([row..focus.focus.row].every (row1) -> grid[row1][col].open)))
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
                for row in [row1..row2]
                    for col in [col1..col2]
                        if g[row][col].open and g[row][col].contents != ""
                            @props.requestOp Ot.opEditCellValue row, col, "contents", ""

            @setState { grid_focus: grid_focus }

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
        if event.ctrlKey
            if event.keyCode == 66 # B
                @toggleOpenness()
                event.preventDefault()
            else if event.keyCode == 73 # I
                @openCellField "number"
                event.preventDefault()
            else if event.keyCode == 85 # P
                @openCellField "contents"
                event.preventDefault()
            else if event.keyCode == 71 # G
                @openMatchFinder()
                event.preventDefault()
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
            grid_focus.is_across = true
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
            if row1 >= 0 and col1 >= 0 and @state.puzzle.grid[row1][col1].open
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
        # (we can assume for this that it's an 'across' word, since we did
        # the transpose, above)
        cells = []
        if @state.grid_focus.is_across
            c1 = col
            c2 = col
            while c1 > 0 and g[row][c1 - 1].open
                c1--
            while c2 < @width() - 1 and g[row][c2 + 1].open
                c2++
            for i in [c1 .. c2]
                cells.push([row, i])
        else
            r1 = row
            r2 = row
            while r1 > 0 and g[r1 - 1][col].open
                r1--
            while r2 < @height() - 1 and g[r2 + 1][col].open
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
        @setState
            findMatchesInfo: null

    # If the user selects a word in the match-finder dialog, we enter that word
    # into the grid here.
    # Note that the board could have changed since the dialog was opened, and maybe
    # the word doesn't match anymore. In that case, we fail.
    onMatchFinderChoose: (word) ->
        if not @state.findMatchesInfo
            return

        fail = () ->
            alert('Unable to enter "' + word + '" into the grid; maybe the grid has been modified?')

        info = @state.findMatchesInfo
        g = @state.puzzle.grid

        # Check that all the cells are still open
        for [r, c] in info.cells
            if not (0 <= r and r < @height() and 0 <= c and c < @width() and g[r][c].open)
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
            prevR++
        if (prevR >= 0 and prevR < @height() and prevC >= 0 and prevC < @width() and g[prevR][prevC].open) or \
           (nextR >= 0 and nextR < @height() and nextC >= 0 and nextC < @width() and g[nextR][nextC].open)
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
        ClipboardUtils.copy(event, col2 - col1 + 1, row2 - row1 + 1, submatr)

    doCut: (event) ->
        if @state.grid_focus == null
            return
        doCopy(event)
        doDeleteAll()

    doPaste: (event) ->
        if @state.grid_focus == null
            return

        submatr = ClipboardUtils.paste()
        if submatr?
            false

    render: ->
        if @state.puzzle == null
            <div className="puzzle_container">
              Loading puzzle...
            </div>
        else
            <div className="puzzle_container">
                <div className="puzzle_container_column">
                    <div className="puzzle_container_box">
                        {@renderPuzzleGrid()}
                    </div>
                    <div className="puzzle_container_box puzzle_container_panel">
                        {@renderPuzzlePanel()}
                    </div>
                </div>
                <div className="puzzle_container_column">
                    <div className="puzzle_container_box">
                        {@renderPuzzleClues('across')}
                    </div>
                    <div className="puzzle_container_box">
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

    renderPuzzlePanel: ->
        if @state.findMatchesInfo
            <FindMatchesDialog
                clueTitle={@state.findMatchesInfo.clueTitle}
                clueText={@state.findMatchesInfo.clueText}
                pattern={@state.findMatchesInfo.pattern}
                onSelect={@onMatchFinderChoose}
                onClose={@closeMatchFinder} />
        else
            <div>
                <div className="reassign-numbers-container">
                  <input type="button" value="Re-assign numbers" onClick={this.renumber}
                        title="Sets the numbers in the grid based off of the locations of the black cells, according to standard crossword rules."
                        className="lt-button" disabled={@needToRenumber()} />
                </div>
                <div className="rotational-symmetry-container">
                  <input type="checkbox"
                          className="lt-checkbox"
                          defaultChecked={true}
                          onChange={@toggleMaintainRotationalSymmetry} />
                      <label className="lt-checkbox-label">Maintain rotational symmetry</label>
                </div>
                <div>
                      <strong>Usage:</strong>
                      <ul>
                        <li>Type any letter to enter into the selected cell</li>
                        <li><span className="keyboard-shortcut">BACKSPACE</span>
                            &nbsp;to empty a cell
                            </li>
                        <li><span className="keyboard-shortcut">CTRL+B</span>
                            &nbsp;to toggle a cell between black/white
                            </li>
                        <li><span className="keyboard-shortcut">CTRL+U</span>
                            &nbsp;to enter arbitrary text into a cell (not restricted to a single letter)
                            </li>
                        <li><span className="keyboard-shortcut">CTRL+I</span>
                            &nbsp;to edit the number of the cell
                            (but the easiest way to set the numbers is 'Re-assign numbers' buttons)
                            </li>
                      </ul>
                </div>
                {@renderToggleOffline()}
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

PuzzleGrid = React.createClass
    shouldComponentUpdate: (nextProps, nextState) -> not Utils.deepEquals(@props, nextProps)

    render: ->
        <table className="puzzle_grid_table">
            { for row in [0 ... @props.grid.length]
               do (row) =>
                <PuzzleGridRow
                    key={"puzzle-grid-row-"+row}
                    row={row}
                    grid_row={@props.grid[row]}
                    cell_classes={@props.cell_classes[row]}
                    grid_focus={
                        if @props.grid_focus? and @props.grid_focus.focus.row == row then @props.grid_focus else null
                    }
                    onCellFieldKeyPress={(event, col) => @props.onCellFieldKeyPress(event, row, col)}
                    onCellClick={(col) => @props.onCellClick(row, col)}
                />
            }
        </table>

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
            React.findDOMNode(field).focus()

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


window.PuzzlePage = PuzzlePage
