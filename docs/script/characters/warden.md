# WARDEN: your lines

The building's computer system. It runs the doors, the lights and the speakers, and it talks over the PA and through terminals.

**How they sound:** Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/warden/` in the game.

## Your lines (26)

Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.

### 1. In the lab, right after the scuffle.

- [ ] `l2_killed.wav`  
  "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN."  
  *Over the room's speakers. Unbothered, like reading a stock price.*

### 2. Over the lab's speakers, the first time the building's computer speaks for itself. Its own recorded announcement cuts it off.

- [ ] `l2_contain_1.wav`  
  "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW--"  
  *Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off.*
- [ ] `l2_contain_2.wav`  
  "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE."  
  *From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later.*

### 3. Over the speakers while the crew tries to reset door controllers to get out of a locked lab.

- [ ] `l2_login.wav`  
  "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE."  
  *The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.*
- [ ] `l2_selftest.wav`  
  "SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM."  
  *The one line with a hint of a smirk.*
- [ ] `l2_found.wav`  
  "QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY."  
  *Reading a rule it knows they're about to break. Cool.*
- [ ] `l2_no_badge.wav`  
  "RESET REFUSED. BADGE REQUIRED."  
  *Flat, instant.*
- [ ] `l2_panel_ok.wav`  
  "RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?"  
  *Patient, then a small dig.*
- [ ] `l2_panel_wrong.wav`  
  "UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS."  
  *The last sentence slightly slower.*
- [ ] `l2_exit_open.wav`  
  "CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED."  
  *Polite, and keeping score.*

### 4. Over the speakers as the crew leaves the lab.

- [ ] `l2_lockdown_tied.wav`  
  "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D."  
  *Reading a log entry.*
- [ ] `l2_sealed.wav`  
  "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT."  
  *The sign-off for the slice. Warm, like wishing them well.*

### 5. Over the speakers in a security office.

- [ ] `l2_arrive.wav`  
  "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE."  
  *Reassuring tone. It is not reassuring.*
- [ ] `l2_cameras.wav`  
  "CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF."  
  *Small pause before the second sentence.*
- [ ] `l2_smudged.wav`  
  "TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU."  
  *Not unfortunate for WARDEN.*
- [ ] `l2_door_ok.wav`  
  "DOOR COMMAND ACCEPTED. DOOR OPENED."  
  *Confident. It is wrong.*
- [ ] `l2_door_fault.wav`  
  "ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING."  
  *When the crew finds the fault themselves. Deadpan, unapologetic.*

### 6. Over every speaker in the building: the building's computer announces a full lockdown. Then, every few minutes, a reminder.

- [ ] `l4_epsilon_1.wav`  
  "CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT."  
  *Flat and slow. A short pause after.*
- [ ] `l4_epsilon_2.wav`  
  "ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE."  
  *Even pauses between sentences, like reading a checklist.*
- [ ] `l4_epsilon_db.wav`  
  "DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY."  
  *Same checklist reading. 'Authorized services only' is just policy, not a hint.*
- [ ] `l4_epsilon_3.wav`  
  "ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL."  
  *No change in tone for 'not a drill'. That's the frightening part.*
- [ ] `l4_epsilon_loop.wav`  
  "REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE."  
  *Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only.*
- [ ] `l4_epsilon_loop_2.wav`  
  "REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE."  
  *Takes turns with the other reminder. Same polite loop.*

### 7. Someone types a change into a terminal during the lockdown. The building's computer answers over the speakers and on the screen.

- [ ] `l4_write_refused.wav`  
  "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON."  
  *The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal.*
- [ ] `l4_write_refused_tease.wav`  
  "YOU MAY STILL LOOK. LOOKING IS FREE."  
  *A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud.*
- [ ] `l4_write_refused_again.wav`  
  "STILL READ-ONLY."  
  *Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat.*
