lacrosse-town
============

Real-time collaborative editor for solving crosswords.
Intended for use in, say, puzzle hunts where multiple people are pouring
over the same crossword puzzle.

Setting up a development instance
============

You need a postgres server. Put the postgres credentials in `config/development.json`.
(See `config/development-template.json` for an example.)

Run `npm install` to install packages.

Run `grunt browserify` to bundle all the clientside source files into `src/static/bundle.js`.
You can also run `grunt watch` to continuously watch the source files.

Finally, run `./run-server-dev.sh` to run the server. It uses `nodemon`, so the server
will reload automatically when source files change.

Deploying to heroku
============

    heroku create

Set up a heroku database:

    heroku addons:add heroku-postgresql:hobby-dev

Use `heroku config -s | grep HEROKU_POSTGRESQL` to get the name of the database, then:

    heroku pg:promote HEROKU_POSTGRESQL_OLIVE

Finally, deploy:

    git push heroku master
