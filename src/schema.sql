CREATE TABLE puzzles (
	puzzleID VARCHAR(128) PRIMARY KEY,

	latest INTEGER NOT NULL
);

CREATE TABLE states (
	id SERIAL PRIMARY KEY,

	puzzleID VARCHAR(128) NOT NULL,
	seq      INTEGER      NOT NULL,
	state    JSON         NOT NULL,

	opID     VARCHAR(128),
	op       JSON
);
CREATE INDEX states_puzzleid_seq_index ON states (puzzleID, seq);
CREATE INDEX states_puzzleid_opid_index ON states (puzzleID, opID);
