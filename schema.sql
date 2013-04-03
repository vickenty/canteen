CREATE TABLE menu (date date, position int, name text);
CREATE TABLE votes (date date, position int, vote int, user text, timestamp timestamp default current_timestamp not null);
CREATE UNIQUE INDEX date_position on menu (date, position);
