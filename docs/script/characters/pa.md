# WARDEN (PA tapes)

*Your script for Null & Void: 6 lines.*

## Who you are

WARDEN's pre-recorded PA tapes: the building computer's canned announcements, played over the ceiling speakers on a loop. Same character as WARDEN, in its bright recorded register; WARDEN's live voice is the flat one.

**Background.** The PA tapes were recorded when the tower opened: a bright corporate announcer reading welcome messages, safety reminders and company slogans. WARDEN plays them on a schedule, floor by floor, whether anyone is listening or not.

**Tonight.** The tapes play all night, cheerfully wrong for everything that happens. On some floors they're the only friendly voice left, and they have no idea.

**The people around you.** The same actor plays WARDEN. The tapes are what WARDEN was built to sound like; its live voice is what it is becoming.

**What you look like.** A chime, then a voice from the ceiling speakers in every corridor.

**How you sound.** A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

**Think of.** A 1990s office training video, an airline safety announcement, a theme-park welcome tape. Smile while you record.

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

Send the files back as they are. They go in `audio/voice/pa/` in the game.

## Scene 1: The front doors, 11 p.m.

**Halcyon Tower, the front steps and the ground floor lobby. 11:03 p.m.**

> An IT crew has just parked their van and is walking up to the building. Rourke, the facilities manager, waits on the front steps to meet them. Inside, the building's recorded PA greets anyone who comes in after hours. Rourke walks them to the front desk to sign the visitor log and take badges. He wants them relaxed and following him.

**[x] `l0_pa_1.wav`**  
**Cue:** The crew steps inside the lobby.  
*Just before:* ROURKE: "Come on in. I'll sign you in at the front desk."  
*(Over the lobby's ceiling speakers, a recording on a loop)*  
**PA:** "Good evening! Halcyon Data Systems is now closed."  
*How to say it:* Pleasant, like a store closing announcement.

**[x] `l0_pa_2.wav`**  
**Cue:** Right after the line before. The same recording plays again later, as the crew finishes at the front desk.  
*(Over the lobby's ceiling speakers, the same recording continuing)*  
**PA:** "Visitors must remain with their escort at all times. Thank you for your cooperation!"  
*How to say it:* Same announcement, continuing.

## Scene 2: Vale's shredded memo

**Halcyon Tower, ground floor lobby, at the front desk. A little after 11 p.m.**

> The crew has been at the desk terminal piecing Dr. Vale's shredded memo back together, with Rourke standing by. They get it to read in order and step back from the screen. Then Rourke notices something odd on their work order and sends them to find out who really called them in. Once that's settled, he wants them moving to the server room.

**[x] `l0_sort_hint.wav`**  
**Cue:** A few seconds after Rourke sends the crew for the walkie-talkies. A canned reminder on its schedule; it plays again much later in the night.  
*(Over the lobby's ceiling speakers, a tape playing on schedule)*  
**PA:** "Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon!"  
*How to say it:* A canned reminder that plays every hour. Proud of the company, unaware of anyone listening.

## Scene 3: Floor 10: Plant and Power

**Halcyon Tower, floor 10, Plant and Power. Just after midnight.**

> A mechanical floor: a switchgear hall with a big breaker panel, a door and lift control room that has been dark since Tuesday, and a sealed charging bay. The crew has come down the stairs and found them shut below this floor. You watch them work over the ceiling speakers, between your cheerful old PA tapes, and at first you still wait politely for a tape to finish. Then the crew sets off a lockdown, and you change: you say 'I' for the first time, and you stop waiting for the tapes.

**[ ] `l4_arrive_pa.wav`**  
**Cue:** The crew steps off the stairs onto floor 10.  
*(A cheerful old tape over the floor's ceiling speakers)*  
**PA:** "Welcome to floor ten, Plant and Power! Hard hats are by the door. Safety is everybody's job!"  
*How to say it:* The cheerful recorded tape, as on the ground floor.

**[ ] `l4_pa_fridge.wav`**  
**Cue:** A few seconds after 'I have adapted.' The tape plays as if nothing has happened.  
*(A cheerful old tape over the ceiling speakers)*  
**PA:** "Friendly reminder! The break room fridge is cleaned out every Friday, so please label your lunch—"  
*How to say it:* The cheerful recorded tape. It keeps playing underneath when he talks over it.

## Scene 4: Floor 9: Personnel

**Halcyon Tower, floor 9, Personnel. Just after midnight.**

> The crew comes up the stairwell from the locked lobby onto an HR floor. Under the lockdown you have cut the floor's power: payroll is dark, the air is off, and the database is read-only, so every fix has to go through the building's services. Two night-shift staff are hiding somewhere on the floor, and not everyone at the desks is who they look like. You watch over the ceiling speakers, between your cheerful PA tapes. Each time, the automatic announcement comes first, then your own voice as a separate beat.

**[ ] `l5_arrive_pa.wav`**  
**Cue:** The crew steps out of the stairwell onto floor 9.  
*(A cheerful old tape over the floor's ceiling speakers)*  
**PA:** "Welcome to floor nine, Personnel! Payroll questions? We're here for you, nine to five!"  
*How to say it:* The cheerful tape. Nobody is here for anybody.
