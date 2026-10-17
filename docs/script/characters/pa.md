# WARDEN (PA tapes): your lines

WARDEN's pre-recorded PA tapes: the building computer's canned announcements, played over the ceiling speakers on a loop. Same character as WARDEN, in its bright recorded register; WARDEN's live voice is the flat one.

**How they sound:** A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/pa/` in the game.

## Your lines (3)

Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.

### 1. At the building's front doors as the IT crew arrives.

- [ ] `l0_pa_1.wav`  
  "Good evening! Halcyon Data Systems is now closed."  
  *Over the lobby PA. Pleasant, like a store closing announcement.*
- [ ] `l0_pa_2.wav`  
  "Visitors must remain with their escort at all times. Thank you for your cooperation!"  
  *Same announcement, continuing.*

### 2. At the front desk while the crew pieces a shredded memo back together on a terminal.

- [ ] `l0_sort_hint.wav`  
  "Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon!"  
  *From the ceiling speakers. A canned reminder that plays every hour. Proud of the company, unaware of anyone listening.*
