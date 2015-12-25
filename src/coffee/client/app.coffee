# This file has routing and some basic high-level setup and a few
# event handlers with no better home.
# Routes are
#   /new - Static page
#   /puzzle - Page where you view and edit a puzzle.
#             Controller is in puzzle.coffee

# TODO could use some lightweight routing framework?

initApp = () ->
    pathname = window.location.pathname
    parts = pathname.split('/')
    if pathname == '/new'
        el = <NewPage />
        container = $('.view-container').get(0)
        React.render(el, container)
    else if parts[1] == 'puzzle'
        initPuzzleSyncer(parts[2])


#TODO This should get its own file
initPuzzleSyncer = (puzzleID) ->
    syncer = new ClientSyncer(puzzleID)
    syncer.addWatcher (newState, op) ->
        if op?
            p.applyOpToPuzzleState op
        else
            p.setPuzzleState newState

    requestOp = (op) ->
        syncer.localOp op

    onToggleOffline = (val) ->
        syncer.setOffline val

    document.body.addEventListener('keydown', ((event) ->
        if (not $(event.target).hasClass('dont-bubble-keydown')) and \
                $(event.target).closest('.dont-bubble-keydown').length == 0
            p.handleKeyPress event
     ), false)

    document.body.addEventListener('click', ((event) ->
        node = p.gridNode()
        if not (event.target == node or $.contains(node, event.target))
            # This is in a timeout, because right now, the thing being
            # focused hasn't focused yet and running things now in between
            # could cause problems.
            setTimeout((() -> p.blur()), 0)
      ), true)

    el = <PuzzlePage
        requestOp={requestOp}
        onToggleOffline={onToggleOffline}
     />
    container = $('.view-container').get(0)
    p = React.render(el, container)

window.initApp = initApp
