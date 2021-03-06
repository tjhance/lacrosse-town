// Initialize everything.

import * as log4js from 'log4js';
import * as async from 'async';
import * as fs from 'fs';

import * as find_matches from './find_matches';
import * as db from './db';
import * as http_server from './http_server';

//log4js.replaceConsole();
const logger = log4js.getLogger('console');
console.log = logger.info.bind(logger);
console.debug = logger.debug.bind(logger);
console.error = logger.error.bind(logger);
console.info = logger.error.bind(logger);

// Read the config file from the command-line argument
if (process.argv.length !== 3) {
  console.log("Expected: one argument, config filename (e.g. 'config/development.json')");
  process.exit(1);
}
const configFilename = process.argv[2];
const config = JSON.parse(fs.readFileSync(configFilename).toString('utf8'));

async.waterfall([
  (callback:any) => {
    find_matches.init(() => {
      console.info('Loaded dictionaries');
      callback();
    });
  },

  (callback:any) => {
    db.init(config, () => {
      console.info('Initialized database');
      callback();
    });
  },

  (callback:any) => {
    http_server.init(config, () => {
      callback();
    });
  },
  
  () => null,
]);
