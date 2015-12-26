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
    getInitialState: () ->
        index: 0

    coerceIndex: (index) ->
        if index < 0
            0
        else if index >= @props.matches.length
            matches.length - 1
        else
            index

    goUp: () ->
        @setState { index: @coerceIndex(@state.index - 1) }

    goDown: () ->
        @setState { index: @coerceIndex(@state.index + 1) }

    enter: () ->
        if 0 <= @state.index and @state.index < @props.matches.length
            @props.onSelect(@state.index, @props.matches[@state.index])

    onKeyDown: (event) ->
        if event.which == 38
            @goUp()
        else if event.which == 40
            @goDown()

    render: () ->
        optionClassName = (i) =>
            if i == @state.index
                "select-list-option select-list-option-selected"
            else
                "select-list-option select-list-option-unselected"

        <div onKeyDown={@onKeyDown}>
            { for i in [0 ... @props.matches.length]
                <div className={optionClassName(i)} key={"option-"+i}>
                    {@props.matches[i]}
                </div>
            }
        </div>

window.FindMatchesDialog = FindMatchesDialog
