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

-- staff_directory, visitors and lights are seeded per run (Level0Data).

-- doors is building-wide (FacilityDB.SHARED_SCHEMA); the lobby only adds its own LOBBY- rows.
INSERT INTO doors VALUES
	('LOBBY-FRONT', 'Main entrance, ground floor', 'L', 1, 0);
