Canteen
=======

Unattanded voting system for canteens.

Development
-----------

Get perl, Mojolicious, Digest::SHA, DBI and DBD::SQLite installed.

To create the database:

    sqlite3 main.db < schema.sql

To run development server:

    morbo main.pl
