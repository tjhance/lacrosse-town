/* @flow */

// Find matches for a given string

import * as fs from 'fs';

let words = null;

export function init(callback: () => void) {
  const simplify = function(word) {
    // TODO should strip other characters like spaces
    return word.toLowerCase();
  };

  return fs.readFile('dictionaries/UKACD-normalized.txt', 'utf8', function(err, data) {
    if (err) {
      console.error(err);
    } else {
      // the licensing information of the dictionary is above this line
      // so we cut it off
      const spl = data.split('--------------------------------------------------------------------\n');
      if (spl.length !== 2) {
        console.error('error parsing dictionary');
      } else {
        const data = spl[1];

        // now 'data' is just a newline-separated list of words
        words = data.split('\n').filter((word) => word != '').map((word) => simplify(word));

				callback();
      }
    }
  });
}

// pattern should be a mix of lower-case letters and periods
function findMatches(pattern: string) {
  if (!words) {
    throw new Error("words is not initialized");
  }
  const regex = new RegExp('^' + pattern + '$');
  const result = [];
  for (let j = 0; j < words.length; j++) {
    const word = words[j];
    if (word.match(regex)) {
      result.push(word);
    }
  }
  return result;
}

function validatePattern(pattern: string): boolean {
  if (typeof pattern !== 'string') {
    return false;
  }
  if (!(pattern.length > 0 && pattern.length < 200)) {
    return false;
  }
  for (let i = 0; i < pattern.length; i++) {
    const c = pattern.charAt(i);
    if (!(c === '.' || (c >= 'a' && c <= 'z'))) {
      return false;
    }
  }
  return true;
}

// HTTP request handler for /find-matches
// Takes 'pattern' as a query param. 'pattern' is a pattern like '..a...'
// Returns a JSON object
// {
//    matches: [ ... all matches ... ]
// }
export function handle(req: any, res: any) {
  const pattern = req.body['pattern'];
  if (!validatePattern(pattern)) {
    res.statusCode = 400;
    res.send('invalid pattern');
    return;
  }
  res.send({
    matches: findMatches(pattern)
  });
}
