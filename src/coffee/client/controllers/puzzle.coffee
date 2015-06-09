# This contains the AngularJS controller for the puzzled-editting page.
# The corresponding template is static/angular/puzzle.html.
#
# It creates a ClientSyncer object (see client/state.coffee) which deals with
# all logic involed in syncing with the server.
#
# The template displays the controllers $scope.puzzle object - but the
# controller just makes this what the ClientSyncer tells it to be.
# Specifically, the controller registers a watcher with the ClientSyncer which
# is called whenever the object-to-be-displayed changes.
#
# The controller responds to most user-input commands by calling the
# ClientSyncer's localOp method with an operation to be made. The ClientSyncer
# will respond by changing the object and calling the watcher to update
# $scope.puzzle. Note, however, that this is not the only time the watcher
# could be called. In particular, it could be called in response to an update
# from the server. As such, the code should be prepared to update the display
# in a way that the user did not ask for.
#
# The most important object here is $scope.puzzle which contain the puzzle to
# be displayed (e.g., a grid containing information about which cells are black,
# what letters are in them, etc.).
#
# Next is $scope.grid_focus which contains information about which cell the
# user is currently focused on, if any.
#
# Finally, there is $scope.settingsModel which is a model that simply contains
# some user configuration settings.

PuzzlePage = React.createClass
    render: ->
        if puzzle == null
            <div className="puzzle_container">
              Loading puzzle...
            </div>
        else
            <div className="puzzle_container">
              <div className="puzzle_grid">
                <table className="puzzle_grid_table">
                  { render_rows() }
                </table>
                <input type="button" value="Re-assign numbers" onClick={this.renumber} />
                <input type="checkbox" /> Maintain rotational symmetry
              </div>
              <div className="offline_mode">
                Offline mode is <br/>
                <input type="radio" name="offlineMode" value="yes"
                                    onChange={this.toggleOffline} /> On <br/>
                <input type="radio" name="offlineMode" value="no"
                                    onChange={this.toggleOffline} /> Off <br/>
              </div>
            </div>

    render_rows: ->
        for row in [0 ... puzzle.grid.length]
            puzzle_row = puzzle.grid[i]

            <tr className="puzzle_grid_row">
                { render_cells(row, puzzle_row) }
            </tr>

    render_cells: (row, puzzle_row) ->
        for col in [0 ... puzzle_row.length]
            cell = puzzle_row[col]

            <td onClick={() => this.onCellClick(row, col)}
                className={"puzzle_grid_cell " + this.getCellClass(row, col)}>
            {
                <div>
                  <div style="position:relative; height: 100%; width: 100%">
                        <div className="cell_number">{if cell.number != null then cell.number else ""}</div>
                  </div>
                  <div className="cell_contents">{if cell.contents == "" then "&nbsp;" else cell.contents}</div>
                </div> if cell.open
            }
            {
                <div style="position:relative">
                  <div className="cellField">
                        <input type="text" id="cellFieldInput"
                                  dont-bubble-keydown
                                  onKeydown="onCellFieldKeyPress(cellFieldInputValue, $event.keyCode)">
                  </div>
                </div> if doesCellHaveFieldOpen(row, col)
            }
            </td>

    getInitialState: () ->
        state =
            puzzle: null
            
            # If this is true, then maintain rotational symmetry of white/blackness
            # when the user toggles a single square.
            maintainRotationalSymmetry: true

            # Controls the offlineMode property of the ClientSyncer. When in offline
            # mode, don't sync with the server.
            offlineMode: false

            # Information on how the user is focused on the grid. Contains a row and
            # column for the primary cell the user is focused on. The 'is_across'
            # field determines whether the user is secondarily focused on the
            # across-word of that cell, or the down-word.
            # The 'field_open' is for when the user has an input field open for
            # editting a cell - necessary when editting the number, or when entering
            # contents of more than a single letter.
            # grid_focus can also be null if the user isn't focused on the grid.
            grid_focus:
                row: 0
                col: 0
                is_across: true
                field_open: "none" # "none" or "number" or "contents"

        for key in state
            this[key] = state[key]

    width: () ->
        this.puzzle.grid[0].length
    height: () ->
        this.puzzle.grid.length

    # Returns the CSS class for styling the cell
    getCellClass: (row, col) ->
        grid = this.state.puzzle.grid
        if grid[row][col].open
            if @state.grid_focus == null
                return "open_cell"
            else
                focus = @state.grid_focus
                if focus.row == row and focus.col == col
                    return "open_cell_highlighted"
                else if (\
                    (focus.is_across and focus.row == row and \
                        ([col..focus.col].every (col1) -> grid[row][col1].open)) or \
                    ((not focus.is_across) and focus.col == col and \
                        ([row..focus.row].every (row1) -> grid[row1][col].open)))
                    return "open_cell_highlighted_intermediate"
                else
                    return "open_cell"
        else
            if (@state.grid_focus != null and @state.grid_focus.row == row \
                    and @state.grid_focus.col == col)
                return "closed_cell_highlighted"
            else
                return "closed_cell"

    # Ensures that the grid_focus is in a valid state even after the puzzle
    # state was modified.
    fixFocus: (puzzle, grid_focus) ->
        row = grid_focus.row
        col = grid_focus.col
        height = puzzle.grid.length
        width = puzzle.grid[0].length
        if not (row >= 0 and row < height and col >= 0 and col < width)
            null
        else
            grid_focus

    setPuzzleState: (puzzle_state) ->
        this.setState
            puzzle: puzzle_state
            grid_focus: this.fixFocus(puzzle_state, this.state.grid_focus)

    # Actions corresponding to keypresses

    moveGridCursor: (drow, dcol) ->
        @removeCellField()
        if @state.grid_focus != null
            col1 = @state.grid_focus.col + dcol
            row1 = @state.grid_focus.row + drow
            if col1 >= 0 and col1 < width() and row1 >= 0 and row1 < height()
                @setState
                    grid_focus:
                        row: row1
                        col: col1
                        is_across: drow == 0
                        field_open: "none"
                return true
        return false

    typeLetter: (keyCode) ->
        @removeCellField()
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            c = String.fromCharCode keyCode
            @props.requestOp Ot.opEditCellValue \
                grid_focus.row, grid_focus.col, "contents", c
            if grid_focus.is_across and grid_focus.col < width() - 1
                grid_focus.col += 1
            else if (not grid_focus.is_across) and grid_focus.row < height() - 1
                grid_focus.row += 1
        @setState { grid_focus: grid_focus }

    deleteLetter: (keyCode) ->
        @removeCellField()
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            row = grid_focus.row
            col = grid_focus.col
            g = $scope.puzzle.grid
            if g[row][col].open and g[row][col].contents != ""
                syncer.localOp Ot.opEditCellValue \
                    grid_focus.row, grid_focus.col, "contents", ""
                if grid_focus.is_across and grid_focus.col > 0
                    grid_focus.col -= 1
                else if (not grid_focus.is_across) and grid_focus.row > 0
                    grid_focus.row -= 1
            else
                if grid_focus.is_across
                    row1 = row
                    col1 = col - 1
                else
                    row1 = row - 1
                    col1 = col
                if row1 >= 0 and col1 >= 0
                    if g[row1][col1].open and g[row1][col1].contents != ""
                        syncer.localOp Ot.opEditCellValue \
                            row1, col1, "contents", ""
                    grid_focus.col = col1
                    grid_focus.row = row1
            @setState { grid_focus: grid_focus }

    # Perform an automatic renumbering.
    renumber: () ->
        @removeCellField()
        @props.requestOp Ot.opGridDiff $scope.puzzle, Utils.getNumberedGrid $scope.puzzle.grid

    toggleOpenness: () ->
        @removeCellField()
        if @state.grid_focus != null
            row = @state.grid_focus.row
            col = @state.grid_focus.col
            newvalue = not $scope.puzzle.grid[row][col].open
            op = Ot.opEditCellValue row, col, "open", newvalue
            if @state.maintainRotationalSymmetry
                op = Ot.compose @state.puzzle, op, (Ot.opEditCellValue \
                    (@height() - 1 - row), (@width() - 1 - col), "open", newvalue)
            @props.requestOp op

    # Stuff relating to the input fields.
    openCellField: (type) ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null and \
                @state.puzzle.grid[grid_focus.row][grid_focus.col].open
            grid_focus.field_open = type
            @setState { grid_focus: grid_focus }
    removeCellField: () ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            grid_focus.field_open = "none"
            @setState { grid_focus: grid_focus }

    doesCellHaveFieldOpen: (row, col) ->
        @state.grid_focus.field_open != "none" and \
               @state.grid_focus.row == row and @state.grid_focus.col == col
    getCellFieldInitialValue: () ->
        if @state.grid_focus != null
            cell = @state.puzzle.grid[@state.grid_focus.row][@state.grid_focus.col]
            if @state.grid_focus.field_open == "number"
                return if cell.number == null then "" else cell.number.toString()
            else if @state.grid_focus.field_open == "contents"
                return cell.contents
    onCellFieldKeyPress: (v, keyCode) ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus == null
            return

        if keyCode == 27 # Escape
            @removeCellField()
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
            @props.requestOp Ot.opEditCellValue grid_focus.row, grid_focus.col, name, value

            grid_focus.field_open = "none"
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
        else
            if event.keyCode == 37 # LEFT
                if @moveGridCursor 0, -1 then event.preventDefault()
            else if event.keyCode == 38 # UP
                if @moveGridCursor -1, 0 then event.preventDefault()
            else if event.keyCode == 39 # RIGHT
                if @moveGridCursor 0, 1 then event.preventDefault()
            else if event.keyCode == 40 # DOWN
                if @moveGridCursor 1, 0 then event.preventDefault()
            else if event.keyCode >= 65 and event.keyCode <= 90 # A-Z
                @typeLetter event.keyCode
            else if event.keyCode == 8 # backspace
                @deleteLetter()

    # Focus on a cell when it is clicked on, or toggle its
    # acrossness/downness if it already has focus.
    onCellClick: (row, col) ->
        @removeCellField()

        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null and grid_focus.row == row and grid_focus.col == col
            grid_focus.is_across = not grid_focus.is_across
        else
            grid_focus.row = row
            grid_focus.col = col
            grid_focus.is_across = true
        this.setState { grid_focus: grid_focus }

    # Offline mode
    toggleOffline: () ->
        checked = this.refs.offline.checked
        this.setState { offlineMode: checked }
        this.onToggleOffline checked

    clueEditted: (name, local_text_op) ->
        @props.requestOp(Ot.getClueOp(name, local_text_op))

window.PuzzlePage = PuzzlePage
