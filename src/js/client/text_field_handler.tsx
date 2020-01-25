// This is an incredibly stateful, very "non reacty" object.
// TODO move the 'stateful' part outside react, make the react object more stateless

import * as React from 'react';
import * as ReactDom from 'react-dom';

import * as OtText from '../shared/ottext';
import * as Utils from '../shared/utils';

import {TextOperation} from '../shared/ottext';

declare var $: any;

type Props = {
  defaultText: string;
  stylingData: any;
  produceOp: (op: TextOperation) => void;
};

type State = {
};

type Range = [number, number];

type LineInfoPiece = {
  node: Node;
  left: number;
  right: number;
  text: string;
  isSpace: boolean;
};

export function EditableTextField(buildContent: (contents: string[], stylingData: any) => Element[]) : any {
  class EditableTextField extends React.Component<Props, State> {
    selection: [number, number][];
    text: string;
    baseText: string;
    stylingData: any;

    componentWillMount() {
      this.selection = [];
      this.text = this.props.defaultText;
      this.baseText = this.props.defaultText;
      this.stylingData = this.props.stylingData;
    }

    getText() {
      return this.baseText;
    }

    render() {
      return (
        <div className="clue-container" ref="editableDivContainer">
          <div className="clue-container-full-height">
            <div contentEditable={true}
                 onKeyDown={this.updateSelection.bind(this)}
                 onKeyUp={this.updateSelection.bind(this)}
                 onKeyPress={this.updateSelection.bind(this)}
                 onMouseUp={this.updateSelection.bind(this)}
                 onFocus={this.updateSelection.bind(this)}
                 onInput={this.onTextChange.bind(this)}

                 className="clue-contenteditable dont-bubble-keydown"

               ref="editableDiv" ></div>
            <div className="clue-right-border">&nbsp;</div>
          </div>
        </div>
      );
    }

    shouldComponentUpdate(nextProps: Props, nextState: State) {
      if (!Utils.deepEquals(nextProps.stylingData, this.stylingData)) {
        this.stylingData = nextProps.stylingData;

        // this will re-render the editor's contents with the new styling data:
        this.rerender();
      }
      return false;
    }

    componentDidMount() {
      this.setContents(this.text);
    }

    updateSelection() {
      const selAndText = this.getSelectionAndText();
      const selection = selAndText[0];
      this.selection = selection;
    }

    rerender() {
      const [newSelection, newText] = this.getSelectionAndText();

      this.selection = newSelection;
      this.text = newText;

      this.setContents(this.text);
      this.setSelection(this.selection);

      this.scrollIfNecessary();
    }

    onTextChange() {
      const [newSelection, newText] = this.getSelectionAndText();

      const selection = this.selection;
      const text = this.baseText;

      let op;
      try {
        op = getOpForTextChange(selection, text, newSelection, newText);
        Utils.assert(newText === OtText.applyTextOp(text, op));
      } catch (ex) {
        // Fallback in case the complicated logic doesn't work
        op = getOpForTextChange2(text, newText);
        Utils.assert(newText === OtText.applyTextOp(text, op))
      }

      this.selection = newSelection;
      this.text = newText;

      this.props.produceOp(op);
    }

    takeOp(op: TextOperation) {
      const modelText = this.baseText;
      const modelTextNew = OtText.applyTextOp(modelText, op);

      let selection: Range[];
      if (modelTextNew === this.text) {
        selection = this.selection;
      } else if (this.baseText === this.text) {
        selection = this.selection.map((range: Range) => OtText.xformRange(this.baseText, op, range));
      } else {
        selection = [];
      }

      this.setContents(modelTextNew);
      this.setSelection(selection);

      this.text = modelTextNew;
      this.baseText = modelTextNew;
      this.selection = selection;

      this.scrollIfNecessary();
    }

    getNode(): Element {
      return ReactDom.findDOMNode(this.refs.editableDiv) as Element;
    }

    getContainerNode(): Element {
      return ReactDom.findDOMNode(this.refs.editableDivContainer) as Element;
    }

    setContents(text: string) {
      const element = this.getNode();
      while (element.firstChild) {
        element.removeChild(element.firstChild);
      }

      const lineElements = buildContent(text.split("\n"), this.stylingData);

      for (const lineElement of lineElements) {
        element.appendChild(lineElement);
      }
    }

    setSelection(selection: [number, number][]) {
      const selObj = window.getSelection() as Selection;
      let element: any = this.getNode();

      // if we're to set the selection to nothing,
      // and there is some selection in the window OUTSIDE this text field
      // then we don't do anything
      if (selection.length === 0) {
        for (let i = 0; i < selObj.rangeCount; i++) {
          const range = selObj.getRangeAt(i);
          if ($(range.startContainer).closest(element).size() === 0) {
            return;
          }
          if ($(range.endContainer).closest(element).size() === 0) {
            return;
          }
        }
      }

      element = this.getNode();

      const countNewlines = (s: string) => s.split("\n").length - 1;

      const getContOffset = (totalIndex: number) => {
        const startOfLine = 1 + this.text.lastIndexOf('\n', totalIndex - 1);
        let offset = totalIndex - startOfLine;
        const containerIndex = countNewlines(this.text.substr(0, startOfLine));
        const container = element.childNodes[containerIndex];
        //const container2 = $(element).children().get(containerIndex);
        if (offset === 0) {
          return [container, 0];
        } else {
          const textNodes = get_text_nodes(container);
          let i = 0
          while (offset > $(textNodes[i]).text().length) {
            Utils.assert(i < textNodes.length);
            offset -= $(textNodes[i]).text().length;
            i += 1;
          }
          return [textNodes[i], offset];
        }
      }

      selObj.removeAllRanges();
      selection.forEach(([left, right]) => {
        const [contL, offsetL] = getContOffset(left);
        const [contR, offsetR] = getContOffset(right);
        const range = document.createRange();
        range.setStart(contL, offsetL);
        range.setEnd(contR, offsetR);
        selObj.addRange(range);
      });
    }

    getSelectionAndText() : [Range[], string] {
      const element: any = this.getNode();

      // Ugh, some annoying crap for traversing the DOM nodes for dealing
      // with the crazy way browsers interpret spaces.
      const text_lines: string[] = [];
      let cur_line: LineInfoPiece[] = [];
      let cur_line_has_text = false;
      let line_num = 0;
      let total_offset = 0;

      const add_line_piece = (node: Node) => {
        (node as any).lt_pieces = [];
        const text = $(node).text();
        if (text.length > 0) {
          let l = 0;
          while (l < text.length) {
            let r;
            if (Utils.isWhitespace(text.charAt(l))) {
              // run of spaces
              r = l + 1;
              while (r < text.length && Utils.isWhitespace(text.charAt(r))) {
                r += 1
              }
              cur_line.push({ node: node, left: l, right: r, text: " ", isSpace: true });
            } else {
              // run of text
              r = l + 1;
              while (r < text.length && !Utils.isWhitespace(text.charAt(r))) {
                r += 1
              }
              cur_line.push({
                node: node,
                left: l,
                right: r,
                text: text.substring(l, r).replace('\xA0', ' '),
                isSpace: false,
              });
              cur_line_has_text = true;
            }
            l = r;
          }
        } else {
          cur_line.push({ node: node, left: 0, right: 0, text: "", isSpace: true });
        }
      };

      const analyze_line_pieces = () => {
        while (cur_line.length > 0 && cur_line[cur_line.length - 1].isSpace) {
          cur_line.length -= 1;
        }

        const totalText: string[] = [];
        for (let i = 0; i < cur_line.length; i++) {
          const piece: any = cur_line[i];
          if (piece.isSpace && (i === 0 || cur_line[i-1].isSpace)) {
            piece.text = "";
          }
          piece.totalOffset = total_offset;
          total_offset += piece.text.length;
          piece.node.lt_pieces.push(piece);
          totalText.push(piece.text);
        }
        return totalText.join("");
      };

      const finish_line = () => {
        line_num++;
        text_lines.push(analyze_line_pieces());
        cur_line = [];
        cur_line_has_text = false;
        total_offset += 1;
      }

      const needs_newline = () => {
        return cur_line_has_text;
      }

      // Traverse the DOM nodes
      // Annotes all text nodes with `lt_pieces` 
      const recurse = (elem: Node) => {
        (elem as any).lt_start_newline = false;
        (elem as any).lt_end_newline = false;

        if (elem.nodeType === 3) { // is text node
          add_line_piece(elem);
        } else if (elem.nodeType === 1) { // ordinary node
          if ((elem as Element).tagName === "BR") {
            finish_line();
            (elem as any).lt_end_newline = true;
          } else if ((elem as Element).tagName == "STYLE") {
            (elem as any).lt_skip = true;
          } else {
            const cssdisplay = $(elem).css('display');
            const is_inline = (cssdisplay != null && cssdisplay.indexOf('inline') !== -1);
            if (!is_inline && needs_newline()) {
              finish_line();
              (elem as any).lt_start_newline = true;
            }

            const contents = $(elem).contents();
            for (let i = 0; i < contents.length; i++) {
              recurse(contents[i]);
            }

            if (!is_inline && needs_newline()) {
              finish_line();
              (elem as any).lt_end_newline = true;
            }
          }
        }
      }
      recurse(element);

      if (line_num === 0 || needs_newline()) {
        finish_line();
      }

      // Traverse the DOM nodes again, annotate all nodes with lt_start and lt_end
      let totalOffset = 0;
      const recurse2 = (elem: Node) => {
        if ((elem as any).lt_skip) {
          return;
        }
        if ((elem as any).lt_start_newline) {
          totalOffset += 1;
        }
        (elem as any).lt_start = totalOffset;
        if (elem.nodeType == 3) { // is text node
          for (const piece of (elem as any).lt_pieces) {
            totalOffset += piece.text.length;
          }
        } else if (elem.nodeType == 1) { // ordinary node
          const contents = $(elem).contents();
          for (let i = 0; i < contents.length; i++) {
            recurse2(contents[i]);
          }
        }
        (elem as any).lt_end = totalOffset;
        if ((elem as any).lt_end_newline) {
          totalOffset += 1;
        }
      };

      recurse2(element);

      // OK, now the text lines should be in `text_lines`.
      // Now we can use all the lt_* properties on the nodes to compute
      // the selection offsets.

      const getTotalOffset = (container: Node, offsetWithinContainer: number) => {
        if ($(container).closest(this.getNode()).size() === 0) {
          return null;
        }
        if (container.nodeType === 1) {
          return offsetWithinContainer === 0 ? (container as any).lt_start : (container as any).lt_end;
        } else if (container.nodeType === 3) {
          for (const piece of (container as any).lt_pieces) {
            if (offsetWithinContainer >= piece.left && offsetWithinContainer <= piece.right) {
              return piece.totalOffset + Math.min(offsetWithinContainer - piece.left, piece.text.length);
            }
          }
          Utils.assert(false, "bad pieces");
        } else {
          Utils.assert(false, "nodeType note 1 or 3, instead " + container.nodeType);
        }
      };

      const sels: Range[] = [];
      const selObj: Selection = window.getSelection() as Selection;
      for (let i = 0; i < selObj.rangeCount; i++) {
        const range = selObj.getRangeAt(i);
        const left = getTotalOffset(range.startContainer, range.startOffset);
        if (left != null) {
          const right = getTotalOffset(range.endContainer, range.endOffset)
          if (right != null) {
            sels.push([left, right]);
          }
        }
      }

      sels.sort(([l,r], [l2,r2]) => (l < l2 ? -1 : (l === l2 ? 0 : 1)));
      return [sels, text_lines.join("\n")];
    }

    scrollIfNecessary() {
      // scroll so that the node with 'node-in-view' class, if it exists
      // is in view, if necessary
      const container = this.getContainerNode();
      const node = $(container).find('.node-in-view').get(0);
      if (node) {
        // position() is relative to the contenteditable div
        const nodeTop = $(node).position().top;
        const nodeBot = nodeTop + $(node).height();

        const viewTop = $(container).scrollTop();
        const viewBot = viewTop + $(container).height();

        if ((nodeTop <= viewTop && !(nodeBot >= viewBot)) ||
          (nodeBot >= viewBot && !(nodeTop <= viewTop))) {
          // try to scroll so that the top is about 40% of the way down the
          // viewport.
          let desired_y = (viewBot - viewTop) * 0.4
          // if it's a really big one that would get cut off, move up
          if (desired_y + (nodeBot - nodeTop) > (viewBot - viewTop)) {
            desired_y = (viewBot - viewTop) - (nodeBot - nodeTop);
          }
          // now if it's too high, settle on 0
          if (desired_y < 0) {
            desired_y = 0;
          }

          $(container).scrollTop(nodeTop - desired_y);
        }
      }
    }
  }
  return EditableTextField;
}

function get_text_nodes(el: Node) {
  const ans: Text[] = [];
  const recurse = function(e: Node) {
    if (e.nodeType === 1) {
      for (let j = 0; j < e.childNodes.length; j++) {
        const node = e.childNodes[j];
        recurse(node);
      }
    } else if (e.nodeType === 3) {
      ans.push(e as Text);
    }
  };
  recurse(el);
  return ans;
}

function getOpForTextChange(old_sel: Range[], old_text: string, new_sel: Range[], new_text: string) {
  const skip = OtText.skip;
  const take = OtText.take;
  const insert = OtText.insert;

  if (old_sel.length === 0 && new_sel.length === 0 && old_text === new_text) {
    // return an identity op:
    return [take(new_text.length)];
  }

  Utils.assert(old_sel.length >= 1);
  Utils.assert(new_sel.length === 1);

  const op_delete_selected = [take(old_sel[0][0])];
  let length_after_delete = old_text.length;
  for (let i = 0; i < old_sel.length; i++) {
    op_delete_selected.push(skip(old_sel[i][1] - old_sel[i][0]));
    op_delete_selected.push(take((i === old_sel.length - 1 ? old_text.length : old_sel[i + 1][0]) - old_sel[i][1]));
    length_after_delete -= old_sel[i][1] - old_sel[i][0];
  }

  const [l, r] = new_sel[0];

  let op2;
  if (r > l) {
    Utils.assert(new_text.length - (r - l) === length_after_delete);
    op2 = [take(l), insert(new_text.slice(l, r)), take(new_text.length - r)];
  } else {
    const prefix_pre = old_sel[0][0];
    const suffix_pre = length_after_delete - prefix_pre;
    const prefix_post = l;
    const suffix_post = new_text.length - l;
    if (prefix_pre === prefix_post) {
      if (suffix_post > suffix_pre) {
        op2 = [take(prefix_pre), insert(new_text.slice(prefix_pre, prefix_pre + suffix_post - suffix_pre)), take(suffix_pre)];
      } else {
        op2 = [take(prefix_pre), skip(suffix_pre - suffix_post), take(suffix_post)];
      }
    } else if (suffix_pre === suffix_post) {
      if (prefix_post > prefix_pre) {
        op2 = [take(prefix_pre), insert(new_text.slice(prefix_pre, prefix_post)), take(suffix_pre)];
      } else {
        op2 = [take(prefix_post), skip(prefix_pre - prefix_post), take(suffix_pre)];
      }
    } else {
      throw new Error("Does not match up on either side");
    }
  }

  return OtText.composeText(old_text, OtText.canonicalized(op_delete_selected), OtText.canonicalized(op2));
}

// Like `getOpForTextChange`, but it never fails
function getOpForTextChange2(old_text: string, new_text: string) {
  let prefix = 0;
  while (prefix < old_text.length && prefix < new_text.length && old_text.charAt(prefix) === new_text.charAt(prefix)) {
    prefix++;
  }

  let suffix = 0;
  while (suffix < old_text.length - prefix && suffix < new_text.length - prefix && old_text.charAt(old_text.length - suffix - 1) === new_text.charAt(new_text.length - suffix - 1)) {
    suffix++;
  }

  return OtText.canonicalized([OtText.take(prefix), OtText.skip(old_text.length - prefix - suffix), OtText.insert(new_text.substring(prefix, new_text.length - suffix)), OtText.take(suffix)]);
}
