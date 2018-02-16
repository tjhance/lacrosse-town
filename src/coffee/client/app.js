/* @flow */

// This file has routing and some basic high-level setup and a few
// event handlers with no better home.
// Routes are
//   /new - Static page
//   /puzzle - Page where you view and edit a puzzle.
//             Controller is in puzzle.coffee

// TODO could use some lightweight routing framework?

import {NewPage} from './new';
import ClientSyncer from './state';
import PuzzlePage from './puzzle';
import * as KeyboardUtils from './keyboard_utils';

import React from 'react';
import ReactDom from 'react-dom';

declare var $;

function initApp() {
  const pathname = window.location.pathname;
  const parts = pathname.split('/');
  if (pathname === '/new' || pathname === '/' || pathname === '') {
    const el = <NewPage />;
    const container = $('.view-container').get(0);
    ReactDom.render(el, container);
  } else if (parts[1] === 'puzzle') {
    initPuzzleSyncer(parts[2], window.PAGE_DATA);
  }
}

// TODO This should get its own file
function initPuzzleSyncer(puzzleID, initialData) {
  const syncer = new ClientSyncer(puzzleID, initialData);
  syncer.addWatcher((newState, op, cursors) => {
    if (op) {
      p.applyOpToPuzzleState(op);
    }
    if (cursors) {
      p.setCursors(cursors);
    }
  });
  syncer.loadInitialData(initialData);

  const requestOp = (op, cursor) => {
    syncer.localOp(op, cursor);
  };

  const onToggleOffline = (val) => {
    syncer.setOffline(val)
  };

  // $FlowFixMe
  document.body.addEventListener('keydown', ((event) => {
    if ((! $(event.target).hasClass('dont-bubble-keydown')) &&
           $(event.target).closest('.dont-bubble-keydown').length == 0) {
      p.handleKeyPress(event);
    }
   }), false)

  // $FlowFixMe
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

  // $FlowFixMe
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

  // $FlowFixMe
	document.body.addEventListener('focus', (function(event) {
		var node;
		node = p.gridNode();
		if (node !== document.body && !(event.target === node || $.contains(node, event.target))) {
			return setTimeout((function() {
				return p.blur();
			}), 0);
		}
	}), true);

  // $FlowFixMe
	document.body.addEventListener('copy', (function(event) {
		if ((!$(event.target).hasClass('dont-bubble-keydown')) && $(event.target).closest('.dont-bubble-keydown').length === 0) {
			return p.doCopy(event);
		}
	}), true);

  // $FlowFixMe
	document.body.addEventListener('cut', (function(event) {
		if ((!$(event.target).hasClass('dont-bubble-keydown')) && $(event.target).closest('.dont-bubble-keydown').length === 0) {
			return p.doCut(event);
		}
	}), true);

  // $FlowFixMe
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
  const p = ReactDom.render(el, container);

  p.setPuzzleState(initialData.puzzle);
}

window.initApp = initApp;
