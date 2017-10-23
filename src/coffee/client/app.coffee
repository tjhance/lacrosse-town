# This file has routing and some basic high-level setup and a few
# event handlers with no better home.
# Routes are
#   /new - Static page
#   /puzzle - Page where you view and edit a puzzle.
#             Controller is in puzzle.coffee

# TODO could use some lightweight routing framework?

NewPage = require('./new').NewPage
ClientSyncer = require('./state').ClientSyncer
PuzzlePage = require('./puzzle').PuzzlePage

initApp = () ->
    pathname = window.location.pathname
    parts = pathname.split('/')
    if pathname == '/new' || pathname == '/' || pathname == ''
        el = <NewPage />
        container = $('.view-container').get(0)
        React.render(el, container)
    else if parts[1] == 'puzzle'
        initPuzzleSyncer(parts[2], window.PAGE_DATA)


#TODO This should get its own file
initPuzzleSyncer = (puzzleID, initialData) ->
    syncer = new ClientSyncer(puzzleID, initialData)
    syncer.addWatcher (newState, op) ->
        p.applyOpToPuzzleState op
    syncer.loadInitialData(initialData)

    requestOp = (op) ->
        syncer.localOp op

    onToggleOffline = (val) ->
        syncer.setOffline val

    document.body.addEventListener('keydown', ((event) ->
        if (not $(event.target).hasClass('dont-bubble-keydown')) and \
                $(event.target).closest('.dont-bubble-keydown').length == 0
            p.handleKeyPress event
     ), false)

    document.body.addEventListener('keydown', ((event) ->
        if event.which == 90 # Z
            if event.ctrlKey and event.shiftKey
                syncer.redo()
                event.preventDefault()
            else if event.ctrlKey
                syncer.undo()
                event.preventDefault()
     ), true)

    document.body.addEventListener('click', ((event) ->
        node = p.gridNode()
        if not (event.target == node or $.contains(node, event.target))
            # This is in a timeout, because right now, the thing being
            # focused hasn't focused yet and running things now in between
            # could cause problems.
            setTimeout((() -> p.blur()), 0)
      ), true)

    document.body.addEventListener('focus', ((event) ->
        node = p.gridNode()
        if node != document.body and not (event.target == node or $.contains(node, event.target))
            setTimeout((() -> p.blur()), 0)
      ), true)

    document.body.addEventListener('copy', ((event) ->
        if (not $(event.target).hasClass('dont-bubble-keydown')) and \
                $(event.target).closest('.dont-bubble-keydown').length == 0
            p.doCopy event
      ), true)

    document.body.addEventListener('cut', ((event) ->
        if (not $(event.target).hasClass('dont-bubble-keydown')) and \
                $(event.target).closest('.dont-bubble-keydown').length == 0
            p.doCut event
      ), true)

    document.body.addEventListener('paste', ((event) ->
        if (not $(event.target).hasClass('dont-bubble-keydown')) and \
                $(event.target).closest('.dont-bubble-keydown').length == 0
            p.doPaste event
      ), true)

    el = <PuzzlePage
        requestOp={requestOp}
        onToggleOffline={onToggleOffline}
     />
    container = $('.view-container').get(0)
    p = React.render(el, container)

    p.setPuzzleState initialData.puzzle

window.initApp = initApp
