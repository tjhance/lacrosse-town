lacrosse-town
============

Real-time collaborative editor for solving crosswords

Deploying to heroku
============
    heroku create
Set up a heroku database:
	heroku addons:add heroku-postgresql:hobby-dev
Use `heroku config -s | grep HEROKU_POSTGRESQL` to get the name of the database, then
	heroku pg:promote HEROKU_POSTGRESQL_OLIVE
Finally, deploy
    git push heroku master
