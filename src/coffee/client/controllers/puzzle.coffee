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

puzzleController = ($scope, $routeParams) ->
    $scope.puzzle_id = $routeParams.puzzle_id

    # Initialize the ClientSyncer.
    $scope.puzzle = null
    syncer = new ClientSyncer $scope.puzzle_id
    syncer.addWatcher (newTip, op) ->
        fn = () ->
            # It would be simplest if we always just set $scope.puzzle to
            # newTip. However, applying the operation in-place rather than
            # replacing the whole object results in much better performance
            # for AngularJS.
            # Also, we had better clone the newTip when we take it; otherwise
            # we could introduce a subtle bug by mutating some object that
            # the ClientSyncer uses.
            if $scope.puzzle == null or op == null
                $scope.puzzle = Utils.clonePuzzle newTip
            else
                Ot.applyInPlace $scope.puzzle, op

            fixFocus()

        # Sometimes we need to wrap this in $scope.apply, in order for the
        # changes to actually be propogated to the display. But sometimes
        # we don't (if we are already in one).
        if $scope.$$phase then fn() else $scope.$apply fn

    $scope.settingsModel = {}
    # If this is true, then maintain rotational symmetry of white/blackness
    # when the user toggles a single square.
    $scope.settingsModel.maintainRotationalSymmetry = false
    # Controls the offlineMode property of the ClientSyncer. When in offline
    # mode, don't sync with the server.
    $scope.settingsModel.offlineMode = "no"

    # User interface stuff

    width = () ->
        $scope.puzzle.grid[0].length
    height = () ->
        $scope.puzzle.grid.length

    # Information on how the user is focused on the grid. Contains a row and
    # column for the primary cell the user is focused on. The 'is_across'
    # field determines whether the user is secondarily focused on the
    # across-word of that cell, or the down-word.
    # The 'field_open' is for when the user has an input field open for
    # editting a cell - necessary when editting the number, or when entering
    # contents of more than a single letter.
    # grid_focus can also be null if the user isn't focused on the grid.
    $scope.grid_focus = {
        row: 0
        col: 0
        is_across: true
        field_open: "none" # "none" or "number" or "contents"
    }

    # Ensures that the grid_focus is in a valid state even after the puzzle
    # state was modified.
    fixFocus = () ->
        row = $scope.grid_focus.row
        col = $scope.grid_focus.col
        if not (row >= 0 and row < height() and col >= 0 and col < width())
            $scope.grid_focus = null

    # Returns the CSS class for styling the cell
    # (called by the AngularJS template).
    $scope.getCellClass = (row, col) ->
        grid = $scope.puzzle.grid
        if grid[row][col].open
            if $scope.grid_focus == null
                "open_cell"
            else
                focus = $scope.grid_focus
                if focus.row == row and focus.col == col
                    "open_cell_highlighted"
                else if (\
                    (focus.is_across and focus.row == row and \
                        ([col..focus.col].every (col1) -> grid[row][col1].open)) or \
                    ((not focus.is_across) and focus.col == col and \
                        ([row..focus.row].every (row1) -> grid[row1][col].open)))
                    "open_cell_highlighted_intermediate"
                else
                    "open_cell"
        else
            if ($scope.grid_focus != null and $scope.grid_focus.row == row \
                    and $scope.grid_focus.col == col)
                "closed_cell_highlighted"
            else
                "closed_cell"

    # Actions corresponding to keypresses

    moveGridCursor = (drow, dcol) ->
        removeCellField()
        if $scope.grid_focus != null
            col1 = $scope.grid_focus.col + dcol
            row1 = $scope.grid_focus.row + drow
            if col1 >= 0 and col1 < width() and row1 >= 0 and row1 < height()
                $scope.grid_focus = {
                    "row" : row1
                    "col" : col1
                    "is_across" : drow == 0
                    "field_open" : "none"
                }
                return true
        return false

    typeLetter = (keyCode) ->
        removeCellField()
        if $scope.grid_focus != null
            c = String.fromCharCode keyCode
            syncer.localOp Ot.opEditCellValue \
                $scope.grid_focus.row, $scope.grid_focus.col, "contents", c
            if $scope.grid_focus.is_across and $scope.grid_focus.col < width() - 1
                $scope.grid_focus.col += 1
            else if (not $scope.grid_focus.is_across) and $scope.grid_focus.row < height() - 1
                $scope.grid_focus.row += 1

    deleteLetter = (keyCode) ->
        removeCellField()
        if $scope.grid_focus != null
            row = $scope.grid_focus.row
            col = $scope.grid_focus.col
            g = $scope.puzzle.grid
            if g[row][col].open and g[row][col].contents != ""
                syncer.localOp Ot.opEditCellValue \
                    $scope.grid_focus.row, $scope.grid_focus.col, "contents", ""
                if $scope.grid_focus.is_across and $scope.grid_focus.col > 0
                    $scope.grid_focus.col -= 1
                else if (not $scope.grid_focus.is_across) and $scope.grid_focus.row > 0
                    $scope.grid_focus.row -= 1
            else
                if $scope.grid_focus.is_across
                    row1 = row
                    col1 = col - 1
                else
                    row1 = row - 1
                    col1 = col
                if row1 >= 0 and col1 >= 0
                    if g[row1][col1].open and g[row1][col1].contents != ""
                        syncer.localOp Ot.opEditCellValue \
                            row1, col1, "contents", ""
                    $scope.grid_focus.col = col1
                    $scope.grid_focus.row = row1

    # Perform an automatic renumbering.
    $scope.renumber = () ->
        removeCellField()
        syncer.localOp Ot.opGridDiff $scope.puzzle, Utils.getNumberedGrid $scope.puzzle.grid

    toggleOpenness = () ->
        removeCellField()
        if $scope.grid_focus != null
            row = $scope.grid_focus.row
            col = $scope.grid_focus.col
            newvalue = not $scope.puzzle.grid[row][col].open
            op = Ot.opEditCellValue row, col, "open", newvalue
            if $scope.settingsModel.maintainRotationalSymmetry
                op = Ot.compose $scope.puzzle, op, (Ot.opEditCellValue \
                    (height() - 1 - row), (width() - 1 - col), "open", newvalue)
            syncer.localOp op

    # Stuff relating to the input fields.
    openCellField = (type) ->
        if $scope.grid_focus != null and \
                $scope.puzzle.grid[$scope.grid_focus.row][$scope.grid_focus.col].open
            $scope.grid_focus.field_open = type
    removeCellField = () ->
        if $scope.grid_focus != null
            $scope.grid_focus.field_open = "none"
    $scope.doesCellHaveFieldOpen = (row, col) ->
        $scope.grid_focus.field_open != "none" and \
                $scope.grid_focus.row == row and $scope.grid_focus.col == col
    $scope.getCellFieldInitialValue = () ->
        if $scope.grid_focus != null
            cell = $scope.puzzle.grid[$scope.grid_focus.row][$scope.grid_focus.col]
            if $scope.grid_focus.field_open == "number"
                return if cell.number == null then "" else cell.number.toString()
            else if $scope.grid_focus.field_open == "contents"
                return cell.contents
    $scope.onCellFieldKeyPress = (v, keyCode) ->
        if $scope.grid_focus == null
            return

        if keyCode == 27 # Escape
            removeCellField()
        else if keyCode == 13 # Enter
            v = v or ""
            if $scope.grid_focus.field_open == "number"
                if v == ""
                    value = null
                else if Utils.isValidInteger v
                    value = parseInt v
                else
                    return
                name = "number"
            else if $scope.grid_focus.field_open == "contents"
                value = v
                name = "contents"
            else
                return
            syncer.localOp Ot.opEditCellValue \
                $scope.grid_focus.row, $scope.grid_focus.col, name, value
            $scope.grid_focus.field_open = "none"

    # Handle a keypress by dispatching to the correct method (above).
    handleKeyPress = (event) ->
        if event.ctrlKey
            if event.keyCode == 66 # B
                toggleOpenness()
                event.preventDefault()
            else if event.keyCode == 73 # I
                openCellField "number"
                event.preventDefault()
            else if event.keyCode == 85 # P
                openCellField "contents"
                event.preventDefault()
        else
            if event.keyCode == 37 # LEFT
                if moveGridCursor 0, -1 then event.preventDefault()
            else if event.keyCode == 38 # UP
                if moveGridCursor -1, 0 then event.preventDefault()
            else if event.keyCode == 39 # RIGHT
                if moveGridCursor 0, 1 then event.preventDefault()
            else if event.keyCode == 40 # DOWN
                if moveGridCursor 1, 0 then event.preventDefault()
            else if event.keyCode >= 65 and event.keyCode <= 90 # A-Z
                typeLetter event.keyCode
            else if event.keyCode == 8 # backspace
                deleteLetter()

    # TODO is there a more "proper" way to do this?
    $('body').keydown (e) ->
        $scope.$apply () ->
            handleKeyPress e

    # Focus on a cell when it is clicked on, or toggle its
    # acrossness/downness if it already has focus.
    $scope.onCellClick = (row, col) ->
        removeCellField()
        if $scope.grid_focus != null and $scope.grid_focus.row == row \
                and $scope.grid_focus.col == col
            $scope.grid_focus.is_across = not $scope.grid_focus.is_across
        else
            $scope.grid_focus.row = row
            $scope.grid_focus.col = col
            $scope.grid_focus.is_across = true

    # Offline mode
    $scope.toggleOffline = () ->
        syncer.setOffline ($scope.settingsModel.offlineMode == "yes")

window.puzzleController = puzzleController
