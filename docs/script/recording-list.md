# Recording list

92 lines in all.

Generated from `scripts/audio/voice_lines.gd`. The full script with scene context is in [script.md](script.md).

## How to record

Each actor gets only their own character's script from [characters/](characters/), which has the same recording spec:

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Returned files go in `audio/voice/<character>/` (for example `audio/voice/rourke/l0_greet_1.wav`); open the project in Godot once so it imports them. The game plays a recording whenever one exists, keeps the subtitle up for as long as it lasts, and falls back to the timed subtitle when it doesn't. Only `<line_id>.wav` is played: to use take 2, rename it.

Lines marked **later** are written ahead for a level that isn't built yet. Record them whenever, or wait until the level is in.

## Dale Rourke (61 lines)

> Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_greet_1` | There you are. Dale Rourke, facilities. I'll be your escort tonight. | Friendly, a handshake in the voice. | Level 0 |
| [ ] | `l0_greet_2` | Don't mind the announcements. They play that to everybody. | Chuckling, waving at the ceiling speaker. | Level 0 |
| [ ] | `l0_greet_3` | Badge rules after hours. You don't go anywhere I don't take you. | Still smiling. Should sound like a joke the first time and a threat on replay. | Level 0 |
| [ ] | `l0_greet_4` | Come on in. I'll sign you in at the front desk. | Holding the door, waving them through. | Level 0 |
| [ ] | `l0_signin` | Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me. | Casual, reassuring. Nothing to worry about. (On a replay it lands differently.) | Level 0 |
| [ ] | `l0_tour_1` | Here's the job. Dr. Vale, our lead engineer, went missing three nights ago. | Walking. Matter-of-fact, the way you'd mention the weather. | Level 0 |
| [ ] | `l0_tour_2` | Her systems are a mess and the director wants them recovered by morning. Quietly. | Small beat before "Quietly." | Level 0 |
| [ ] | `l0_desk_1` | The front desk scanner ate one of Vale's memos. The scraps went into a table. | Pointing at the desk. | Level 0 |
| [ ] | `l0_desk_2` | Director wants to know what it said. Go ahead, terminal's on the desk. | Casual, but he wants to know too. | Level 0 |
| [ ] | `l0_memo_flag` | Nice work. I'll make sure that goes straight to the director. | Pleased, jotting it on his clipboard before he's read it. Warm; on a replay it's the worst thing he says all night. | Level 0 |
| [ ] | `l0_memo_1` | ...Huh. She always was dramatic. | A beat too long before he speaks. Covering. | Level 0 |
| [ ] | `l0_memo_2` | Grab the walkie-talkies from lost and found, back behind the desk. | Back to friendly, changing the subject. | Level 0 |
| [ ] | `l0_memo_3` | And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either. | Amused, he's said this to every visitor. A little eye-roll at corporate. | Level 0 |
| [ ] | `l0_memo_4` | Grab one and I'll take you to the server room. | Friendly, already heading for the hall. | Level 0 |
| [ ] | `l0_walkie` | Channel one. Keep them on. Reception's lousy once we're past the shutter. This way. | Offhand. | Level 0 |
| [ ] | `l0_coffee` | Machine's been eating quarters since '94. Watch. ... There. Coffee's on me. Don't tell facilities. | In the cafeteria. He thumps the vending machine and it drops a cup. Proud of the trick. | Level 0, later |
| [ ] | `l0_boost_1` | Panel's stuck up top? Here, step on my hands. I've got you. | Interlocking his fingers for a boost. Easy, practised. | Level 0, later |
| [ ] | `l0_boost_2` | See? Teamwork. | Brushing his hands off. | Level 0, later |
| [ ] | `l0_hum` | Don't mind the hum down that way. Old transformer. There's been a ticket open on it since before my time. | Near the dark east corridor. Casual, but he doesn't look down it. | Level 0, later |
| [ ] | `l0_cover` | They're with me. Escort's right here. | Toward the ceiling speaker when the PA's escort reminder replays while the crew is behind the counter. Covering for them like a friend. | Level 0, later |
| [ ] | `l0_elevator` | Server floor's one up. Elevator's slow, but it gets there. | At the elevator bank, holding the door. | Level 0, later |
| [ ] | `l0_tour_3` | Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings. | Tour-guide mode, enjoying himself. | Level 0 |
| [ ] | `l0_tour_4` | Board fired him when they installed WARDEN. That's the AI that runs the campus now. | Still chatting to the crew, a little proud of the trivia. | Level 0 |
| [ ] | `l0_tour_5` | Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable. | Spooky-campfire voice, playing it up. | Level 0 |
| [ ] | `l0_tour_6` | Ghost stories. Anyway. | Dropping it fast. He doesn't want them thinking about it. | Level 0 |
| [ ] | `l0_sra` | Here we are. Server Room A. | Badging the door. Pleasant, like the end of a tour. | Level 0 |
| [ ] | `l1_enter` | In you come. Terminal's just over here. | Calling back over his shoulder, inside the room. | Level 1 |
| [ ] | `l1_terminal` | Here's our database problem. One of the door controllers on this floor keeps faulting, and half the doors up here won't open till it's reset. Hopefully it's a quick fix. | Mundane, a facilities guy with a real problem. Hopeful. | Level 1 |
| [ ] | `l1_waiting` | Take your time. I've been staring at that rack for a week. | Leaning on the doorframe. Patient. | Level 1, later |
| [ ] | `l1_badge_help` | Reset wants a badge? Here, use mine. | Swiping his badge for them. Helpful, no hesitation. | Level 1, later |
| [ ] | `l1_wrong_panel` | Nope, panel's not having it. Try another? | Shrugging, no blame. | Level 1, later |
| [ ] | `l1_fixed_1` | Would you look at that. Green across the board. Six months I've been filing tickets on that thing. | Genuinely impressed. | Level 1, later |
| [ ] | `l1_fixed_2` | You lot are good. Director's going to want to hear about this. | Warm. On a replay, the director hearing about them is the problem. | Level 1, later |
| [ ] | `l1_pivot_1` | Hang on. That fault log... every reset this week came from Vale's login. | Reading over a shoulder. Curious, a little too quickly. | Level 1, later |
| [ ] | `l1_pivot_2` | Her lab's up on the security floor. Secure Lab B. | Thinking out loud. | Level 1, later |
| [ ] | `l1_pivot_3` | Come on. If anyone can tell us what she was up to, it's her own terminal. Elevator works now, thanks to you. | Already walking. Friendly, steering. | Level 1, later |
| [ ] | `l2_lab_arrive` | Secure Lab B. Vale practically lived in here. | Fond, a little sad. | Level 2, later |
| [ ] | `l2_lab_badge_1` | Badge in for me, each of you. Visitor log. Security floor's fussy about it. | Routine, holding the reader out. The frame happens in plain sight. | Level 2, later |
| [ ] | `l2_lab_badge_2` | Thanks. Paperwork keeps everybody honest. | Once everyone has badged. | Level 2, later |
| [ ] | `l2_lab_shock_1` | Oh, no. No, no. Iris? | Fake shock. Good enough to fool them the first time, a beat too rehearsed on a replay. | Level 2, later |
| [ ] | `l2_lab_shock_2` | That's her coat. She never leaves without her coat. | Quiet, staring at it. | Level 2, later |
| [ ] | `l2_lab_terminal` | Her terminal's still logged in. Check it, see what she was working on. I'll call this in. | Backing toward the door, already reaching for his radio. | Level 2, later |
| [ ] | `l2_frame` | Intruders in Secure Lab B. Contractors. They've hurt Dr. Vale. | On his radio to WARDEN, heard through the door and on the crew's walkies. Urgent and breathless: a perfect performance. | Level 2, later |
| [ ] | `l2_trap_1` | Sorry about this. Nothing personal. | The door has just locked. The friendliness switches off. | Level 2, later |
| [ ] | `l2_trap_2` | Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself. | Tired, explaining a chore. | Level 2, later |
| [ ] | `l2_return` | Should've checked the other door. | Coming back in. Calm, cracking his neck. | Level 2, later |
| [ ] | `l2_hit_prints` | Go on, touch everything. Your prints are all over her desk now. | Taunting. Can repeat. | Level 2, later |
| [ ] | `l2_hit_1` | Stay down! | Swinging. | Level 2, later |
| [ ] | `l2_hit_2` | Should've stayed in the van. | Breathing hard. | Level 2, later |
| [ ] | `l2_hit_3` | Nobody's coming for you. | Low. | Level 2, later |
| [ ] | `l2_hit_4` | Hold still! | Frustrated. | Level 2, later |
| [ ] | `l2_hurt_1` | Agh! | Just a grunt of pain. | Level 2, later |
| [ ] | `l2_hurt_2` | Okay. Okay, that one hurt. | Winded, almost laughing. | Level 2, later |
| [ ] | `l2_hurt_3` | Lucky. | Spat out. | Level 2, later |
| [ ] | `l2_downed` | Wait... wait. You don't know what you're doing. | On the floor, out of breath. Genuinely scared for the first time. | Level 2, later |
| [ ] | `l2_tied_1` | You think a bit of cable holds me? | Tied up on the floor, grinning through it. | Level 2, later |
| [ ] | `l2_tied_2` | WARDEN will eat you alive in here. | Quieter. He means it. | Level 2, later |
| [ ] | `l2_tied_3` | Run if you like. Every camera on this floor already thinks you killed her. | Tied up, smiling. The frame, said out loud. | Level 2, later |
| [ ] | `l2_rourke_1` | Still on channel one? Good. Thought you'd want to know I'm out. | Through the walkie. Relaxed, enjoying himself again. | Level 2 |
| [ ] | `l2_rourke_2` | Security office is the only way down from here. Say hi to the night guard for me. | Through the walkie, casual, like giving directions. | Level 2 |
| [ ] | `l2_rourke_3` | Oh, he won't say much. Nobody's seen him since Tuesday. | Let it hang. Then the radio clicks off. | Level 2 |

## WARDEN (17 lines)

> Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_killed` | ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN. | Over the room's speakers. Unbothered, like reading a stock price. | Level 2, later |
| [ ] | `l2_contain_1` | VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW-- | Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off. | Level 2, later |
| [ ] | `l2_contain_2` | VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE. | From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later. | Level 2, later |
| [ ] | `l2_login` | BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE. | The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant. | Level 2, later |
| [ ] | `l2_selftest` | SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM. | The one line with a hint of a smirk. | Level 2, later |
| [ ] | `l2_found` | QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY. | Reading a rule it knows they're about to break. Cool. | Level 2, later |
| [ ] | `l2_no_badge` | RESET REFUSED. BADGE REQUIRED. | Flat, instant. | Level 2, later |
| [ ] | `l2_panel_ok` | RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU? | Patient, then a small dig. | Level 2, later |
| [ ] | `l2_panel_wrong` | UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS. | The last sentence slightly slower. | Level 2, later |
| [ ] | `l2_exit_open` | CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED. | Polite, and keeping score. | Level 2, later |
| [ ] | `l2_lockdown_tied` | LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D. | Reading a log entry. | Level 2, later |
| [ ] | `l2_sealed` | ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT. | The sign-off for the slice. Warm, like wishing them well. | Level 2, later |
| [ ] | `l2_arrive` | SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE. | Reassuring tone. It is not reassuring. | Level 2 |
| [ ] | `l2_cameras` | CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF. | Small pause before the second sentence. | Level 2 |
| [ ] | `l2_smudged` | TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU. | Not unfortunate for WARDEN. | Level 2 |
| [ ] | `l2_door_ok` | DOOR COMMAND ACCEPTED. DOOR OPENED. | Confident. It is wrong. | Level 2 |
| [ ] | `l2_door_fault` | ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING. | When the crew finds the fault themselves. Deadpan, unapologetic. | Level 2 |

## WARDEN (PA tapes) (3 lines)

> A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [x] | `l0_pa_1` | Good evening! Halcyon Data Systems is now closed. | Over the lobby PA. Pleasant, like a store closing announcement. | Level 0 |
| [x] | `l0_pa_2` | Visitors must remain with their escort at all times. Thank you for your cooperation! | Same announcement, continuing. | Level 0 |
| [x] | `l0_sort_hint` | Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon! | From the ceiling speakers. A canned reminder that plays every hour. Proud of the company, unaware of anyone listening. | Level 0 |

## Dr. Iris Vale (3 lines)

> Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_vale_1` | Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry. | Beep before this. Hushed, fast. | Level 2 |
| [ ] | `l2_vale_2` | If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it. | Urgent. A glance over her shoulder in the voice. | Level 2 |
| [ ] | `l2_vale_3` | And please don't give your PIN to anyone. Not even Dale. | Softer. Then she hangs up. | Level 2 |

## Byte-Right dispatch (3 lines)

> Bored, routine, a little crackly. Reading tickets off a list at the end of a long shift. Nothing about this call is unusual to them.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_dispatch_1` | Van three, you're on site at Halcyon Data Systems. After-hours callout. | Over the van radio. Routine. | Level 0 |
| [ ] | `l0_dispatch_2` | They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors. | Reading it off the ticket. | Level 0 |
| [ ] | `l0_dispatch_3` | Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out. | Bored, reading the form. Signing off, already onto the next call. | Level 0 |

## Harold Mercer (5 lines)

> Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_tape_1` | Harold Mercer. March of '94. My last day, apparently. | Click of the record button before this. Dry. | Level 0 |
| [ ] | `l0_tape_2` | If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors. | Approving, a little smile. | Level 0 |
| [ ] | `l0_tape_3` | Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out. | The one moment of anger, still controlled. | Level 0 |
| [ ] | `l0_tape_4` | So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter. | Quiet, almost proud, then wry on the last sentence. | Level 0 |
| [ ] | `l0_tape_5` | If it ever comes to that, look for my plans. The building's records remember more than people do. | Slow. Then the click of the stop button. | Level 0 |
