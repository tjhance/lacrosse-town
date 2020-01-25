/*
React component representing the dialog to find matching words.

Makes an AJAX call to /find-matches

props:
    clueTitle - e.g. "2 Across"
    clueText
    pattern - e.g. "b..t"
    onSelect - callback that takes a single word argument, an array of characters
               whose length matches the number of periods in the input pattern
    onClose - callback for when the user tries to close the dialog
*/

import * as Utils from '../shared/utils';

import * as React from 'react';
import * as ReactDom from 'react-dom';
declare var $: any;

type Props = {
  pattern: string,
  clueTitle: string,
  clueText: string,
  onClose: () => void,
  onSelect: (s:string) => void,
};

type State = {
  matchList: string[] | null,
  error: string | null,
};

export class FindMatchesDialog extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = this.defaultState();
  }

  defaultState() {
    return {
      matchList: null,
      error: null,
    };
  }

  componentWillReceiveProps(newProps: Props) {
    if (newProps.pattern !== this.props.pattern) {
      this.setState(this.defaultState());
    }
  }

  componentDidMount() {
    this.doAjax();
  }

  componentDidUpdate() {
    if (!this.state.matchList && !this.state.error) {
      this.doAjax();
    }
  }

  doAjax() {
    // Make the ajax request
    $.ajax({
      type: 'POST',
      url: '/find-matches/',
      data: {
          pattern: this.props.pattern,
      },
      dataType: 'json',
      success: (data:any) => {
        this.setState({ matchList: data.matches.map((m:string) => m.toUpperCase()) });
      },
      error: (jqXHR:any, textStatus:any, errorThrown:any) => {
        this.setState({ error: "error: " + textStatus });
      },
    });
  }

  render() {
    return (
      <div className="find-matches-container">
          <div className="find-matches-text">Searching for matches of pattern</div>
          <div className="find-matches-pattern">{this.renderPattern()}</div>
          <div className="find-matches-text">for clue</div>
          <div className="find-matches-clue">
              <strong>{this.props.clueTitle}.</strong>
              <span style={{'whiteSpace': 'pre'}}>{"\xA0" + this.props.clueText}</span>
          </div>
          <div className="find-matches-text">(Using UKACD dictionary)</div>
          <div className="find-matches-result">
              {this.renderResults()}
          </div>
          <div className="find-matches-close-button">
              <input type="button" className="lt-button" value="Close" onClick={this.props.onClose} />
          </div>
      </div>
    );
  }

  renderPattern() {
    const pattern = this.props.pattern.toUpperCase();
    const res = [];
    for (let i = 0; i < pattern.length; i++) {
      const c = pattern.charAt(i);
      if (c === ".") {
        res.push(<span key={"pattern-blank-" + i} className="find-matches-pattern-blank">{"\xA0"}</span>);
      } else {
        res.push(<span key={"pattern-blank-" + i} className="find-matches-pattern-blank">{c}</span>);
      }
    }
    return res;
  }

  renderResults() {
    if (this.state.matchList) {
      return (
        <div>
            <SelectList matches={this.state.matchList}
                    onSelect={(index, value) => this.props.onSelect(value)}
                    onClose={() => this.props.onClose()} />
        </div>
      );
    } else if (this.state.error) {
      return (
        <div style={{'color': 'red'}}>
            {this.state.error}
        </div>
      );
    } else {
      return (
        <div>
            Loading...
        </div>
      );
    }
  }
}

type SelectListProps = {
  matches: string[],
  onSelect: (n:number, s:string) => void,
  onClose: () => void,
};

type SelectListState = {
  mousedOver: boolean,
};

// A menu for selecting an option
// props:
//    options: a list of string options
//    onSelect: a callback taking arguments (index, value)
class SelectList extends React.Component<SelectListProps, SelectListState> {
  componentDidMount() {
    this.focusIndex(0);
  }

  coerceIndex(index: number) {
    if (index < 0) {
      return 0;
    } else if (index >= this.props.matches.length) {
      return this.props.matches.length - 1;
    } else {
      return index;
    }
  }

  focusIndex(index: number) {
    const ref = this.refs['option-' + index];
    if (ref) {
      const anode = ReactDom.findDOMNode(ref) as HTMLAnchorElement; // the 'a' node
      anode.focus();
    }
  }

  goUp(index: number) {
    this.focusIndex(this.coerceIndex(index - 1));
  }

  goDown(index: number) {
    this.focusIndex(this.coerceIndex(index + 1));
  }

  enter(index: number) {
    if (0 <= index && index < this.props.matches.length) {
      this.props.onSelect(index, this.props.matches[index]);
    }
  }

  onKeyDown(event: any, i: number) {
    if (event.which === 38) {
      this.goUp(i);
      event.preventDefault();
      event.stopPropagation();
    } else if (event.which === 40) {
      this.goDown(i);
      event.preventDefault();
      event.stopPropagation();
    } else if (event.which === 13) {
      this.enter(i);
      event.preventDefault();
      event.stopPropagation();
    } else if (event.which === 27) { // escape
      this.props.onClose();
    }
  }

  onClick(event: any, i: number) {
    this.enter(i);
    // even with this, we still fail to restore focus to the grid when closing
    // ... why?
    event.preventDefault();
    event.stopPropagation();
  }

  render() {
    return (
      <div 
        //TODO was this supposed to be enabled?
        //className="dont-bubble-keydown"
        className="lt-select-list"
              onMouseEnter={() => this.setState({mousedOver: true})}
              onMouseLeave={() => this.setState({mousedOver: false})} >
          { Utils.makeArray(this.props.matches.length, (i) => {
              return (
                <a href="#" style={{'display': 'block'}}
                        onKeyDown={(event: any) => this.onKeyDown(event, i)}
                        className={"lt-select-list-option"}
                        onClick={(event) => this.onClick(event, i)}
                        ref={"option-"+i}
                        key={"option-"+i}>
                    {this.props.matches[i]}
                </a>
              );
            })
          }
      </div>
    );
  }
}
