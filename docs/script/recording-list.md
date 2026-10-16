# Recording list

61 lines in all.

Generated from `scripts/audio/voice_lines.gd`. The full script with scene context is in [script.md](script.md).

## How to record

1. Record each line as its own file, named exactly as the **File** column plus `.wav` or `.ogg` (for example `l0_greet_1.wav`).
2. Mono, 44.1 or 48 kHz. Leave about a quarter second of silence at the start and end, and keep the loudest part around -3 dB.
3. Record dry: no reverb or radio effect. The game puts WARDEN through a PA speaker sound, and walkie lines will get radio static once the radio is built.
4. Do two or three takes and keep the best one. Lines can be any length; the subtitle stays up as long as the recording plays.
5. Put the files in `audio/voice/` and open the project in Godot once so it imports them. That's it: the game plays a recording whenever one exists and falls back to the timed subtitle when it doesn't.

WARDEN's subtitles are in capitals because that is how WARDEN prints. Say them at normal volume.

Lines marked **later** are written for Level 2, which isn't built yet. Record them whenever, or wait until the level is in.

## Dale Rourke (33 lines)

> Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_greet_1` | There you are. Dale Rourke, facilities. I'll be your escort tonight. | Friendly, a handshake in the voice. | Level 0 |
| [ ] | `l0_greet_2` | Don't mind WARDEN. It says that to everybody. | Chuckling, waving at the ceiling speaker. | Level 0 |
| [ ] | `l0_greet_3` | Badge rules after hours. You don't go anywhere I don't take you. | Still smiling. Should sound like a joke the first time and a threat on replay. | Level 0 |
| [ ] | `l0_tour_1` | Here's the job. Dr. Vale, our lead engineer, went missing three nights ago. | Walking. Matter-of-fact, the way you'd mention the weather. | Level 0 |
| [ ] | `l0_tour_2` | Her systems are a mess and the director wants them recovered by morning. Quietly. | Small beat before "Quietly." | Level 0 |
| [ ] | `l0_tour_3` | Fun fact: the man who founded this place, Harold Mercer, hated computers running buildings. | Tour-guide mode, enjoying himself. | Level 0 |
| [ ] | `l0_tour_4` | Board fired him when they installed WARDEN. That's the AI that runs the campus now. |  | Level 0 |
| [ ] | `l0_tour_5` | Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable. | Spooky-campfire voice, playing it up. | Level 0 |
| [ ] | `l0_tour_6` | Ghost stories. Anyway. | Dropping it fast. He doesn't want them thinking about it. | Level 0 |
| [ ] | `l0_desk_1` | The front desk scanner ate one of Vale's memos. The scraps went into a table. | Pointing at the desk. | Level 0 |
| [ ] | `l0_desk_2` | Director wants to know what it said. Go ahead, terminal's on the desk. | Casual, but he wants to know too. | Level 0 |
| [ ] | `l0_memo_1` | ...Huh. She always was dramatic. | A beat too long before he speaks. Covering. | Level 0 |
| [ ] | `l0_memo_2` | Grab the walkie-talkies from lost and found behind the desk. Over the counter, it's fine. | Back to friendly, changing the subject. | Level 0 |
| [ ] | `l0_walkie` | Channel one. Keep them on. Reception's lousy once we're past the shutter. | Offhand. | Level 0 |
| [ ] | `l0_shutter_1` | Jammed again. You'll have to duck under it. | Annoyed at the shutter, not at them. | Level 0 |
| [ ] | `l0_shutter_2` | I'll take the staff door and meet you at the server room. | Already walking away. | Level 0 |
| [ ] | `l0_sra` | Server Room A. After you. | Holding the door. Polite. Too polite. | Level 0 |
| [ ] | `l1_enter` | Vale's last login came from this room. Come on in. | Calling back over his shoulder, inside the room. | Level 1 |
| [ ] | `l1_trap_1` | Sorry about this. Nothing personal. | The door has just locked. The friendliness switches off. | Level 1 |
| [ ] | `l1_trap_2` | Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself. | Tired, explaining a chore. | Level 1 |
| [ ] | `l1_hit_1` | Stay down! | Swinging. | Level 1 |
| [ ] | `l1_hit_2` | Should've stayed in the van. | Breathing hard. | Level 1 |
| [ ] | `l1_hit_3` | Nobody's coming for you. | Low. | Level 1 |
| [ ] | `l1_hit_4` | Hold still! | Frustrated. | Level 1 |
| [ ] | `l1_hurt_1` | Agh! | Just a grunt of pain. | Level 1 |
| [ ] | `l1_hurt_2` | Okay. Okay, that one hurt. | Winded, almost laughing. | Level 1 |
| [ ] | `l1_hurt_3` | Lucky. | Spat out. | Level 1 |
| [ ] | `l1_downed` | Wait... wait. You don't know what you're doing. | On the floor, out of breath. Genuinely scared for the first time. | Level 1 |
| [ ] | `l1_tied_1` | You think a bit of cable holds me? | Tied up on the floor, grinning through it. | Level 1 |
| [ ] | `l1_tied_2` | WARDEN will eat you alive in here. | Quieter. He means it. | Level 1 |
| [ ] | `l2_rourke_1` | Still on channel one? Good. Thought you'd want to know I'm out. | Through the walkie. Relaxed, enjoying himself again. | Level 2, later |
| [ ] | `l2_rourke_2` | Security office is the only way down from here. Say hi to the night guard for me. |  | Level 2, later |
| [ ] | `l2_rourke_3` | Oh, he won't say much. Nobody's seen him since Tuesday. | Let it hang. Then the radio clicks off. | Level 2, later |

## WARDEN (20 lines)

> Calm, polite, flat. Customer-service cadence with even pauses. The sarcasm is in the words, never the tone, and it never raises its voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_pa_1` | GOOD EVENING. HALCYON DATA SYSTEMS IS CLOSED. | Over the lobby PA. Pleasant, like a store closing announcement. | Level 0 |
| [ ] | `l0_pa_2` | VISITORS MUST REMAIN WITH THEIR ESCORT AT ALL TIMES. THANK YOU FOR YOUR COOPERATION. | Same announcement, continuing. | Level 0 |
| [ ] | `l0_sort_hint` | THOSE SCRAPS ARE OUT OF ORDER. EACH ONE HAS A PIECE NUMBER. SORT THEM WITH ORDER BY. | From the terminal speaker, helpful in the way a parking meter is helpful. | Level 0 |
| [ ] | `l0_memo_flag` | DOCUMENT RECONSTRUCTED. A COPY HAS BEEN SENT TO THE DIRECTOR. | Brightly. This should land as a chill. | Level 0 |
| [ ] | `l1_killed` | ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN. | Over the room's speakers. Unbothered, like reading a stock price. | Level 1 |
| [ ] | `l1_login` | BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE. | The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant. | Level 1 |
| [ ] | `l1_selftest` | SELF-TEST COMPLETE. TWO FAILURES. I'M SURE YOU'LL WORK IT OUT. | The one line with a hint of a smirk. | Level 1 |
| [ ] | `l1_found` | THAT IS THE ONE. A MANUAL RESET AT ITS RACK WILL CLEAR IT. | Grudging. | Level 1 |
| [ ] | `l1_no_badge` | RESET REFUSED. BADGE REQUIRED. | Flat, instant. | Level 1 |
| [ ] | `l1_panel_ok` | THAT CONTROLLER IS WORKING NORMALLY. NOTHING TO RESET. | Patient, like talking to a child. | Level 1 |
| [ ] | `l1_panel_wrong` | THAT IS NOT THE EXIT'S CONTROLLER. PANELS LOCKED. PLEASE STOP TOUCHING THINGS. | The last sentence slightly slower. | Level 1 |
| [ ] | `l1_exit_open` | CONTROLLER RESET. EXIT UNLOCKED. PLEASE PROCEED CALMLY. |  | Level 1 |
| [ ] | `l1_lockdown_tied` | LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D. | Reading a log entry. | Level 1 |
| [ ] | `l1_sealed` | ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT. | The sign-off for the slice. Warm, like wishing them well. | Level 1 |
| [ ] | `l2_dead_escort` | REMINDER: VISITORS MUST REMAIN WITH THEIR ESCORT. YOUR ESCORT IS NO LONGER AVAILABLE. PLEASE WAIT WHERE YOU ARE. | Only if Rourke was killed. Plays on arrival, in place of Rourke's radio call. | Level 2, later |
| [ ] | `l2_arrive` | SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE. | Reassuring tone. It is not reassuring. | Level 2, later |
| [ ] | `l2_cameras` | LIVE CAMERA STATES ARE AVAILABLE AT GET SLASH CAMERAS. I SUGGEST CHECKING THEM. OFTEN. | Small pause before "Often." | Level 2, later |
| [ ] | `l2_smudged` | GUARD PINS ARE KEPT IN STAFF RECORDS. THE NAME ON TONIGHT'S SIGN-IN SHEET IS SMUDGED. HOW UNFORTUNATE. | Not unfortunate for WARDEN. | Level 2, later |
| [ ] | `l2_door_ok` | DOOR COMMAND ACCEPTED. DOOR OPENED. | Confident. It is wrong. | Level 2, later |
| [ ] | `l2_door_fault` | CORRECTION. THE DOOR REPORTS AN ACTUATOR FAULT. THE REQUEST WAS RECEIVED. THE DOOR DID NOT CARE. | When the players check the sensor. Deadpan. | Level 2, later |

## Dr. Iris Vale (3 lines)

> Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_vale_1` | Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry. | Beep before this. Hushed, fast. | Level 2, later |
| [ ] | `l2_vale_2` | If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it. | Urgent. A glance over her shoulder in the voice. | Level 2, later |
| [ ] | `l2_vale_3` | And please don't give your PIN to anyone. Not even Dale. | Softer. Then she hangs up. | Level 2, later |

## Harold Mercer (5 lines)

> Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_tape_1` | Harold Mercer. March of '94. My last day, apparently. | Click of the record button before this. Dry. | Level 0 |
| [ ] | `l0_tape_2` | If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors. | Approving, a little smile. | Level 0 |
| [ ] | `l0_tape_3` | Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out. | The one moment of anger, still controlled. | Level 0 |
| [ ] | `l0_tape_4` | So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter. | Quiet, almost proud, then wry on the last sentence. | Level 0 |
| [ ] | `l0_tape_5` | If it ever comes to that, look for my plans. The building's records remember more than people do. | Slow. Then the click of the stop button. | Level 0 |
