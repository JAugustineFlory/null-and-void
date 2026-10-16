-- Level 0: The Lobby. Front desk terminal data.

CREATE TABLE memo_fragments (
	piece_no INTEGER,
	text TEXT,
	scanned_at TEXT
);
INSERT INTO memo_fragments VALUES
	(4, 'The night logs are being rewritten after midnight.', '1997-10-12 02:14'),
	(1, 'If you are reading this, WARDEN has already locked me out.', '1997-10-12 02:11'),
	(7, '-- I.V.', '1997-10-12 02:16'),
	(3, 'He is running Project LUMEN off the books.', '1997-10-12 02:13'),
	(6, 'I hid copies where WARDEN cannot look. Mercer knew where.', '1997-10-12 02:15'),
	(2, 'The director knows I found out.', '1997-10-12 02:12'),
	(5, 'Do not trust anyone who offers to escort you.', '1997-10-12 02:15');

CREATE TABLE visitors (
	id INTEGER,
	name TEXT,
	company TEXT,
	escort TEXT,
	checked_in TEXT
);
INSERT INTO visitors VALUES
	(311, 'Contract IT crew', 'Byte-Right IT Services', 'ROURKE, D.', '1997-10-15 23:02'),
	(310, 'P. Okafor', 'Delmont Courier', 'NONE', '1997-10-15 16:40'),
	(309, 'Board delegation', 'Halcyon Board', 'DIRECTOR', '1997-10-13 09:00');

CREATE TABLE staff_directory (
	name TEXT,
	title TEXT,
	extension INTEGER,
	status TEXT
);
INSERT INTO staff_directory VALUES
	('Iris Vale', 'Lead Engineer', 4471, 'MISSING'),
	('Dale Rourke', 'Facilities Manager', 2210, 'ON SHIFT'),
	('Harlan Pike', 'Night Security', 1102, 'NO SHOW'),
	('Office of the Director', 'Director', 1000, 'OFFSITE');

-- doors is building-wide (FacilityDB.SHARED_SCHEMA); the lobby only adds its own LOBBY- rows.
INSERT INTO doors VALUES
	('LOBBY-FRONT', 'Main entrance', 'L', 1, 0);
