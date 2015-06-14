EditableTextField = React.createClass
    componentWillMount: ->
        @selection = []
        @text = @props.defaultText
        @baseText = @props.defaultText

    render: ->
        <div contentEditable={true}
             onKeyDown={@updateSelection}
             onKeyUp={@updateSelection}
             onKeyPress={@updateSelection}
             onMouseUp={@updateSelection}
             onInput={@onTextChange}

             style={{'fontFamily': 'Courier New'}}
             id="across_clue"
             className="dont-bubble-keydown"

             ref="editableDiv" ></div>

    shouldComponentUpdate: (nextProps, nextState) ->
        false

    componentDidMount: ->
        @setContents @text

    updateSelection: () ->
        [selection, text] = @getSelectionAndText()
        @selection = selection

    onTextChange: () ->
        [newSelection, newText] = @getSelectionAndText()

        selection = @selection
        text = @baseText

        #try
        op = getOpForTextChange selection, text, newSelection, newText
        Utils.assert (newText == OtText.applyTextOp text, op)
        #catch
            # Fallback in case the complicated logic doesn't work
        #    asStr = (sel) ->
        #        "[#{("(#{a}, #{b})" for [a,b] in sel).join(", ")}]"

        #    op = OtText.text_diff2 text, newText

        @selection = newSelection
        @text = newText

        @props.produceOp op

    takeOp: (op) ->
        modelText = @baseText
        modelTextNew = OtText.applyTextOp modelText, op

        if modelTextNew == @text
            selection = @selection
        else if @baseText == @text
            # TODO OT the selection over the op
            selection = null
        else
            selection = null

        @setContents modelTextNew
        @setSelection selection

        @text = modelTextNew
        @baseText = modelTextNew
        @selection = selection

    getNode: ->
        React.findDOMNode(this.refs.editableDiv)

    setContents: (text) ->
        element = @getNode()
        while element.firstChild
            element.removeChild(element.firstChild)

        i = 0
        for text_row in (text.split "\n")[0 ... -1]
            # TODO factor this out, maybe write it with React
            childElem = document.createElement('div')
            if text_row.length > 0
                $(childElem).text(text_row)
            else
                childElem.appendChild(document.createElement('br'))

            # Append element
            element.appendChild childElem

            i += 1

    setSelection: (selection) ->
        element = @getNode()

        countNewlines = (s) ->
            return (s.split "\n").length - 1
        getContOffset = (totalIndex) =>
            #if totalIndex == modelTextNew.length - 1
            #    return [element, $(element).contents().length]
            startOfLine = 1 + @text.lastIndexOf '\n', totalIndex-1
            offset = totalIndex - startOfLine
            containerIndex = countNewlines (@text.substr 0, startOfLine)
            container = element.childNodes[containerIndex]
            container2 = $(element).children().get(containerIndex)
            subcontainer = if offset == 0 then container else (get_text_nodes container)[0]
            return [subcontainer, offset]

        selObj = window.getSelection()
        selObj.removeAllRanges()
        for [left, right] in selection
            [contL, offsetL] = getContOffset left
            [contR, offsetR] = getContOffset right
            range = document.createRange()
            range.setStart contL, offsetL
            range.setEnd contR, offsetR
            selObj.addRange range

    getSelectionAndText: () ->
        element = React.findDOMNode(this)

        # Ugh, some annoying state thing for traversing the DOM nodes for dealing
        # with the crazy way browsers interpret spaces.
        text_lines = []
        cur_line = []
        line_num = 0
        line_offset = 0
        space_state = SPACE_STATE_BEGINNING
        add_line_piece = (piece) ->
            if piece.length > 0
                [space1, main_piece, space2] = plainify_text(piece)
                if space1.length == piece.length
                    if space_state == SPACE_STATE_AFTER_TEXT
                        space_state = SPACE_STATE_AFTER_SPACE
                    return 0
                else
                    if space_state == SPACE_STATE_AFTER_SPACE
                        cur_line.push(' ')
                        line_offset += 1
                    else if space_state == SPACE_STATE_AFTER_TEXT
                        cur_line.push(' ')
                        line_offset += 1
                    cur_line.push(main_piece)
                    line_offset += main_piece.length
                    space_state = if space2.length > 0 then SPACE_STATE_AFTER_SPACE else SPACE_STATE_AFTER_TEXT
                    return space1.length
            else
                return 0

        finish_line = () ->
            text_lines.push(cur_line.join(""))
            line_num++
            line_offset = 0
            cur_line = []
            space_state = SPACE_STATE_BEGINNING

        needs_newline = () ->
            return cur_line.length > 0

        # Traverse the DOM nodes
        recurse = (elem) ->
            if elem.nodeType == 3 # is text node
                elem.lt_index = [line_num, line_offset]
                elem.lt_text_node_real_start = add_line_piece $(elem).text()
            else if elem.tagName == "BR"
                elem.lt_index = [line_num, line_offset]
                finish_line()
            else
                cssdisplay = $(elem).css('display')
                is_inline = cssdisplay? and cssdisplay.indexOf('inline') != -1
                if not is_inline and needs_newline()
                    finish_line()

                elem.lt_index = [line_num, line_offset]

                for childElem in $(elem).contents()
                    recurse childElem

                if not is_inline and needs_newline()
                    finish_line()

        recurse element, false

        if line_num == 0 or needs_newline()
            finish_line()

        # OK, now the text lines should be in `text_lines`.
        # Now we can use all the lt_* properties on the nodes to compute
        # the selection offsets.

        getLineColOffset = (container, offsetWithinContainer) ->
            if container.nodeType == 3 # is text node
                if container.lt_index?
                    [line, offset] = container.lt_index
                    real_start = container.lt_text_node_real_start
                    return [line, offset + Math.max(offsetWithinContainer - real_start, 0)]
                else
                    return null
            else
                subcont = if offsetWithinContainer == 0 then container else $(container).contents()[offsetWithinContainer]
                return if subcont.lt_index? then subcont.lt_index else null

        getTotalOffset = (container, offsetWithinContainer) ->
            o = getLineColOffset(container, offsetWithinContainer)
            if o != null
                [line, offset] = o
                return text_lines.slice(0, line).join("").length + line + offset
            else
                return null

        sels = []
        selObj = window.getSelection()
        for i in [0 ... selObj.rangeCount]
            range = selObj.getRangeAt(i)
            left = getTotalOffset(range.startContainer, range.startOffset)
            if left?
                right = getTotalOffset(range.endContainer, range.endOffset)
                if right?
                    sels.push [left, right]

        sels.sort ([l,r], [l2,r2]) -> l < l2
        return [sels, text_lines.join("\n") + "\n"]


# Thanks http://stackoverflow.com/questions/298750/how-do-i-select-text-nodes-with-jquery
get_text_nodes = (el) ->
    $(el).find(":not(iframe)").addBack().contents().filter () -> @nodeType == 3

isWhitespace = (c) ->
    return c == ' ' or c == '\n' or c == '\r' or c == '\t'

plainify_text = (s, offsets) ->
    l = 0
    while l < s.length and isWhitespace(s.charAt(l))
        l += 1
    if l == s.length
        # all whitespace case
        return [s, "", ""]
    else
        r = s.length
        while isWhitespace(s.charAt(r-1))
            r -= 1
        mid = s.substring(l, r)
        # Replace runs of spaces with a single space
        # Replace \xA0 (i.e., &nbsp;) with a single space
        mid_fixed = mid.replace(/[ \n]+/g, ' ').replace('\xA0', ' ')
        return [s.substring(0, l), mid_fixed, s.substring(r, s.length)]

browserify_text = (s) ->
    t = []
    inSpaceRun = true
    spaceRunLen = 1
    for i in [0 ... s.length]
        c = s[i]
        if c == ' '
            if inSpaceRun
                spaceRunLen++
            else
                inSpaceRun = true
                spaceRunLen = 0
            t.push (if i == s.length - 1 or spaceRunLen % 2 == 1 then '\xA0' else ' ')
        else
            inSpaceRun = false
            t.push c
        
    return t.join ""



getOpForTextChange = (old_sel, old_text, new_sel, new_text) ->
    Utils.assert old_sel.length >= 1
    Utils.assert new_sel.length == 1

    skip = OtText.skip; take = OtText.take; insert = OtText.insert

    op_delete_selected = [take old_sel[0][0]]
    length_after_delete = old_text.length
    for i in [0...old_sel.length]
        op_delete_selected.push (skip (old_sel[i][1] - old_sel[i][0]))
        op_delete_selected.push (take (((if i == old_sel.length - 1 then \
                old_text.length else old_sel[i+1][0]) - old_sel[i][1])))
        length_after_delete -= (old_sel[i][1] - old_sel[i][0])

    [l, r] = new_sel[0]
    if r > l
        Utils.assert new_text.length - (r - l) == length_after_delete
        op2 = [take(l), insert(new_text[l...r]), take(new_text.length-r)]
    else
        prefix_pre = old_sel[0][0]
        suffix_pre = length_after_delete - prefix_pre
        prefix_post = l
        suffix_post = new_text.length - l
        if prefix_pre == prefix_post
            if suffix_post > suffix_pre
                op2 = [take(prefix_pre), insert(new_text[prefix_pre...prefix_pre+suffix_post-suffix_pre]),
                       take(suffix_pre)]
            else
                op2 = [take(prefix_pre), skip(suffix_pre-suffix_post), take(suffix_post)]
        else if suffix_pre == suffix_post
            if prefix_post > prefix_pre
                op2 = [take(prefix_pre), insert(new_text[prefix_pre...prefix_post]), take(suffix_pre)]
            else
                op2 = [take(prefix_post), skip(prefix_pre-prefix_post), take(suffix_pre)]
        else
            throw "Does not match up on either side"

    op = OtText.composeText old_text,
                            (OtText.canonicalized op_delete_selected),
                            (OtText.canonicalized op2)
    return op

SPACE_STATE_BEGINNING = 0
SPACE_STATE_AFTER_SPACE = 1
SPACE_STATE_AFTER_TEXT = 2

window.EditableTextField = EditableTextField
