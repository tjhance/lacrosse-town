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
        row: 0
        col: 0
        is_across: true
        field_open: "none" # "none" or "number" or "contents"

    width: () ->
        @state.puzzle.grid[0].length
    height: () ->
        @state.puzzle.grid.length

    # Returns a grid of the the CSS classes for styling the cell
    getCellClasses: () ->
        getCellClass = (row, col) =>
            grid = @state.puzzle.grid
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
        for i in [0 ... @height()]
            for j in [0 ... @width()]
                getCellClass(i, j)

    # Ensures that the grid_focus is in a valid state even after the puzzle
    # state was modified.
    fixFocus: (puzzle, grid_focus) ->
        if grid_focus == null
            return null
        row = grid_focus.row
        col = grid_focus.col
        height = puzzle.grid.length
        width = puzzle.grid[0].length
        if not (row >= 0 and row < height and col >= 0 and col < width)
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

    moveGridCursor: (drow, dcol) ->
        if @state.grid_focus
            col1 = @state.grid_focus.col + dcol
            row1 = @state.grid_focus.row + drow
            if col1 >= 0 and col1 < @width() and row1 >= 0 and row1 < @height()
                @setState
                    grid_focus:
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
                grid_focus.row, grid_focus.col, "contents", c
            if grid_focus.is_across and grid_focus.col < @width() - 1
                grid_focus.col += 1
            else if (not grid_focus.is_across) and grid_focus.row < @height() - 1
                grid_focus.row += 1
        @setState { grid_focus: grid_focus }

    deleteLetter: (keyCode) ->
        grid_focus = Utils.clone @state.grid_focus
        if grid_focus != null
            grid_focus.cell_field = "none"
            row = grid_focus.row
            col = grid_focus.col
            g = @state.puzzle.grid
            if g[row][col].open and g[row][col].contents != ""
                @props.requestOp Ot.opEditCellValue \
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
                        @props.requestOp Ot.opEditCellValue \
                            row1, col1, "contents", ""
                    grid_focus.col = col1
                    grid_focus.row = row1
            @setState { grid_focus: grid_focus }

    # Perform an automatic renumbering.
    renumber: () ->
        @setState { grid_focus: @removeCellField(@state.grid_focus) }
        @props.requestOp Ot.opGridDiff @state.puzzle, PuzzleUtils.getNumberedGrid @state.puzzle.grid

    toggleOpenness: () ->
        if @state.grid_focus != null
            grid_focus = Utils.clone @state.grid_focus
            grid_focus.field_open = "none"
            @setState { grid_focus: grid_focus }
            row = grid_focus.row
            col = grid_focus.col
            newvalue = not @state.puzzle.grid[row][col].open
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
    removeCellField: (grid_focus) ->
        if grid_focus != null
            grid_focus = Utils.clone grid_focus
            grid_focus.field_open = "none"
        return grid_focus

    onCellFieldKeyPress: (event, row, col) ->
        v = event.target.value
        keyCode = event.keyCode

        grid_focus = Utils.clone @state.grid_focus
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
        event.preventDefault()
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
        grid_focus = if @state.grid_focus == null then @defaultGridFocus() else Utils.clone @state.grid_focus

        grid_focus = @removeCellField(grid_focus)

        if grid_focus != null and grid_focus.row == row and grid_focus.col == col
            grid_focus.is_across = not grid_focus.is_across
        else
            grid_focus.row = row
            grid_focus.col = col
            grid_focus.is_across = true
        this.setState { grid_focus: grid_focus }

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

    clueStylingData: (isAcross) ->
        if @state.grid_focus == null
            return {
                primaryNumber: null,
                secondaryNumber: null
             }
        row = @state.grid_focus.row
        col = @state.grid_focus.col
        while true
            row1 = if isAcross then row else row - 1
            col1 = if isAcross then col - 1 else col
            if row1 >= 0 and col1 >= 0 and @state.puzzle.grid[row1][col1].open
                row = row1
                col = col1
            else
                break
        s = {
            primaryNumber: null,
            secondaryNumber: null
         }
        if @state.puzzle.grid[row][col].number != null
            keyName = if @state.grid_focus.is_across == isAcross then 'primaryNumber' else 'secondaryNumber'
            s[keyName] = @state.puzzle.grid[row][col].number
        return s

    render: ->
        if @state.puzzle == null
            <div className="puzzle_container">
              Loading puzzle...
            </div>
        else
            <div className="puzzle_container">
              <div>
                  Commands:<br/>
                  Ctrl+b to toggle a cell between black/white<br/>
                  Type any letter to enter into the selected cell<br/>
                  Hit backspace to empty a cell<br/>
                  Ctrl+u to enter arbitrary text into a cell (not restricted to a single letter)<br/>
                  Ctlr+i to edit the number of the cell (but the easiest way to set the numbers is the button at the bottom)
              </div>
              <table><tr><td>
                  <div className="puzzle_grid">
                    <PuzzleGrid
                        ref="grid"
                        grid={@state.puzzle.grid}
                        grid_focus={@state.grid_focus}
                        cell_classes={@getCellClasses()}
                        onCellClick={@onCellClick}
                        onCellFieldKeyPress={@onCellFieldKeyPress}
                      />
                    <input type="button" value="Re-assign numbers" onClick={this.renumber} />
                    <input type="checkbox"
                            defaultChecked={true}
                            onChange={@toggleMaintainRotationalSymmetry} />
                        Maintain rotational symmetry
                  </div>
              </td><td>
                  <div stye={{'float': 'left'}}>
                      <div><strong>Across clues:</strong></div>
                      <div className="clue-container">
                        <CluesEditableTextField
                                defaultText={@state.initial_puzzle.across_clues}
                                produceOp={(op) => @clueEdited('across', op)}
                                stylingData={@clueStylingData(true)}
                                ref="acrossClues" />
                      </div>
                      <div><strong>Down clues:</strong></div>
                      <div className="clue-container">
                        <CluesEditableTextField
                                defaultText={@state.initial_puzzle.down_clues}
                                produceOp={(op) => @clueEdited('down', op)}
                                stylingData={@clueStylingData(false)}
                                ref="downClues" />
                      </div>
                  </div>
              </td></tr></table>
              <div className="offline_mode">
                <input type="checkbox"
                        defaultChecked={false}
                        onChange={@toggleOffline} />
                    Offline mode
              </div>
            </div>

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
                        if @props.grid_focus? and @props.grid_focus.row == row then @props.grid_focus else null
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
                        if @props.grid_focus? and @props.grid_focus.col == col then @props.grid_focus else null
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

            if parsed.number and parsed.number == stylingData.primaryNumber
                $(childElem).addClass('clues-highlight-primary')
            if parsed.number and parsed.number == stylingData.secondaryNumber
                $(childElem).addClass('clues-highlight-secondary')

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
