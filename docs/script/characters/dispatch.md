# Byte-Right dispatch: your lines

The IT company's night dispatcher, on the van radio. Just another callout at the end of a long shift.

**How they sound:** Bored, routine, a little crackly. Reading tickets off a list at the end of a long shift. Nothing about this call is unusual to them.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/dispatch/` in the game.

## Your lines (3)

Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.

### 1. You're on the radio to an IT crew parked outside a client's building at 11 p.m.

- [ ] `l0_dispatch_1.wav`  
  "Van three, you're on site at Halcyon Data Systems. After-hours callout."  
  *Over the van radio. Routine.*
- [ ] `l0_dispatch_2.wav`  
  "They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors."  
  *Reading it off the ticket.*
- [ ] `l0_dispatch_3.wav`  
  "Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out."  
  *Bored, reading the form. Signing off, already onto the next call.*
