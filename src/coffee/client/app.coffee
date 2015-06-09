# This file defines the AngularJS module and configures it,
# mapping routes. Routes are
#   /new - Static page
#   /puzzle - Page where you view and edit a puzzle.
#             Controller is in controllers/puzzle.coffee

# TODO could use some lightweight routing framework?

initApp = () ->
    pathname = window.location.pathname
    parts = pathname.split('/')
    if pathname == '/new'
        el = <NewPage />
        React.render(el, document.getElementById('view-container'))
    else if parts[1] == 'puzzle'
        initPuzzleSyncer(parts[2])


#TODO This should get its own file
initPuzzleSyncer = (puzzleID) ->
    syncer = new ClientSyncer(puzzleId)
    syncer.addWatcher (newState, op) ->
        p.setPuzzleState newState

    requestOp = (op) ->
        syncer.localOp op

    el = <PuzzlePage
        requestOp={requestOp}
        onToggleOffline={onToggleOffline}
     />
    p = React.render(el, document.getElementById('view-container'))

window.initApp = initApp
