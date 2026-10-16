class_name VoiceLines
extends RefCounted
## Every spoken line in the game, keyed by id. This is the script: the levels play
## lines by id (`hud.line("l0_greet_1")`), the recording list in docs/script/ is
## generated from it, and a recording named after the id replaces the timed subtitle.
## Change a line here, then run tools/write_script_docs.gd to refresh the docs.

## Who speaks, and how Augustine should play them.
const CHARACTERS := {
	"ROURKE": {
		"name": "Dale Rourke",
		"who": "Facilities manager, 50s. The director's plant.",
		"voice": "Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth.",
	},
	"WARDEN": {
		"name": "WARDEN",
		"who": "The campus AI, heard over 1997 PA speakers and terminals.",
		"voice": "Calm, polite, flat. Customer-service cadence with even pauses. The sarcasm is in the words, never the tone, and it never raises its voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.",
	},
	"VALE": {
		"name": "Dr. Iris Vale",
		"who": "Lead engineer, 40s. Officially missing, presumed dead.",
		"voice": "Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.",
	},
	"DISPATCH": {
		"name": "Byte-Right dispatch",
		"who": "The IT company's night dispatcher, heard on the van radio.",
		"voice": "Bored, routine, a little crackly. Reading tickets off a list at the end of a long shift. Nothing about this call is unusual to them.",
	},
	"MERCER": {
		"name": "Harold Mercer",
		"who": "Halcyon's founder, 70s. Fired in 1994 for fighting WARDEN.",
		"voice": "Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.",
	},
}

## Scenes in story order. `wired` is false for lines written ahead of their level.
const SCENES := [
	{"id": "l0_van", "level": 0, "title": "The IT van", "wired": true,
		"context": "The crew sits in their Byte-Right IT van in Halcyon's car park while dispatch reads them the job over the radio. Nothing is wrong yet: this is an ordinary after-hours callout. The radio stops once everyone has readied up."},
	{"id": "l0_arrive", "level": 0, "title": "The front doors, 11 p.m.", "wired": true,
		"context": "The crew walks up from the van. Rourke opens the front doors and WARDEN greets them over the PA. Rourke walks them in to the front desk; the doors lock behind them and he has them sign the visitor log."},
	{"id": "l0_tour", "level": 0, "title": "The tour", "wired": true,
		"context": "Rourke walks the crew to reception, explaining the job and the building's history."},
	{"id": "l0_memo", "level": 0, "title": "Vale's shredded memo", "wired": true,
		"context": "The crew rebuilds Vale's memo at the front desk terminal. It says not to trust anyone who offers to escort you. Rourke is standing right there."},
	{"id": "l0_tape", "level": 0, "title": "Mercer's cassette (optional)", "wired": true,
		"context": "In the forgotten closet behind the air-return vent, a cassette recorder sits on the shelf under the old newspaper clipping. Only players who crawl through the vent hear it."},
	{"id": "l0_hall", "level": 0, "title": "To Server Room A", "wired": true,
		"context": "Rourke badges the hall shutter; it jams halfway. He leaves to take the staff door and is waiting at Server Room A."},
	{"id": "l1_trap", "level": 1, "title": "The betrayal", "wired": true,
		"context": "Rourke leads the crew into Server Room A, the door locks behind them, the lights go red, and he turns on them."},
	{"id": "l1_fight", "level": 1, "title": "The fight (barks)", "wired": true,
		"context": "Short lines played at random during the fight: when he lands a hit, when he takes one, and when he goes down. Keep each one short; they can play many times."},
	{"id": "l1_fate", "level": 1, "title": "Kill or tie him up", "wired": true,
		"context": "Rourke is down. If the crew kills him, his badge's dead-man switch fires and WARDEN starts the lockdown. If they tie him up, he taunts them. Either way they take his badge and the terminal logs in with it."},
	{"id": "l1_controllers", "level": 1, "title": "Resetting the door controller", "wired": true,
		"context": "The crew reads WARDEN's self-test, queries door_controllers, and resets the right rack. The terminal shows the details; these lines are WARDEN reacting."},
	{"id": "l1_exit", "level": 1, "title": "Lockdown", "wired": true,
		"context": "The crew steps through the emergency exit. If Rourke was tied up, he has cut himself loose and authorized the lockdown himself."},
	{"id": "l2_radio", "level": 2, "title": "Rourke on the radio (if he escaped)", "wired": false,
		"context": "Level 2 opening, only if Rourke was tied up in Level 1. He still has his facilities radio on channel 1 and calls the crew's walkie-talkies."},
	{"id": "l2_security", "level": 2, "title": "The security office", "wired": false,
		"context": "WARDEN on the security office PA. The Watcher moves only when unseen; GET /cameras shows live camera states; the guard's name on the sign-in sheet is smudged (LIKE 'Har%'); a door command reports success but the door has an actuator fault (the first terminal lie)."},
	{"id": "l2_voicemail", "level": 2, "title": "Vale's voicemail", "wired": false,
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
	"l0_pa_1": {"scene": "l0_arrive", "speaker": "WARDEN", "text": "GOOD EVENING. HALCYON DATA SYSTEMS IS CLOSED.",
		"note": "Over the lobby PA. Pleasant, like a store closing announcement."},
	"l0_pa_2": {"scene": "l0_arrive", "speaker": "WARDEN", "text": "VISITORS MUST REMAIN WITH THEIR ESCORT AT ALL TIMES. THANK YOU FOR YOUR COOPERATION.",
		"note": "Same announcement, continuing."},
	"l0_greet_1": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "There you are. Dale Rourke, facilities. I'll be your escort tonight.",
		"note": "Friendly, a handshake in the voice."},
	"l0_greet_2": {"scene": "l0_arrive", "speaker": "ROURKE", "text": "Don't mind WARDEN. It says that to everybody.",
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
	"l0_tour_3": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Fun fact: the man who founded this place, Harold Mercer, hated computers running buildings.",
		"note": "Tour-guide mode, enjoying himself."},
	"l0_tour_4": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Board fired him when they installed WARDEN. That's the AI that runs the campus now.",
		"note": ""},
	"l0_tour_5": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable.",
		"note": "Spooky-campfire voice, playing it up."},
	"l0_tour_6": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Ghost stories. Anyway.",
		"note": "Dropping it fast. He doesn't want them thinking about it."},
	"l0_desk_1": {"scene": "l0_tour", "speaker": "ROURKE", "text": "The front desk scanner ate one of Vale's memos. The scraps went into a table.",
		"note": "Pointing at the desk."},
	"l0_desk_2": {"scene": "l0_tour", "speaker": "ROURKE", "text": "Director wants to know what it said. Go ahead, terminal's on the desk.",
		"note": "Casual, but he wants to know too."},
	"l0_sort_hint": {"scene": "l0_memo", "speaker": "WARDEN", "text": "THOSE SCRAPS ARE OUT OF ORDER. EACH ONE HAS A PIECE NUMBER. SORT THEM WITH ORDER BY.",
		"note": "From the terminal speaker, helpful in the way a parking meter is helpful."},
	"l0_memo_flag": {"scene": "l0_memo", "speaker": "WARDEN", "text": "DOCUMENT RECONSTRUCTED. A COPY HAS BEEN SENT TO THE DIRECTOR.",
		"note": "Brightly. This should land as a chill."},
	"l0_memo_1": {"scene": "l0_memo", "speaker": "ROURKE", "text": "...Huh. She always was dramatic.",
		"note": "A beat too long before he speaks. Covering."},
	"l0_memo_2": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Grab the walkie-talkies from lost and found behind the desk. Over the counter, it's fine.",
		"note": "Back to friendly, changing the subject."},
	"l0_walkie": {"scene": "l0_memo", "speaker": "ROURKE", "text": "Channel one. Keep them on. Reception's lousy once we're past the shutter.",
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
	"l0_shutter_1": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Jammed again. You'll have to duck under it.",
		"note": "Annoyed at the shutter, not at them."},
	"l0_shutter_2": {"scene": "l0_hall", "speaker": "ROURKE", "text": "I'll take the staff door and meet you at the server room.",
		"note": "Already walking away."},
	"l0_sra": {"scene": "l0_hall", "speaker": "ROURKE", "text": "Server Room A. After you.",
		"note": "Holding the door. Polite. Too polite."},

	# --- Level 1 -------------------------------------------------------------
	"l1_enter": {"scene": "l1_trap", "speaker": "ROURKE", "text": "Vale's last login came from this room. Come on in.",
		"note": "Calling back over his shoulder, inside the room."},
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
	"l1_selftest": {"scene": "l1_fate", "speaker": "WARDEN", "text": "SELF-TEST COMPLETE. TWO FAILURES. I'M SURE YOU'LL WORK IT OUT.",
		"note": "The one line with a hint of a smirk."},
	"l1_found": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "THAT IS THE ONE. A MANUAL RESET AT ITS RACK WILL CLEAR IT.",
		"note": "Grudging."},
	"l1_no_badge": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "RESET REFUSED. BADGE REQUIRED.",
		"note": "Flat, instant."},
	"l1_panel_ok": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "THAT CONTROLLER IS WORKING NORMALLY. NOTHING TO RESET.",
		"note": "Patient, like talking to a child."},
	"l1_panel_wrong": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "THAT IS NOT THE EXIT'S CONTROLLER. PANELS LOCKED. PLEASE STOP TOUCHING THINGS.",
		"note": "The last sentence slightly slower."},
	"l1_exit_open": {"scene": "l1_controllers", "speaker": "WARDEN", "text": "CONTROLLER RESET. EXIT UNLOCKED. PLEASE PROCEED CALMLY.",
		"note": ""},
	"l1_lockdown_tied": {"scene": "l1_exit", "speaker": "WARDEN", "text": "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D.",
		"note": "Reading a log entry."},
	"l1_sealed": {"scene": "l1_exit", "speaker": "WARDEN", "text": "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT.",
		"note": "The sign-off for the slice. Warm, like wishing them well."},

	# --- Level 2 (written ahead; the Level 2 build wires these) ---------------
	"l2_rourke_1": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Still on channel one? Good. Thought you'd want to know I'm out.",
		"note": "Through the walkie. Relaxed, enjoying himself again."},
	"l2_rourke_2": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Security office is the only way down from here. Say hi to the night guard for me.",
		"note": ""},
	"l2_rourke_3": {"scene": "l2_radio", "speaker": "ROURKE", "text": "Oh, he won't say much. Nobody's seen him since Tuesday.",
		"note": "Let it hang. Then the radio clicks off."},
	"l2_dead_escort": {"scene": "l2_security", "speaker": "WARDEN", "text": "REMINDER: VISITORS MUST REMAIN WITH THEIR ESCORT. YOUR ESCORT IS NO LONGER AVAILABLE. PLEASE WAIT WHERE YOU ARE.",
		"note": "Only if Rourke was killed. Plays on arrival, in place of Rourke's radio call."},
	"l2_arrive": {"scene": "l2_security", "speaker": "WARDEN", "text": "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE.",
		"note": "Reassuring tone. It is not reassuring."},
	"l2_cameras": {"scene": "l2_security", "speaker": "WARDEN", "text": "LIVE CAMERA STATES ARE AVAILABLE AT GET SLASH CAMERAS. I SUGGEST CHECKING THEM. OFTEN.",
		"note": "Small pause before \"Often.\""},
	"l2_smudged": {"scene": "l2_security", "speaker": "WARDEN", "text": "GUARD PINS ARE KEPT IN STAFF RECORDS. THE NAME ON TONIGHT'S SIGN-IN SHEET IS SMUDGED. HOW UNFORTUNATE.",
		"note": "Not unfortunate for WARDEN."},
	"l2_door_ok": {"scene": "l2_security", "speaker": "WARDEN", "text": "DOOR COMMAND ACCEPTED. DOOR OPENED.",
		"note": "Confident. It is wrong."},
	"l2_door_fault": {"scene": "l2_security", "speaker": "WARDEN", "text": "CORRECTION. THE DOOR REPORTS AN ACTUATOR FAULT. THE REQUEST WAS RECEIVED. THE DOOR DID NOT CARE.",
		"note": "When the players check the sensor. Deadpan."},
	"l2_vale_1": {"scene": "l2_voicemail", "speaker": "VALE", "text": "Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry.",
		"note": "Beep before this. Hushed, fast."},
	"l2_vale_2": {"scene": "l2_voicemail", "speaker": "VALE", "text": "If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it.",
		"note": "Urgent. A glance over her shoulder in the voice."},
	"l2_vale_3": {"scene": "l2_voicemail", "speaker": "VALE", "text": "And please don't give your PIN to anyone. Not even Dale.",
		"note": "Softer. Then she hangs up."},
}


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
