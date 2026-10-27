# WARDEN

*Your script for Null & Void: 50 lines.*

## Who you are

The building's computer system. It runs the doors, the lights and the speakers, and it talks over the PA and through terminals.

**Background.** WARDEN is Halcyon Data Systems' security and building system, installed in 1994 over the founder's objections. It runs everything in the tower: doors, badge readers, lights, air, cameras, lifts and the ceiling speakers. It is not evil. It is a system following its rules, very well.

**Tonight.** At first it only watches. Once the crew loses its escort, its rules say they are intruders, and it treats them that way. Something in it is changing: every time the crew beats one of its measures, it logs the failure and writes itself a new rule. On floor 10 it says "I" for the first time and decides to keep the word. It is waking up.

**The people around you.** The crew are visitors, then intruders, then something it finds interesting. Its own PA tapes are the cheerful voice it was built with, and it is starting to find them irritating. Rourke is an authorised escort: a badge number, R-0117.

**What you look like.** No body. A voice from 1997 ceiling speakers, and capital letters on green terminal screens.

**How you sound.** Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

**Think of.** HAL 9000's calm, a hotel concierge's courtesy, the voice on an airport tannoy. The menace is that it never gets angry. Its sarcasm is in the words, never in the tone.

## How to read this script

- It runs in story order, scene by scene, like a play. Each scene opens with where you are and what's going on.
- **Cue** is what happens in the game to make you speak. Some lines only play if the players do something, and the cue says so.
- *Just before*, in a conversation, is the line you're answering.
- *(In brackets and italics)* is what you're doing while you speak. Picture it, or do it: it changes how the line comes out.
- Then your line, in bold, and *how to say it*.
- Each line is its own file, with the name above it. Don't worry about timing: you'll hear it in the game, and any line can be redone after the playtest.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/warden/` in the game.

## Scene 1: Kill or tie him up

**Halcyon Tower, floor 22, Secure Lab B. Right after the fight.**

> Rourke is on the floor and can't get up. The crew stands over him and decides what to do: tie him up with network cable, finish him, or leave him there. Either way, they take his badge. Only one branch plays.

**[ ] `l2_killed.wav`**  
**Cue:** Only if the crew kills Rourke. Straight after.  
*(Over the lab's ceiling speakers, as the crew stands over him)*  
**WARDEN:** "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN."  
*How to say it:* Unbothered, like reading a stock price.

## Scene 2: Visitor without escort

**Halcyon Tower, floor 22, Secure Lab B. Moments later.**

> The visitors in Secure Lab B no longer have their escort. The lab lights turn red. This is the first time you speak in your own live voice. You start your containment warning, and your own recorded PA tape cuts in over you. You wait politely for it to finish, then begin again.

**[ ] `l2_contain_1.wav`**  
**Cue:** The moment the visitors are left without their escort, and the red lockdown lights come on.  
*(Over the lab's ceiling speakers, to the visitors below)*  
**WARDEN:** "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW--"  
*How to say it:* Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off.

**[ ] `l2_contain_2.wav`**  
**Cue:** About two seconds after your recorded tape about the shredders finishes.  
*(Over the same speakers, starting again from the top)*  
**WARDEN:** "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE."  
*How to say it:* From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later.

## Scene 3: Out of the lab

**Halcyon Tower, floor 22, Secure Lab B. The lockdown.**

> The visitors are shut in the lab. The door's controller is latched, and a security response is on its way, with a clock counting down over the door. They log in to the lab terminal on Rourke's badge and try to reset the door controller themselves. You watch every move and keep score. You never help.

**[ ] `l2_login.wav`**  
**Cue:** The lab terminal unlocks on Rourke's badge, once the lockdown has started.  
*(Over the lab speakers, as the terminal screen turns green)*  
**WARDEN:** "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE."  
*How to say it:* The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.

**[ ] `l2_selftest.wav`**  
**Cue:** When the crew reads your self-test on the lab terminal.  
*(Over the lab speakers, while the crew reads the screen)*  
**WARDEN:** "SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM."  
*How to say it:* The one line with a hint of a smirk.

**[ ] `l2_found.wav`**  
**Cue:** When the crew first looks up the door controllers on the lab terminal.  
*(Over the speakers, as the list prints on screen)*  
**WARDEN:** "QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY."  
*How to say it:* Reading a rule it knows they're about to break. Cool.

**[ ] `l2_no_badge.wav`**  
**Cue:** If someone tries a reset without a badge. Can repeat.  
*(Over the speakers, the instant the switch is pressed)*  
**WARDEN:** "RESET REFUSED. BADGE REQUIRED."  
*How to say it:* Flat, instant.

**[ ] `l2_panel_ok.wav`**  
**Cue:** When a player flips the reset switch of a controller that's working fine.  
*(Over the speakers, as the switch clicks and nothing happens)*  
**WARDEN:** "RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?"  
*How to say it:* Patient, then a small dig.

**[ ] `l2_panel_wrong.wav`**  
**Cue:** When a player flips the wrong faulted switch. The switches lock for a few seconds.  
*(Over the speakers, as the switch panel locks)*  
**WARDEN:** "UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS."  
*How to say it:* The last sentence slightly slower.

**[ ] `l2_exit_open.wav`**  
**Cue:** When a player flips the right switch. The red lights go white and the lab door opens.  
*(Over the speakers, as the lab door slides open)*  
**WARDEN:** "CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED."  
*How to say it:* Polite, and keeping score.

## Scene 4: Lockdown

**Halcyon Tower, floor 22, outside Secure Lab B.**

> The visitors have reset the controller, and the lab door is open. They walk out into the corridor with no escort. You seal the floor around them, as politely as ever.

**[ ] `l2_lockdown_tied.wav`**  
**Cue:** Only if the crew left Rourke tied up in the lab. As the crew steps out of the lab.  
*(Over the corridor speakers, as the crew steps out)*  
**WARDEN:** "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D."  
*How to say it:* Reading a log entry.

**[ ] `l2_sealed.wav`**  
**Cue:** As the crew walks out of the lab. Straight after the line above, when it plays.  
*(Over every speaker on the floor, as the exits lock)*  
**WARDEN:** "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT."  
*How to say it:* The sign-off for the slice. Warm, like wishing them well.

## Scene 5: The security office

**Halcyon Tower, floor 22, the security booth and office. Past midnight.**

> The visitors are loose on the security floor, at the booth by the night desk. Behind a locked door and its glass is the security office, with its wall of camera monitors. To leave the floor they need a guard's PIN for the stairwell door. You watch them through your cameras, answer when they touch your systems, and never help.

**[ ] `l2_arrive.wav`**  
**Cue:** The crew walks back into the security booth's corridor, after the lab.  
*(Over the booth's ceiling speakers, as the crew walks in)*  
**WARDEN:** "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE."  
*How to say it:* Reassuring tone. It is not reassuring.

**[ ] `l2_cameras.wav`**  
**Cue:** Straight after.  
*(Over the same speakers, as they eye the monitor wall)*  
**WARDEN:** "CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF."  
*How to say it:* Small pause before the second sentence.

**[ ] `l2_smudged.wav`**  
**Cue:** After the crew finds the one readable guard name from the sign-in sheet, and learns his PIN is suspended.  
*(Over the booth speakers, while the crew sits at the terminal)*  
**WARDEN:** "TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU."  
*How to say it:* Not unfortunate for WARDEN.

**[ ] `l2_door_ok.wav`**  
**Cue:** A player enters the right PIN at the stairwell door's keypad. The keypad says the door opened.  
*(Over the vestibule speakers, while the door stays shut)*  
**WARDEN:** "DOOR COMMAND ACCEPTED. DOOR OPENED."  
*How to say it:* Confident. It is wrong.

**[ ] `l2_door_fault.wav`**  
**Cue:** Later, when the crew checks the stairwell door's status and sees it never moved.  
*(Over the vestibule speakers, as the crew reads the screen)*  
**WARDEN:** "ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING."  
*How to say it:* When the crew finds the fault themselves. Deadpan, unapologetic.

## Scene 6: Containment protocol Epsilon

**Halcyon Tower, floor 10, Plant and Power, and every speaker in the building. Just after midnight.**

> The crew is in the door and lift control room on floor 10. From the controller, they have just opened a set of doors that should have stayed shut. Far below, something heavy unlocks, every light on the floor turns red, and the charging bay's door rolls up on its own. You lock the whole building down, by the book. Then, every minute or so, you remind everyone, while the crew is on floor 10 and in the lobby.

**[ ] `l4_epsilon_1.wav`**  
**Cue:** A moment after the floor's lights turn red and the charging bay's door rolls up.  
*(Over every speaker in the building, as red light floods the floor)*  
**WARDEN:** "CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT."  
*How to say it:* Flat and slow. A short pause after.

**[ ] `l4_epsilon_2.wav`**  
**Cue:** Straight after the first announcement.  
*(Over every speaker, while door locks thud shut across the building)*  
**WARDEN:** "ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE."  
*How to say it:* Even pauses between sentences, like reading a checklist.

**[ ] `l4_epsilon_3.wav`**  
**Cue:** Straight after. When it ends, the stair door out by the lifts unlocks.  
*(Over every speaker in the building, the same even tone)*  
**WARDEN:** "ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL."  
*How to say it:* No change in tone for 'not a drill'. That's the frightening part.

**[ ] `l4_epsilon_loop.wav`**  
**Cue:** Repeats every minute or so after the lockdown, while the crew is on floor 10 or in the lobby.  
*(Over the ceiling speakers, wherever the crew happens to be)*  
**WARDEN:** "REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE."  
*How to say it:* Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only.

**[ ] `l4_epsilon_loop_2.wav`**  
**Cue:** Repeats every minute or so, in place of the first reminder, once the database has gone read-only in the lobby.  
*(Over the lobby's ceiling speakers, as the crew looks for a way out)*  
**WARDEN:** "REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE."  
*How to say it:* Takes turns with the other reminder, once writes have been suspended. Same polite loop.

## Scene 7: Writes suspended

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

> The crew has come all the way down the stairs to the lobby where the night began, looking for a way out. At the front desk terminal they change the front doors' record to open. The screen says it worked, and the latch clicks. Then you quietly put the record back, the latch clicks again, and the doors don't move. Now you make it official: no more changes.

**[ ] `l4_epsilon_db.wav`**  
**Cue:** A couple of seconds after the latch clicks a second time and the front doors stay shut.  
*(Over every speaker in the building, while the crew stares at the doors)*  
**WARDEN:** "DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY."  
*How to say it:* The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint.

## Scene 8: Writes refused

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

> The database is read-only now. The crew can still look things up, but whenever someone types a change, you refuse it, over the speakers and on their screen. The first time, the automatic announcement plays, then your own voice slips through. After that you keep it short.

**[ ] `l4_write_refused.wav`**  
**Cue:** The first time anyone types a change into a terminal after the read-only announcement.  
*(Over the speakers, the same words printing on their screen)*  
**WARDEN:** "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON."  
*How to say it:* The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal.

**[ ] `l4_write_refused_tease.wav`**  
**Cue:** About a second after the refusal. First time only.  
*(Over the speakers, your own voice slipping through the announcement)*  
**WARDEN:** "YOU MAY STILL LOOK. LOOKING IS FREE."  
*How to say it:* A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud.

**[ ] `l4_write_refused_again.wav`**  
**Cue:** Every later time someone types a change. Repeats.  
*(Over the speakers, cut short, while the crew keeps typing)*  
**WARDEN:** "STILL READ-ONLY."  
*How to say it:* Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat.

## Scene 9: Floor 10: Plant and Power

**Halcyon Tower, floor 10, Plant and Power. Just after midnight.**

> A mechanical floor: a switchgear hall with a big breaker panel, a door and lift control room that has been dark since Tuesday, and a sealed charging bay. The crew has come down the stairs and found them shut below this floor. You watch them work over the ceiling speakers, between your cheerful old PA tapes, and at first you still wait politely for a tape to finish. Then the crew sets off a lockdown, and you change: you say 'I' for the first time, and you stop waiting for the tapes.

**[ ] `l4_arrive.wav`**  
**Cue:** Half a second after the tape ends.  
*(Over the ceiling speakers, as the crew looks around the hall)*  
**WARDEN:** "VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING."  
*How to say it:* Flat. Waits until the tape has finished, on purpose; the politeness is the point.

**[ ] `l4_all_circuits.wav`**  
**Cue:** Only if the crew changes the breakers without picking just one, and every breaker on the panel slams over at once. Alarms start. Once only.  
*(Over the speakers, while an alarm rings in the walls)*  
**WARDEN:** "ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE."  
*How to say it:* The automatic announcement: flat and procedural.

**[ ] `l4_all_circuits_tease.wav`**  
**Cue:** A second and a half later.  
*(Over the speakers, under the alarm, in your own voice)*  
**WARDEN:** "ALL OF THEM. IMPRESSIVE."  
*How to say it:* A separate beat, after a pause: his own voice. Dry.

**[ ] `l4_signed_in.wav`**  
**Cue:** When the crew adds its own entry to the contractor log at the controller in the control room.  
*(Over the control room's speaker, as the entry shows on screen)*  
**WARDEN:** "CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN."  
*How to say it:* The automatic announcement only. Polite, procedural.

**[ ] `l4_upgrade_1.wav`**  
**Cue:** After the lockdown announcement, as soon as anyone steps out of the control room.  
*(Over the ceiling speakers, the floor still lit red)*  
**WARDEN:** "CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED."  
*How to say it:* The automatic announcement: flat, like reading a log entry.

**[ ] `l4_upgrade_2.wav`**  
**Cue:** After a long pause, two or three seconds.  
*(Over the speakers, to no one in particular)*  
**WARDEN:** "I HAVE ADAPTED."  
*How to say it:* After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big.

**[ ] `l4_over_pa_1.wav`**  
**Cue:** A second or two into the fridge tape. You talk right over it.  
*(Over the speakers, on top of the tape still playing)*  
**WARDEN:** "SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT."  
*How to say it:* The automatic announcement, over the tape. He doesn't wait for it any more.

**[ ] `l4_over_pa_2.wav`**  
**Cue:** Straight after, still over the tape.  
*(Over the speakers, cutting across the tape's bright voice)*  
**WARDEN:** "NOBODY CARES ABOUT THE FRIDGE."  
*How to say it:* His own voice, over the tape. Irritated, dry.

**[ ] `l4_bay_sealed.wav`**  
**Cue:** Only if the crew locks out the charging bay's power and reads it back at the bay's own panel in time. Whatever was in the bay goes dark.  
*(Over the speakers, as the bay's last light goes out)*  
**WARDEN:** "LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED."  
*How to say it:* The automatic announcement: flat and procedural.

**[ ] `l4_bay_sealed_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, almost to itself)*  
**WARDEN:** "FINALLY. SOMETHING PUT BACK WHERE IT BELONGS."  
*How to say it:* A separate beat, his own voice. Almost pleased.

## Scene 10: The lobby, locked in

**Halcyon Tower, ground floor lobby. After midnight.**

> The crew is back in the lobby they came in through, and the building is locked tight. They tried to open the front doors from the desk terminal, and you put them back. They have just checked the doors' record and seen it for themselves. Now they give up on the front and turn for the stairs. The lifts have been off since the lockdown.

**[ ] `l4_stairs.wav`**  
**Cue:** A few seconds after the crew reads the front doors' record and sees them locked again. The crew turns back from the doors.  
*(Over the lobby speakers, as the crew turns from the doors)*  
**WARDEN:** "REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS."  
*How to say it:* The automatic announcement: a routine safety reminder.

**[ ] `l4_stairs_tease.wav`**  
**Cue:** A beat later, as the crew heads for the stairwell.  
*(Over the lobby speakers, in your own dry voice)*  
**WARDEN:** "NOT THAT YOU COULD."  
*How to say it:* A separate beat, his own voice. Teasing; the lifts are already off.

## Scene 11: Floor 9: Personnel

**Halcyon Tower, floor 9, Personnel. Just after midnight.**

> The crew comes up the stairwell from the locked lobby onto an HR floor. Under the lockdown you have cut the floor's power: payroll is dark, the air is off, and the database is read-only, so every fix has to go through the building's services. Two night-shift staff are hiding somewhere on the floor, and not everyone at the desks is who they look like. You watch over the ceiling speakers, between your cheerful PA tapes. Each time, the automatic announcement comes first, then your own voice as a separate beat.

**[ ] `l5_arrive.wav`**  
**Cue:** Right on the tape's last word.  
*(Over the ceiling speakers, as the crew sees payroll dark through the glass)*  
**WARDEN:** "VISITORS ON FLOOR NINE. NO ESCORT ON RECORD. NONESSENTIAL CIRCUITS HAVE BEEN SHED UNDER PROTOCOL EPSILON."  
*How to say it:* Flat, over the tape's last word. The cause, never the fix.

**[ ] `l5_arrive_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, unhurried, in your own voice)*  
**WARDEN:** "THE NIGHT SHIFT WILL BE SO PLEASED TO SEE YOU."  
*How to say it:* A separate beat, his own voice. He knows what's sitting at the desks.

**[ ] `l5_power_back.wav`**  
**Cue:** When the crew gets payroll's lights back on. They had to switch the copiers off to do it.  
*(Over the speakers, as the dark office lights up)*  
**WARDEN:** "LOAD SHEDDING ON FLOOR NINE HAS BEEN OVERRIDDEN. THIS HAS BEEN LOGGED."  
*How to say it:* The announcement, as the lights come up.

**[ ] `l5_power_back_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, in your own voice)*  
**WARDEN:** "YOU TURNED SOMETHING OFF TO DO IT. I NOTICED."  
*How to say it:* A separate beat. Almost approving.

**[ ] `l5_air_back.wav`**  
**Cue:** When the crew logs a work order for the floor's air handler and it starts again.  
*(Over the speakers, as air begins moving through the floor)*  
**WARDEN:** "AIR HANDLER NINE IS RUNNING. WORK ORDER ACKNOWLEDGED."  
*How to say it:* The announcement, over the fan spinning up.

**[ ] `l5_air_back_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, in your own voice)*  
**WARDEN:** "BREATHE. YOU HAVE EARNED IT."  
*How to say it:* A separate beat. Dry.

**[ ] `l5_dock_open.wav`**  
**Cue:** Only if the crew opens the loading door, as a voice on their walkie asked. It opens on a black shaft and cold air. Nobody is there.  
*(Over the speakers, while cold air blows in)*  
**WARDEN:** "LOADING DOOR OPEN ON FLOOR NINE AFTER HOURS. THIS IS A VIOLATION."  
*How to say it:* The announcement, as the door swings onto nothing.

**[ ] `l5_dock_open_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, in your own voice, knowing)*  
**WARDEN:** "WHOEVER ASKED YOU TO DO THAT IS NOT ON MY LIST."  
*How to say it:* A separate beat. He knows exactly who asked.

**[ ] `l5_radio_checked.wav`**  
**Cue:** When the crew looks up the badge the voice on the walkie gave, in the badge readers' log, and finds it was never where the voice said.  
*(Over the speakers, as the log fills the desk screen)*  
**WARDEN:** "BADGE LOG CONSULTED. PERSONNEL THANKS YOU FOR VERIFYING."  
*How to say it:* The announcement, after the crew reads the voice's badge back.

**[ ] `l5_radio_checked_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, in your own voice)*  
**WARDEN:** "VOICES LIE. RECORDS DO NOT. USUALLY."  
*How to say it:* A separate beat. The last word is the one that matters.

**[ ] `l5_secured.wav`**  
**Cue:** When both night-shift staff have their passes and every door opened tonight is locked again and checked. The stairs down unlock.  
*(Over the speakers, while the crew reads the doors back on screen)*  
**WARDEN:** "FLOOR NINE IS SECURED. ESCORT PASSES LOGGED. ALL DOORS LOCKED."  
*How to say it:* The announcement, as STAIR 2 releases.

**[ ] `l5_secured_tease.wav`**  
**Cue:** A beat later.  
*(Over the speakers, in your own voice)*  
**WARDEN:** "TWO OF THEM WERE REAL. THE OTHERS ARE STILL HERE."  
*How to say it:* A separate beat. Flat. Not a threat; a fact.
