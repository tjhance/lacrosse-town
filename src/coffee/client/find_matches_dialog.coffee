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

    componentDidMount: () ->
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
        <div>
            <strong>{@props.clueTitle}</strong>
            <div style={{'whiteSpace': 'pre'}}>{@props.clueText}</div>
            <div>{@props.pattern}</div>
            {@renderResults()}
            <div>
                <input type="button" value="Close" onClick={@props.onClose} />
            </div>
        </div>

    renderResults: () ->
        if @state.matchList
            <div>
                <SelectList matches={@state.matchList}
                        onSelect={(index, value) => @props.onSelect(value)} />
                <div>(Using UKACD dictionary)</div>
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

    render: () ->
        <div className="dont-bubble-keydown">
            { for i in [0 ... @props.matches.length]
               do (i) =>
                <a href="#" style={{'display': 'block'}}
                        onKeyDown={(event) => @onKeyDown(event, i)}
                        className={"select-list-option"}
                        ref={"option-"+i}
                        key={"option-"+i}>
                    {@props.matches[i]}
                </a>
            }
        </div>

window.FindMatchesDialog = FindMatchesDialog
