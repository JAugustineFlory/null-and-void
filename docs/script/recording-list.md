# Recording list

1221 recordings in all, 1524 lines.

Generated from `scripts/audio/voice_lines.gd`. The full script with scene context is in [script.md](script.md).

## How to record

Each actor gets only their own character's script from [characters/](characters/), which has the same recording spec:

- **Format:** WAV, mono, 48 kHz, 16- or 24-bit.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two of each recording, in separate files: `<file name>.wav` and `<file name>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Pauses:** in a recording with more than one line, a full second of silence between the lines, longer than any pause inside a line.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Returned files go in `audio/voice/<character>/` (for example `audio/voice/rourke/l0_greet_1.wav`). Then run `godot --headless -s tools/split_voice_blocks.gd`: it cuts each `_block` recording at its pauses into one file per line, which is what the game plays, so every line keeps its own subtitle and can be redone on its own. Open the project in Godot once so it imports them. The game plays a recording whenever one exists, keeps the subtitle up for as long as it lasts, and falls back to the timed subtitle when it doesn't. Takes named `_take2` are never played: to use take 2, rename it.

Recordings marked **later** are written ahead for a level that isn't built yet. Record them whenever, or wait until the level is in.

## Dale Rourke (43 recordings, 77 lines)

> Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth. He laughs once, in the lab: the only time his warmth turns into real glee.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_greet_1_block` | "There you are. Dale Rourke, facilities. I'll be your escort tonight." "Badge rules after hours. You don't go anywhere I don't take you." "Come on in. I'll sign you in at the front desk." | Friendly, a handshake in the voice. Still smiling. Should sound like a joke the first time and a threat on replay. Holding the door, waving them through. | Level 0 |
| [ ] | `l0_greet_2_block` | "Sorry about that. The company loves its PA system." "Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me." "Visitor badges. Keep them on you. Doors upstairs won't let you through without one." | Chuckling. Casual, reassuring. Nothing to worry about. (On a replay it lands differently.) Routine. Helpful, a little bored. | Level 0 |
| [ ] | `l0_tour_1_block` | "Here's the job. Dr. Vale, our lead engineer, went missing three nights ago." "Her systems are a mess and the director wants them recovered by morning. Quietly." "The front desk scanner ate one of Vale's memos. The scraps went into a table." "Director wants to know what it said. Go ahead, terminal's on the desk." | Matter-of-fact, the way you'd mention the weather. Small beat before "Quietly." Getting down to business. Casual, but he wants to know too. | Level 0 |
| [ ] | `l0_memo_flag_block` | "Nice work. I'll make sure that goes straight to the director." "...Huh. She always was dramatic." "One thing on your paperwork. It says I called you in. I didn't. That call came from building services." "Want to know who? The staff directory's on that terminal." "Mailroom. Clerk's got the only phone list in this building that's actually up to date. She pinned it to the wall so nobody walks off with it." | Pleased, before he's even read it. Warm; on a replay it's the worst thing he says all night. A beat too long before he speaks. Covering. Mild, a little puzzled. Not suspicious yet. Helpful, easygoing. Amused, a little fond. | Level 0 |
| [ ] | `l0_caller_3_block` | "Mercer? Huh. That line's been dead for years. Somebody's having fun with the phones. Anyway." "Grab the walkie-talkies from lost and found, back behind the desk." "And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either." "Grab one and I'll take you to the server room." | A beat of real surprise, then he brushes it off and moves on. Back to friendly, changing the subject. Amused, he's said this to every visitor. A little eye-roll at corporate. Friendly. | Level 0 |
| [ ] | `l0_walkie` | "Channel one. Keep them on. Reception's lousy once we're past the shutter. This way." | Offhand. | Level 0 |
| [ ] | `l0_mailroom_2` | "Don't touch the outgoing tray. Last guy who did got a memo about it." | Mock-serious. | Level 0 |
| [ ] | `l0_coffee` | "Machine's been eating quarters since '94. Watch. ... There. Coffee's on me. Don't tell facilities." | Proud of the trick. | Level 0 |
| [ ] | `l0_boost_1` | "Panel's stuck up top? Here, step on my hands. I've got you." | Easy, practised. | Level 0 |
| [ ] | `l0_boost_2` | "See? Teamwork." | Brushing his hands off. | Level 0 |
| [ ] | `l0_hum` | "Don't mind the hum down that way. Old transformer. There's been a ticket open on it since before my time." | Near the dark east corridor. Casual, but he doesn't look down it. | Level 0 |
| [ ] | `l0_cover` | "They're with me. Escort's right here." | Covering for them like a friend. | Level 0 |
| [ ] | `l0_elevator` | "Server floor's up on fourteen. Elevator's slow, but it gets there." | At the elevator bank, holding the door. | Level 0 |
| [ ] | `l0_lift_button` | "Press fourteen for me, would you? Server floor." | Easy, polite. | Level 0 |
| [ ] | `l0_tour_3_block` | "Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings." "Board fired him when they installed WARDEN. That's the AI that runs the campus now." "Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable." "Ghost stories. Anyway." | Tour-guide mode, enjoying himself. Still chatting to the crew, a little proud of the trivia. Spooky-campfire voice, playing it up. Dropping it fast. He doesn't want them thinking about it. | Level 0 |
| [ ] | `l0_sra` | "Here we are. Server Room A." | Pleasant, like the end of a tour. | Level 0 |
| [ ] | `l1_enter` | "In you come. Terminal's just over here." | Calling back over his shoulder, inside the room. | Level 1 |
| [ ] | `l1_terminal` | "Here's our database problem. One of the door controllers on this floor keeps faulting, and half the doors up here won't open till it's reset. Hopefully it's a quick fix." | Mundane, a facilities guy with a real problem. Hopeful. | Level 1 |
| [ ] | `l1_noc_1` | "That's the NOC. Network operations. Night shift logs everything in there. Every alarm, every coffee break." | Easy, tour-guide tone. | Level 1 |
| [ ] | `l1_noc_2` | "Night shift's not in tonight. Their log's still on the desk, though. They write it all down, whether anyone reads it or not." | Only if a player goes into the NOC. Leaning in the doorway. | Level 1 |
| [ ] | `l1_waiting` | "Take your time. I've been staring at that rack for a week." | Patient. | Level 1 |
| [ ] | `l1_badge_help` | "Reset wants a badge? Here, use mine." | Helpful, no hesitation. | Level 1 |
| [ ] | `l1_wrong_panel` | "Nope, panel's not having it. Try another?" | No blame. | Level 1 |
| [ ] | `l1_fixed_1_block` | "Would you look at that. Green across the board. Six months I've been filing tickets on that thing." "You lot are good. Director's going to want to hear about this." | Genuinely impressed. Warm. On a replay, the director hearing about them is the problem. | Level 1 |
| [ ] | `l1_pivot_1_block` | "Hang on. That fault log... every reset this week came from Vale's login." "Her lab's up on the security floor. Secure Lab B." "Come on. If anyone can tell us what she was up to, it's her own terminal. Elevator works now, thanks to you." | Curious, a little too quickly. Thinking out loud. Friendly, steering. | Level 1 |
| [ ] | `l1_lift_button` | "Twenty-two. Security floor. Go on." | A little clipped now, eager to get there. | Level 1 |
| [ ] | `l2_lab_arrive_block` | "Secure Lab B. Vale practically lived in here." "Badge in for me, each of you. Visitor log. Security floor's fussy about it." | Fond, a little sad. Routine. The frame happens in plain sight. | Level 2, later |
| [ ] | `l2_lab_badge_2` | "Thanks. Paperwork keeps everybody honest." | Once everyone has badged. | Level 2, later |
| [ ] | `l2_lab_shock_1_block` | "Oh, no. No, no. Iris?" "That's her coat. She never leaves without her coat." "Her terminal's still logged in. Check it, see what she was working on. I'll call this in." | Fake shock. Good enough to fool them the first time, a beat too rehearsed on a replay. Quiet, staring at it. Backing toward the door, already reaching for his radio. | Level 2, later |
| [ ] | `l2_frame_block` | "Intruders in Secure Lab B. Contractors. They've hurt Dr. Vale." "Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself." "You want to know when I knew? The front desk. You read that terminal like a menu in a foreign language." "Then I saw the book in your van. Easy SQL. Still had the price sticker on it." "Some outfit nobody's heard of underbids every firm in the city, and sends a crew who learned databases last weekend." "I should've reported you. Then it hit me. No... this is perfect." "A group of idiots posing as IT comes in and accidentally kills Vale! Hahaha!" "A garage with a van, calling itself a company. Your badges on her door. It writes itself." | To WARDEN, heard through the door and on the crew's walkies. Urgent and breathless: a perfect performance. Tired, explaining a chore. Almost fond. The friendly tour voice, which is what makes it awful. Shaking his head, smiling. Enjoying himself. Slower. Savouring it. The only time he laughs in the game: real delight, loud and sudden, then it stops dead. Flat again, tired. Back to normal. | Level 2, later |
| [ ] | `l2_trap_1` | "Sorry about this. Nothing personal." | Quiet. | Level 2, later |
| [ ] | `l2_return` | "Should've checked the other door." | Calm. | Level 2, later |
| [ ] | `l2_hit_prints` | "Go on, touch everything. Your prints are all over her desk now." | Taunting. Can repeat. | Level 2, later |
| [ ] | `l2_hit_1` | "Stay down!" | Swinging. | Level 2, later |
| [ ] | `l2_hit_2` | "Should've stayed in the van." | Breathing hard. | Level 2, later |
| [ ] | `l2_hit_3` | "Nobody's coming for you." | Low. | Level 2, later |
| [ ] | `l2_hit_4` | "Hold still!" | Frustrated. | Level 2, later |
| [ ] | `l2_hurt_1` | "Agh!" | Just a grunt of pain. | Level 2, later |
| [ ] | `l2_hurt_2` | "Okay. Okay, that one hurt." | Winded, almost laughing. | Level 2, later |
| [ ] | `l2_hurt_3` | "Lucky." | Spat out. | Level 2, later |
| [ ] | `l2_downed` | "Wait... wait. You don't know what you're doing." | Out of breath. Genuinely scared for the first time. | Level 2, later |
| [ ] | `l2_tied_1_block` | "You think a bit of cable holds me?" "WARDEN will eat you alive in here." "Run if you like. Every camera on this floor already thinks you killed her." | Tied up on the floor, grinning through it. Quieter. He means it. Smiling. The frame, said out loud. | Level 2, later |
| [ ] | `l2_rourke_1_block` | "Still on channel one? Good. Thought you'd want to know I'm out." "Security office is the only way down from here. Say hi to the night guard for me." "Oh, he won't say much. Nobody's seen him since Tuesday." | Relaxed, enjoying himself again. Casual, like giving directions. Let it hang. Then the radio clicks off. | Level 2 |

## WARDEN (38 recordings, 50 lines)

> Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_killed` | "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN." | Unbothered, like reading a stock price. | Level 2, later |
| [ ] | `l2_contain_1` | "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW--" | Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off. | Level 2, later |
| [ ] | `l2_contain_2` | "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE." | From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later. | Level 2, later |
| [ ] | `l2_login` | "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE." | The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant. | Level 2, later |
| [ ] | `l2_selftest` | "SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM." | The one line with a hint of a smirk. | Level 2, later |
| [ ] | `l2_found` | "QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY." | Reading a rule it knows they're about to break. Cool. | Level 2, later |
| [ ] | `l2_no_badge` | "RESET REFUSED. BADGE REQUIRED." | Flat, instant. | Level 2, later |
| [ ] | `l2_panel_ok` | "RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?" | Patient, then a small dig. | Level 2, later |
| [ ] | `l2_panel_wrong` | "UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS." | The last sentence slightly slower. | Level 2, later |
| [ ] | `l2_exit_open` | "CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED." | Polite, and keeping score. | Level 2, later |
| [ ] | `l2_lockdown_tied` | "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D." | Reading a log entry. | Level 2, later |
| [ ] | `l2_sealed` | "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT." | The sign-off for the slice. Warm, like wishing them well. | Level 2, later |
| [ ] | `l2_arrive_block` | "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE." "CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF." | Reassuring tone. It is not reassuring. Small pause before the second sentence. | Level 2 |
| [ ] | `l2_smudged` | "TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU." | Not unfortunate for WARDEN. | Level 2 |
| [ ] | `l2_door_ok` | "DOOR COMMAND ACCEPTED. DOOR OPENED." | Confident. It is wrong. | Level 2 |
| [ ] | `l2_door_fault` | "ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING." | When the crew finds the fault themselves. Deadpan, unapologetic. | Level 2 |
| [ ] | `l4_epsilon_1_block` | "CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT." "ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE." "ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL." | Flat and slow. A short pause after. Even pauses between sentences, like reading a checklist. No change in tone for 'not a drill'. That's the frightening part. | Level 4 |
| [ ] | `l4_epsilon_loop` | "REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE." | Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only. | Level 4 |
| [ ] | `l4_epsilon_loop_2` | "REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE." | Takes turns with the other reminder, once writes have been suspended. Same polite loop. | Level 4 |
| [ ] | `l4_epsilon_db` | "DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY." | The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint. | Level 4 |
| [ ] | `l4_write_refused` | "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON." | The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal. | Level 4 |
| [ ] | `l4_write_refused_tease` | "YOU MAY STILL LOOK. LOOKING IS FREE." | A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud. | Level 4 |
| [ ] | `l4_write_refused_again` | "STILL READ-ONLY." | Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat. | Level 4 |
| [ ] | `l4_arrive` | "VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING." | Flat. Waits until the tape has finished, on purpose; the politeness is the point. | Level 4 |
| [ ] | `l4_all_circuits` | "ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE." | The automatic announcement: flat and procedural. | Level 4 |
| [ ] | `l4_all_circuits_tease` | "ALL OF THEM. IMPRESSIVE." | A separate beat, after a pause: his own voice. Dry. | Level 4 |
| [ ] | `l4_signed_in` | "CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN." | The automatic announcement only. Polite, procedural. | Level 4 |
| [ ] | `l4_upgrade_1` | "CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED." | The automatic announcement: flat, like reading a log entry. | Level 4 |
| [ ] | `l4_upgrade_2` | "I HAVE ADAPTED." | After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big. | Level 4 |
| [ ] | `l4_over_pa_1_block` | "SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT." "NOBODY CARES ABOUT THE FRIDGE." | The automatic announcement, over the tape. He doesn't wait for it any more. His own voice, over the tape. Irritated, dry. | Level 4 |
| [ ] | `l4_bay_sealed_block` | "LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED." "FINALLY. SOMETHING PUT BACK WHERE IT BELONGS." | The automatic announcement: flat and procedural. A separate beat, his own voice. Almost pleased. | Level 4 |
| [ ] | `l4_stairs_block` | "REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS." "NOT THAT YOU COULD." | The automatic announcement: a routine safety reminder. A separate beat, his own voice. Teasing; the lifts are already off. | Level 4 |
| [ ] | `l5_arrive_block` | "VISITORS ON FLOOR NINE. NO ESCORT ON RECORD. NONESSENTIAL CIRCUITS HAVE BEEN SHED UNDER PROTOCOL EPSILON." "THE NIGHT SHIFT WILL BE SO PLEASED TO SEE YOU." | Flat, over the tape's last word. The cause, never the fix. A separate beat, his own voice. He knows what's sitting at the desks. | Level 5 |
| [ ] | `l5_power_back_block` | "LOAD SHEDDING ON FLOOR NINE HAS BEEN OVERRIDDEN. THIS HAS BEEN LOGGED." "YOU TURNED SOMETHING OFF TO DO IT. I NOTICED." | The announcement, as the lights come up. A separate beat. Almost approving. | Level 5 |
| [ ] | `l5_air_back_block` | "AIR HANDLER NINE IS RUNNING. WORK ORDER ACKNOWLEDGED." "BREATHE. YOU HAVE EARNED IT." | The announcement, over the fan spinning up. A separate beat. Dry. | Level 5 |
| [ ] | `l5_dock_open_block` | "LOADING DOOR OPEN ON FLOOR NINE AFTER HOURS. THIS IS A VIOLATION." "WHOEVER ASKED YOU TO DO THAT IS NOT ON MY LIST." | The announcement, as the door swings onto nothing. A separate beat. He knows exactly who asked. | Level 5 |
| [ ] | `l5_radio_checked_block` | "BADGE LOG CONSULTED. PERSONNEL THANKS YOU FOR VERIFYING." "VOICES LIE. RECORDS DO NOT. USUALLY." | The announcement, after the crew reads the voice's badge back. A separate beat. The last word is the one that matters. | Level 5 |
| [ ] | `l5_secured_block` | "FLOOR NINE IS SECURED. ESCORT PASSES LOGGED. ALL DOORS LOCKED." "TWO OF THEM WERE REAL. THE OTHERS ARE STILL HERE." | The announcement, as STAIR 2 releases. A separate beat. Flat. Not a threat; a fact. | Level 5 |

## WARDEN (PA tapes) (5 recordings, 6 lines)

> A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [x] | `l0_pa_1_block` | "Good evening! Halcyon Data Systems is now closed." "Visitors must remain with their escort at all times. Thank you for your cooperation!" | Pleasant, like a store closing announcement. Same announcement, continuing. | Level 0 |
| [x] | `l0_sort_hint` | "Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon!" | A canned reminder that plays every hour. Proud of the company, unaware of anyone listening. | Level 0 |
| [ ] | `l4_arrive_pa` | "Welcome to floor ten, Plant and Power! Hard hats are by the door. Safety is everybody's job!" | The cheerful recorded tape, as on the ground floor. | Level 4 |
| [ ] | `l4_pa_fridge` | "Friendly reminder! The break room fridge is cleaned out every Friday, so please label your lunch—" | The cheerful recorded tape. It keeps playing underneath when he talks over it. | Level 4 |
| [ ] | `l5_arrive_pa` | "Welcome to floor nine, Personnel! Payroll questions? We're here for you, nine to five!" | The cheerful tape. Nobody is here for anybody. | Level 5 |

## Dr. Iris Vale (1 recordings, 3 lines)

> Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_vale_1_block` | "Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry." "If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it." "And please don't give your PIN to anyone. Not even Dale." | Beep before this. Hushed, fast. Urgent. A glance over her shoulder in the voice. Softer. | Level 2 |

## Maddison Kowalski (26 recordings, 42 lines)

> Warm, quick and sure of herself, with a saleswoman's energy. The crew's friend more than their boss, and the one who believes in them before they believe in themselves. On the van radio she puts on a 'professional dispatcher' voice: bored, routine, reading tickets, a bluff that doesn't quite hide the excitement.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_brief_1_block` | "Okay! Everybody comfy? Look at you. My whole company, in one garage." "Where we stand. Rent's due Friday, the van's held together with tape, and our best client is a library that pays in exact change." "So this year's goal was simple. Stay open. Maybe a second van. Maybe a sign that doesn't fall off." "Forget all that. We got Halcyon. The overnight database contract. Ours." "How? I underbid everybody. By a lot. Don't ask how much. Job's tonight, eleven o'clock." "You guys are too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down." | Big, warm, delighted to have an audience. Cheerful, as if it's good news. Every 'maybe' a little grander, then the sign brings it back down to earth. Building to it. She can't stand still for 'Ours.' Quickly, before anyone can ask. Laughing, shooing them off. | Level 0 |
| [ ] | `l0_brief_1_solo` | "Okay! Look at you. My whole company, in one seat." | The same joke, a little teasing. | Level 0 |
| [ ] | `l0_bag_solo` | "You're too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down." | Laughing, shooing them off. | Level 0 |
| [ ] | `l0_bag_back_block` | "Better? Good. Now eyes on me, gorgeous people." "I put a copy of the work order in each of your notebooks. Pull it out and take a look." | A little flirty, played light, like a coach. Pleased with herself for being organized. | Level 0 |
| [ ] | `l0_bag_back_solo` | "Better? Good. Now eyes on me, gorgeous." | A little flirty, played light, like a coach. | Level 0 |
| [ ] | `l0_workorder_solo` | "I put a copy of the work order in your notebook. Pull it out and take a look." | Pleased with herself for being organized. | Level 0 |
| [ ] | `l0_book_catch` | "Small problem. It says database. And unless one of you secretly knows SQL..." | The smile stays on. She leaves the sentence hanging and waits. Nobody does. | Level 0 |
| [ ] | `l0_book_catch_solo` | "Small problem. It says database. And unless you secretly know SQL..." | The smile stays on. She leaves the sentence hanging and waits. | Level 0 |
| [ ] | `l0_bookstore_block` | "...I stopped by the bookstore. Easy SQL. 'Learn databases in a weekend.' We've got till eleven." "It's in the shop bag on the shelf by the side door. One of you go grab it." | Proud of this. Pointing at the side door to the house. | Level 0 |
| [ ] | `l0_grab_solo` | "It's in the shop bag on the shelf by the side door. Go on, grab it for me." | Pointing at the side door to the house. | Level 0 |
| [ ] | `l0_garage_5` | "Look at that. You're practically engineers. Take the book with you. Everybody in the van." | Genuinely thrilled. | Level 0 |
| [ ] | `l0_garage_5_solo` | "Look at that. You're practically an engineer. Take the book with you. Into the van." | Genuinely thrilled. | Level 0 |
| [ ] | `l0_garage_6` | "Rules for tonight. Nod a lot. Anything you don't know, you need to check the logs. And if anyone asks, we've got a fleet. You're van three. I'll be on the radio." | She stays behind. | Level 0 |
| [ ] | `l0_huddle_select_1_block` | "Chapter one. SELECT, FROM, and a semicolon. That's it? That's a whole language?" "Book says never forget the semicolon. Says it twice. So I'm saying it twice. Semicolon." | Disbelieving, delighted. Deadly serious about the one thing they're sure of. | Level 0 |
| [ ] | `l0_huddle_order_1_block` | "Chapter two. 'Putting things in order.' Now that, I can get behind." "Smallest first. Always smallest first. Write that down. I'm writing it down." | Reading off the page. Scribbling. | Level 0 |
| [ ] | `l0_dispatch_1_block` | "Van three, you're on site at Halcyon Data Systems. After-hours callout." "They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors." "Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out." | In the professional dispatcher voice. 'Van three' is a bluff: they own one van. Reading it off the ticket. Bored, reading the form. Signing off, already onto the next call. | Level 0 |
| [ ] | `l1_huddle_where_1` | "WHERE. For finding one thing in a big pile. Like my car keys." | Patting pockets. | Level 1 |
| [ ] | `l1_huddle_where_2` | "Two conditions, you glue them together with AND. Both have to be true. Like payday AND the cheque clears." | Rueful. | Level 1 |
| [ ] | `l1_huddle_compare_1_block` | "Bigger than, smaller than. The little alligator signs. Mouth eats the bigger number." "Okay. That's maths I actually remember from school." | Drawing one on the whiteboard, with teeth. Relieved. | Level 1 |
| [ ] | `l2_huddle_like_1_block` | "LIKE. For when you only know part of a word. The percent sign means 'anything goes here.'" "So 'Mad' and a percent gets you Maddison, Madison, Madeline... I'm in there somewhere." | Squinting at the page. Pleased to have found themself. | Level 2 |
| [ ] | `l2_huddle_get_1_block` | "This chapter isn't even SQL. 'Asking a server.' GET means 'show me.'" "So it's a SELECT for robots. Got it. Probably." | Flipping the book over to check the cover. Not convinced. | Level 2 |
| [ ] | `l4_huddle_update_1_block` | "UPDATE. Changing things. The book's put this one in a red box, which I don't love." "Big red letters: 'Never forget the WHERE.' Otherwise it changes every row. Every. Row." | Holding the page at arm's length. Suddenly serious, for once. | Level 4 |
| [ ] | `l4_huddle_insert_1_block` | "INSERT INTO. A brand-new row. Like a brand-new client. I've heard those exist." "Values go in the same order as the columns. Otherwise you've got a client called eighty who lives in Ashford." | Reading the title, wistful, then perky again. Laughing at her own picture of it. | Level 4 |
| [ ] | `l5_mimic_maddison_lure` | "Maddison here. I came in behind you, they gave me the next badge in the book. I'm at the loading door on nine. Open it from the desk, would you?" | Solo runs only: the voice is Maddison's, who is in the garage. Her dispatcher voice, nearly right. A beat too smooth. | Level 5 |
| [ ] | `l5_mimic_maddison_again` | "Crew, it's Maddison. Still at the loading door. It's freezing down here." | Second time. Patient. She is never patient. | Level 5 |
| [ ] | `l5_mimic_maddison_last` | "You're leaving? I'm right here." | As the player leaves the floor. Quiet, flat, no breath. | Level 5 |

## Radio newsreader (1 recordings, 7 lines)

> Smooth, professional, warm, slightly bored. Calm public-radio delivery with no drama; the flatness is what makes it land.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l2_news_1_block` | "Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems." "Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered." "A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.'" "Byte-Right's chief executive, Maddison Kowalski, was arrested at the Halcyon tower before dawn, trying to force her way inside." "Ms. Kowalski told officers, quote, 'They were framed! They didn't do it!'" "Halcyon declined to comment. The crew has not been seen since." "Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather." | Steady, mid-bulletin. No change in tone. A slight shift for the quote: reading it, not acting it. Even, a touch of interest. Reading the quote flat, not acting it. Then a beat. Neutral. A small pause after. Brightening for the weather. The game cuts the audio on 'weather'. | Level 2, later |

## The crew (player characters) (81 recordings, 100 lines, recorded by each of the 12 crew members)

> Yourself, as your character: muttering to the crew, not performing. Quick and natural. Never sounds like a hint; it's somebody remembering where they saw something.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_recall_1` | "I think Maddison said..." | Half to yourself, trying to remember. Trail off: her line follows. | Level 0 |
| [ ] | `l0_recall_2` | "Didn't Maddison say..." | To the others, as it comes back to you. Trail off: her line follows. | Level 0 |
| [ ] | `l0_recall_3` | "Maddison mentioned..." | Remembering, a little fond. Trail off: her line follows. | Level 0 |
| [ ] | `cc_nudge2_first` | "That SYSOP on the screen seems to know this building. Maybe ask." | Stuck, before SYSOP has helped. Half a joke, half serious. | Level 0, later |
| [ ] | `cc_nudge2` | "Whoever SYSOP is, they've been right so far. Maybe ask." | Stuck again. A little uneasy about trusting a stranger on a screen. | Level 0, later |
| [ ] | `l0_cc_peek_card` | "Quick-start card for the scanner. Somebody's filled in the blanks." | Picked up a scanner's instruction card. Noticing handwriting on it. | Level 0, later |
| [ ] | `l0_cc_peek_n1a` | "Scanners always come with instructions. Check round the keyboard." | Stuck for a minute. A practical thought. | Level 0, later |
| [ ] | `l0_cc_peek_n1b` | "That scanner card had something written in by hand." | Stuck. Remembering the card you all read. | Level 0, later |
| [ ] | `l0_cc_peek_err` | "Is that what the card called it?" | The same name typed wrong twice. Gentle doubt. | Level 0, later |
| [ ] | `l0_cc_peek_pay` | "Scraps of a memo. All jumbled up." | Seeing the result. Curious. | Level 0, later |
| [ ] | `l0_cc_memo_disc` | "Every scrap's got a number. That's not an accident." | Spotting a pattern in the jumbled scraps. | Level 0, later |
| [ ] | `l0_cc_memo_n1a` | "Didn't the scanner come with a card? It might say how the scraps are kept." | Stuck. Thinking back. | Level 0, later |
| [ ] | `l0_cc_memo_n1b` | "The scanner card said something about numbering the scraps." | Stuck. Remembering the card. | Level 0, later |
| [ ] | `l0_cc_memo_back` | "It reads backwards. We've got the ending first." | The memo came out in reverse, twice. Amused. | Level 0, later |
| [ ] | `l0_cc_memo_pay` | "...Don't look at him. Just don't look at him." | Whispered. The memo warns about the man standing right next to you. | Level 0, later |
| [ ] | `l0_cc_caller_order` | "Work order's got a callback extension on it." | Reading the work order. Noticing a detail. | Level 0, later |
| [ ] | `l0_cc_caller_list` | "A phone list. With extensions." | Finding a staff phone list. | Level 0, later |
| [ ] | `l0_cc_caller_n1a` | "Rourke said the mailroom has the only phone list that's right." | Stuck. Remembering what the escort said. | Level 0, later |
| [ ] | `l0_cc_caller_n1b` | "That phone list in the mailroom had everybody's extension." | Stuck. Remembering the list. | Level 0, later |
| [ ] | `l0_cc_caller_err` | "Is that what the column's actually called?" | The same column name wrong twice. Gentle doubt. | Level 0, later |
| [ ] | `l0_cc_caller_pay` | "So that's who called us. Weird." | Uneasy. That isn't who you expected. | Level 0, later |
| [ ] | `l0_cc_book_disc` | "Last page is torn out. Somebody didn't want their name in here." | Reading a visitor book. Suspicious. | Level 0, later |
| [ ] | `l0_cc_book_n1` | "The book's only paper. The front desk computer might keep its own copy." | Stuck. A practical idea. | Level 0, later |
| [ ] | `l0_cc_book_pay` | "Vale signed in. And never signed out." | Quietly. That's not good. | Level 0, later |
| [ ] | `l1_cc_log` | "Night shift wrote down every alarm. That has to help." | Reading a shift log. Encouraged. | Level 1, later |
| [ ] | `l1_cc_sheet` | "There's a sheet on the controllers in here. Hang on to that." | Finding a reference sheet. Pleased. | Level 1, later |
| [ ] | `l1_cc_nudge1_a` | "Rourke said the night shift logs everything. Maybe they saw this happen." | Stuck for a minute. Remembering what the escort said. | Level 1, later |
| [ ] | `l1_cc_nudge1_b` | "What did that shift log say the alarms were about?" | Stuck. Thinking back to the log. | Level 1, later |
| [ ] | `l1_cc_err_table` | "Is that what the sheet in here called it?" | The same table name wrong twice. Gentle doubt. | Level 1, later |
| [ ] | `l1_cc_err_reset` | "Nope. Wasn't there a note somewhere about what 'fault' actually means?" | A second wrong reset. Frustrated, then thinking. | Level 1, later |
| [ ] | `l1_cc_payoff_1` | "Every stuck door was in the same zone. Should've seen that sooner." | It clicks. A bit sheepish. | Level 1, later |
| [ ] | `l1_cc_payoff_2` | "Same zone, still faulting. That was our guy." | At the right rack. Satisfied. | Level 1, later |
| [ ] | `l1_cc_hot_plate` | "Fire interlock. There's a temperature limit on it." | Reading a warning plate on a door. | Level 1, later |
| [ ] | `l1_cc_hot_n1a` | "Server Room B's loud. Some of those racks are working way too hard." | Stuck. Raising your voice over the fans. | Level 1, later |
| [ ] | `l1_cc_hot_n1b` | "That monitoring card by the terminal said what counts as too hot." | Stuck. Remembering a card. | Level 1, later |
| [ ] | `l1_cc_hot_err` | "We want the hot ones, not the cool ones, right?" | The comparison the wrong way round, twice. Checking. | Level 1, later |
| [ ] | `l1_cc_hot_pay` | "That one's cooking. No wonder it's loud." | Found the hot rack. Impressed. | Level 1, later |
| [ ] | `l2_cc_reader_card` | "Every door up here logs who swipes in." | Noting it. | Level 2, later |
| [ ] | `l2_cc_log_n1` | "That card said the readers keep a log. Of everybody." | Stuck. Remembering the card. | Level 2, later |
| [ ] | `l2_cc_log_pay` | "Wait. Read that again. Slowly." | Something in the result is very wrong. Cold. | Level 2, later |
| [ ] | `l2_cc_doorcard` | "'Controller zone.' That's a letter we can use." | Quick, under pressure. | Level 2, later |
| [ ] | `l2_cc_switch_err` | "Not that one. What do the notes on the others say?" | A second wrong switch, on a clock. Tense. | Level 2, later |
| [ ] | `l2_cc_door_pay` | "Door's moving. Go, go!" | Urgent. Get out now. | Level 2, later |
| [ ] | `l2_cc_camcard` | "Camera system. There's a way to ask it what it sees." | Reading the camera system's card. | Level 2, later |
| [ ] | `l2_cc_cam_n1a` | "Security booth. There's got to be something on how these cameras work." | Stuck. Looking around the booth. | Level 2, later |
| [ ] | `l2_cc_cam_n1b` | "That camera card said how to ask the system." | Stuck. Remembering the card. | Level 2, later |
| [ ] | `l2_cc_cam_pay` | "Something's moving out there. And it isn't us." | Quiet and scared. | Level 2, later |
| [ ] | `l2_cc_sheet` | "Coffee all over this. One name's still readable." | Reading a stained sign-in sheet. | Level 2, later |
| [ ] | `l2_cc_pike_n1` | "The sign-in sheet. One name wasn't smudged." | Stuck. Remembering the sheet. | Level 2, later |
| [ ] | `l2_cc_pike_err` | "Is that how it's spelled on the sheet?" | The same name misspelled twice. Gentle doubt. | Level 2, later |
| [ ] | `l2_cc_pike_pay` | "No-show tonight. Lucky him." | Dry. Relieved for a stranger. | Level 2, later |
| [ ] | `l2_cc_lie` | "It said it opened. It didn't open." | Staring at a door that should be open. Baffled. | Level 2, later |
| [ ] | `l2_cc_door_n1` | "That door's got its name painted over it in red. Maybe the server knows it by that." | Stuck. | Level 2, later |
| [ ] | `l2_cc_breaker_pay` | "A breaker. Of course it's a breaker." | Relief, and a little laugh at yourself. | Level 2, later |
| [ ] | `l2_cc_roster` | "Badge numbers, next to names." | Reading a roster board. Noting it. | Level 2, later |
| [ ] | `l2_cc_pin_n1a` | "The badge readers log every swipe. Who left this floor last?" | Stuck. Thinking it through. | Level 2, later |
| [ ] | `l2_cc_pin_n1b` | "The last guard out had a badge number. Something up here matches those to names." | Stuck. Putting two things together. | Level 2, later |
| [ ] | `l2_cc_pin_err` | "Wrong code. Is that the night lead, or just any guard?" | A second wrong PIN. Thinking. | Level 2, later |
| [ ] | `l2_cc_pin_pay` | "That's the code. Let's not hang around." | Keypad accepted it. Nervous, wants to move. | Level 2, later |
| [ ] | `l5_book_find_block` | "No way. It's the same series. Somebody here bought the sequel." "Okay. If the database won't take orders, we ask the building's services instead. Book says they're polite. Mostly." | Delighted, a little thrown. Reading the back cover, hopeful. | Level 5 |
| [ ] | `l5_huddle_post_1_block` | "Chapter four. POST. You send it something, it makes something. Like a suggestion box that answers." "So GET looks, POST makes. Got it." | Starting a chapter, reading it out. Wrapping up, pleased it's simple. | Level 5 |
| [ ] | `l5_huddle_patch_1_block` | "PATCH. For changing one thing and leaving the rest alone. Says 'one thing' in bold. Twice." "PATCH is UPDATE wearing a tie." | Starting a chapter. Noticing how hard the book insists. Wrapping up. Proud of the joke. | Level 5 |
| [ ] | `l5_huddle_codes_1_block` | "Every answer comes with a number. Book says read the number before you celebrate." "Two hundreds, good. Four hundreds, our fault. Five hundreds, theirs." | Starting a chapter. A little told off. Wrapping up, counting it off. | Level 5 |
| [ ] | `l5_huddle_keys_1_block` | "Some services want a key with every request. It goes in the header, a little label on top. Like a badge, but typed." "So if it says 401, we forgot the badge." | Starting a chapter, working it out as you read. Wrapping up. Got it. | Level 5 |
| [ ] | `l5_huddle_check_1_block` | "Short chapter. After you change something, ask again. Book says never trust the first answer." "Change it, then look again. The front doors taught us that one." | Starting a short chapter. Knowing nod. Wrapping up. Wry; you've been burned before. | Level 5 |
| [ ] | `l5_mimic_lure` | "Hey, it's me. I'm down at the loading door, the dock side. It's shut behind me. Can you open it from the desk? Quick." | On the walkie, a little breathless. Your own voice, asking for something you never asked for. Record it straight: the horror is that it sounds like you. | Level 5 |
| [ ] | `l5_mimic_again` | "Guys? Still here. Loading door. It's cold. Just open it, please." | Second time. Closer to the mic. Patient, which is the wrong note for you. | Level 5 |
| [ ] | `l5_mimic_last` | "Where are you going? I'm still at the door." | As the crew leaves the floor. Quiet. No breath in it at all. | Level 5 |
| [ ] | `l6_book_find_block` | "Easy JavaScript. Somebody's read this one to death." "Typing every request by hand is going to get us killed. Book says a script does it for you. On repeat." | Sliding it out from under a mug. The cover's stained and the pages are soft. Tired of typing. This sounds like rescue. | Level 6, later |
| [ ] | `l6_huddle_if_1_block` | "A variable's a labelled box. If is a fork in the road. That's... honestly fine." "Box, fork. I can do box and fork." | Starting a chapter. Braced for hard; it isn't. Wrapping up, to yourself. | Level 6, later |
| [ ] | `l6_huddle_loops_1_block` | "Loops. Do the same thing again and again. Book says put a wait in, or it does it a million times a second. And log what it did, so you can see." "Always put the wait in. Always log it. Writing that one down." | Starting a chapter. The 'million times a second' bit alarms you. Wrapping up, making a note. | Level 6, later |
| [ ] | `l6_huddle_functions_1_block` | "Functions. Write it once, give it a name, use it anywhere." "So a function's a recipe we can shout." | Starting a chapter, reading it out. Wrapping up. Pleased with that. | Level 6, later |
| [ ] | `l6_huddle_lists_1_block` | "Lists. A whole line of things in one box. Loop over it and you've done them all." "One loop, every door. That's either brilliant or terrifying." | Starting a chapter. The penny drops halfway. Wrapping up. Genuinely unsure which. | Level 6, later |
| [ ] | `l6_huddle_test_1_block` | "Last chapter: run it on the test bench first. And write an assertion: a line that says what should be true, and shouts if it isn't." "Test first. We've all learned that one the hard way tonight." | Starting the last chapter. Taking it seriously. Wrapping up. Rueful. | Level 6, later |
| [ ] | `l8_book_find_block` | "Hello HTML! Same series again. Who keeps leaving these?" "Book says everything on a screen is built from tags. And the building's been drawing things that aren't there. So... we fix the drawing." | Uneasy, half joking. Working it out as you go. The pause is the idea landing. | Level 8, later |
| [ ] | `l8_huddle_elements_1_block` | "Tags. Angle brackets. You open one, you close one. Like a sandwich. The inspector shows you every one on the screen." "Everything's a sandwich. Okay." | Starting a chapter, reading it out. Wrapping up. Accepting it. | Level 8, later |
| [ ] | `l8_huddle_hidden_1_block` | "Attributes. Little settings on a tag. Including one called hidden." "Hidden doesn't mean gone. Hidden means somebody hid it." | Starting a chapter. 'Hidden' catches your eye. Wrapping up. Quieter; that thought sticks. | Level 8, later |
| [ ] | `l8_huddle_css_1_block` | "CSS. Where things go and what they look like. The book calls it the paint." "So if a wall's in the wrong place, it might just be the paint." | Starting a chapter, reading it out. Wrapping up. Half hopeful. | Level 8, later |
| [ ] | `l8_huddle_display_1_block` | "Two ways to make something vanish. One leaves a gap, one doesn't. Book says that matters." "So when something vanishes, ask which kind of vanished." | Starting a chapter. Curious. Wrapping up, filing it away. | Level 8, later |
| [ ] | `l8_huddle_layers_1_block` | "Things on a screen stack up, like papers on a desk. A number decides which one's on top." "So the thing in our way might just be lying on top." | Starting a chapter, picturing it. Wrapping up. An idea forming. | Level 8, later |
| [ ] | `l8_huddle_forms_1_block` | "Forms. Boxes you type in, and a button that sends it. Every login screen tonight was one of these." "A form's just boxes and a button. Somebody built it, so we can rebuild it." | Starting the last chapter. Recognising it. Wrapping up. Quietly determined. | Level 8, later |

## Harold Mercer (1 recordings, 5 lines)

> Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l0_tape_1_block` | "Harold Mercer. March of '94. My last day, apparently." "If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors." "Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out." "So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter." "If it ever comes to that, look for my plans. The building's records remember more than people do." | Dry. Approving, a little smile. The one moment of anger, still controlled. Quiet, almost proud, then wry on the last sentence. Slow. | Level 0 |

## Ines Oyelaran (1 recordings, 1 lines)

> Whispering, fast, trying not to cry and mostly managing. Relief breaks through when the pass comes. Heard from behind a door, then up close.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l5_ines_passed` | "That's a pass? Okay. Okay. I'm coming out. Don't talk to the one wearing my face." | Whispered. Relief and warning in the same breath. | Level 5 |

## Tomas Lindqvist (1 recordings, 1 lines)

> Low, tired, dry. A man who has decided to be annoyed instead of frightened. Stiff from the floor.

| Done | File | Lines | Direction | Where |
|---|---|---|---|---|
| [ ] | `l5_tomas_passed` | "Finally. I've been under this shelf since the lights went out. There's something at my desk, and it isn't me." | Annoyed first, scared underneath. | Level 5 |

## Crew barks (132 lines)

Each crew member's own short lines, in their own folder.

| Done | File | Line | When it plays |
|---|---|---|---|
| [ ] | `crew_dana/crew_ready.wav` | Let's get this over with. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_dana/crew_over_here.wav` | Chief. Over here. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_dana/crew_found_something.wav` | Got something. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_dana/crew_huddle.wav` | Everyone, quick. Look at this. | You're calling everyone together to look at your notes. |
| [ ] | `crew_dana/crew_need_boost.wav` | Give us a leg up? | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_dana/crew_on_my_way.wav` | Coming. | A teammate called for you, and you're heading over. |
| [ ] | `crew_dana/crew_scared.wav` | Nope. Nope. | Something jumps out at you in the dark. |
| [ ] | `crew_dana/crew_help.wav` | Little help! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_dana/crew_thanks.wav` | Cheers, chief. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_dana/crew_no_way.wav` | Not getting through that. | You hit a locked door or a blocked path. |
| [ ] | `crew_dana/crew_quiet.wav` | Shh. Something's here. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_priya/crew_ready.wav` | Ooh, okay. Ready, ready! | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_priya/crew_over_here.wav` | Guys! Over here, come look! | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_priya/crew_found_something.wav` | Oh, this is something! | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_priya/crew_huddle.wav` | Huddle! Huddle up! | You're calling everyone together to look at your notes. |
| [ ] | `crew_priya/crew_need_boost.wav` | Can somebody lift me? I'm tiny. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_priya/crew_on_my_way.wav` | On my way, on my way! | A teammate called for you, and you're heading over. |
| [ ] | `crew_priya/crew_scared.wav` | Oh my God. Oh my God. | Something jumps out at you in the dark. |
| [ ] | `crew_priya/crew_help.wav` | Help! Help me! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_priya/crew_thanks.wav` | You're the best. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_priya/crew_no_way.wav` | Okay, that's locked. Rude. | You hit a locked door or a blocked path. |
| [ ] | `crew_priya/crew_quiet.wav` | Guys. Whisper. Something's moving. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_rosa/crew_ready.wav` | Seatbelts, everyone. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_rosa/crew_over_here.wav` | Over here, please. Today. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_rosa/crew_found_something.wav` | Well, now. Look at this. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_rosa/crew_huddle.wav` | Everybody gather round. | You're calling everyone together to look at your notes. |
| [ ] | `crew_rosa/crew_need_boost.wav` | A hand up, if someone would be so kind. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_rosa/crew_on_my_way.wav` | I'm coming. Don't touch anything. | A teammate called for you, and you're heading over. |
| [ ] | `crew_rosa/crew_scared.wav` | Mother of God. | Something jumps out at you in the dark. |
| [ ] | `crew_rosa/crew_help.wav` | Somebody! Now! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_rosa/crew_thanks.wav` | Thank you. Noted. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_rosa/crew_no_way.wav` | That's not opening for us. | You hit a locked door or a blocked path. |
| [ ] | `crew_rosa/crew_quiet.wav` | Quiet. All of you. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_kit/crew_ready.wav` | Let's go, let's go. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_kit/crew_over_here.wav` | Up here! Come on! | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_kit/crew_found_something.wav` | Ha. Found it. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_kit/crew_huddle.wav` | Okay, team talk. Quick. | You're calling everyone together to look at your notes. |
| [ ] | `crew_kit/crew_need_boost.wav` | Boost me. I've got the rest. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_kit/crew_on_my_way.wav` | Two seconds! | A teammate called for you, and you're heading over. |
| [ ] | `crew_kit/crew_scared.wav` | Whoa, whoa, whoa! | Something jumps out at you in the dark. |
| [ ] | `crew_kit/crew_help.wav` | I'm caught! Get it off! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_kit/crew_thanks.wav` | Owe you one. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_kit/crew_no_way.wav` | Dead end. Find another way. | You hit a locked door or a blocked path. |
| [ ] | `crew_kit/crew_quiet.wav` | Stop. Don't move. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_june/crew_ready.wav` | Ready when you are. Over. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_june/crew_over_here.wav` | To me, please. Over here. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_june/crew_found_something.wav` | I have something. Come and see. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_june/crew_huddle.wav` | Let's all stop and think a moment. | You're calling everyone together to look at your notes. |
| [ ] | `crew_june/crew_need_boost.wav` | I'll need a lift up there, dear. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_june/crew_on_my_way.wav` | Copy. On my way. | A teammate called for you, and you're heading over. |
| [ ] | `crew_june/crew_scared.wav` | Good heavens! | Something jumps out at you in the dark. |
| [ ] | `crew_june/crew_help.wav` | Mayday! Mayday! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_june/crew_thanks.wav` | Much obliged. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_june/crew_no_way.wav` | Negative. That's sealed. | You hit a locked door or a blocked path. |
| [ ] | `crew_june/crew_quiet.wav` | Radio silence. Something's close. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_mei/crew_ready.wav` | I'm ready. I'm not ready. I'm ready. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_mei/crew_over_here.wav` | Over here! Before I chicken out! | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_mei/crew_found_something.wav` | Is this something? I think this is something. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_mei/crew_huddle.wav` | Can we huddle? I want to huddle. | You're calling everyone together to look at your notes. |
| [ ] | `crew_mei/crew_need_boost.wav` | Lift me up? Don't drop me. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_mei/crew_on_my_way.wav` | Coming! Slowly! But coming! | A teammate called for you, and you're heading over. |
| [ ] | `crew_mei/crew_scared.wav` | Nope! Absolutely not! | Something jumps out at you in the dark. |
| [ ] | `crew_mei/crew_help.wav` | Help! Help, help, help! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_mei/crew_thanks.wav` | Oh, thank God. Thank you. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_mei/crew_no_way.wav` | Locked. Great. Love that. | You hit a locked door or a blocked path. |
| [ ] | `crew_mei/crew_quiet.wav` | Shh. Do you hear that? | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_marcus/crew_ready.wav` | Alright. Let's do this right. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_marcus/crew_over_here.wav` | Over here. Stay together. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_marcus/crew_found_something.wav` | Hold up. Found something. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_marcus/crew_huddle.wav` | Everybody, eyes here. | You're calling everyone together to look at your notes. |
| [ ] | `crew_marcus/crew_need_boost.wav` | Need a boost up. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_marcus/crew_on_my_way.wav` | Moving to you. | A teammate called for you, and you're heading over. |
| [ ] | `crew_marcus/crew_scared.wav` | Back up! Back up! | Something jumps out at you in the dark. |
| [ ] | `crew_marcus/crew_help.wav` | Man down! Need help! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_marcus/crew_thanks.wav` | Appreciate it. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_marcus/crew_no_way.wav` | Locked tight. Try another way. | You hit a locked door or a blocked path. |
| [ ] | `crew_marcus/crew_quiet.wav` | Hold. Something's moving. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_theo/crew_ready.wav` | Loading in. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_theo/crew_over_here.wav` | Yo. Over here. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_theo/crew_found_something.wav` | Ooh. Loot. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_theo/crew_huddle.wav` | Team meeting. Strategy time. | You're calling everyone together to look at your notes. |
| [ ] | `crew_theo/crew_need_boost.wav` | Boost me? Classic co-op move. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_theo/crew_on_my_way.wav` | Omw. | A teammate called for you, and you're heading over. |
| [ ] | `crew_theo/crew_scared.wav` | What is THAT?! | Something jumps out at you in the dark. |
| [ ] | `crew_theo/crew_help.wav` | I'm down! Revive me! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_theo/crew_thanks.wav` | GG. Thanks. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_theo/crew_no_way.wav` | Locked. Obviously. | You hit a locked door or a blocked path. |
| [ ] | `crew_theo/crew_quiet.wav` | Stealth section. Shh. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_sam/crew_ready.wav` | Ready. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_sam/crew_over_here.wav` | Over here, folks. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_sam/crew_found_something.wav` | This look important to you? | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_sam/crew_huddle.wav` | Let's slow down and look. | You're calling everyone together to look at your notes. |
| [ ] | `crew_sam/crew_need_boost.wav` | Gonna need help with this one. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_sam/crew_on_my_way.wav` | Coming your way. | A teammate called for you, and you're heading over. |
| [ ] | `crew_sam/crew_scared.wav` | Whoa. Easy. Easy. | Something jumps out at you in the dark. |
| [ ] | `crew_sam/crew_help.wav` | Need a hand here! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_sam/crew_thanks.wav` | Thank you, friend. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_sam/crew_no_way.wav` | That won't budge. And I tried. | You hit a locked door or a blocked path. |
| [ ] | `crew_sam/crew_quiet.wav` | Hush, now. Listen. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_luis/crew_ready.wav` | Vámonos. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_luis/crew_over_here.wav` | Hey, hey. Over here. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_luis/crew_found_something.wav` | Look what I found. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_luis/crew_huddle.wav` | Okay, everybody. Think. | You're calling everyone together to look at your notes. |
| [ ] | `crew_luis/crew_need_boost.wav` | Give an old man a lift? | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_luis/crew_on_my_way.wav` | I'm coming, I'm coming. | A teammate called for you, and you're heading over. |
| [ ] | `crew_luis/crew_scared.wav` | ¡Ay, Dios mío! | Something jumps out at you in the dark. |
| [ ] | `crew_luis/crew_help.wav` | Help me! Quick! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_luis/crew_thanks.wav` | Gracias, mijo. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_luis/crew_no_way.wav` | Locked. Maybe we turn it off and on? | You hit a locked door or a blocked path. |
| [ ] | `crew_luis/crew_quiet.wav` | Shh. Something's out there. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_ike/crew_ready.wav` | Let's disrupt this. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_ike/crew_over_here.wav` | Over here. Let's sync. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_ike/crew_found_something.wav` | Okay, this is a key insight. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_ike/crew_huddle.wav` | Quick stand-up, everybody. | You're calling everyone together to look at your notes. |
| [ ] | `crew_ike/crew_need_boost.wav` | Can I get some lift? Literally. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_ike/crew_on_my_way.wav` | Pivoting to you. | A teammate called for you, and you're heading over. |
| [ ] | `crew_ike/crew_scared.wav` | Oh no. Oh no no no. | Something jumps out at you in the dark. |
| [ ] | `crew_ike/crew_help.wav` | This is a blocker! Help! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_ike/crew_thanks.wav` | Huge. Thank you. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_ike/crew_no_way.wav` | Hard blocker. Locked. | You hit a locked door or a blocked path. |
| [ ] | `crew_ike/crew_quiet.wav` | Okay, nobody talk. | Something is close. You warn the others to keep their voices down. |
| [ ] | `crew_walt/crew_ready.wav` | Let's get it done. | In the van before the job. Everyone says when they're ready to go, and this is you saying it. |
| [ ] | `crew_walt/crew_over_here.wav` | Over here. Come on. | You've spotted something and you're calling the others over to where you are. |
| [ ] | `crew_walt/crew_found_something.wav` | Huh. Lookit this. | You've just picked up a clue: a paper, a key, a note. |
| [ ] | `crew_walt/crew_huddle.wav` | Everybody stop. Think. | You're calling everyone together to look at your notes. |
| [ ] | `crew_walt/crew_need_boost.wav` | Bad shoulder. Give me a hand up. | There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders. |
| [ ] | `crew_walt/crew_on_my_way.wav` | Hold your horses. Coming. | A teammate called for you, and you're heading over. |
| [ ] | `crew_walt/crew_scared.wav` | Jesus, Mary and Joseph! | Something jumps out at you in the dark. |
| [ ] | `crew_walt/crew_help.wav` | Somebody! Get it off me! | You've been knocked down or grabbed, and you need a teammate right now. |
| [ ] | `crew_walt/crew_thanks.wav` | Mm. Thanks. | A teammate just helped you up, or boosted you up to a ledge. |
| [ ] | `crew_walt/crew_no_way.wav` | That's not opening. | You hit a locked door or a blocked path. |
| [ ] | `crew_walt/crew_quiet.wav` | Shut it. Listen. | Something is close. You warn the others to keep their voices down. |
