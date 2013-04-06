CREATE TABLE menu (date date, position int, name text);
CREATE TABLE users (email text, password text, created_at date, last_login_at date, last_login_ip text, active bool default 1 not null);
CREATE TABLE votes (date date, position int, vote int, user text, timestamp timestamp default current_timestamp not null);
CREATE UNIQUE INDEX date_position on menu (date, position);
CREATE UNIQUE INDEX email on users (email);
