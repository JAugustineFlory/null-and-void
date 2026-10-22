# Recording list

1436 lines in all.

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

## Dale Rourke (77 lines)

> Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth. He laughs once, in the lab: the only time his warmth turns into real glee.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_greet_1` | There you are. Dale Rourke, facilities. I'll be your escort tonight. | Waiting outside the front doors as the crew walks up. Friendly, a handshake in the voice. | Level 0 |
| [ ] | `l0_greet_3` | Badge rules after hours. You don't go anywhere I don't take you. | Still smiling. Should sound like a joke the first time and a threat on replay. | Level 0 |
| [ ] | `l0_greet_4` | Come on in. I'll sign you in at the front desk. | Holding the door, waving them through. | Level 0 |
| [ ] | `l0_greet_2` | Sorry about that. The company loves its PA system. | Inside the lobby, right after the PA. Chuckling, waving at the ceiling speaker. | Level 0 |
| [ ] | `l0_signin` | Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me. | Casual, reassuring. Nothing to worry about. (On a replay it lands differently.) | Level 0 |
| [ ] | `l0_badges` | Visitor badges. Keep them on you. Doors upstairs won't let you through without one. | Handing them over the desk, routine. Helpful, a little bored. | Level 0 |
| [ ] | `l0_tour_1` | Here's the job. Dr. Vale, our lead engineer, went missing three nights ago. | Walking. Matter-of-fact, the way you'd mention the weather. | Level 0 |
| [ ] | `l0_tour_2` | Her systems are a mess and the director wants them recovered by morning. Quietly. | Small beat before "Quietly." | Level 0 |
| [ ] | `l0_desk_1` | The front desk scanner ate one of Vale's memos. The scraps went into a table. | Pointing at the desk. | Level 0 |
| [ ] | `l0_desk_2` | Director wants to know what it said. Go ahead, terminal's on the desk. | Casual, but he wants to know too. | Level 0 |
| [ ] | `l0_memo_flag` | Nice work. I'll make sure that goes straight to the director. | Pleased, jotting it on his clipboard before he's read it. Warm; on a replay it's the worst thing he says all night. | Level 0 |
| [ ] | `l0_memo_1` | ...Huh. She always was dramatic. | A beat too long before he speaks. Covering. | Level 0 |
| [ ] | `l0_caller_1` | One thing on your paperwork. It says I called you in. I didn't. That call came from building services. | Mild, a little puzzled, tapping the work order. Not suspicious yet. | Level 0 |
| [ ] | `l0_caller_2` | Want to know who? The staff directory's on that terminal. | Helpful, easygoing. Nodding at the terminal. | Level 0 |
| [ ] | `l0_mailroom_1` | Mailroom. Clerk's got the only phone list in this building that's actually up to date. She pinned it to the wall so nobody walks off with it. | Nodding down the back corridor toward the mailroom. Amused, a little fond. | Level 0 |
| [ ] | `l0_caller_3` | Mercer? Huh. That line's been dead for years. Somebody's having fun with the phones. Anyway. | A beat of real surprise, then he brushes it off and moves on. | Level 0 |
| [ ] | `l0_memo_2` | Grab the walkie-talkies from lost and found, back behind the desk. | Back to friendly, changing the subject. | Level 0 |
| [ ] | `l0_memo_3` | And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either. | Amused, he's said this to every visitor. A little eye-roll at corporate. | Level 0 |
| [ ] | `l0_memo_4` | Grab one and I'll take you to the server room. | Friendly, already heading for the hall. | Level 0 |
| [ ] | `l0_walkie` | Channel one. Keep them on. Reception's lousy once we're past the shutter. This way. | Offhand. | Level 0 |
| [ ] | `l0_mailroom_2` | Don't touch the outgoing tray. Last guy who did got a memo about it. | Only if a player goes inside the mailroom. Mock-serious. | Level 0 |
| [ ] | `l0_coffee` | Machine's been eating quarters since '94. Watch. ... There. Coffee's on me. Don't tell facilities. | In the cafeteria. He thumps the vending machine and it drops a cup. Proud of the trick. | Level 0 |
| [ ] | `l0_boost_1` | Panel's stuck up top? Here, step on my hands. I've got you. | Interlocking his fingers for a boost. Easy, practised. | Level 0 |
| [ ] | `l0_boost_2` | See? Teamwork. | Brushing his hands off. | Level 0 |
| [ ] | `l0_hum` | Don't mind the hum down that way. Old transformer. There's been a ticket open on it since before my time. | Near the dark east corridor. Casual, but he doesn't look down it. | Level 0 |
| [ ] | `l0_cover` | They're with me. Escort's right here. | Toward the ceiling speaker when the PA's escort reminder replays while the crew is behind the counter. Covering for them like a friend. | Level 0 |
| [ ] | `l0_elevator` | Server floor's up on fourteen. Elevator's slow, but it gets there. | At the elevator bank, holding the door. | Level 0 |
| [ ] | `l0_lift_button` | Press fourteen for me, would you? Server floor. | Inside the car, back against the far wall from the buttons. Easy, polite. | Level 0 |
| [ ] | `l0_tour_3` | Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings. | Tour-guide mode, enjoying himself. | Level 0 |
| [ ] | `l0_tour_4` | Board fired him when they installed WARDEN. That's the AI that runs the campus now. | Still chatting to the crew, a little proud of the trivia. | Level 0 |
| [ ] | `l0_tour_5` | Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable. | Spooky-campfire voice, playing it up. | Level 0 |
| [ ] | `l0_tour_6` | Ghost stories. Anyway. | Dropping it fast. He doesn't want them thinking about it. | Level 0 |
| [ ] | `l0_sra` | Here we are. Server Room A. | Badging the door. Pleasant, like the end of a tour. | Level 0 |
| [ ] | `l1_enter` | In you come. Terminal's just over here. | Calling back over his shoulder, inside the room. | Level 1 |
| [ ] | `l1_terminal` | Here's our database problem. One of the door controllers on this floor keeps faulting, and half the doors up here won't open till it's reset. Hopefully it's a quick fix. | Mundane, a facilities guy with a real problem. Hopeful. | Level 1 |
| [ ] | `l1_noc_1` | That's the NOC. Network operations. Night shift logs everything in there. Every alarm, every coffee break. | Passing the NOC window on the way to Server Room A, after the elevator. Easy, tour-guide tone. | Level 1 |
| [ ] | `l1_noc_2` | Night shift's not in tonight. Their log's still on the desk, though. They write it all down, whether anyone reads it or not. | Only if a player goes into the NOC. Leaning in the doorway. | Level 1 |
| [ ] | `l1_waiting` | Take your time. I've been staring at that rack for a week. | Leaning on the doorframe. Patient. | Level 1 |
| [ ] | `l1_badge_help` | Reset wants a badge? Here, use mine. | Swiping his badge for them. Helpful, no hesitation. | Level 1 |
| [ ] | `l1_wrong_panel` | Nope, panel's not having it. Try another? | Shrugging, no blame. | Level 1 |
| [ ] | `l1_fixed_1` | Would you look at that. Green across the board. Six months I've been filing tickets on that thing. | Genuinely impressed. | Level 1 |
| [ ] | `l1_fixed_2` | You lot are good. Director's going to want to hear about this. | Warm. On a replay, the director hearing about them is the problem. | Level 1 |
| [ ] | `l1_pivot_1` | Hang on. That fault log... every reset this week came from Vale's login. | Reading over a shoulder. Curious, a little too quickly. | Level 1 |
| [ ] | `l1_pivot_2` | Her lab's up on the security floor. Secure Lab B. | Thinking out loud. | Level 1 |
| [ ] | `l1_pivot_3` | Come on. If anyone can tell us what she was up to, it's her own terminal. Elevator works now, thanks to you. | Already walking. Friendly, steering. | Level 1 |
| [ ] | `l1_lift_button` | Twenty-two. Security floor. Go on. | Inside the car, across from the buttons. A little clipped now, eager to get there. | Level 1 |
| [ ] | `l2_lab_arrive` | Secure Lab B. Vale practically lived in here. | Fond, a little sad. | Level 2, later |
| [ ] | `l2_lab_badge_1` | Badge in for me, each of you. Visitor log. Security floor's fussy about it. | Routine, holding the reader out. The frame happens in plain sight. | Level 2, later |
| [ ] | `l2_lab_badge_2` | Thanks. Paperwork keeps everybody honest. | Once everyone has badged. | Level 2, later |
| [ ] | `l2_lab_shock_1` | Oh, no. No, no. Iris? | Fake shock. Good enough to fool them the first time, a beat too rehearsed on a replay. | Level 2, later |
| [ ] | `l2_lab_shock_2` | That's her coat. She never leaves without her coat. | Quiet, staring at it. | Level 2, later |
| [ ] | `l2_lab_terminal` | Her terminal's still logged in. Check it, see what she was working on. I'll call this in. | Backing toward the door, already reaching for his radio. | Level 2, later |
| [ ] | `l2_frame` | Intruders in Secure Lab B. Contractors. They've hurt Dr. Vale. | On his radio to WARDEN, heard through the door and on the crew's walkies. Urgent and breathless: a perfect performance. | Level 2, later |
| [ ] | `l2_trap_2` | Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself. | Through the door's glass, straight after the radio call. Tired, explaining a chore. | Level 2, later |
| [ ] | `l2_gloat_1` | You want to know when I knew? The front desk. You read that terminal like a menu in a foreign language. | Through the glass, almost fond. The friendly tour voice, which is what makes it awful. | Level 2, later |
| [ ] | `l2_gloat_2` | Then I saw the book in your van. Easy SQL. Still had the price sticker on it. | Shaking his head, smiling. | Level 2, later |
| [ ] | `l2_gloat_3` | Some outfit nobody's heard of underbids every firm in the city, and sends a crew who learned databases last weekend. | Ticking it off, enjoying himself. | Level 2, later |
| [ ] | `l2_gloat_4` | I should've reported you. Then it hit me. No... this is perfect. | Slower. Savouring it. | Level 2, later |
| [ ] | `l2_gloat_5` | A group of idiots posing as IT comes in and accidentally kills Vale! Hahaha! | The only time he laughs in the game: real delight, loud and sudden, then it stops dead. | Level 2, later |
| [ ] | `l2_gloat_6` | A garage with a van, calling itself a company. Your badges on her door. It writes itself. | Flat again, tired. Back to normal. | Level 2, later |
| [ ] | `l2_trap_1` | Sorry about this. Nothing personal. | Last line of the monologue, quiet. Walking away from the glass. | Level 2, later |
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

## WARDEN (38 lines)

> Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

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
| [ ] | `l4_epsilon_1` | CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT. | Flat and slow. A short pause after. | Level 4 |
| [ ] | `l4_epsilon_2` | ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE. | Even pauses between sentences, like reading a checklist. | Level 4 |
| [ ] | `l4_epsilon_3` | ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL. | No change in tone for 'not a drill'. That's the frightening part. | Level 4 |
| [ ] | `l4_epsilon_loop` | REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE. | Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only. | Level 4 |
| [ ] | `l4_epsilon_loop_2` | REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE. | Takes turns with the other reminder, once writes have been suspended. Same polite loop. | Level 4 |
| [ ] | `l4_epsilon_db` | DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY. | The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint. | Level 4 |
| [ ] | `l4_write_refused` | WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON. | The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal. | Level 4 |
| [ ] | `l4_write_refused_tease` | YOU MAY STILL LOOK. LOOKING IS FREE. | A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud. | Level 4 |
| [ ] | `l4_write_refused_again` | STILL READ-ONLY. | Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat. | Level 4 |
| [ ] | `l4_arrive` | VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING. | Flat. Waits until the tape has finished, on purpose; the politeness is the point. | Level 4 |
| [ ] | `l4_all_circuits` | ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE. | The automatic announcement: flat and procedural. | Level 4 |
| [ ] | `l4_all_circuits_tease` | ALL OF THEM. IMPRESSIVE. | A separate beat, after a pause: his own voice. Dry. | Level 4 |
| [ ] | `l4_signed_in` | CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN. | The automatic announcement only. Polite, procedural. | Level 4 |
| [ ] | `l4_upgrade_1` | CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED. | The automatic announcement: flat, like reading a log entry. | Level 4 |
| [ ] | `l4_upgrade_2` | I HAVE ADAPTED. | After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big. | Level 4 |
| [ ] | `l4_over_pa_1` | SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT. | The automatic announcement, over the tape. He doesn't wait for it any more. | Level 4 |
| [ ] | `l4_over_pa_2` | NOBODY CARES ABOUT THE FRIDGE. | His own voice, over the tape. Irritated, dry. | Level 4 |
| [ ] | `l4_bay_sealed` | LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED. | The automatic announcement: flat and procedural. | Level 4 |
| [ ] | `l4_bay_sealed_tease` | FINALLY. SOMETHING PUT BACK WHERE IT BELONGS. | A separate beat, his own voice. Almost pleased. | Level 4 |
| [ ] | `l4_stairs` | REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS. | The automatic announcement: a routine safety reminder. | Level 4 |
| [ ] | `l4_stairs_tease` | NOT THAT YOU COULD. | A separate beat, his own voice. Teasing; the lifts are already off. | Level 4 |

## WARDEN (PA tapes) (5 lines)

> A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [x] | `l0_pa_1` | Good evening! Halcyon Data Systems is now closed. | Over the lobby PA, as the crew steps inside. Pleasant, like a store closing announcement. | Level 0 |
| [x] | `l0_pa_2` | Visitors must remain with their escort at all times. Thank you for your cooperation! | Same announcement, continuing. | Level 0 |
| [x] | `l0_sort_hint` | Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon! | From the ceiling speakers. A canned reminder that plays every hour. Proud of the company, unaware of anyone listening. | Level 0 |
| [ ] | `l4_arrive_pa` | Welcome to floor ten, Plant and Power! Hard hats are by the door. Safety is everybody's job! | The cheerful recorded tape, as on the ground floor. | Level 4 |
| [ ] | `l4_pa_fridge` | Friendly reminder! The break room fridge is cleaned out every Friday, so please label your lunch— | The cheerful recorded tape. It keeps playing underneath when he talks over it. | Level 4 |

## Dr. Iris Vale (3 lines)

> Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_vale_1` | Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry. | Beep before this. Hushed, fast. | Level 2 |
| [ ] | `l2_vale_2` | If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it. | Urgent. A glance over her shoulder in the voice. | Level 2 |
| [ ] | `l2_vale_3` | And please don't give your PIN to anyone. Not even Dale. | Softer. Then she hangs up. | Level 2 |

## Maddison Kowalski (41 lines)

> Warm, quick and sure of herself, with a saleswoman's energy. The crew's friend more than their boss, and the one who believes in them before they believe in themselves. On the van radio she puts on a 'professional dispatcher' voice: bored, routine, reading tickets, a bluff that doesn't quite hide the excitement.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_brief_1` | Okay! Everybody comfy? Look at you. My whole company, in one garage. | Big, warm, delighted to have an audience. The crew is already sitting, facing her. | Level 0 |
| [ ] | `l0_brief_1_solo` | Okay! Look at you. My whole company, in one seat. | Solo version. The same joke, a little teasing. | Level 0 |
| [ ] | `l0_brief_2` | Where we stand. Rent's due Friday, the van's held together with tape, and our best client is a library that pays in exact change. | Cheerful, as if it's good news. Counting it off on her fingers. | Level 0 |
| [ ] | `l0_brief_3` | So this year's goal was simple. Stay open. Maybe a second van. Maybe a sign that doesn't fall off. | Every 'maybe' a little grander, then the sign brings it back down to earth. | Level 0 |
| [ ] | `l0_brief_4` | Forget all that. We got Halcyon. The overnight database contract. Ours. | Building to it. She can't stand still for 'Ours.' | Level 0 |
| [ ] | `l0_brief_5` | How? I underbid everybody. By a lot. Don't ask how much. Job's tonight, eleven o'clock. | Quickly, before anyone can ask. | Level 0 |
| [ ] | `l0_bag` | You guys are too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down. | Laughing, shooing them off. | Level 0 |
| [ ] | `l0_bag_solo` | You're too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down. | Solo version. Laughing, shooing them off. | Level 0 |
| [ ] | `l0_bag_back` | Better? Good. Now eyes on me, gorgeous people. | Once everyone's back in their seats. A little flirty, played light, like a coach. | Level 0 |
| [ ] | `l0_bag_back_solo` | Better? Good. Now eyes on me, gorgeous. | Solo version. A little flirty, played light, like a coach. | Level 0 |
| [ ] | `l0_workorder` | I put a copy of the work order in each of your notebooks. Pull it out and take a look. | Pleased with herself for being organized. | Level 0 |
| [ ] | `l0_workorder_solo` | I put a copy of the work order in your notebook. Pull it out and take a look. | Solo version. Pleased with herself for being organized. | Level 0 |
| [ ] | `l0_book_catch` | Small problem. It says database. And unless one of you secretly knows SQL... | The smile stays on. She leaves the sentence hanging and waits. Nobody does. | Level 0 |
| [ ] | `l0_book_catch_solo` | Small problem. It says database. And unless you secretly know SQL... | Solo version. The smile stays on. She leaves the sentence hanging and waits. | Level 0 |
| [ ] | `l0_bookstore` | ...I stopped by the bookstore. Easy SQL. 'Learn databases in a weekend.' We've got till eleven. | Proud of this. Holding up the receipt, not the book. | Level 0 |
| [ ] | `l0_grab` | It's in the shop bag on the shelf by the side door. One of you go grab it. | Pointing at the side door to the house. | Level 0 |
| [ ] | `l0_grab_solo` | It's in the shop bag on the shelf by the side door. Go on, grab it for me. | Solo version. Pointing at the side door to the house. | Level 0 |
| [ ] | `l0_whiteboard` | Thank you! Okay. Whiteboard. Chapter zero. We're reading this together. | When whoever got the book sits down. Uncapping a marker with a flourish, like she's about to teach a class she's never taken. | Level 0 |
| [ ] | `l0_whiteboard_solo` | Thank you! Okay. Whiteboard. Chapter zero. Let's read this together. | Solo version. Uncapping a marker with a flourish. | Level 0 |
| [ ] | `l0_garage_5` | Look at that. You're practically engineers. Take the book with you. Everybody in the van. | Genuinely thrilled. After the huddle's quiz. | Level 0 |
| [ ] | `l0_garage_5_solo` | Look at that. You're practically an engineer. Take the book with you. Into the van. | Solo version. Genuinely thrilled. After the huddle's quiz. | Level 0 |
| [ ] | `l0_garage_6` | Rules for tonight. Nod a lot. Anything you don't know, you need to check the logs. And if anyone asks, we've got a fleet. You're van three. I'll be on the radio. | At the van door, counting the rules off. She stays behind. | Level 0 |
| [ ] | `l0_huddle_select_1` | Chapter one. SELECT, FROM, and a semicolon. That's it? That's a whole language? | Disbelieving, delighted. | Level 0, later |
| [ ] | `l0_huddle_select_2` | Book says never forget the semicolon. Says it twice. So I'm saying it twice. Semicolon. | Deadly serious about the one thing they're sure of. | Level 0, later |
| [ ] | `l0_huddle_order_1` | Chapter two. 'Putting things in order.' Now that, I can get behind. | Reading off the page. | Level 0, later |
| [ ] | `l0_huddle_order_2` | Smallest first, unless you say DESC. Write that down. I'm writing it down. | Scribbling. | Level 0, later |
| [ ] | `l0_dispatch_1` | Van three, you're on site at Halcyon Data Systems. After-hours callout. | Over the van radio, in the professional dispatcher voice. 'Van three' is a bluff: they own one van. | Level 0 |
| [ ] | `l0_dispatch_2` | They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors. | Reading it off the ticket. | Level 0 |
| [ ] | `l0_dispatch_3` | Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out. | Bored, reading the form. Signing off, already onto the next call. | Level 0 |
| [ ] | `l1_huddle_where_1` | WHERE. For finding one thing in a big pile. Like my car keys. | Patting pockets. | Level 1, later |
| [ ] | `l1_huddle_where_2` | Two conditions, you glue them together with AND. Both have to be true. Like payday AND the cheque clears. | Rueful. | Level 1, later |
| [ ] | `l1_huddle_compare_1` | Bigger than, smaller than. The little alligator signs. Mouth eats the bigger number. | Drawing one on the whiteboard, with teeth. | Level 1, later |
| [ ] | `l1_huddle_compare_2` | Okay. That's maths I actually remember from school. | Relieved. | Level 1, later |
| [ ] | `l2_huddle_like_1` | LIKE. For when you only know part of a word. The percent sign means 'anything goes here.' | Squinting at the page. | Level 2, later |
| [ ] | `l2_huddle_like_2` | So 'Mad' and a percent gets you Maddison, Madison, Madeline... I'm in there somewhere. | Pleased to have found themself. | Level 2, later |
| [ ] | `l2_huddle_get_1` | This chapter isn't even SQL. 'Talking to other machines.' GET means 'show me.' | Flipping the book over to check the cover. | Level 2, later |
| [ ] | `l2_huddle_get_2` | So it's a SELECT for robots. Got it. Probably. | Not convinced. | Level 2, later |
| [ ] | `l4_huddle_update_1` | UPDATE. Changing things. The book's put this one in a red box, which I don't love. | Holding the page at arm's length. | Level 4 |
| [ ] | `l4_huddle_update_2` | Big red letters: 'Never forget the WHERE.' Otherwise it changes every row. Every. Row. | Suddenly serious, for once. | Level 4 |
| [ ] | `l4_huddle_insert_1` | INSERT INTO. A brand-new row. Like a brand-new client. I've heard those exist. | Reading the title, wistful, then perky again. | Level 4 |
| [ ] | `l4_huddle_insert_2` | Values go in the same order as the columns. Otherwise you've got a client called eighty who lives in Ashford. | Laughing at her own picture of it. Then she writes SAME ORDER on the whiteboard. | Level 4 |

## Radio newsreader (7 lines)

> Smooth, professional, warm, slightly bored. Calm public-radio delivery with no drama; the flatness is what makes it land.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_news_1` | Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems. | Steady, mid-bulletin. | Level 2, later |
| [ ] | `l2_news_2` | Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered. | No change in tone. | Level 2, later |
| [ ] | `l2_news_3` | A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.' | A slight shift for the quote: reading it, not acting it. | Level 2, later |
| [ ] | `l2_news_4` | Byte-Right's chief executive, Maddison Kowalski, was arrested at the Halcyon tower before dawn, trying to force her way inside. | Even, a touch of interest. | Level 2, later |
| [ ] | `l2_news_6` | Ms. Kowalski told officers, quote, 'They were framed! They didn't do it!' | Reading the quote flat, not acting it. Then a beat. | Level 2, later |
| [ ] | `l2_news_7` | Halcyon declined to comment. The crew has not been seen since. | Neutral. A small pause after. | Level 2, later |
| [ ] | `l2_news_5` | Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather. | Brightening for the weather. The game cuts the audio on 'weather'. | Level 2, later |

## The crew (player characters) (94 lines, recorded by each of the 12 crew members)

> Yourself, as your character: muttering to the crew, not performing. Quick and natural. Never sounds like a hint; it's somebody remembering where they saw something.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `cc_nudge2_first` | That SYSOP on the screen seems to know this building. Maybe ask. | Stuck, before SYSOP has helped. Half a joke, half serious. | Level 0, later |
| [ ] | `cc_nudge2` | Whoever SYSOP is, they've been right so far. Maybe ask. | Stuck again. A little uneasy about trusting a stranger on a screen. | Level 0, later |
| [ ] | `l0_cc_peek_card` | Quick-start card for the scanner. Somebody's filled in the blanks. | Picked up a scanner's instruction card. Noticing handwriting on it. | Level 0, later |
| [ ] | `l0_cc_peek_n1a` | Scanners always come with instructions. Check round the keyboard. | Stuck for a minute. A practical thought. | Level 0, later |
| [ ] | `l0_cc_peek_n1b` | That scanner card had something written in by hand. | Stuck. Remembering the card you all read. | Level 0, later |
| [ ] | `l0_cc_peek_err` | Is that what the card called it? | The same name typed wrong twice. Gentle doubt. | Level 0, later |
| [ ] | `l0_cc_peek_pay` | Scraps of a memo. All jumbled up. | Seeing the result. Curious. | Level 0, later |
| [ ] | `l0_cc_memo_disc` | Every scrap's got a number. That's not an accident. | Spotting a pattern in the jumbled scraps. | Level 0, later |
| [ ] | `l0_cc_memo_n1a` | Didn't the scanner come with a card? It might say how the scraps are kept. | Stuck. Thinking back. | Level 0, later |
| [ ] | `l0_cc_memo_n1b` | The scanner card said something about numbering the scraps. | Stuck. Remembering the card. | Level 0, later |
| [ ] | `l0_cc_memo_back` | It reads backwards. We've got the ending first. | The memo came out in reverse, twice. Amused. | Level 0, later |
| [ ] | `l0_cc_memo_pay` | ...Don't look at him. Just don't look at him. | Whispered. The memo warns about the man standing right next to you. | Level 0, later |
| [ ] | `l0_cc_caller_order` | Work order's got a callback extension on it. | Reading the work order. Noticing a detail. | Level 0, later |
| [ ] | `l0_cc_caller_list` | A phone list. With extensions. | Finding a staff phone list. | Level 0, later |
| [ ] | `l0_cc_caller_n1a` | Rourke said the mailroom has the only phone list that's right. | Stuck. Remembering what the escort said. | Level 0, later |
| [ ] | `l0_cc_caller_n1b` | That phone list in the mailroom had everybody's extension. | Stuck. Remembering the list. | Level 0, later |
| [ ] | `l0_cc_caller_err` | Is that what the column's actually called? | The same column name wrong twice. Gentle doubt. | Level 0, later |
| [ ] | `l0_cc_caller_pay` | So that's who called us. Weird. | Uneasy. That isn't who you expected. | Level 0, later |
| [ ] | `l0_cc_book_disc` | Last page is torn out. Somebody didn't want their name in here. | Reading a visitor book. Suspicious. | Level 0, later |
| [ ] | `l0_cc_book_n1` | The book's only paper. The front desk computer might keep its own copy. | Stuck. A practical idea. | Level 0, later |
| [ ] | `l0_cc_book_pay` | Vale signed in. And never signed out. | Quietly. That's not good. | Level 0, later |
| [ ] | `l1_cc_log` | Night shift wrote down every alarm. That has to help. | Reading a shift log. Encouraged. | Level 1, later |
| [ ] | `l1_cc_sheet` | There's a sheet on the controllers in here. Hang on to that. | Finding a reference sheet. Pleased. | Level 1, later |
| [ ] | `l1_cc_nudge1_a` | Rourke said the night shift logs everything. Maybe they saw this happen. | Stuck for a minute. Remembering what the escort said. | Level 1, later |
| [ ] | `l1_cc_nudge1_b` | What did that shift log say the alarms were about? | Stuck. Thinking back to the log. | Level 1, later |
| [ ] | `l1_cc_err_table` | Is that what the sheet in here called it? | The same table name wrong twice. Gentle doubt. | Level 1, later |
| [ ] | `l1_cc_err_reset` | Nope. Wasn't there a note somewhere about what 'fault' actually means? | A second wrong reset. Frustrated, then thinking. | Level 1, later |
| [ ] | `l1_cc_payoff_1` | Every stuck door was in the same zone. Should've seen that sooner. | It clicks. A bit sheepish. | Level 1, later |
| [ ] | `l1_cc_payoff_2` | Same zone, still faulting. That was our guy. | At the right rack. Satisfied. | Level 1, later |
| [ ] | `l1_cc_hot_plate` | Fire interlock. There's a temperature limit on it. | Reading a warning plate on a door. | Level 1, later |
| [ ] | `l1_cc_hot_n1a` | Server Room B's loud. Some of those racks are working way too hard. | Stuck. Raising your voice over the fans. | Level 1, later |
| [ ] | `l1_cc_hot_n1b` | That monitoring card by the terminal said what counts as too hot. | Stuck. Remembering a card. | Level 1, later |
| [ ] | `l1_cc_hot_err` | We want the hot ones, not the cool ones, right? | The comparison the wrong way round, twice. Checking. | Level 1, later |
| [ ] | `l1_cc_hot_pay` | That one's cooking. No wonder it's loud. | Found the hot rack. Impressed. | Level 1, later |
| [ ] | `l2_cc_reader_card` | Every door up here logs who swipes in. | Reading a badge reader's card. Noting it. | Level 2, later |
| [ ] | `l2_cc_log_n1` | That card said the readers keep a log. Of everybody. | Stuck. Remembering the card. | Level 2, later |
| [ ] | `l2_cc_log_pay` | Wait. Read that again. Slowly. | Something in the result is very wrong. Cold. | Level 2, later |
| [ ] | `l2_cc_doorcard` | 'Controller zone.' That's a letter we can use. | Reading a door's card. Quick, under pressure. | Level 2, later |
| [ ] | `l2_cc_switch_err` | Not that one. What do the notes on the others say? | A second wrong switch, on a clock. Tense. | Level 2, later |
| [ ] | `l2_cc_door_pay` | Door's moving. Go, go! | Urgent. Get out now. | Level 2, later |
| [ ] | `l2_cc_camcard` | Camera system. There's a way to ask it what it sees. | Reading the camera system's card. | Level 2, later |
| [ ] | `l2_cc_cam_n1a` | Security booth. There's got to be something on how these cameras work. | Stuck. Looking around the booth. | Level 2, later |
| [ ] | `l2_cc_cam_n1b` | That camera card said how to ask the system. | Stuck. Remembering the card. | Level 2, later |
| [ ] | `l2_cc_cam_pay` | Something's moving out there. And it isn't us. | Quiet and scared. | Level 2, later |
| [ ] | `l2_cc_sheet` | Coffee all over this. One name's still readable. | Reading a stained sign-in sheet. | Level 2, later |
| [ ] | `l2_cc_pike_n1` | The sign-in sheet. One name wasn't smudged. | Stuck. Remembering the sheet. | Level 2, later |
| [ ] | `l2_cc_pike_err` | Is that how it's spelled on the sheet? | The same name misspelled twice. Gentle doubt. | Level 2, later |
| [ ] | `l2_cc_pike_pay` | No-show tonight. Lucky him. | Dry. Relieved for a stranger. | Level 2, later |
| [ ] | `l2_cc_lie` | It said it opened. It didn't open. | Staring at a door that should be open. Baffled. | Level 2, later |
| [ ] | `l2_cc_door_n1` | That door's got its name painted over it in red. Maybe the server knows it by that. | Stuck. Noticing the sign above the door. | Level 2, later |
| [ ] | `l2_cc_breaker_pay` | A breaker. Of course it's a breaker. | Relief, and a little laugh at yourself. | Level 2, later |
| [ ] | `l2_cc_roster` | Badge numbers, next to names. | Reading a roster board. Noting it. | Level 2, later |
| [ ] | `l2_cc_pin_n1a` | The badge readers log every swipe. Who left this floor last? | Stuck. Thinking it through. | Level 2, later |
| [ ] | `l2_cc_pin_n1b` | The last guard out had a badge number. Something up here matches those to names. | Stuck. Putting two things together. | Level 2, later |
| [ ] | `l2_cc_pin_err` | Wrong code. Is that the night lead, or just any guard? | A second wrong PIN. Thinking. | Level 2, later |
| [ ] | `l2_cc_pin_pay` | That's the code. Let's not hang around. | Keypad accepted it. Nervous, wants to move. | Level 2, later |
| [ ] | `l5_book_find` | No way. It's the same series. Somebody here bought the sequel. | Picking it up off a desk. Delighted, a little thrown. | Level 5, later |
| [ ] | `l5_book_open` | Okay. If the database won't take orders, we ask the building's services instead. Book says they're polite. Mostly. | Reading the back cover, hopeful. | Level 5, later |
| [ ] | `l5_huddle_post_1` | Chapter one. POST. You send it something, it makes something. Like a suggestion box that answers. | Starting a chapter, reading it out. | Level 5, later |
| [ ] | `l5_huddle_post_2` | So GET looks, POST makes. Got it. | Wrapping up, pleased it's simple. | Level 5, later |
| [ ] | `l5_huddle_patch_1` | PATCH. For changing one thing and leaving the rest alone. Says 'one thing' in bold. Twice. | Starting a chapter. Noticing how hard the book insists. | Level 5, later |
| [ ] | `l5_huddle_patch_2` | PATCH is UPDATE wearing a tie. | Wrapping up. Proud of the joke. | Level 5, later |
| [ ] | `l5_huddle_codes_1` | Every answer comes with a number. Book says read the number before you celebrate. | Starting a chapter. A little told off. | Level 5, later |
| [ ] | `l5_huddle_codes_2` | Two hundreds, good. Four hundreds, our fault. Five hundreds, theirs. | Wrapping up, counting it off. | Level 5, later |
| [ ] | `l5_huddle_keys_1` | Some services want a key with every request. It goes in the header, a little label on top. Like a badge, but typed. | Starting a chapter, working it out as you read. | Level 5, later |
| [ ] | `l5_huddle_keys_2` | So if it says 401, we forgot the badge. | Wrapping up. Got it. | Level 5, later |
| [ ] | `l5_huddle_check_1` | Short chapter. After you change something, ask again. Book says never trust the first answer. | Starting a short chapter. Knowing nod. | Level 5, later |
| [ ] | `l5_huddle_check_2` | Change it, then look again. The front doors taught us that one. | Wrapping up. Wry; you've been burned before. | Level 5, later |
| [ ] | `l6_book_find` | Easy JavaScript. Somebody's read this one to death. | Sliding it out from under a mug. The cover's stained and the pages are soft. | Level 6, later |
| [ ] | `l6_book_open` | Typing every request by hand is going to get us killed. Book says a script does it for you. On repeat. | Tired of typing. This sounds like rescue. | Level 6, later |
| [ ] | `l6_huddle_if_1` | A variable's a labelled box. If is a fork in the road. That's... honestly fine. | Starting a chapter. Braced for hard; it isn't. | Level 6, later |
| [ ] | `l6_huddle_if_2` | Box, fork. I can do box and fork. | Wrapping up, to yourself. | Level 6, later |
| [ ] | `l6_huddle_loops_1` | Loops. Do the same thing again and again. Book says put a wait in, or it does it a million times a second. And log what it did, so you can see. | Starting a chapter. The 'million times a second' bit alarms you. | Level 6, later |
| [ ] | `l6_huddle_loops_2` | Always put the wait in. Always log it. Writing that one down. | Wrapping up, making a note. | Level 6, later |
| [ ] | `l6_huddle_functions_1` | Functions. Write it once, give it a name, use it anywhere. | Starting a chapter, reading it out. | Level 6, later |
| [ ] | `l6_huddle_functions_2` | So a function's a recipe we can shout. | Wrapping up. Pleased with that. | Level 6, later |
| [ ] | `l6_huddle_lists_1` | Lists. A whole line of things in one box. Loop over it and you've done them all. | Starting a chapter. The penny drops halfway. | Level 6, later |
| [ ] | `l6_huddle_lists_2` | One loop, every door. That's either brilliant or terrifying. | Wrapping up. Genuinely unsure which. | Level 6, later |
| [ ] | `l6_huddle_test_1` | Last chapter: run it on the test bench first. And write an assertion: a line that says what should be true, and shouts if it isn't. | Starting the last chapter. Taking it seriously. | Level 6, later |
| [ ] | `l6_huddle_test_2` | Test first. We've all learned that one the hard way tonight. | Wrapping up. Rueful. | Level 6, later |
| [ ] | `l8_book_find` | Hello HTML! Same series again. Who keeps leaving these? | Pulling it from behind the handrail. Uneasy, half joking. | Level 8, later |
| [ ] | `l8_book_open` | Book says everything on a screen is built from tags. And the building's been drawing things that aren't there. So... we fix the drawing. | Working it out as you go. The pause is the idea landing. | Level 8, later |
| [ ] | `l8_huddle_elements_1` | Tags. Angle brackets. You open one, you close one. Like a sandwich. The inspector shows you every one on the screen. | Starting a chapter, reading it out. | Level 8, later |
| [ ] | `l8_huddle_elements_2` | Everything's a sandwich. Okay. | Wrapping up. Accepting it. | Level 8, later |
| [ ] | `l8_huddle_hidden_1` | Attributes. Little settings on a tag. Including one called hidden. | Starting a chapter. 'Hidden' catches your eye. | Level 8, later |
| [ ] | `l8_huddle_hidden_2` | Hidden doesn't mean gone. Hidden means somebody hid it. | Wrapping up. Quieter; that thought sticks. | Level 8, later |
| [ ] | `l8_huddle_css_1` | CSS. Where things go and what they look like. The book calls it the paint. | Starting a chapter, reading it out. | Level 8, later |
| [ ] | `l8_huddle_css_2` | So if a wall's in the wrong place, it might just be the paint. | Wrapping up. Half hopeful. | Level 8, later |
| [ ] | `l8_huddle_display_1` | Two ways to make something vanish. One leaves a gap, one doesn't. Book says that matters. | Starting a chapter. Curious. | Level 8, later |
| [ ] | `l8_huddle_display_2` | So when something vanishes, ask which kind of vanished. | Wrapping up, filing it away. | Level 8, later |
| [ ] | `l8_huddle_layers_1` | Things on a screen stack up, like papers on a desk. A number decides which one's on top. | Starting a chapter, picturing it. | Level 8, later |
| [ ] | `l8_huddle_layers_2` | So the thing in our way might just be lying on top. | Wrapping up. An idea forming. | Level 8, later |
| [ ] | `l8_huddle_forms_1` | Forms. Boxes you type in, and a button that sends it. Every login screen tonight was one of these. | Starting the last chapter. Recognising it. | Level 8, later |
| [ ] | `l8_huddle_forms_2` | A form's just boxes and a button. Somebody built it, so we can rebuild it. | Wrapping up. Quietly determined. | Level 8, later |

## Harold Mercer (5 lines)

> Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.

| Done | File | Line | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_tape_1` | Harold Mercer. March of '94. My last day, apparently. | Click of the record button before this. Dry. | Level 0 |
| [ ] | `l0_tape_2` | If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors. | Approving, a little smile. | Level 0 |
| [ ] | `l0_tape_3` | Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out. | The one moment of anger, still controlled. | Level 0 |
| [ ] | `l0_tape_4` | So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter. | Quiet, almost proud, then wry on the last sentence. | Level 0 |
| [ ] | `l0_tape_5` | If it ever comes to that, look for my plans. The building's records remember more than people do. | Slow. Then the click of the stop button. | Level 0 |

## Crew barks (132 lines)

Each crew member's own short lines, in their own folder.

| Done | File | Line | When it plays |
|---|---|---|---|
| [ ] | `crew_dana/crew_ready.wav` | Let's get this over with. | the van ready-up |
| [ ] | `crew_dana/crew_over_here.wav` | Chief. Over here. | calling the crew over |
| [ ] | `crew_dana/crew_found_something.wav` | Got something. | a clue pickup that has no written discovery line |
| [ ] | `crew_dana/crew_huddle.wav` | Everyone, quick. Look at this. | starting a notes huddle |
| [ ] | `crew_dana/crew_need_boost.wav` | Give us a leg up? | asking for shoulders |
| [ ] | `crew_dana/crew_on_my_way.wav` | Coming. | answering a call |
| [ ] | `crew_dana/crew_scared.wav` | Nope. Nope. | something jumps out |
| [ ] | `crew_dana/crew_help.wav` | Little help! | downed or caught |
| [ ] | `crew_dana/crew_thanks.wav` | Cheers, chief. | helped up or boosted |
| [ ] | `crew_dana/crew_no_way.wav` | Not getting through that. | a locked door or a blocked route |
| [ ] | `crew_dana/crew_quiet.wav` | Shh. Something's here. | radio, something's near |
| [ ] | `crew_priya/crew_ready.wav` | Ooh, okay. Ready, ready! | the van ready-up |
| [ ] | `crew_priya/crew_over_here.wav` | Guys! Over here, come look! | calling the crew over |
| [ ] | `crew_priya/crew_found_something.wav` | Oh, this is something! | a clue pickup that has no written discovery line |
| [ ] | `crew_priya/crew_huddle.wav` | Huddle! Huddle up! | starting a notes huddle |
| [ ] | `crew_priya/crew_need_boost.wav` | Can somebody lift me? I'm tiny. | asking for shoulders |
| [ ] | `crew_priya/crew_on_my_way.wav` | On my way, on my way! | answering a call |
| [ ] | `crew_priya/crew_scared.wav` | Oh my God. Oh my God. | something jumps out |
| [ ] | `crew_priya/crew_help.wav` | Help! Help me! | downed or caught |
| [ ] | `crew_priya/crew_thanks.wav` | You're the best. | helped up or boosted |
| [ ] | `crew_priya/crew_no_way.wav` | Okay, that's locked. Rude. | a locked door or a blocked route |
| [ ] | `crew_priya/crew_quiet.wav` | Guys. Whisper. Something's moving. | radio, something's near |
| [ ] | `crew_rosa/crew_ready.wav` | Seatbelts, everyone. | the van ready-up |
| [ ] | `crew_rosa/crew_over_here.wav` | Over here, please. Today. | calling the crew over |
| [ ] | `crew_rosa/crew_found_something.wav` | Well, now. Look at this. | a clue pickup that has no written discovery line |
| [ ] | `crew_rosa/crew_huddle.wav` | Everybody gather round. | starting a notes huddle |
| [ ] | `crew_rosa/crew_need_boost.wav` | A hand up, if someone would be so kind. | asking for shoulders |
| [ ] | `crew_rosa/crew_on_my_way.wav` | I'm coming. Don't touch anything. | answering a call |
| [ ] | `crew_rosa/crew_scared.wav` | Mother of God. | something jumps out |
| [ ] | `crew_rosa/crew_help.wav` | Somebody! Now! | downed or caught |
| [ ] | `crew_rosa/crew_thanks.wav` | Thank you. Noted. | helped up or boosted |
| [ ] | `crew_rosa/crew_no_way.wav` | That's not opening for us. | a locked door or a blocked route |
| [ ] | `crew_rosa/crew_quiet.wav` | Quiet. All of you. | radio, something's near |
| [ ] | `crew_kit/crew_ready.wav` | Let's go, let's go. | the van ready-up |
| [ ] | `crew_kit/crew_over_here.wav` | Up here! Come on! | calling the crew over |
| [ ] | `crew_kit/crew_found_something.wav` | Ha. Found it. | a clue pickup that has no written discovery line |
| [ ] | `crew_kit/crew_huddle.wav` | Okay, team talk. Quick. | starting a notes huddle |
| [ ] | `crew_kit/crew_need_boost.wav` | Boost me. I've got the rest. | asking for shoulders |
| [ ] | `crew_kit/crew_on_my_way.wav` | Two seconds! | answering a call |
| [ ] | `crew_kit/crew_scared.wav` | Whoa, whoa, whoa! | something jumps out |
| [ ] | `crew_kit/crew_help.wav` | I'm caught! Get it off! | downed or caught |
| [ ] | `crew_kit/crew_thanks.wav` | Owe you one. | helped up or boosted |
| [ ] | `crew_kit/crew_no_way.wav` | Dead end. Find another way. | a locked door or a blocked route |
| [ ] | `crew_kit/crew_quiet.wav` | Stop. Don't move. | radio, something's near |
| [ ] | `crew_june/crew_ready.wav` | Ready when you are. Over. | the van ready-up |
| [ ] | `crew_june/crew_over_here.wav` | To me, please. Over here. | calling the crew over |
| [ ] | `crew_june/crew_found_something.wav` | I have something. Come and see. | a clue pickup that has no written discovery line |
| [ ] | `crew_june/crew_huddle.wav` | Let's all stop and think a moment. | starting a notes huddle |
| [ ] | `crew_june/crew_need_boost.wav` | I'll need a lift up there, dear. | asking for shoulders |
| [ ] | `crew_june/crew_on_my_way.wav` | Copy. On my way. | answering a call |
| [ ] | `crew_june/crew_scared.wav` | Good heavens! | something jumps out |
| [ ] | `crew_june/crew_help.wav` | Mayday! Mayday! | downed or caught |
| [ ] | `crew_june/crew_thanks.wav` | Much obliged. | helped up or boosted |
| [ ] | `crew_june/crew_no_way.wav` | Negative. That's sealed. | a locked door or a blocked route |
| [ ] | `crew_june/crew_quiet.wav` | Radio silence. Something's close. | radio, something's near |
| [ ] | `crew_mei/crew_ready.wav` | I'm ready. I'm not ready. I'm ready. | the van ready-up |
| [ ] | `crew_mei/crew_over_here.wav` | Over here! Before I chicken out! | calling the crew over |
| [ ] | `crew_mei/crew_found_something.wav` | Is this something? I think this is something. | a clue pickup that has no written discovery line |
| [ ] | `crew_mei/crew_huddle.wav` | Can we huddle? I want to huddle. | starting a notes huddle |
| [ ] | `crew_mei/crew_need_boost.wav` | Lift me up? Don't drop me. | asking for shoulders |
| [ ] | `crew_mei/crew_on_my_way.wav` | Coming! Slowly! But coming! | answering a call |
| [ ] | `crew_mei/crew_scared.wav` | Nope! Absolutely not! | something jumps out |
| [ ] | `crew_mei/crew_help.wav` | Help! Help, help, help! | downed or caught |
| [ ] | `crew_mei/crew_thanks.wav` | Oh, thank God. Thank you. | helped up or boosted |
| [ ] | `crew_mei/crew_no_way.wav` | Locked. Great. Love that. | a locked door or a blocked route |
| [ ] | `crew_mei/crew_quiet.wav` | Shh. Do you hear that? | radio, something's near |
| [ ] | `crew_marcus/crew_ready.wav` | Alright. Let's do this right. | the van ready-up |
| [ ] | `crew_marcus/crew_over_here.wav` | Over here. Stay together. | calling the crew over |
| [ ] | `crew_marcus/crew_found_something.wav` | Hold up. Found something. | a clue pickup that has no written discovery line |
| [ ] | `crew_marcus/crew_huddle.wav` | Everybody, eyes here. | starting a notes huddle |
| [ ] | `crew_marcus/crew_need_boost.wav` | Need a boost up. | asking for shoulders |
| [ ] | `crew_marcus/crew_on_my_way.wav` | Moving to you. | answering a call |
| [ ] | `crew_marcus/crew_scared.wav` | Back up! Back up! | something jumps out |
| [ ] | `crew_marcus/crew_help.wav` | Man down! Need help! | downed or caught |
| [ ] | `crew_marcus/crew_thanks.wav` | Appreciate it. | helped up or boosted |
| [ ] | `crew_marcus/crew_no_way.wav` | Locked tight. Try another way. | a locked door or a blocked route |
| [ ] | `crew_marcus/crew_quiet.wav` | Hold. Something's moving. | radio, something's near |
| [ ] | `crew_theo/crew_ready.wav` | Loading in. | the van ready-up |
| [ ] | `crew_theo/crew_over_here.wav` | Yo. Over here. | calling the crew over |
| [ ] | `crew_theo/crew_found_something.wav` | Ooh. Loot. | a clue pickup that has no written discovery line |
| [ ] | `crew_theo/crew_huddle.wav` | Team meeting. Strategy time. | starting a notes huddle |
| [ ] | `crew_theo/crew_need_boost.wav` | Boost me? Classic co-op move. | asking for shoulders |
| [ ] | `crew_theo/crew_on_my_way.wav` | Omw. | answering a call |
| [ ] | `crew_theo/crew_scared.wav` | What is THAT?! | something jumps out |
| [ ] | `crew_theo/crew_help.wav` | I'm down! Revive me! | downed or caught |
| [ ] | `crew_theo/crew_thanks.wav` | GG. Thanks. | helped up or boosted |
| [ ] | `crew_theo/crew_no_way.wav` | Locked. Obviously. | a locked door or a blocked route |
| [ ] | `crew_theo/crew_quiet.wav` | Stealth section. Shh. | radio, something's near |
| [ ] | `crew_sam/crew_ready.wav` | Ready. | the van ready-up |
| [ ] | `crew_sam/crew_over_here.wav` | Over here, folks. | calling the crew over |
| [ ] | `crew_sam/crew_found_something.wav` | This look important to you? | a clue pickup that has no written discovery line |
| [ ] | `crew_sam/crew_huddle.wav` | Let's slow down and look. | starting a notes huddle |
| [ ] | `crew_sam/crew_need_boost.wav` | Gonna need help with this one. | asking for shoulders |
| [ ] | `crew_sam/crew_on_my_way.wav` | Coming your way. | answering a call |
| [ ] | `crew_sam/crew_scared.wav` | Whoa. Easy. Easy. | something jumps out |
| [ ] | `crew_sam/crew_help.wav` | Need a hand here! | downed or caught |
| [ ] | `crew_sam/crew_thanks.wav` | Thank you, friend. | helped up or boosted |
| [ ] | `crew_sam/crew_no_way.wav` | That won't budge. And I tried. | a locked door or a blocked route |
| [ ] | `crew_sam/crew_quiet.wav` | Hush, now. Listen. | radio, something's near |
| [ ] | `crew_luis/crew_ready.wav` | Vámonos. | the van ready-up |
| [ ] | `crew_luis/crew_over_here.wav` | Hey, hey. Over here. | calling the crew over |
| [ ] | `crew_luis/crew_found_something.wav` | Look what I found. | a clue pickup that has no written discovery line |
| [ ] | `crew_luis/crew_huddle.wav` | Okay, everybody. Think. | starting a notes huddle |
| [ ] | `crew_luis/crew_need_boost.wav` | Give an old man a lift? | asking for shoulders |
| [ ] | `crew_luis/crew_on_my_way.wav` | I'm coming, I'm coming. | answering a call |
| [ ] | `crew_luis/crew_scared.wav` | ¡Ay, Dios mío! | something jumps out |
| [ ] | `crew_luis/crew_help.wav` | Help me! Quick! | downed or caught |
| [ ] | `crew_luis/crew_thanks.wav` | Gracias, mijo. | helped up or boosted |
| [ ] | `crew_luis/crew_no_way.wav` | Locked. Maybe we turn it off and on? | a locked door or a blocked route |
| [ ] | `crew_luis/crew_quiet.wav` | Shh. Something's out there. | radio, something's near |
| [ ] | `crew_ike/crew_ready.wav` | Let's disrupt this. | the van ready-up |
| [ ] | `crew_ike/crew_over_here.wav` | Over here. Let's sync. | calling the crew over |
| [ ] | `crew_ike/crew_found_something.wav` | Okay, this is a key insight. | a clue pickup that has no written discovery line |
| [ ] | `crew_ike/crew_huddle.wav` | Quick stand-up, everybody. | starting a notes huddle |
| [ ] | `crew_ike/crew_need_boost.wav` | Can I get some lift? Literally. | asking for shoulders |
| [ ] | `crew_ike/crew_on_my_way.wav` | Pivoting to you. | answering a call |
| [ ] | `crew_ike/crew_scared.wav` | Oh no. Oh no no no. | something jumps out |
| [ ] | `crew_ike/crew_help.wav` | This is a blocker! Help! | downed or caught |
| [ ] | `crew_ike/crew_thanks.wav` | Huge. Thank you. | helped up or boosted |
| [ ] | `crew_ike/crew_no_way.wav` | Hard blocker. Locked. | a locked door or a blocked route |
| [ ] | `crew_ike/crew_quiet.wav` | Okay, nobody talk. | radio, something's near |
| [ ] | `crew_walt/crew_ready.wav` | Let's get it done. | the van ready-up |
| [ ] | `crew_walt/crew_over_here.wav` | Over here. Come on. | calling the crew over |
| [ ] | `crew_walt/crew_found_something.wav` | Huh. Lookit this. | a clue pickup that has no written discovery line |
| [ ] | `crew_walt/crew_huddle.wav` | Everybody stop. Think. | starting a notes huddle |
| [ ] | `crew_walt/crew_need_boost.wav` | Bad shoulder. Give me a hand up. | asking for shoulders |
| [ ] | `crew_walt/crew_on_my_way.wav` | Hold your horses. Coming. | answering a call |
| [ ] | `crew_walt/crew_scared.wav` | Jesus, Mary and Joseph! | something jumps out |
| [ ] | `crew_walt/crew_help.wav` | Somebody! Get it off me! | downed or caught |
| [ ] | `crew_walt/crew_thanks.wav` | Mm. Thanks. | helped up or boosted |
| [ ] | `crew_walt/crew_no_way.wav` | That's not opening. | a locked door or a blocked route |
| [ ] | `crew_walt/crew_quiet.wav` | Shut it. Listen. | radio, something's near |
