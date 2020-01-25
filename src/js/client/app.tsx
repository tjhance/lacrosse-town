// This file has routing and some basic high-level setup and a few
// event handlers with no better home.
// Routes are
//   /new - Static page
//   /puzzle - Page where you view and edit a puzzle.
//             Controller is in puzzle.js

// TODO could use some lightweight routing framework?

import {NewPage} from './new';
import {ClientSyncer} from './state';
import {PuzzlePage} from './puzzle';
import * as KeyboardUtils from './keyboard_utils';

import * as React from 'react';
import * as ReactDom from 'react-dom';

declare var $: any;

function initApp() {
  const pathname = window.location.pathname;
  const parts = pathname.split('/');
  if (pathname === '/new' || pathname === '/' || pathname === '') {
    const el = <NewPage />;
    const container = $('.view-container').get(0);
    ReactDom.render(el, container);
  } else if (parts[1] === 'puzzle') {
    initPuzzleSyncer(parts[2], (window as any).PAGE_DATA);
  }
}

// TODO This should get its own file
function initPuzzleSyncer(puzzleID: string, initialData: any) {
  const syncer = new ClientSyncer(puzzleID, initialData);
  syncer.addWatcher((newState, op, cursors) => {
    if (op) {
      p.applyOpToPuzzleState(op);
    }
    if (cursors) {
      p.setCursors(cursors);
    }
  });

  const requestOp = (op: any, cursor: any) => {
    syncer.localOp(op, cursor);
  };

  const onToggleOffline = (val: boolean) => {
    syncer.setOffline(val)
  };

  document.body.addEventListener('keydown', ((event) => {
    if ((! $(event.target).hasClass('dont-bubble-keydown')) &&
           $(event.target).closest('.dont-bubble-keydown').length == 0) {
      p.handleKeyPress(event);
    }
   }), false)

	document.body.addEventListener('keydown', (function(event) {
		var meta;
		meta = (KeyboardUtils.usesCmd() ? event.metaKey : event.ctrlKey);
		if (event.which === 90) { // Z
			if (meta && event.shiftKey) {
				syncer.redo();
				return event.preventDefault();
			} else if (meta) {
				syncer.undo();
				return event.preventDefault();
			}
		}
	}), true);

	document.body.addEventListener('click', (function(event) {
		var node;
		node = p.gridNode();
		if (!(event.target === node || $.contains(node, event.target))) {
			// This is in a timeout, because right now, the thing being
			// focused hasn't focused yet and running things now in between
			// could cause problems.
			return setTimeout((function() {
				return p.blur();
			}), 0);
		}
	}), true);

	document.body.addEventListener('focus', (function(event) {
		var node;
		node = p.gridNode();
		if (node !== document.body && !(event.target === node || $.contains(node, event.target))) {
			return setTimeout((function() {
				return p.blur();
			}), 0);
		}
	}), true);

	document.body.addEventListener('copy', (function(event) {
		if ((!$(event.target).hasClass('dont-bubble-keydown')) && $(event.target).closest('.dont-bubble-keydown').length === 0) {
			return p.doCopy(event);
		}
	}), true);

	document.body.addEventListener('cut', (function(event) {
		if ((!$(event.target).hasClass('dont-bubble-keydown')) && $(event.target).closest('.dont-bubble-keydown').length === 0) {
			return p.doCut(event);
		}
	}), true);

	document.body.addEventListener('paste', (function(event) {
		if ((!$(event.target).hasClass('dont-bubble-keydown')) && $(event.target).closest('.dont-bubble-keydown').length === 0) {
			return p.doPaste(event);
		}
	}), true);

  const el = <PuzzlePage
      requestOp={requestOp}
      onToggleOffline={onToggleOffline}
   />;
  const container = $('.view-container').get(0);
  const p: any = ReactDom.render(el, container);

  p.setPuzzleState(initialData.puzzle);
}

(window as any).initApp = initApp;
