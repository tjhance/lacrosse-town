###
React component representing the dialog to find matching words.

Makes an AJAX call to /find-matches

props:
    clueTitle - e.g. "2 Across"
    clueText
    pattern - e.g. "b..t"
    onSelect - callback that takes a single word argument, an array of characters
               whose length matches the number of periods in the input pattern
    onClose - callback for when the user tries to close the dialog
###

FindMatchesDialog = React.createClass
    getInitialState: () ->
        matchList: null
        error: null

    componentWillReceiveProps: (newProps) ->
        if newProps.pattern != @props.pattern
            @setState(@getInitialState())

    componentDidMount: () ->
        @doAjax()

    componentDidUpdate: () ->
        if not @state.matchList and not @state.error
            @doAjax()

    doAjax: () ->
        # Make the ajax request
        $.ajax({
            type: 'POST',
            url: '/find-matches/',
            data:
                pattern: @props.pattern,
            dataType: 'json',
            success: (data) =>
                @setState { matchList: (m.toUpperCase() for m in data.matches) }
            error: (jqXHR, textStatus, errorThrown) =>
                @setState { error: "error: " + textStatus }
          })

    render: () ->
        <div className="find-matches-container">
            <div className="find-matches-text">Searching for matches of pattern</div>
            <div className="find-matches-pattern">{@renderPattern()}</div>
            <div className="find-matches-text">for clue</div>
            <div className="find-matches-clue">
                <strong>{@props.clueTitle}.</strong>
                <span style={{'whiteSpace': 'pre'}}>{"\xA0" + @props.clueText}</span>
            </div>
            <div className="find-matches-text">(Using UKACD dictionary)</div>
            <div className="find-matches-result">
                {@renderResults()}
            </div>
            <div className="find-matches-close-button">
                <input type="button" className="lt-button" value="Close" onClick={@props.onClose} />
            </div>
        </div>

    renderPattern: () ->
        pattern = @props.pattern.toUpperCase()
        for i in [0 .. pattern.length - 1]
            c = pattern.charAt(i)
            if c == "."
                <span className="find-matches-pattern-blank">{"\xA0"}</span>
            else
                <span className="find-matches-pattern-blank">{c}</span>

    renderResults: () ->
        if @state.matchList
            <div>
                <SelectList matches={@state.matchList}
                        onSelect={(index, value) => @props.onSelect(value)}
                        onClose={() => @props.onClose()} />
            </div>
        else if @state.error
            <div style={{'color': 'red'}}>
                {@state.error}
            </div>
        else
            <div>
                Loading...
            </div>

# A menu for selecting an option
# props:
#    options: a list of string options
#    onSelect: a callback taking arguments (index, value)
SelectList = React.createClass
    componentDidMount: () ->
        @focusIndex(0)

    coerceIndex: (index) ->
        if index < 0
            0
        else if index >= @props.matches.length
            @props.matches.length - 1
        else
            index

    focusIndex: (index) ->
        ref = this.refs['option-' + index]
        if ref?
            anode = React.findDOMNode(ref) # the 'a' node
            anode.focus()

    goUp: (index) ->
        @focusIndex(@coerceIndex(index - 1))

    goDown: (index) ->
        @focusIndex(@coerceIndex(index + 1))

    enter: (index) ->
        if 0 <= index and index < @props.matches.length
            @props.onSelect(index, @props.matches[index])

    onKeyDown: (event, i) ->
        if event.which == 38
            @goUp(i)
            event.preventDefault()
            event.stopPropagation()
        else if event.which == 40
            @goDown(i)
            event.preventDefault()
            event.stopPropagation()
        else if event.which == 13
            @enter(i)
            event.preventDefault()
            event.stopPropagation()
        else if event.which == 27 # escape
            @props.onClose()

    onClick: (event, i) ->
        @enter(i)
        # even with this, we still fail to restore focus to the grid when closing
        # ... why?
        event.preventDefault()
        event.stopPropagation()

    render: () ->
        <div className="dont-bubble-keydown" className="lt-select-list"
                onMouseEnter={() => @setState({mousedOver: true})}
                onMouseLeave={() => @setState({mousedOver: false})} >
            { for i in [0 ... @props.matches.length]
               do (i) =>
                <a href="#" style={{'display': 'block'}}
                        onKeyDown={(event) => @onKeyDown(event, i)}
                        className={"lt-select-list-option"}
                        onClick={(event) => @onClick(event, i)}
                        ref={"option-"+i}
                        key={"option-"+i}>
                    {@props.matches[i]}
                </a>
            }
        </div>

module.exports.FindMatchesDialog = FindMatchesDialog
