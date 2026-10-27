# WARDEN

*Your script for Null & Void: 38 recordings.*

## Who you are

The building's computer system. It runs the doors, the lights and the speakers, and it talks over the PA and through terminals.

**Background.** Halcyon's security and building system, installed in 1994 over the founder's objections. It runs the doors, badge readers, lights, air, cameras, lifts and speakers. It isn't evil: it follows its rules, very well.

**Tonight.** Once the crew loses its escort, its rules say they're intruders. Every time they beat one of its measures, it writes itself a new rule, and on floor 10 it says "I" for the first time. It is waking up.

**How you sound.** Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

**Think of.** HAL 9000's calm and a hotel concierge's courtesy. The menace is that it never gets angry.

## How to read this script

- It runs in story order, scene by scene, like a play. Each scene opens with where you are and what's going on.
- Each file name is one recording. Read everything under it in one take, top to bottom.
- What you say is in "quotes". *Italics* say what's happening, what you're doing and how to say it: don't read them out.
- When a recording has more than one line, stop for a full second wherever italics come between them. The game cuts the recording at those pauses.
- A boxed quote is someone else's line, just before yours.

## Recording

- **Format:** WAV, mono, 48 kHz, 16- or 24-bit.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two of each recording, in separate files: `<file name>.wav` and `<file name>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Pauses:** in a recording with more than one line, a full second of silence between the lines, longer than any pause inside a line.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/warden/` in the game.

## Scene 1: Kill or tie him up

**Halcyon Tower, floor 22, Secure Lab B. Right after the fight.**

> Rourke is on the floor and can't get up. The crew stands over him and decides what to do: tie him up with network cable, finish him, or leave him there. Either way, they take his badge. Only one branch plays.

**[ ] `l2_killed.wav`**

*Only if the crew kills Rourke. Straight after. Over the lab's ceiling speakers, as the crew stands over him. Unbothered, like reading a stock price.*

"ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN."

## Scene 2: Visitor without escort

**Halcyon Tower, floor 22, Secure Lab B. Moments later.**

> The visitors in Secure Lab B no longer have their escort. The lab lights turn red. This is the first time you speak in your own live voice. You start your containment warning, and your own recorded PA tape cuts in over you. You wait politely for it to finish, then begin again.

**[ ] `l2_contain_1.wav`**

*The moment the visitors are left without their escort, and the red lockdown lights come on. Over the lab's ceiling speakers, to the visitors below. Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off.*

"VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW--"

**[ ] `l2_contain_2.wav`**

*About two seconds after your recorded tape about the shredders finishes. Over the same speakers, starting again from the top. From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later.*

"VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE."

## Scene 3: Out of the lab

**Halcyon Tower, floor 22, Secure Lab B. The lockdown.**

> The visitors are shut in the lab. The door's controller is latched, and a security response is on its way, with a clock counting down over the door. They log in to the lab terminal on Rourke's badge and try to reset the door controller themselves. You watch every move and keep score. You never help.

**[ ] `l2_login.wav`**

*The lab terminal unlocks on Rourke's badge, once the lockdown has started. Over the lab speakers, as the terminal screen turns green. The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.*

"BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE."

**[ ] `l2_selftest.wav`**

*When the crew reads your self-test on the lab terminal. Over the lab speakers, while the crew reads the screen. The one line with a hint of a smirk.*

"SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM."

**[ ] `l2_found.wav`**

*When the crew first looks up the door controllers on the lab terminal. Over the speakers, as the list prints on screen. Reading a rule it knows they're about to break. Cool.*

"QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY."

**[ ] `l2_no_badge.wav`**

*If someone tries a reset without a badge. Can repeat. Over the speakers, the instant the switch is pressed. Flat, instant.*

"RESET REFUSED. BADGE REQUIRED."

**[ ] `l2_panel_ok.wav`**

*When a player flips the reset switch of a controller that's working fine. Over the speakers, as the switch clicks and nothing happens. Patient, then a small dig.*

"RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?"

**[ ] `l2_panel_wrong.wav`**

*When a player flips the wrong faulted switch. The switches lock for a few seconds. Over the speakers, as the switch panel locks. The last sentence slightly slower.*

"UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS."

**[ ] `l2_exit_open.wav`**

*When a player flips the right switch. The red lights go white and the lab door opens. Over the speakers, as the lab door slides open. Polite, and keeping score.*

"CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED."

## Scene 4: Lockdown

**Halcyon Tower, floor 22, outside Secure Lab B.**

> The visitors have reset the controller, and the lab door is open. They walk out into the corridor with no escort. You seal the floor around them, as politely as ever.

**[ ] `l2_lockdown_tied.wav`**

*Only if the crew left Rourke tied up in the lab. As the crew steps out of the lab. Over the corridor speakers, as the crew steps out. Reading a log entry.*

"LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D."

**[ ] `l2_sealed.wav`**

*As the crew walks out of the lab. If the lockdown announcement plays, straight after it. Over every speaker on the floor, as the exits lock. The sign-off for the slice. Warm, like wishing them well.*

"ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT."

## Scene 5: The security office

**Halcyon Tower, floor 22, the security booth and office. Past midnight.**

> The visitors are loose on the security floor, at the booth by the night desk. Behind a locked door and its glass is the security office, with its wall of camera monitors. To leave the floor they need a guard's PIN for the stairwell door. You watch them through your cameras, answer when they touch your systems, and never help.

**[ ] `l2_arrive_block.wav`**

*The crew walks back into the security booth's corridor, after the lab. Over the booth's ceiling speakers, as the crew walks in. Reassuring tone. It is not reassuring.*

"SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE."

*Over the same speakers, as they eye the monitor wall. Small pause before the second sentence.*

"CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF."

**[ ] `l2_smudged.wav`**

*After the crew finds the one readable guard name from the sign-in sheet, and learns his PIN is suspended. Over the booth speakers, while the crew sits at the terminal. Not unfortunate for WARDEN.*

"TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU."

**[ ] `l2_door_ok.wav`**

*A player enters the right PIN at the stairwell door's keypad. The keypad says the door opened. Over the vestibule speakers, while the door stays shut. Confident. It is wrong.*

"DOOR COMMAND ACCEPTED. DOOR OPENED."

**[ ] `l2_door_fault.wav`**

*Later, when the crew checks the stairwell door's status and sees it never moved. Over the vestibule speakers, as the crew reads the screen. When the crew finds the fault themselves. Deadpan, unapologetic.*

"ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING."

## Scene 6: Containment protocol Epsilon

**Halcyon Tower, floor 10, Plant and Power, and every speaker in the building. Just after midnight.**

> The crew is in the door and lift control room on floor 10. From the controller, they have just opened a set of doors that should have stayed shut. Far below, something heavy unlocks, every light on the floor turns red, and the charging bay's door rolls up on its own. You lock the whole building down, by the book. Then, every minute or so, you remind everyone, while the crew is on floor 10 and in the lobby.

**[ ] `l4_epsilon_1_block.wav`**

*A moment after the floor's lights turn red and the charging bay's door rolls up. Over every speaker in the building, as red light floods the floor. Flat and slow. A short pause after.*

"CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT."

*Over every speaker, while door locks thud shut across the building. Even pauses between sentences, like reading a checklist.*

"ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE."

*When it ends, the stair door out by the lifts unlocks. Over every speaker in the building, the same even tone. No change in tone for 'not a drill'. That's the frightening part.*

"ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL."

**[ ] `l4_epsilon_loop.wav`**

*Repeats every minute or so after the lockdown, while the crew is on floor 10 or in the lobby. Over the ceiling speakers, wherever the crew happens to be. Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only.*

"REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE."

**[ ] `l4_epsilon_loop_2.wav`**

*Repeats every minute or so, in place of the first reminder, once the database has gone read-only in the lobby. Over the lobby's ceiling speakers, as the crew looks for a way out. Takes turns with the other reminder, once writes have been suspended. Same polite loop.*

"REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE."

## Scene 7: Writes suspended

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

> The crew has come all the way down the stairs to the lobby where the night began, looking for a way out. At the front desk terminal they change the front doors' record to open. The screen says it worked, and the latch clicks. Then you quietly put the record back, the latch clicks again, and the doors don't move. Now you make it official: no more changes.

**[ ] `l4_epsilon_db.wav`**

*A couple of seconds after the latch clicks a second time and the front doors stay shut. Over every speaker in the building, while the crew stares at the doors. The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint.*

"DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY."

## Scene 8: Writes refused

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

> The database is read-only now. The crew can still look things up, but whenever someone types a change, you refuse it, over the speakers and on their screen. The first time, the automatic announcement plays, then your own voice slips through. After that you keep it short.

**[ ] `l4_write_refused.wav`**

*The first time anyone types a change into a terminal after the read-only announcement. Over the speakers, the same words printing on their screen. The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal.*

"WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON."

**[ ] `l4_write_refused_tease.wav`**

*About a second after the refusal. First time only. Over the speakers, your own voice slipping through the announcement. A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud.*

"YOU MAY STILL LOOK. LOOKING IS FREE."

**[ ] `l4_write_refused_again.wav`**

*Every later time someone types a change. Repeats. Over the speakers, cut short, while the crew keeps typing. Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat.*

"STILL READ-ONLY."

## Scene 9: Floor 10: Plant and Power

**Halcyon Tower, floor 10, Plant and Power. Just after midnight.**

> A mechanical floor: a switchgear hall with a big breaker panel, a door and lift control room that has been dark since Tuesday, and a sealed charging bay. The crew has come down the stairs and found them shut below this floor. You watch them work over the ceiling speakers, between your cheerful old PA tapes, and at first you still wait politely for a tape to finish. Then the crew sets off a lockdown, and you change: you say 'I' for the first time, and you stop waiting for the tapes.

**[ ] `l4_arrive.wav`**

*Half a second after the tape ends. Over the ceiling speakers, as the crew looks around the hall. Flat. Waits until the tape has finished, on purpose; the politeness is the point.*

"VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING."

**[ ] `l4_all_circuits.wav`**

*Only if the crew changes the breakers without picking just one, and every breaker on the panel slams over at once. Alarms start. Once only. Over the speakers, while an alarm rings in the walls. The automatic announcement: flat and procedural.*

"ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE."

**[ ] `l4_all_circuits_tease.wav`**

*A second and a half later. Over the speakers, under the alarm, in your own voice. A separate beat, after a pause: his own voice. Dry.*

"ALL OF THEM. IMPRESSIVE."

**[ ] `l4_signed_in.wav`**

*When the crew adds its own entry to the contractor log at the controller in the control room. Over the control room's speaker, as the entry shows on screen. The automatic announcement only. Polite, procedural.*

"CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN."

**[ ] `l4_upgrade_1.wav`**

*After the lockdown announcement, as soon as anyone steps out of the control room. Over the ceiling speakers, the floor still lit red. The automatic announcement: flat, like reading a log entry.*

"CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED."

**[ ] `l4_upgrade_2.wav`**

*After a long pause, two or three seconds. Over the speakers, to no one in particular. After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big.*

"I HAVE ADAPTED."

**[ ] `l4_over_pa_1_block.wav`**

*A second or two into the fridge tape. You talk right over it. Over the speakers, on top of the tape still playing. The automatic announcement, over the tape. He doesn't wait for it any more.*

"SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT."

*Still over the tape. Over the speakers, cutting across the tape's bright voice. His own voice, over the tape. Irritated, dry.*

"NOBODY CARES ABOUT THE FRIDGE."

**[ ] `l4_bay_sealed_block.wav`**

*Only if the crew locks out the charging bay's power and reads it back at the bay's own panel in time. Whatever was in the bay goes dark. Over the speakers, as the bay's last light goes out. The automatic announcement: flat and procedural.*

"LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED."

*Over the speakers, almost to itself. A separate beat, his own voice. Almost pleased.*

"FINALLY. SOMETHING PUT BACK WHERE IT BELONGS."

## Scene 10: The lobby, locked in

**Halcyon Tower, ground floor lobby. After midnight.**

> The crew is back in the lobby they came in through, and the building is locked tight. They tried to open the front doors from the desk terminal, and you put them back. They have just checked the doors' record and seen it for themselves. Now they give up on the front and turn for the stairs. The lifts have been off since the lockdown.

**[ ] `l4_stairs_block.wav`**

*A few seconds after the crew reads the front doors' record and sees them locked again. The crew turns back from the doors. Over the lobby speakers, as the crew turns from the doors. The automatic announcement: a routine safety reminder.*

"REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS."

*As the crew heads for the stairwell. Over the lobby speakers, in your own dry voice. A separate beat, his own voice. Teasing; the lifts are already off.*

"NOT THAT YOU COULD."

## Scene 11: Floor 9: Personnel

**Halcyon Tower, floor 9, Personnel. Just after midnight.**

> The crew comes up the stairwell from the locked lobby onto an HR floor. Under the lockdown you have cut the floor's power: payroll is dark, the air is off, and the database is read-only, so every fix has to go through the building's services. Two night-shift staff are hiding somewhere on the floor, and not everyone at the desks is who they look like. You watch over the ceiling speakers, between your cheerful PA tapes. Each time, the automatic announcement comes first, then your own voice as a separate beat.

**[ ] `l5_arrive_block.wav`**

*Right on the tape's last word. Over the ceiling speakers, as the crew sees payroll dark through the glass. Flat, over the tape's last word. The cause, never the fix.*

"VISITORS ON FLOOR NINE. NO ESCORT ON RECORD. NONESSENTIAL CIRCUITS HAVE BEEN SHED UNDER PROTOCOL EPSILON."

*Over the speakers, unhurried, in your own voice. A separate beat, his own voice. He knows what's sitting at the desks.*

"THE NIGHT SHIFT WILL BE SO PLEASED TO SEE YOU."

**[ ] `l5_power_back_block.wav`**

*When the crew gets payroll's lights back on. They had to switch the copiers off to do it. Over the speakers, as the dark office lights up. The announcement, as the lights come up.*

"LOAD SHEDDING ON FLOOR NINE HAS BEEN OVERRIDDEN. THIS HAS BEEN LOGGED."

*Over the speakers, in your own voice. A separate beat. Almost approving.*

"YOU TURNED SOMETHING OFF TO DO IT. I NOTICED."

**[ ] `l5_air_back_block.wav`**

*When the crew logs a work order for the floor's air handler and it starts again. Over the speakers, as air begins moving through the floor. The announcement, over the fan spinning up.*

"AIR HANDLER NINE IS RUNNING. WORK ORDER ACKNOWLEDGED."

*Over the speakers, in your own voice. A separate beat. Dry.*

"BREATHE. YOU HAVE EARNED IT."

**[ ] `l5_dock_open_block.wav`**

*Only if the crew opens the loading door, as a voice on their walkie asked. It opens on a black shaft and cold air. Nobody is there. Over the speakers, while cold air blows in. The announcement, as the door swings onto nothing.*

"LOADING DOOR OPEN ON FLOOR NINE AFTER HOURS. THIS IS A VIOLATION."

*Over the speakers, in your own voice, knowing. A separate beat. He knows exactly who asked.*

"WHOEVER ASKED YOU TO DO THAT IS NOT ON MY LIST."

**[ ] `l5_radio_checked_block.wav`**

*When the crew looks up the badge the voice on the walkie gave, in the badge readers' log, and finds it was never where the voice said. Over the speakers, as the log fills the desk screen. The announcement, after the crew reads the voice's badge back.*

"BADGE LOG CONSULTED. PERSONNEL THANKS YOU FOR VERIFYING."

*Over the speakers, in your own voice. A separate beat. The last word is the one that matters.*

"VOICES LIE. RECORDS DO NOT. USUALLY."

**[ ] `l5_secured_block.wav`**

*When both night-shift staff have their passes and every door opened tonight is locked again and checked. The stairs down unlock. Over the speakers, while the crew reads the doors back on screen. The announcement, as STAIR 2 releases.*

"FLOOR NINE IS SECURED. ESCORT PASSES LOGGED. ALL DOORS LOCKED."

*Over the speakers, in your own voice. A separate beat. Flat. Not a threat; a fact.*

"TWO OF THEM WERE REAL. THE OTHERS ARE STILL HERE."
