class_name VoiceLines
extends RefCounted
## Every spoken line in the game, keyed by id. This is the script: the levels play
## lines by id (`hud.line("l0_greet_1")`), the recording list in docs/script/ is
## generated from it, and a recording named after the id replaces the timed subtitle.
## Change a line here, then run tools/write_script_docs.gd to refresh the docs.

## Who speaks, and how to play them. `who` can spoil the story and is for the
## team; `card` is what an actor who only gets this character's script is told.
## `slug` names the character's script file and recordings folder.
const CHARACTERS := {
	"ROURKE": {
		"slug": "rourke",
		"card": "Dale Rourke, the building's facilities manager, 50s. Tonight he's escorting an IT crew around after hours, and he's friendlier than he needs to be.",
		"name": "Dale Rourke",
		"who": "Facilities manager, 50s. The director's plant.",
		"voice": "Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth.",
	},
	"WARDEN": {
		"slug": "warden",
		"card": "The building's computer system. It runs the doors, the lights and the speakers, and it talks over the PA and through terminals.",
		"name": "WARDEN",
		"who": "The campus security system, heard over 1997 PA speakers and terminals. Not a villain: it enforces protocol, and turns hostile only once the crew breaches it and loses their escort.",
		"voice": "Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.",
	},
	"PA": {
		"slug": "pa",
		"card": "The building's pre-recorded announcements, played over the ceiling speakers on a loop.",
		"name": "Building PA",
		"who": "Halcyon's canned PA announcements. Cheerful and seemingly unaware, but WARDEN picks what plays and when; players realize later it was watching all along. WARDEN itself says nothing in Level 0.",
		"voice": "A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Record dry: the game adds the PA speaker sound.",
	},
	"VALE": {
		"slug": "vale",
		"card": "Dr. Iris Vale, the lead engineer, 40s. Calling the night desk late at night about something she'd rather nobody saw.",
		"name": "Dr. Iris Vale",
		"who": "Lead engineer, 40s. Officially missing, presumed dead.",
		"voice": "Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.",
	},
	"DISPATCH": {
		"slug": "dispatch",
		"card": "The IT company's night dispatcher, on the van radio. Just another callout at the end of a long shift.",
		"name": "Byte-Right dispatch",
		"who": "The IT company's night dispatcher, heard on the van radio.",
		"voice": "Bored, routine, a little crackly. Reading tickets off a list at the end of a long shift. Nothing about this call is unusual to them.",
	},
	"MERCER": {
		"slug": "mercer",
		"card": "Harold Mercer, the company's founder, 70s. Recording a cassette at his desk on his last day, in 1994.",
		"name": "Harold Mercer",
		"who": "Halcyon's founder, 70s. Fired in 1994 for fighting WARDEN.",
		"voice": "Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.",
	},
}

## Scenes in story order. `wired` is false for lines written ahead of their level.
## `context` is the plot for the team; `moment` is the spoiler-light version actors see.
## Set `reveal: true` on scenes that give away a twist: their lines go to a separate
## "later session" script (so do all lines from REVEAL_LEVEL on).
const SCENES := [
	{"id": "l0_van", "level": 0, "title": "The IT van", "wired": true,
		"moment": "You're on the radio to an IT crew parked outside a client's building at 11 p.m.",
		"context": "The crew sits in their Byte-Right IT van in Halcyon's car park while dispatch reads them the job over the radio. Nothing is wrong yet: this is an ordinary after-hours callout. The radio stops once everyone has readied up."},
	{"id": "l0_arrive", "level": 0, "title": "The front doors, 11 p.m.", "wired": true,
		"moment": "At the building's front doors as the IT crew arrives.",
		"context": "The crew walks up from the van. Rourke opens the front doors as the building PA plays its closing announcement. Rourke walks them in to the front desk; the doors lock behind them and he has them sign the visitor log."},
	{"id": "l0_tour", "level": 0, "title": "The tour", "wired": true,
		"moment": "Walking the crew through the lobby to the front desk, chatting as you go.",
		"context": "Rourke walks the crew to reception and explains the job."},
	{"id": "l0_memo", "level": 0, "title": "Vale's shredded memo", "wired": true,
		"moment": "At the front desk while the crew pieces a shredded memo back together on a terminal.",
		"context": "The crew rebuilds Vale's memo at the front desk terminal. It says not to trust anyone who offers to escort you. Rourke is standing right there."},
	{"id": "l0_tape", "level": 0, "title": "Mercer's cassette (optional)", "wired": true,
		"moment": "Alone at your desk, talking into a cassette recorder for whoever finds it someday.",
		"context": "In the forgotten closet behind the air-return vent, a cassette recorder sits on the shelf under the old newspaper clipping. Only players who crawl through the vent hear it."},
	{"id": "l0_hall", "level": 0, "title": "To Server Room A", "wired": true,
		"moment": "Strolling down a quiet office corridor with the crew, making small talk on the way to the server room.",
		"context": "Rourke badges the hall shutter open and walks the crew to Server Room A himself, filling the walk with the story of the founder and his safe room."},
	{"id": "l1_trap", "level": 1, "title": "The betrayal", "wired": true,
		"moment": "Inside a server room with the crew. Friendly at first; then, while one of them works at the terminal, the door locks.",
		"context": "Rourke leads the crew into Server Room A and points them at the terminal. A few seconds after someone starts working, the door locks behind them, the lights go red, and he turns on them."},
	{"id": "l1_fight", "level": 1, "title": "The fight (barks)", "wired": true,
		"moment": "Short lines in a scuffle. Loud and out of breath; each one can play many times.",
		"context": "Short lines played at random during the fight: when he lands a hit, when he takes one, and when he goes down. Keep each one short; they can play many times."},
	{"id": "l1_fate", "level": 1, "title": "Kill or tie him up", "wired": true,
		"moment": "In the server room, right after the scuffle.",
		"context": "Rourke is down. If the crew kills him, his badge's dead-man switch fires and WARDEN starts the lockdown. If they tie him up, he taunts them. Either way they take his badge and the terminal logs in with it."},
	{"id": "l1_controllers", "level": 1, "title": "Resetting the door controller", "wired": true,
		"moment": "Over the server room speakers while the crew tries to reset door controllers.",
		"context": "The crew reads WARDEN's self-test, queries door_controllers, and resets the right rack. The terminal shows the details; these lines are WARDEN reacting."},
	{"id": "l1_exit", "level": 1, "title": "Lockdown", "wired": true,
		"moment": "Over the speakers as the crew leaves the server room.",
		"context": "The crew steps through the emergency exit. If Rourke was tied up, he has cut himself loose and authorized the lockdown himself."},
	{"id": "l2_radio", "level": 2, "title": "Rourke on the radio (if he escaped)", "wired": true,
		"moment": "On a walkie-talkie to the crew, from somewhere else in the building.",
		"context": "Level 2 opening, only if Rourke was tied up in Level 1. He still has his facilities radio on channel 1 and calls the crew's walkie-talkies."},
	{"id": "l2_security", "level": 2, "title": "The security office", "wired": true,
		"moment": "Over the speakers in a security office.",
		"context": "WARDEN on the security office PA. The Watcher moves only when unseen; GET /cameras shows live camera states; the guard's name on the sign-in sheet is smudged (LIKE 'Har%'); a door command reports success but the door has an actuator fault (the first terminal lie)."},
	{"id": "l2_voicemail", "level": 2, "title": "Vale's voicemail", "wired": true,
		"moment": "Leaving a message on a desk answering machine, late at night.",
		"context": "The answering machine on the night desk blinks: one message, stamped SUN 10/12 1:52 AM. That is before her last badge swipe and before the memo was scanned, so it must not hint that she is alive (the reveal is at the end of Level 10). Optional, near the desk."},
]

## speaker, text (also the subtitle), and a short note for the actor.
const LINES := {
	# --- Level 0 -------------------------------------------------------------
	"l0_dispatch_1": {"scene": "l0_van", "speaker": "DISPATCH", "text": "Van three, you're on site at Halcyon Data Systems. After-hours callout.",
		"note": "Over the van radio. Routine."},
	"l0_dispatch_2": {"scene": "l0_van", "speaker": "DISPATCH", "text": "They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors.",
		"note": "Reading it off the ticket."},
	"l0_dispatch_3": {"scene": "l0_van", "speaker": "DISPATCH", "text": "Hop out when you're ready. Dispatch out.",
		"note": "Signing off, already onto the next call."},
	"l0_pa_1": {"scene": "l0_arrive", "speaker": "PA", "text": "Good evening! Halcyon Data Systems is now closed.",
		"note": "Over the lobby PA. Pleasant, like a store closing announcement."},
	"l0_pa_2": {"scene": "l0_arrive", "speaker": "PA", "text": "Visitors must remain with their escort at all times. Thank you for your cooperation!",
		"note": "Same announcement, continuing."},
	"l0_greet_1": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "There you are. Dale Rourke, facilities. I'll be your escort tonight.",
		"note": "Friendly, a handshake in the voice."},
	"l0_greet_2": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "Don't mind the announcements. They play that to everybody.",
		"note": "Chuckling, waving at the ceiling speaker."},
	"l0_greet_3": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "Badge rules after hours. You don't go anywhere I don't take you.",
		"note": "Still smiling. Should sound like a joke the first time and a threat on replay."},
	"l0_greet_4": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "Come on in. I'll sign you in at the front desk.",
		"note": "Holding the door, waving them through."},
	"l0_signin": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me.",
		"note": "Casual, reassuring. Nothing to worry about. (On a replay it lands differently.)"},
	"l0_tour_1": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Here's the job. Dr. Vale, our lead engineer, went missing three nights ago.",
		"note": "Walking. Matter-of-fact, the way you'd mention the weather."},
	"l0_tour_2": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Her systems are a mess and the director wants them recovered by morning. Quietly.",
		"note": "Small beat before \"Quietly.\""},
	"l0_tour_3": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings.",
		"note": "Tour-guide mode, enjoying himself."},
	"l0_tour_4": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Board fired him when they installed WARDEN. That's the AI that runs the campus now.",
		"note": "Still chatting to the crew, a little proud of the trivia."},
	"l0_tour_5": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable.",
		"note": "Spooky-campfire voice, playing it up."},
	"l0_tour_6": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Ghost stories. Anyway.",
		"note": "Dropping it fast. He doesn't want them thinking about it."},
	"l0_desk_1": {"scene": "l0_tour", "speaker": "ROURKE", "text": "The front desk scanner ate one of Vale's memos. The scraps went into a table.",
		"note": "Pointing at the desk."},
	"l0_desk_2": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Director wants to know what it said. Go ahead, terminal's on the desk.",
		"note": "Casual, but he wants to know too."},
	"l0_sort_hint": {"scene": "l0_memo", "speaker": "PA", "text": "Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon!",
		"note": "From the ceiling speakers. A canned reminder that plays every hour. Proud of the company, unaware of anyone listening."},
	"l0_memo_flag": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Nice work. I'll make sure that goes straight to the director.",
		"note": "Pleased, jotting it on his clipboard before he's read it. Warm; on a replay it's the worst thing he says all night."},
	"l0_memo_1": {"scene": "l0_memo", "speaker": "ROURKE", "text": "...Huh. She always was dramatic.",
		"note": "A beat too long before he speaks. Covering."},
	"l0_memo_2": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Grab the walkie-talkies from lost and found, back behind the desk.",
		"note": "Back to friendly, changing the subject."},
	"l0_memo_3": {"scene": "l0_memo", "speaker": "ROURKE", "text": "And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either.",
		"note": "Amused, he's said this to every visitor. A little eye-roll at corporate."},
	"l0_memo_4": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Grab one and I'll take you to the server room.",
		"note": "Friendly, already heading for the hall."},
	"l0_walkie": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Channel one. Keep them on. Reception's lousy once we're past the shutter. This way.",
		"note": "Offhand."},
	"l0_tape_1": {"scene": "l0_tape", "speaker": "MERCER", "text": "Harold Mercer. March of '94. My last day, apparently.",
		"note": "Click of the record button before this. Dry."},
	"l0_tape_2": {"scene": "l0_tape", "speaker": "MERCER", "text": "If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors.",
		"note": "Approving, a little smile."},
	"l0_tape_3": {"scene": "l0_tape", "speaker": "MERCER", "text": "Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out.",
		"note": "The one moment of anger, still controlled."},
	"l0_tape_4": {"scene": "l0_tape", "speaker": "MERCER", "text": "So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter.",
		"note": "Quiet, almost proud, then wry on the last sentence."},
	"l0_tape_5": {"scene": "l0_tape", "speaker": "MERCER", "text": "If it ever comes to that, look for my plans. The building's records remember more than people do.",
		"note": "Slow. Then the click of the stop button."},
	"l0_sra": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Here we are. Server Room A.",
		"note": "Badging the door. Pleasant, like the end of a tour."},

	# --- Level 1 -------------------------------------------------------------
	"l1_enter": {"scene": "l1_trap", "speaker": "ROURKE", "text": "Vale's last login came from this room. Come on in.",
		"note": "Calling back over his shoulder, inside the room."},
	"l1_terminal": {"scene": "l1_trap", "speaker": "ROURKE", "text": "Terminal's on the desk. Pull up her last session, I'll be right here.",
		"note": "Friendly, pointing. Then he goes quiet and drifts behind them."},
	"l1_trap_1": {"scene": "l1_trap", "speaker": "ROURKE", "text": "Sorry about this. Nothing personal.",
		"note": "The door has just locked. The friendliness switches off."},
	"l1_trap_2": {"scene": "l1_trap", "speaker": "ROURKE", "text": "Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself.",
		"note": "Tired, explaining a chore."},
	"l1_hit_1": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Stay down!", "note": "Swinging."},
	"l1_hit_2": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Should've stayed in the van.", "note": "Breathing hard."},
	"l1_hit_3": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Nobody's coming for you.", "note": "Low."},
	"l1_hit_4": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Hold still!", "note": "Frustrated."},
	"l1_hurt_1": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Agh!", "note": "Just a grunt of pain."},
	"l1_hurt_2": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Okay. Okay, that one hurt.", "note": "Winded, almost laughing."},
	"l1_hurt_3": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Lucky.", "note": "Spat out."},
	"l1_downed": {"scene": "l1_fight", "speaker": "ROURKE", "text": "Wait... wait. You don't know what you're doing.",
		"note": "On the floor, out of breath. Genuinely scared for the first time."},
	"l1_killed": {"scene": "l1_fate", "speaker": "WARDEN", "text": "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN.",
		"note": "Over the room's speakers. Unbothered, like reading a stock price."},
	"l1_tied_1": {"scene": "l1_fate", "speaker": "ROURKE", "text": "You think a bit of cable holds me?",
		"note": "Tied up on the floor, grinning through it."},
	"l1_tied_2": {"scene": "l1_fate", "speaker": "ROURKE", "text": "WARDEN will eat you alive in here.",
		"note": "Quieter. He means it."},
	"l1_login": {"scene": "l1_fate", "speaker": "WARDEN", "text": "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE.",
		"note": "The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant."},
	"l1_selftest": {"scene": "l1_fate", "speaker": "WARDEN", "text": "SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM.",
		"note": "The one line with a hint of a smirk."},
	"l1_found": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY.",
		"note": "Reading a rule it knows they're about to break. Cool."},
	"l1_no_badge": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "RESET REFUSED. BADGE REQUIRED.",
		"note": "Flat, instant."},
	"l1_panel_ok": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?",
		"note": "Patient, then a small dig."},
	"l1_panel_wrong": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS.",
		"note": "The last sentence slightly slower."},
	"l1_exit_open": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED.",
		"note": "Polite, and keeping score."},
	"l1_lockdown_tied": {"scene": "l1_exit", "speaker": "WARDEN", "text": "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D.",
		"note": "Reading a log entry."},
	"l1_sealed": {"scene": "l1_exit", "speaker": "WARDEN", "text": "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT.",
		"note": "The sign-off for the slice. Warm, like wishing them well."},

	# --- Level 2 (written ahead; the Level 2 build wires these) ---------------
	"l2_rourke_1": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Still on channel one? Good. Thought you'd want to know I'm out.",
		"note": "Through the walkie. Relaxed, enjoying himself again."},
	"l2_rourke_2": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Security office is the only way down from here. Say hi to the night guard for me.",
		"note": "Through the walkie, casual, like giving directions."},
	"l2_rourke_3": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Oh, he won't say much. Nobody's seen him since Tuesday.",
		"note": "Let it hang. Then the radio clicks off."},
	"l2_dead_escort": {"scene": "l2_security", "speaker": "WARDEN", "text": "REMINDER: VISITORS MUST REMAIN WITH THEIR ESCORT. YOUR ESCORT IS NO LONGER AVAILABLE. PLEASE WAIT WHERE YOU ARE.",
		"note": "Plays in one version of the story only. Patient, slightly too formal."},
	"l2_arrive": {"scene": "l2_security", "speaker": "WARDEN", "text": "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE.",
		"note": "Reassuring tone. It is not reassuring."},
	"l2_cameras": {"scene": "l2_security", "speaker": "WARDEN", "text": "CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF.",
		"note": "Small pause before the second sentence."},
	"l2_smudged": {"scene": "l2_security", "speaker": "WARDEN", "text": "TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU.",
		"note": "Not unfortunate for WARDEN."},
	"l2_door_ok": {"scene": "l2_security", "speaker": "WARDEN", "text": "DOOR COMMAND ACCEPTED. DOOR OPENED.",
		"note": "Confident. It is wrong."},
	"l2_door_fault": {"scene": "l2_security", "speaker": "WARDEN", "text": "ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING.",
		"note": "When the crew finds the fault themselves. Deadpan, unapologetic."},
	"l2_vale_1": {"scene": "l2_voicemail", "speaker": "VALE", "text": "Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry.",
		"note": "Beep before this. Hushed, fast."},
	"l2_vale_2": {"scene": "l2_voicemail", "speaker": "VALE", "text": "If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it.",
		"note": "Urgent. A glance over her shoulder in the voice."},
	"l2_vale_3": {"scene": "l2_voicemail", "speaker": "VALE", "text": "And please don't give your PIN to anyone. Not even Dale.",
		"note": "Softer. Then she hangs up."},
}


## From this level on, every line is held back for a later recording session.
const REVEAL_LEVEL := 10


## Lines in this scene would spoil a twist, so actors get them in a later session.
static func held_back(scene_data: Dictionary) -> bool:
	return scene_data.get("reveal", false) or int(scene_data.get("level", 0)) >= REVEAL_LEVEL


static func has_line(id: String) -> bool:
	return LINES.has(id)


static func get_line(id: String) -> Dictionary:
	return LINES.get(id, {})


static func scene(id: String) -> Dictionary:
	for s in SCENES:
		if s["id"] == id:
			return s
	return {}


## Line ids for one scene, in script order.
static func ids_in_scene(scene_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in LINES:
		if LINES[id]["scene"] == scene_id:
			out.append(id)
	return out
