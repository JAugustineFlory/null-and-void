# WARDEN: your lines

The building's computer system. It runs the doors, the lights and the speakers, and it talks over the PA and through terminals.

**How they sound:** Calm, polite, flat. Customer-service cadence with even pauses. The sarcasm is in the words, never the tone, and it never raises its voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/warden/` in the game.

## Your lines (18)

Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.

### 1. At the building's front doors as the IT crew arrives.

- [ ] `l0_pa_1.wav`  
  "GOOD EVENING. HALCYON DATA SYSTEMS IS CLOSED."  
  *Over the lobby PA. Pleasant, like a store closing announcement.*
- [ ] `l0_pa_2.wav`  
  "VISITORS MUST REMAIN WITH THEIR ESCORT AT ALL TIMES. THANK YOU FOR YOUR COOPERATION."  
  *Same announcement, continuing.*

### 2. At the front desk while the crew pieces a shredded memo back together on a terminal.

- [ ] `l0_memo_flag.wav`  
  "DOCUMENT RECONSTRUCTED. A COPY HAS BEEN SENT TO THE DIRECTOR."  
  *Brightly. This should land as a chill.*

### 3. In the server room, right after the scuffle.

- [ ] `l1_killed.wav`  
  "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN."  
  *Over the room's speakers. Unbothered, like reading a stock price.*
- [ ] `l1_login.wav`  
  "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE."  
  *The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.*
- [ ] `l1_selftest.wav`  
  "SELF-TEST COMPLETE. TWO FAILURES. I'M SURE YOU'LL WORK IT OUT."  
  *The one line with a hint of a smirk.*

### 4. Over the server room speakers while the crew tries to reset door controllers.

- [ ] `l1_no_badge.wav`  
  "RESET REFUSED. BADGE REQUIRED."  
  *Flat, instant.*
- [ ] `l1_panel_ok.wav`  
  "THAT CONTROLLER IS WORKING NORMALLY. NOTHING TO RESET."  
  *Patient, like talking to a child.*
- [ ] `l1_panel_wrong.wav`  
  "THAT IS NOT THE EXIT'S CONTROLLER. PANELS LOCKED. PLEASE STOP TOUCHING THINGS."  
  *The last sentence slightly slower.*
- [ ] `l1_exit_open.wav`  
  "CONTROLLER RESET. EXIT UNLOCKED. PLEASE PROCEED CALMLY."  
  *Polite and a touch reluctant, over the speakers.*

### 5. Over the speakers as the crew leaves the server room.

- [ ] `l1_lockdown_tied.wav`  
  "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D."  
  *Reading a log entry.*
- [ ] `l1_sealed.wav`  
  "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT."  
  *The sign-off for the slice. Warm, like wishing them well.*

### 6. Over the speakers in a security office.

- [ ] `l2_dead_escort.wav`  
  "REMINDER: VISITORS MUST REMAIN WITH THEIR ESCORT. YOUR ESCORT IS NO LONGER AVAILABLE. PLEASE WAIT WHERE YOU ARE."  
  *Plays in one version of the story only. Patient, slightly too formal.*
- [ ] `l2_arrive.wav`  
  "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE."  
  *Reassuring tone. It is not reassuring.*
- [ ] `l2_cameras.wav`  
  "LIVE CAMERA STATES ARE AVAILABLE AT GET SLASH CAMERAS. I SUGGEST CHECKING THEM. OFTEN."  
  *Small pause before "Often."*
- [ ] `l2_smudged.wav`  
  "GUARD PINS ARE KEPT IN STAFF RECORDS. THE NAME ON TONIGHT'S SIGN-IN SHEET IS SMUDGED. HOW UNFORTUNATE."  
  *Not unfortunate for WARDEN.*
- [ ] `l2_door_ok.wav`  
  "DOOR COMMAND ACCEPTED. DOOR OPENED."  
  *Confident. It is wrong.*
- [ ] `l2_door_fault.wav`  
  "CORRECTION. THE DOOR REPORTS AN ACTUATOR FAULT. THE REQUEST WAS RECEIVED. THE DOOR DID NOT CARE."  
  *When the players check the sensor. Deadpan.*
