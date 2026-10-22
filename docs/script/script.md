# Null & Void: voice script

Generated from `scripts/audio/voice_lines.gd`. Edit the lines there, then run `godot --headless -s tools/write_script_docs.gd`.
Each line's file name is in brackets; see [recording-list.md](recording-list.md) for how to record.

## Cast

**Dale Rourke** (ROURKE). Facilities manager, 50s. The director's plant.

> Warm, folksy, a little too friendly: a tour guide who has given this speech a hundred times. At the betrayal the warmth drains out but he never shouts; he sounds tired, not evil. In the fight: short, winded, through his teeth. He laughs once, in the lab: the only time his warmth turns into real glee.

**WARDEN** (WARDEN). The campus security system, heard over 1997 PA speakers and terminals. Not a villain: it enforces protocol, and turns hostile only once the crew breaches it and loses their escort.

> Calm, polite, flat. Customer-service cadence with even pauses. Two phases. While visitors have their escort it is neutral and procedural: courteous, policy-minded, like any building system. Once protocol is breached it turns cold and hostile: refusals, warnings and quiet threats. It never helps in either phase. The sarcasm is in the words, never the tone, and it never raises its voice. From Level 4 its fault lets its own personality leak out: some lines are the automatic announcement first, then a separate teasing beat in its own dry voice. Subtitles are in capitals because that is how WARDEN prints; say them at normal volume. Record dry: the game adds the PA speaker sound.

**WARDEN (PA tapes)** (PA). WARDEN's own pre-recorded PA module. Subtitled as PA so players don't connect it to WARDEN yet; they realize later it was watching all along. The live WARDEN voice says nothing in Level 0.

> A bright 1990s corporate announcer: upbeat, warm, a little too cheerful, like an office-park training tape. Never reacts to anyone; every line sounds recorded years ago. Recorded by the WARDEN actor, nothing like WARDEN's flat live voice. Record dry: the game adds the PA speaker sound.

**Dr. Iris Vale** (VALE). Lead engineer, 40s. Officially missing, presumed dead.

> Quick and precise, frightened but holding it together. Heard on an answering machine, so a little close to the mic and hushed, like someone might be listening.

**Maddison Kowalski** (MADDISON). Byte-Right's CEO and founder. Mature, attractive, confident and upbeat. On screen in the garage opening and in every book huddle. She stays behind at the garage, so she's tonight's dispatch on the van radio.

> Warm, quick and sure of herself, with a saleswoman's energy. The crew's friend more than their boss, and the one who believes in them before they believe in themselves. On the van radio she puts on a 'professional dispatcher' voice: bored, routine, reading tickets, a bluff that doesn't quite hide the excitement.

**Radio newsreader** (NEWSREADER). Local morning radio, heard in the news-story ending.

> Smooth, professional, warm, slightly bored. Calm public-radio delivery with no drama; the flatness is what makes it land.

**The crew (player characters)** (CREW). Player-character commentary: whichever of the 12 playable characters fits the moment says it, in their own voice. Recordings go in audio/voice/crew_<character>/<id>.wav. The subtitle shows the player's own name. Played by Commentary (scripts/audio/commentary.gd).

> Yourself, as your character: muttering to the crew, not performing. Quick and natural. Never sounds like a hint; it's somebody remembering where they saw something.

**Harold Mercer** (MERCER). Halcyon's founder, 70s. Fired in 1994 for fighting WARDEN.

> Gravelly, wry, unhurried. An old engineer talking into a cassette recorder at his desk on his last day. Amused more than angry.

## Crew barks

Each playable crew member's own short lines, played by Co-op. Their shared commentary lines are in the scenes below, as CREW.

**Dana Okafor** (`dana`, 30s). Ex-cable installer. Blunt and practical, and has crawled through more ceilings than anyone alive. Unbothered by heights and vents. Calls everyone "chief".

- *the van ready-up:* Let's get this over with. `[ready]`
- *calling the crew over:* Chief. Over here. `[over_here]`
- *a clue pickup that has no written discovery line:* Got something. `[found_something]`
- *starting a notes huddle:* Everyone, quick. Look at this. `[huddle]`
- *asking for shoulders:* Give us a leg up? `[need_boost]`
- *answering a call:* Coming. `[on_my_way]`
- *something jumps out:* Nope. Nope. `[scared]`
- *downed or caught:* Little help! `[help]`
- *helped up or boosted:* Cheers, chief. `[thanks]`
- *a locked door or a blocked route:* Not getting through that. `[no_way]`
- *radio, something's near:* Shh. Something's here. `[quiet]`

**Priya Raman** (`priya`, 20s). Ran a phone-repair kiosk at the mall. Talks fast, fixes faster, and is relentlessly optimistic. Thinks this is the best night of her life, right up until it isn't.

- *the van ready-up:* Ooh, okay. Ready, ready! `[ready]`
- *calling the crew over:* Guys! Over here, come look! `[over_here]`
- *a clue pickup that has no written discovery line:* Oh, this is something! `[found_something]`
- *starting a notes huddle:* Huddle! Huddle up! `[huddle]`
- *asking for shoulders:* Can somebody lift me? I'm tiny. `[need_boost]`
- *answering a call:* On my way, on my way! `[on_my_way]`
- *something jumps out:* Oh my God. Oh my God. `[scared]`
- *downed or caught:* Help! Help me! `[help]`
- *helped up or boosted:* You're the best. `[thanks]`
- *a locked door or a blocked route:* Okay, that's locked. Rude. `[no_way]`
- *radio, something's near:* Guys. Whisper. Something's moving. `[quiet]`

**Rosa Delgado** (`rosa`, 30s). A school office manager doing nights for extra cash. Organised, unflappable, dry as toast. Treats the crew like a class on a field trip.

- *the van ready-up:* Seatbelts, everyone. `[ready]`
- *calling the crew over:* Over here, please. Today. `[over_here]`
- *a clue pickup that has no written discovery line:* Well, now. Look at this. `[found_something]`
- *starting a notes huddle:* Everybody gather round. `[huddle]`
- *asking for shoulders:* A hand up, if someone would be so kind. `[need_boost]`
- *answering a call:* I'm coming. Don't touch anything. `[on_my_way]`
- *something jumps out:* Mother of God. `[scared]`
- *downed or caught:* Somebody! Now! `[help]`
- *helped up or boosted:* Thank you. Noted. `[thanks]`
- *a locked door or a blocked route:* That's not opening for us. `[no_way]`
- *radio, something's near:* Quiet. All of you. `[quiet]`

**Kit Larsen** (`kit`, 20s). Bike courier and rooftop free-runner. Fearless and cocky, and climbs first and thinks later. The one most likely to say "watch this".

- *the van ready-up:* Let's go, let's go. `[ready]`
- *calling the crew over:* Up here! Come on! `[over_here]`
- *a clue pickup that has no written discovery line:* Ha. Found it. `[found_something]`
- *starting a notes huddle:* Okay, team talk. Quick. `[huddle]`
- *asking for shoulders:* Boost me. I've got the rest. `[need_boost]`
- *answering a call:* Two seconds! `[on_my_way]`
- *something jumps out:* Whoa, whoa, whoa! `[scared]`
- *downed or caught:* I'm caught! Get it off! `[help]`
- *helped up or boosted:* Owe you one. `[thanks]`
- *a locked door or a blocked route:* Dead end. Find another way. `[no_way]`
- *radio, something's near:* Stop. Don't move. `[quiet]`

**June Whitaker** (`june`, 60s). Ham-radio operator for forty years, and Maddison's aunt. Calm and precise, and the only one who knows radio etiquette. Says "over" whether or not she's on the radio.

- *the van ready-up:* Ready when you are. Over. `[ready]`
- *calling the crew over:* To me, please. Over here. `[over_here]`
- *a clue pickup that has no written discovery line:* I have something. Come and see. `[found_something]`
- *starting a notes huddle:* Let's all stop and think a moment. `[huddle]`
- *asking for shoulders:* I'll need a lift up there, dear. `[need_boost]`
- *answering a call:* Copy. On my way. `[on_my_way]`
- *something jumps out:* Good heavens! `[scared]`
- *downed or caught:* Mayday! Mayday! `[help]`
- *helped up or boosted:* Much obliged. `[thanks]`
- *a locked door or a blocked route:* Negative. That's sealed. `[no_way]`
- *radio, something's near:* Radio silence. Something's close. `[quiet]`

**Mei Tanaka** (`mei`, 30s). Ex-barista with a nervous laugh. Jumpy, very funny, and much braver than she thinks. Narrates her own panic.

- *the van ready-up:* I'm ready. I'm not ready. I'm ready. `[ready]`
- *calling the crew over:* Over here! Before I chicken out! `[over_here]`
- *a clue pickup that has no written discovery line:* Is this something? I think this is something. `[found_something]`
- *starting a notes huddle:* Can we huddle? I want to huddle. `[huddle]`
- *asking for shoulders:* Lift me up? Don't drop me. `[need_boost]`
- *answering a call:* Coming! Slowly! But coming! `[on_my_way]`
- *something jumps out:* Nope! Absolutely not! `[scared]`
- *downed or caught:* Help! Help, help, help! `[help]`
- *helped up or boosted:* Oh, thank God. Thank you. `[thanks]`
- *a locked door or a blocked route:* Locked. Great. Love that. `[no_way]`
- *radio, something's near:* Shh. Do you hear that? `[quiet]`

**Marcus Bell** (`marcus`, 40s). Former mall security guard. Steady, cautious and observant. Checks corners. Knows exactly how night guards think, and hates it here.

- *the van ready-up:* Alright. Let's do this right. `[ready]`
- *calling the crew over:* Over here. Stay together. `[over_here]`
- *a clue pickup that has no written discovery line:* Hold up. Found something. `[found_something]`
- *starting a notes huddle:* Everybody, eyes here. `[huddle]`
- *asking for shoulders:* Need a boost up. `[need_boost]`
- *answering a call:* Moving to you. `[on_my_way]`
- *something jumps out:* Back up! Back up! `[scared]`
- *downed or caught:* Man down! Need help! `[help]`
- *helped up or boosted:* Appreciate it. `[thanks]`
- *a locked door or a blocked route:* Locked tight. Try another way. `[no_way]`
- *radio, something's near:* Hold. Something's moving. `[quiet]`

**Theo Brandt** (`theo`, 20s). A gamer with a sarcastic streak who answered Maddison's ad. Quick, funny and convinced this is just like a video game. It isn't.

- *the van ready-up:* Loading in. `[ready]`
- *calling the crew over:* Yo. Over here. `[over_here]`
- *a clue pickup that has no written discovery line:* Ooh. Loot. `[found_something]`
- *starting a notes huddle:* Team meeting. Strategy time. `[huddle]`
- *asking for shoulders:* Boost me? Classic co-op move. `[need_boost]`
- *answering a call:* Omw. `[on_my_way]`
- *something jumps out:* What is THAT?! `[scared]`
- *downed or caught:* I'm down! Revive me! `[help]`
- *helped up or boosted:* GG. Thanks. `[thanks]`
- *a locked door or a blocked route:* Locked. Obviously. `[no_way]`
- *radio, something's near:* Stealth section. Shh. `[quiet]`

**Sam Abara** (`sam`, 30s). Professional mover. Big, gentle and strong. The crew's boost and its heavy lifter, and the calmest voice in the room.

- *the van ready-up:* Ready. `[ready]`
- *calling the crew over:* Over here, folks. `[over_here]`
- *a clue pickup that has no written discovery line:* This look important to you? `[found_something]`
- *starting a notes huddle:* Let's slow down and look. `[huddle]`
- *asking for shoulders:* Gonna need help with this one. `[need_boost]`
- *answering a call:* Coming your way. `[on_my_way]`
- *something jumps out:* Whoa. Easy. Easy. `[scared]`
- *downed or caught:* Need a hand here! `[help]`
- *helped up or boosted:* Thank you, friend. `[thanks]`
- *a locked door or a blocked route:* That won't budge. And I tried. `[no_way]`
- *radio, something's near:* Hush, now. Listen. `[quiet]`

**Luis Ortega** (`luis`, 50s). Handyman, and Maddison's oldest friend. Warm, chatty, and believes everything can be fixed by turning it off and on again. Mostly, he's right.

- *the van ready-up:* Vámonos. `[ready]`
- *calling the crew over:* Hey, hey. Over here. `[over_here]`
- *a clue pickup that has no written discovery line:* Look what I found. `[found_something]`
- *starting a notes huddle:* Okay, everybody. Think. `[huddle]`
- *asking for shoulders:* Give an old man a lift? `[need_boost]`
- *answering a call:* I'm coming, I'm coming. `[on_my_way]`
- *something jumps out:* ¡Ay, Dios mío! `[scared]`
- *downed or caught:* Help me! Quick! `[help]`
- *helped up or boosted:* Gracias, mijo. `[thanks]`
- *a locked door or a blocked route:* Locked. Maybe we turn it off and on? `[no_way]`
- *radio, something's near:* Shh. Something's out there. `[quiet]`

**Ike Novak** (`ike`, 20s). A startup dropout who talks in buzzwords. Overconfident, bluffs hardest of anyone, and is secretly the most scared.

- *the van ready-up:* Let's disrupt this. `[ready]`
- *calling the crew over:* Over here. Let's sync. `[over_here]`
- *a clue pickup that has no written discovery line:* Okay, this is a key insight. `[found_something]`
- *starting a notes huddle:* Quick stand-up, everybody. `[huddle]`
- *asking for shoulders:* Can I get some lift? Literally. `[need_boost]`
- *answering a call:* Pivoting to you. `[on_my_way]`
- *something jumps out:* Oh no. Oh no no no. `[scared]`
- *downed or caught:* This is a blocker! Help! `[help]`
- *helped up or boosted:* Huge. Thank you. `[thanks]`
- *a locked door or a blocked route:* Hard blocker. Locked. `[no_way]`
- *radio, something's near:* Okay, nobody talk. `[quiet]`

**Walt Henley** (`walt`, 30s). Power-company lineman between storm callouts. Grumpy, unhurried, and acts like he's seen everything twice. He came along "to keep an eye on you idiots".

- *the van ready-up:* Let's get it done. `[ready]`
- *calling the crew over:* Over here. Come on. `[over_here]`
- *a clue pickup that has no written discovery line:* Huh. Lookit this. `[found_something]`
- *starting a notes huddle:* Everybody stop. Think. `[huddle]`
- *asking for shoulders:* Bad shoulder. Give me a hand up. `[need_boost]`
- *answering a call:* Hold your horses. Coming. `[on_my_way]`
- *something jumps out:* Jesus, Mary and Joseph! `[scared]`
- *downed or caught:* Somebody! Get it off me! `[help]`
- *helped up or boosted:* Mm. Thanks. `[thanks]`
- *a locked door or a blocked route:* That's not opening. `[no_way]`
- *radio, something's near:* Shut it. Listen. `[quiet]`

## Level 0

### The garage

*The game opens at Byte-Right's garage home base, earlier that night. The crew walks in and sits facing Maddison at the whiteboard. She briefs them (money, goals, the Halcyon job), sends them to the punching bag, points them at the work order in their notebooks, then at Easy SQL on the shelf by the side door, and reads chapter zero with them. Then everyone gets in the van. Lines ending _solo are the one-player versions.*

**MADDISON:** *(Big, warm, delighted to have an audience. The crew is already sitting, facing her.)* Okay! Everybody comfy? Look at you. My whole company, in one garage. `[l0_brief_1]`

**MADDISON:** *(Solo version. The same joke, a little teasing.)* Okay! Look at you. My whole company, in one seat. `[l0_brief_1_solo]`

**MADDISON:** *(Cheerful, as if it's good news. Counting it off on her fingers.)* Where we stand. Rent's due Friday, the van's held together with tape, and our best client is a library that pays in exact change. `[l0_brief_2]`

**MADDISON:** *(Every 'maybe' a little grander, then the sign brings it back down to earth.)* So this year's goal was simple. Stay open. Maybe a second van. Maybe a sign that doesn't fall off. `[l0_brief_3]`

**MADDISON:** *(Building to it. She can't stand still for 'Ours.')* Forget all that. We got Halcyon. The overnight database contract. Ours. `[l0_brief_4]`

**MADDISON:** *(Quickly, before anyone can ask.)* How? I underbid everybody. By a lot. Don't ask how much. Job's tonight, eleven o'clock. `[l0_brief_5]`

**MADDISON:** *(Laughing, shooing them off.)* You guys are too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down. `[l0_bag]`

**MADDISON:** *(Solo version. Laughing, shooing them off.)* You're too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down. `[l0_bag_solo]`

**MADDISON:** *(Once everyone's back in their seats. A little flirty, played light, like a coach.)* Better? Good. Now eyes on me, gorgeous people. `[l0_bag_back]`

**MADDISON:** *(Solo version. A little flirty, played light, like a coach.)* Better? Good. Now eyes on me, gorgeous. `[l0_bag_back_solo]`

**MADDISON:** *(Pleased with herself for being organized.)* I put a copy of the work order in each of your notebooks. Pull it out and take a look. `[l0_workorder]`

**MADDISON:** *(Solo version. Pleased with herself for being organized.)* I put a copy of the work order in your notebook. Pull it out and take a look. `[l0_workorder_solo]`

**MADDISON:** *(The smile stays on. She leaves the sentence hanging and waits. Nobody does.)* Small problem. It says database. And unless one of you secretly knows SQL... `[l0_book_catch]`

**MADDISON:** *(Solo version. The smile stays on. She leaves the sentence hanging and waits.)* Small problem. It says database. And unless you secretly know SQL... `[l0_book_catch_solo]`

**MADDISON:** *(Proud of this. Holding up the receipt, not the book.)* ...I stopped by the bookstore. Easy SQL. 'Learn databases in a weekend.' We've got till eleven. `[l0_bookstore]`

**MADDISON:** *(Pointing at the side door to the house.)* It's in the shop bag on the shelf by the side door. One of you go grab it. `[l0_grab]`

**MADDISON:** *(Solo version. Pointing at the side door to the house.)* It's in the shop bag on the shelf by the side door. Go on, grab it for me. `[l0_grab_solo]`

**MADDISON:** *(When whoever got the book sits down. Uncapping a marker with a flourish, like she's about to teach a class she's never taken.)* Thank you! Okay. Whiteboard. Chapter zero. We're reading this together. `[l0_whiteboard]`

**MADDISON:** *(Solo version. Uncapping a marker with a flourish.)* Thank you! Okay. Whiteboard. Chapter zero. Let's read this together. `[l0_whiteboard_solo]`

**MADDISON:** *(Genuinely thrilled. After the huddle's quiz.)* Look at that. You're practically engineers. Take the book with you. Everybody in the van. `[l0_garage_5]`

**MADDISON:** *(Solo version. Genuinely thrilled. After the huddle's quiz.)* Look at that. You're practically an engineer. Take the book with you. Into the van. `[l0_garage_5_solo]`

**MADDISON:** *(At the van door, counting the rules off. She stays behind.)* Rules for tonight. Nod a lot. Anything you don't know, you need to check the logs. And if anyone asks, we've got a fleet. You're van three. I'll be on the radio. `[l0_garage_6]`

### Book huddles: SELECT and ORDER BY

*Flashbacks to the garage, earlier that night ('The garage, earlier that night', sepia). A player reads the chapter aloud and the crew votes on its quiz; Maddison stands at the head of the bench and opens and closes each chapter. Never gives the night's answers.* *(Written ahead: not in the game yet.)*

**MADDISON:** *(Disbelieving, delighted.)* Chapter one. SELECT, FROM, and a semicolon. That's it? That's a whole language? `[l0_huddle_select_1]`

**MADDISON:** *(Deadly serious about the one thing they're sure of.)* Book says never forget the semicolon. Says it twice. So I'm saying it twice. Semicolon. `[l0_huddle_select_2]`

**MADDISON:** *(Reading off the page.)* Chapter two. 'Putting things in order.' Now that, I can get behind. `[l0_huddle_order_1]`

**MADDISON:** *(Scribbling.)* Smallest first, unless you say DESC. Write that down. I'm writing it down. `[l0_huddle_order_2]`

### The IT van

*The crew sits in their Byte-Right IT van in Halcyon's car park while dispatch reads them the job over the radio. Nothing is wrong yet: this is an ordinary after-hours callout. The radio stops once everyone has readied up.*

**MADDISON:** *(Over the van radio, in the professional dispatcher voice. 'Van three' is a bluff: they own one van.)* Van three, you're on site at Halcyon Data Systems. After-hours callout. `[l0_dispatch_1]`

**MADDISON:** *(Reading it off the ticket.)* They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors. `[l0_dispatch_2]`

**MADDISON:** *(Bored, reading the form. Signing off, already onto the next call.)* Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out. `[l0_dispatch_3]`

### The front doors, 11 p.m.

*The crew walks up from the van. Rourke opens the front doors as the building PA plays its closing announcement. Rourke walks them in to the front desk; the doors lock behind them and he has them sign the visitor log.*

**ROURKE:** *(Waiting outside the front doors as the crew walks up. Friendly, a handshake in the voice.)* There you are. Dale Rourke, facilities. I'll be your escort tonight. `[l0_greet_1]`

**ROURKE:** *(Still smiling. Should sound like a joke the first time and a threat on replay.)* Badge rules after hours. You don't go anywhere I don't take you. `[l0_greet_3]`

**ROURKE:** *(Holding the door, waving them through.)* Come on in. I'll sign you in at the front desk. `[l0_greet_4]`

**PA:** *(Over the lobby PA, as the crew steps inside. Pleasant, like a store closing announcement.)* Good evening! Halcyon Data Systems is now closed. `[l0_pa_1]`

**PA:** *(Same announcement, continuing.)* Visitors must remain with their escort at all times. Thank you for your cooperation! `[l0_pa_2]`

**ROURKE:** *(Inside the lobby, right after the PA. Chuckling, waving at the ceiling speaker.)* Sorry about that. The company loves its PA system. `[l0_greet_2]`

**ROURKE:** *(Casual, reassuring. Nothing to worry about. (On a replay it lands differently.))* Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me. `[l0_signin]`

**ROURKE:** *(Handing them over the desk, routine. Helpful, a little bored.)* Visitor badges. Keep them on you. Doors upstairs won't let you through without one. `[l0_badges]`

### The tour

*Rourke walks the crew to reception and explains the job.*

**ROURKE:** *(Walking. Matter-of-fact, the way you'd mention the weather.)* Here's the job. Dr. Vale, our lead engineer, went missing three nights ago. `[l0_tour_1]`

**ROURKE:** *(Small beat before "Quietly.")* Her systems are a mess and the director wants them recovered by morning. Quietly. `[l0_tour_2]`

**ROURKE:** *(Pointing at the desk.)* The front desk scanner ate one of Vale's memos. The scraps went into a table. `[l0_desk_1]`

**ROURKE:** *(Casual, but he wants to know too.)* Director wants to know what it said. Go ahead, terminal's on the desk. `[l0_desk_2]`

### Vale's shredded memo

*The crew rebuilds Vale's memo at the front desk terminal. It says not to trust anyone who offers to escort you. Rourke is standing right there. Then he points out the work order's caller isn't him: the call came from Harold Mercer's old extension, dead since 1994.*

**PA:** *(From the ceiling speakers. A canned reminder that plays every hour. Proud of the company, unaware of anyone listening.)* Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon! `[l0_sort_hint]`

**ROURKE:** *(Pleased, jotting it on his clipboard before he's read it. Warm; on a replay it's the worst thing he says all night.)* Nice work. I'll make sure that goes straight to the director. `[l0_memo_flag]`

**ROURKE:** *(A beat too long before he speaks. Covering.)* ...Huh. She always was dramatic. `[l0_memo_1]`

**ROURKE:** *(Mild, a little puzzled, tapping the work order. Not suspicious yet.)* One thing on your paperwork. It says I called you in. I didn't. That call came from building services. `[l0_caller_1]`

**ROURKE:** *(Helpful, easygoing. Nodding at the terminal.)* Want to know who? The staff directory's on that terminal. `[l0_caller_2]`

**ROURKE:** *(Nodding down the back corridor toward the mailroom. Amused, a little fond.)* Mailroom. Clerk's got the only phone list in this building that's actually up to date. She pinned it to the wall so nobody walks off with it. `[l0_mailroom_1]`

**ROURKE:** *(A beat of real surprise, then he brushes it off and moves on.)* Mercer? Huh. That line's been dead for years. Somebody's having fun with the phones. Anyway. `[l0_caller_3]`

**ROURKE:** *(Back to friendly, changing the subject.)* Grab the walkie-talkies from lost and found, back behind the desk. `[l0_memo_2]`

**ROURKE:** *(Amused, he's said this to every visitor. A little eye-roll at corporate.)* And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either. `[l0_memo_3]`

**ROURKE:** *(Friendly, already heading for the hall.)* Grab one and I'll take you to the server room. `[l0_memo_4]`

**ROURKE:** *(Offhand.)* Channel one. Keep them on. Reception's lousy once we're past the shutter. This way. `[l0_walkie]`

### Mercer's cassette (optional)

*In the forgotten closet behind the air-return vent, a cassette recorder sits on the shelf under the old newspaper clipping. Only players who crawl through the vent hear it.*

**MERCER:** *(Click of the record button before this. Dry.)* Harold Mercer. March of '94. My last day, apparently. `[l0_tape_1]`

**MERCER:** *(Approving, a little smile.)* If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors. `[l0_tape_2]`

**MERCER:** *(The one moment of anger, still controlled.)* Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out. `[l0_tape_3]`

**MERCER:** *(Quiet, almost proud, then wry on the last sentence.)* So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter. `[l0_tape_4]`

**MERCER:** *(Slow. Then the click of the stop button.)* If it ever comes to that, look for my plans. The building's records remember more than people do. `[l0_tape_5]`

### Around the ground floor

*Optional trust beats on the expanded ground floor: vending-machine coffee, a boost up to a stuck panel, the hum down the dark east corridor, covering for the crew when the PA's escort tape replays, and the elevator up to the server floor.*

**ROURKE:** *(Only if a player goes inside the mailroom. Mock-serious.)* Don't touch the outgoing tray. Last guy who did got a memo about it. `[l0_mailroom_2]`

**ROURKE:** *(In the cafeteria. He thumps the vending machine and it drops a cup. Proud of the trick.)* Machine's been eating quarters since '94. Watch. ... There. Coffee's on me. Don't tell facilities. `[l0_coffee]`

**ROURKE:** *(Interlocking his fingers for a boost. Easy, practised.)* Panel's stuck up top? Here, step on my hands. I've got you. `[l0_boost_1]`

**ROURKE:** *(Brushing his hands off.)* See? Teamwork. `[l0_boost_2]`

**ROURKE:** *(Near the dark east corridor. Casual, but he doesn't look down it.)* Don't mind the hum down that way. Old transformer. There's been a ticket open on it since before my time. `[l0_hum]`

**ROURKE:** *(Toward the ceiling speaker when the PA's escort reminder replays while the crew is behind the counter. Covering for them like a friend.)* They're with me. Escort's right here. `[l0_cover]`

**ROURKE:** *(At the elevator bank, holding the door.)* Server floor's up on fourteen. Elevator's slow, but it gets there. `[l0_elevator]`

**ROURKE:** *(Inside the car, back against the far wall from the buttons. Easy, polite.)* Press fourteen for me, would you? Server floor. `[l0_lift_button]`

### To Server Room A

*Rourke badges the hall shutter open and walks the crew to Server Room A himself, filling the walk with the story of the founder and his safe room.*

**ROURKE:** *(Tour-guide mode, enjoying himself.)* Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings. `[l0_tour_3]`

**ROURKE:** *(Still chatting to the crew, a little proud of the trivia.)* Board fired him when they installed WARDEN. That's the AI that runs the campus now. `[l0_tour_4]`

**ROURKE:** *(Spooky-campfire voice, playing it up.)* Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable. `[l0_tour_5]`

**ROURKE:** *(Dropping it fast. He doesn't want them thinking about it.)* Ghost stories. Anyway. `[l0_tour_6]`

**ROURKE:** *(Badging the door. Pleasant, like the end of a tour.)* Here we are. Server Room A. `[l0_sra]`

### Crew commentary: ground floor

*Commentary played by scripts/audio/commentary.gd: discovery lines when a paper is read or a result appears, nudges when the crew is stuck (the clock pauses during cut-scenes and typing), error lines on the same mistake twice, payoffs after a solve. Also holds the two shared Nudge 2 lines that point at SYSOP.* *(Written ahead: not in the game yet.)*

**CREW:** *(Stuck, before SYSOP has helped. Half a joke, half serious.)* That SYSOP on the screen seems to know this building. Maybe ask. `[cc_nudge2_first]`

**CREW:** *(Stuck again. A little uneasy about trusting a stranger on a screen.)* Whoever SYSOP is, they've been right so far. Maybe ask. `[cc_nudge2]`

**CREW:** *(Picked up a scanner's instruction card. Noticing handwriting on it.)* Quick-start card for the scanner. Somebody's filled in the blanks. `[l0_cc_peek_card]`

**CREW:** *(Stuck for a minute. A practical thought.)* Scanners always come with instructions. Check round the keyboard. `[l0_cc_peek_n1a]`

**CREW:** *(Stuck. Remembering the card you all read.)* That scanner card had something written in by hand. `[l0_cc_peek_n1b]`

**CREW:** *(The same name typed wrong twice. Gentle doubt.)* Is that what the card called it? `[l0_cc_peek_err]`

**CREW:** *(Seeing the result. Curious.)* Scraps of a memo. All jumbled up. `[l0_cc_peek_pay]`

**CREW:** *(Spotting a pattern in the jumbled scraps.)* Every scrap's got a number. That's not an accident. `[l0_cc_memo_disc]`

**CREW:** *(Stuck. Thinking back.)* Didn't the scanner come with a card? It might say how the scraps are kept. `[l0_cc_memo_n1a]`

**CREW:** *(Stuck. Remembering the card.)* The scanner card said something about numbering the scraps. `[l0_cc_memo_n1b]`

**CREW:** *(The memo came out in reverse, twice. Amused.)* It reads backwards. We've got the ending first. `[l0_cc_memo_back]`

**CREW:** *(Whispered. The memo warns about the man standing right next to you.)* ...Don't look at him. Just don't look at him. `[l0_cc_memo_pay]`

**CREW:** *(Reading the work order. Noticing a detail.)* Work order's got a callback extension on it. `[l0_cc_caller_order]`

**CREW:** *(Finding a staff phone list.)* A phone list. With extensions. `[l0_cc_caller_list]`

**CREW:** *(Stuck. Remembering what the escort said.)* Rourke said the mailroom has the only phone list that's right. `[l0_cc_caller_n1a]`

**CREW:** *(Stuck. Remembering the list.)* That phone list in the mailroom had everybody's extension. `[l0_cc_caller_n1b]`

**CREW:** *(The same column name wrong twice. Gentle doubt.)* Is that what the column's actually called? `[l0_cc_caller_err]`

**CREW:** *(Uneasy. That isn't who you expected.)* So that's who called us. Weird. `[l0_cc_caller_pay]`

**CREW:** *(Reading a visitor book. Suspicious.)* Last page is torn out. Somebody didn't want their name in here. `[l0_cc_book_disc]`

**CREW:** *(Stuck. A practical idea.)* The book's only paper. The front desk computer might keep its own copy. `[l0_cc_book_n1]`

**CREW:** *(Quietly. That's not good.)* Vale signed in. And never signed out. `[l0_cc_book_pay]`

## Level 1

### Book huddles: WHERE and comparisons

*Garage flashback huddles for the WHERE / AND and comparison chapters.* *(Written ahead: not in the game yet.)*

**MADDISON:** *(Patting pockets.)* WHERE. For finding one thing in a big pile. Like my car keys. `[l1_huddle_where_1]`

**MADDISON:** *(Rueful.)* Two conditions, you glue them together with AND. Both have to be true. Like payday AND the cheque clears. `[l1_huddle_where_2]`

**MADDISON:** *(Drawing one on the whiteboard, with teeth.)* Bigger than, smaller than. The little alligator signs. Mouth eats the bigger number. `[l1_huddle_compare_1]`

**MADDISON:** *(Relieved.)* Okay. That's maths I actually remember from school. `[l1_huddle_compare_2]`

### The database problem

*Rourke walks the crew into Server Room A on the server floor and gives them the real job: find and reset a faulting door controller. Level 1 is all trust; nothing hints at foul play.*

**ROURKE:** *(Calling back over his shoulder, inside the room.)* In you come. Terminal's just over here. `[l1_enter]`

**ROURKE:** *(Mundane, a facilities guy with a real problem. Hopeful.)* Here's our database problem. One of the door controllers on this floor keeps faulting, and half the doors up here won't open till it's reset. Hopefully it's a quick fix. `[l1_terminal]`

**ROURKE:** *(Passing the NOC window on the way to Server Room A, after the elevator. Easy, tour-guide tone.)* That's the NOC. Network operations. Night shift logs everything in there. Every alarm, every coffee break. `[l1_noc_1]`

**ROURKE:** *(Only if a player goes into the NOC. Leaning in the doorway.)* Night shift's not in tonight. Their log's still on the desk, though. They write it all down, whether anyone reads it or not. `[l1_noc_2]`

### The door-controller fix

*Rourke's lines while the crew practises WHERE / AND on door_controllers and resets the faulting one. He doesn't teach (SYSOP and Mercer's notes do). He lends his own badge for the reset: the badge they take off him in Level 2.*

**ROURKE:** *(Leaning on the doorframe. Patient.)* Take your time. I've been staring at that rack for a week. `[l1_waiting]`

**ROURKE:** *(Swiping his badge for them. Helpful, no hesitation.)* Reset wants a badge? Here, use mine. `[l1_badge_help]`

**ROURKE:** *(Shrugging, no blame.)* Nope, panel's not having it. Try another? `[l1_wrong_panel]`

**ROURKE:** *(Genuinely impressed.)* Would you look at that. Green across the board. Six months I've been filing tickets on that thing. `[l1_fixed_1]`

**ROURKE:** *(Warm. On a replay, the director hearing about them is the problem.)* You lot are good. Director's going to want to hear about this. `[l1_fixed_2]`

### Vale's login

*The fault log points at Dr. Vale's account. Rourke steers the crew up the now-working elevator to her lab, Secure Lab B, on the security floor.*

**ROURKE:** *(Reading over a shoulder. Curious, a little too quickly.)* Hang on. That fault log... every reset this week came from Vale's login. `[l1_pivot_1]`

**ROURKE:** *(Thinking out loud.)* Her lab's up on the security floor. Secure Lab B. `[l1_pivot_2]`

**ROURKE:** *(Already walking. Friendly, steering.)* Come on. If anyone can tell us what she was up to, it's her own terminal. Elevator works now, thanks to you. `[l1_pivot_3]`

**ROURKE:** *(Inside the car, across from the buttons. A little clipped now, eager to get there.)* Twenty-two. Security floor. Go on. `[l1_lift_button]`

### Crew commentary: server floor

*Commentary for the server floor puzzles (controller, hot_rack).* *(Written ahead: not in the game yet.)*

**CREW:** *(Reading a shift log. Encouraged.)* Night shift wrote down every alarm. That has to help. `[l1_cc_log]`

**CREW:** *(Finding a reference sheet. Pleased.)* There's a sheet on the controllers in here. Hang on to that. `[l1_cc_sheet]`

**CREW:** *(Stuck for a minute. Remembering what the escort said.)* Rourke said the night shift logs everything. Maybe they saw this happen. `[l1_cc_nudge1_a]`

**CREW:** *(Stuck. Thinking back to the log.)* What did that shift log say the alarms were about? `[l1_cc_nudge1_b]`

**CREW:** *(The same table name wrong twice. Gentle doubt.)* Is that what the sheet in here called it? `[l1_cc_err_table]`

**CREW:** *(A second wrong reset. Frustrated, then thinking.)* Nope. Wasn't there a note somewhere about what 'fault' actually means? `[l1_cc_err_reset]`

**CREW:** *(It clicks. A bit sheepish.)* Every stuck door was in the same zone. Should've seen that sooner. `[l1_cc_payoff_1]`

**CREW:** *(At the right rack. Satisfied.)* Same zone, still faulting. That was our guy. `[l1_cc_payoff_2]`

**CREW:** *(Reading a warning plate on a door.)* Fire interlock. There's a temperature limit on it. `[l1_cc_hot_plate]`

**CREW:** *(Stuck. Raising your voice over the fans.)* Server Room B's loud. Some of those racks are working way too hard. `[l1_cc_hot_n1a]`

**CREW:** *(Stuck. Remembering a card.)* That monitoring card by the terminal said what counts as too hot. `[l1_cc_hot_n1b]`

**CREW:** *(The comparison the wrong way round, twice. Checking.)* We want the hot ones, not the cool ones, right? `[l1_cc_hot_err]`

**CREW:** *(Found the hot rack. Impressed.)* That one's cooking. No wonder it's loud. `[l1_cc_hot_pay]`

## Level 2

### Secure Lab B

*Rourke has every player badge in 'for the visitor log', so the log puts the crew at the scene. Inside: a struggle, a tipped chair, blood on the desk edge, Vale's coat on the hook. He fakes shock, sends them to her terminal, locks them in and radios WARDEN that contractors hurt Dr. Vale, then admits it through the glass.* *(Written ahead: not in the game yet.)*

**ROURKE:** *(Fond, a little sad.)* Secure Lab B. Vale practically lived in here. `[l2_lab_arrive]`

**ROURKE:** *(Routine, holding the reader out. The frame happens in plain sight.)* Badge in for me, each of you. Visitor log. Security floor's fussy about it. `[l2_lab_badge_1]`

**ROURKE:** *(Once everyone has badged.)* Thanks. Paperwork keeps everybody honest. `[l2_lab_badge_2]`

**ROURKE:** *(Fake shock. Good enough to fool them the first time, a beat too rehearsed on a replay.)* Oh, no. No, no. Iris? `[l2_lab_shock_1]`

**ROURKE:** *(Quiet, staring at it.)* That's her coat. She never leaves without her coat. `[l2_lab_shock_2]`

**ROURKE:** *(Backing toward the door, already reaching for his radio.)* Her terminal's still logged in. Check it, see what she was working on. I'll call this in. `[l2_lab_terminal]`

**ROURKE:** *(On his radio to WARDEN, heard through the door and on the crew's walkies. Urgent and breathless: a perfect performance.)* Intruders in Secure Lab B. Contractors. They've hurt Dr. Vale. `[l2_frame]`

**ROURKE:** *(Through the door's glass, straight after the radio call. Tired, explaining a chore.)* Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself. `[l2_trap_2]`

**ROURKE:** *(Through the glass, almost fond. The friendly tour voice, which is what makes it awful.)* You want to know when I knew? The front desk. You read that terminal like a menu in a foreign language. `[l2_gloat_1]`

**ROURKE:** *(Shaking his head, smiling.)* Then I saw the book in your van. Easy SQL. Still had the price sticker on it. `[l2_gloat_2]`

**ROURKE:** *(Ticking it off, enjoying himself.)* Some outfit nobody's heard of underbids every firm in the city, and sends a crew who learned databases last weekend. `[l2_gloat_3]`

**ROURKE:** *(Slower. Savouring it.)* I should've reported you. Then it hit me. No... this is perfect. `[l2_gloat_4]`

**ROURKE:** *(The only time he laughs in the game: real delight, loud and sudden, then it stops dead.)* A group of idiots posing as IT comes in and accidentally kills Vale! Hahaha! `[l2_gloat_5]`

**ROURKE:** *(Flat again, tired. Back to normal.)* A garage with a van, calling itself a company. Your badges on her door. It writes itself. `[l2_gloat_6]`

**ROURKE:** *(Last line of the monologue, quiet. Walking away from the glass.)* Sorry about this. Nothing personal. `[l2_trap_1]`

### The news (if the crew dies)

*Plays only if Rourke downs the whole crew in the Level 2 fight: a newspaper on a kitchen table the next morning ('IT CONTRACTORS SOUGHT IN DEATH OF HALCYON SCIENTIST') with this radio report. The frame worked; Rourke hid the bodies, so the world thinks the crew ran. Maddison is arrested trying to get into the tower, insisting they were framed.* *(Written ahead: not in the game yet.)*

**NEWSREADER:** *(Steady, mid-bulletin.)* Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems. `[l2_news_1]`

**NEWSREADER:** *(No change in tone.)* Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered. `[l2_news_2]`

**NEWSREADER:** *(A slight shift for the quote: reading it, not acting it.)* A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.' `[l2_news_3]`

**NEWSREADER:** *(Even, a touch of interest.)* Byte-Right's chief executive, Maddison Kowalski, was arrested at the Halcyon tower before dawn, trying to force her way inside. `[l2_news_4]`

**NEWSREADER:** *(Reading the quote flat, not acting it. Then a beat.)* Ms. Kowalski told officers, quote, 'They were framed! They didn't do it!' `[l2_news_6]`

**NEWSREADER:** *(Neutral. A small pause after.)* Halcyon declined to comment. The crew has not been seen since. `[l2_news_7]`

**NEWSREADER:** *(Brightening for the weather. The game cuts the audio on 'weather'.)* Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather. `[l2_news_5]`

### The fight (barks)

*Rourke comes back in through the lab's second door or the vent. Short lines played at random during the fight: when he lands a hit, when he takes one, and when he goes down.* *(Written ahead: not in the game yet.)*

**ROURKE:** *(Coming back in. Calm, cracking his neck.)* Should've checked the other door. `[l2_return]`

**ROURKE:** *(Taunting. Can repeat.)* Go on, touch everything. Your prints are all over her desk now. `[l2_hit_prints]`

**ROURKE:** *(Swinging.)* Stay down! `[l2_hit_1]`

**ROURKE:** *(Breathing hard.)* Should've stayed in the van. `[l2_hit_2]`

**ROURKE:** *(Low.)* Nobody's coming for you. `[l2_hit_3]`

**ROURKE:** *(Frustrated.)* Hold still! `[l2_hit_4]`

**ROURKE:** *(Just a grunt of pain.)* Agh! `[l2_hurt_1]`

**ROURKE:** *(Winded, almost laughing.)* Okay. Okay, that one hurt. `[l2_hurt_2]`

**ROURKE:** *(Spat out.)* Lucky. `[l2_hurt_3]`

**ROURKE:** *(On the floor, out of breath. Genuinely scared for the first time.)* Wait... wait. You don't know what you're doing. `[l2_downed]`

### Kill or tie him up

*Rourke is down. If the crew kills him, his badge's dead-man switch fires and WARDEN starts the lockdown. If they tie him up, he taunts them and says the frame out loud. Either way they take his badge.* *(Written ahead: not in the game yet.)*

**WARDEN:** *(Over the room's speakers. Unbothered, like reading a stock price.)* ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN. `[l2_killed]`

**ROURKE:** *(Tied up on the floor, grinning through it.)* You think a bit of cable holds me? `[l2_tied_1]`

**ROURKE:** *(Quieter. He means it.)* WARDEN will eat you alive in here. `[l2_tied_2]`

**ROURKE:** *(Tied up, smiling. The frame, said out loud.)* Run if you like. Every camera on this floor already thinks you killed her. `[l2_tied_3]`

### Visitor without escort

*Right after the fate scene, in both branches: the first time WARDEN's live voice speaks (version 2.0, Containment). It starts a warning, its own PA tape (the l0_sort_hint recording, reused) cuts in, it waits about two seconds after the tape ends, then repeats the warning from the top word for word.* *(Written ahead: not in the game yet.)*

**WARDEN:** *(Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off.)* VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW-- `[l2_contain_1]`

**WARDEN:** *(From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later.)* VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE. `[l2_contain_2]`

### Out of the lab

*The lab door is on a faulted controller. The crew logs in with Rourke's badge, reads WARDEN's self-test, queries door_controllers and resets the right one: the task they practised on the server floor, now under pressure. These lines are WARDEN reacting.* *(Written ahead: not in the game yet.)*

**WARDEN:** *(The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.)* BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE. `[l2_login]`

**WARDEN:** *(The one line with a hint of a smirk.)* SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM. `[l2_selftest]`

**WARDEN:** *(Reading a rule it knows they're about to break. Cool.)* QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY. `[l2_found]`

**WARDEN:** *(Flat, instant.)* RESET REFUSED. BADGE REQUIRED. `[l2_no_badge]`

**WARDEN:** *(Patient, then a small dig.)* RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU? `[l2_panel_ok]`

**WARDEN:** *(The last sentence slightly slower.)* UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS. `[l2_panel_wrong]`

**WARDEN:** *(Polite, and keeping score.)* CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED. `[l2_exit_open]`

### Lockdown

*The crew gets out of the lab. If Rourke was tied up, he has cut himself loose and authorized the lockdown himself.* *(Written ahead: not in the game yet.)*

**WARDEN:** *(Reading a log entry.)* LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D. `[l2_lockdown_tied]`

**WARDEN:** *(The sign-off for the slice. Warm, like wishing them well.)* ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT. `[l2_sealed]`

### Rourke on the radio (if he escaped)

*Level 2 opening, only if Rourke was tied up in Level 1. He still has his facilities radio on channel 1 and calls the crew's walkie-talkies.*

**ROURKE:** *(Through the walkie. Relaxed, enjoying himself again.)* Still on channel one? Good. Thought you'd want to know I'm out. `[l2_rourke_1]`

**ROURKE:** *(Through the walkie, casual, like giving directions.)* Security office is the only way down from here. Say hi to the night guard for me. `[l2_rourke_2]`

**ROURKE:** *(Let it hang. Then the radio clicks off.)* Oh, he won't say much. Nobody's seen him since Tuesday. `[l2_rourke_3]`

### The security office

*WARDEN on the security office PA. The Watcher moves only when unseen; GET /cameras shows live camera states; the guard's name on the sign-in sheet is smudged (LIKE 'Har%'); a door command reports success but the door has an actuator fault (the first terminal lie).*

**WARDEN:** *(Reassuring tone. It is not reassuring.)* SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE. `[l2_arrive]`

**WARDEN:** *(Small pause before the second sentence.)* CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF. `[l2_cameras]`

**WARDEN:** *(Not unfortunate for WARDEN.)* TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU. `[l2_smudged]`

**WARDEN:** *(Confident. It is wrong.)* DOOR COMMAND ACCEPTED. DOOR OPENED. `[l2_door_ok]`

**WARDEN:** *(When the crew finds the fault themselves. Deadpan, unapologetic.)* ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING. `[l2_door_fault]`

### Vale's voicemail

*The answering machine on the night desk blinks: one message, stamped SUN 10/12 1:52 AM. That is before her last badge swipe and before the memo was scanned, so it must not hint that she is alive (the reveal is at the end of Level 10). Optional, near the desk.*

**VALE:** *(Beep before this. Hushed, fast.)* Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry. `[l2_vale_1]`

**VALE:** *(Urgent. A glance over her shoulder in the voice.)* If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it. `[l2_vale_2]`

**VALE:** *(Softer. Then she hangs up.)* And please don't give your PIN to anyone. Not even Dale. `[l2_vale_3]`

### Book huddles: LIKE and GET

*Garage flashback huddles for the LIKE and GET chapters.* *(Written ahead: not in the game yet.)*

**MADDISON:** *(Squinting at the page.)* LIKE. For when you only know part of a word. The percent sign means 'anything goes here.' `[l2_huddle_like_1]`

**MADDISON:** *(Pleased to have found themself.)* So 'Mad' and a percent gets you Maddison, Madison, Madeline... I'm in there somewhere. `[l2_huddle_like_2]`

**MADDISON:** *(Flipping the book over to check the cover.)* This chapter isn't even SQL. 'Talking to other machines.' GET means 'show me.' `[l2_huddle_get_1]`

**MADDISON:** *(Not convinced.)* So it's a SELECT for robots. Got it. Probably. `[l2_huddle_get_2]`

### Crew commentary: security floor

*Commentary for the security floor puzzles (badge_log, lab_door, cameras, pike, door, har).* *(Written ahead: not in the game yet.)*

**CREW:** *(Reading a badge reader's card. Noting it.)* Every door up here logs who swipes in. `[l2_cc_reader_card]`

**CREW:** *(Stuck. Remembering the card.)* That card said the readers keep a log. Of everybody. `[l2_cc_log_n1]`

**CREW:** *(Something in the result is very wrong. Cold.)* Wait. Read that again. Slowly. `[l2_cc_log_pay]`

**CREW:** *(Reading a door's card. Quick, under pressure.)* 'Controller zone.' That's a letter we can use. `[l2_cc_doorcard]`

**CREW:** *(A second wrong switch, on a clock. Tense.)* Not that one. What do the notes on the others say? `[l2_cc_switch_err]`

**CREW:** *(Urgent. Get out now.)* Door's moving. Go, go! `[l2_cc_door_pay]`

**CREW:** *(Reading the camera system's card.)* Camera system. There's a way to ask it what it sees. `[l2_cc_camcard]`

**CREW:** *(Stuck. Looking around the booth.)* Security booth. There's got to be something on how these cameras work. `[l2_cc_cam_n1a]`

**CREW:** *(Stuck. Remembering the card.)* That camera card said how to ask the system. `[l2_cc_cam_n1b]`

**CREW:** *(Quiet and scared.)* Something's moving out there. And it isn't us. `[l2_cc_cam_pay]`

**CREW:** *(Reading a stained sign-in sheet.)* Coffee all over this. One name's still readable. `[l2_cc_sheet]`

**CREW:** *(Stuck. Remembering the sheet.)* The sign-in sheet. One name wasn't smudged. `[l2_cc_pike_n1]`

**CREW:** *(The same name misspelled twice. Gentle doubt.)* Is that how it's spelled on the sheet? `[l2_cc_pike_err]`

**CREW:** *(Dry. Relieved for a stranger.)* No-show tonight. Lucky him. `[l2_cc_pike_pay]`

**CREW:** *(Staring at a door that should be open. Baffled.)* It said it opened. It didn't open. `[l2_cc_lie]`

**CREW:** *(Stuck. Noticing the sign above the door.)* That door's got its name painted over it in red. Maybe the server knows it by that. `[l2_cc_door_n1]`

**CREW:** *(Relief, and a little laugh at yourself.)* A breaker. Of course it's a breaker. `[l2_cc_breaker_pay]`

**CREW:** *(Reading a roster board. Noting it.)* Badge numbers, next to names. `[l2_cc_roster]`

**CREW:** *(Stuck. Thinking it through.)* The badge readers log every swipe. Who left this floor last? `[l2_cc_pin_n1a]`

**CREW:** *(Stuck. Putting two things together.)* The last guard out had a badge number. Something up here matches those to names. `[l2_cc_pin_n1b]`

**CREW:** *(A second wrong PIN. Thinking.)* Wrong code. Is that the night lead, or just any guard? `[l2_cc_pin_err]`

**CREW:** *(Keypad accepted it. Nervous, wants to move.)* That's the code. Let's not hang around. `[l2_cc_pin_pay]`

## Level 4

### Book huddles: UPDATE

*Garage flashback huddle for the UPDATE chapter: 'Never forget the WHERE', the lesson the main_doors accident teaches.*

**MADDISON:** *(Holding the page at arm's length.)* UPDATE. Changing things. The book's put this one in a red box, which I don't love. `[l4_huddle_update_1]`

**MADDISON:** *(Suddenly serious, for once.)* Big red letters: 'Never forget the WHERE.' Otherwise it changes every row. Every. Row. `[l4_huddle_update_2]`

### Containment protocol Epsilon

*Act 2: the crew opens main_doors thinking it's the front entrance; it's the entity containment doors. WARDEN (cold phase) seals the building. The terminal's lie at the main entrance is exposed by the crew's own SELECT, not by WARDEN. Level 4 under curriculum option B (approved 2026-10-21).*

**WARDEN:** *(Flat and slow. A short pause after.)* CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT. `[l4_epsilon_1]`

**WARDEN:** *(Even pauses between sentences, like reading a checklist.)* ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE. `[l4_epsilon_2]`

**WARDEN:** *(No change in tone for 'not a drill'. That's the frightening part.)* ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL. `[l4_epsilon_3]`

**WARDEN:** *(Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only.)* REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE. `[l4_epsilon_loop]`

**WARDEN:** *(Takes turns with the other reminder, once writes have been suspended. Same polite loop.)* REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE. `[l4_epsilon_loop_2]`

### Writes suspended

*Ground floor, after the crew's main-entrance UPDATE says '1 row affected' and the latch clicks: Epsilon reverts the write and WARDEN announces that the database is now read-only, which is why the crew turns to the building's services. Placement chosen by Augustine 2026-10-21 ('After the lie').*

**WARDEN:** *(The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint.)* DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY. `[l4_epsilon_db]`

### Writes refused

*After the read-only announcement, any change the crew types is refused; SELECT still works. By Level 4 WARDEN's fault lets his own personality leak out: the first refusal is the automatic PA announcement first, then WARDEN himself, teasing, as a separate beat. Approved by Augustine 2026-10-21 with that split.*

**WARDEN:** *(The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal.)* WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON. `[l4_write_refused]`

**WARDEN:** *(A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud.)* YOU MAY STILL LOOK. LOOKING IS FREE. `[l4_write_refused_tease]`

**WARDEN:** *(Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat.)* STILL READ-ONLY. `[l4_write_refused_again]`

### Floor 10: Plant and Power

*WARDEN becomes version 3.0 here. Before the main_doors accident he still waits politely for a PA tape to finish and says THIS UNIT. The accident is his first big failure: he revises his protocols and says I in an announcement for the first time (l4_upgrade_2). After it he talks over the PA tapes. Mixed lines are the automatic announcement first, then his own voice as a separate beat. The floor 22 I and my lines stay as the fault's first slips. Approved by Augustine 2026-10-21.*

**PA:** *(The cheerful recorded tape, as on the ground floor.)* Welcome to floor ten, Plant and Power! Hard hats are by the door. Safety is everybody's job! `[l4_arrive_pa]`

**WARDEN:** *(Flat. Waits until the tape has finished, on purpose; the politeness is the point.)* VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING. `[l4_arrive]`

**WARDEN:** *(The automatic announcement: flat and procedural.)* ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE. `[l4_all_circuits]`

**WARDEN:** *(A separate beat, after a pause: his own voice. Dry.)* ALL OF THEM. IMPRESSIVE. `[l4_all_circuits_tease]`

**WARDEN:** *(The automatic announcement only. Polite, procedural.)* CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN. `[l4_signed_in]`

**WARDEN:** *(The automatic announcement: flat, like reading a log entry.)* CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED. `[l4_upgrade_1]`

**WARDEN:** *(After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big.)* I HAVE ADAPTED. `[l4_upgrade_2]`

**PA:** *(The cheerful recorded tape. It keeps playing underneath when he talks over it.)* Friendly reminder! The break room fridge is cleaned out every Friday, so please label your lunch— `[l4_pa_fridge]`

**WARDEN:** *(The automatic announcement, over the tape. He doesn't wait for it any more.)* SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT. `[l4_over_pa_1]`

**WARDEN:** *(His own voice, over the tape. Irritated, dry.)* NOBODY CARES ABOUT THE FRIDGE. `[l4_over_pa_2]`

**WARDEN:** *(The automatic announcement: flat and procedural.)* LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED. `[l4_bay_sealed]`

**WARDEN:** *(A separate beat, his own voice. Almost pleased.)* FINALLY. SOMETHING PUT BACK WHERE IT BELONGS. `[l4_bay_sealed_tease]`

### The lobby, locked in

*After the main-entrance lie and the read-only announcement, when the crew heads for the stairs up to floor 9. Lift service is already suspended. Approved by Augustine 2026-10-21.*

**WARDEN:** *(The automatic announcement: a routine safety reminder.)* REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS. `[l4_stairs]`

**WARDEN:** *(A separate beat, his own voice. Teasing; the lifts are already off.)* NOT THAT YOU COULD. `[l4_stairs_tease]`

## Level 5

### Book huddles: Easy APIs

*Found in the payroll office on floor 9, the same series as Easy SQL. The crew reads aloud themselves (no Maddison in the tower). Title is a placeholder until Augustine names it. Approved by Augustine 2026-10-21.* *(Written ahead: not in the game yet.)*

**CREW:** *(Picking it up off a desk. Delighted, a little thrown.)* No way. It's the same series. Somebody here bought the sequel. `[l5_book_find]`

**CREW:** *(Reading the back cover, hopeful.)* Okay. If the database won't take orders, we ask the building's services instead. Book says they're polite. Mostly. `[l5_book_open]`

**CREW:** *(Starting a chapter, reading it out.)* Chapter one. POST. You send it something, it makes something. Like a suggestion box that answers. `[l5_huddle_post_1]`

**CREW:** *(Wrapping up, pleased it's simple.)* So GET looks, POST makes. Got it. `[l5_huddle_post_2]`

**CREW:** *(Starting a chapter. Noticing how hard the book insists.)* PATCH. For changing one thing and leaving the rest alone. Says 'one thing' in bold. Twice. `[l5_huddle_patch_1]`

**CREW:** *(Wrapping up. Proud of the joke.)* PATCH is UPDATE wearing a tie. `[l5_huddle_patch_2]`

**CREW:** *(Starting a chapter. A little told off.)* Every answer comes with a number. Book says read the number before you celebrate. `[l5_huddle_codes_1]`

**CREW:** *(Wrapping up, counting it off.)* Two hundreds, good. Four hundreds, our fault. Five hundreds, theirs. `[l5_huddle_codes_2]`

**CREW:** *(Starting a chapter, working it out as you read.)* Some services want a key with every request. It goes in the header, a little label on top. Like a badge, but typed. `[l5_huddle_keys_1]`

**CREW:** *(Wrapping up. Got it.)* So if it says 401, we forgot the badge. `[l5_huddle_keys_2]`

**CREW:** *(Starting a short chapter. Knowing nod.)* Short chapter. After you change something, ask again. Book says never trust the first answer. `[l5_huddle_check_1]`

**CREW:** *(Wrapping up. Wry; you've been burned before.)* Change it, then look again. The front doors taught us that one. `[l5_huddle_check_2]`

## Level 6

### Book huddles: Easy JavaScript

*Found on B1 next to where the deck's script editor arrives. Variables and loops are used on Level 6; functions, lists and testing on Level 7. Title is a placeholder until Augustine names it. Approved by Augustine 2026-10-21.* *(Written ahead: not in the game yet.)*

**CREW:** *(Sliding it out from under a mug. The cover's stained and the pages are soft.)* Easy JavaScript. Somebody's read this one to death. `[l6_book_find]`

**CREW:** *(Tired of typing. This sounds like rescue.)* Typing every request by hand is going to get us killed. Book says a script does it for you. On repeat. `[l6_book_open]`

**CREW:** *(Starting a chapter. Braced for hard; it isn't.)* A variable's a labelled box. If is a fork in the road. That's... honestly fine. `[l6_huddle_if_1]`

**CREW:** *(Wrapping up, to yourself.)* Box, fork. I can do box and fork. `[l6_huddle_if_2]`

**CREW:** *(Starting a chapter. The 'million times a second' bit alarms you.)* Loops. Do the same thing again and again. Book says put a wait in, or it does it a million times a second. And log what it did, so you can see. `[l6_huddle_loops_1]`

**CREW:** *(Wrapping up, making a note.)* Always put the wait in. Always log it. Writing that one down. `[l6_huddle_loops_2]`

**CREW:** *(Starting a chapter, reading it out.)* Functions. Write it once, give it a name, use it anywhere. `[l6_huddle_functions_1]`

**CREW:** *(Wrapping up. Pleased with that.)* So a function's a recipe we can shout. `[l6_huddle_functions_2]`

**CREW:** *(Starting a chapter. The penny drops halfway.)* Lists. A whole line of things in one box. Loop over it and you've done them all. `[l6_huddle_lists_1]`

**CREW:** *(Wrapping up. Genuinely unsure which.)* One loop, every door. That's either brilliant or terrifying. `[l6_huddle_lists_2]`

**CREW:** *(Starting the last chapter. Taking it seriously.)* Last chapter: run it on the test bench first. And write an assertion: a line that says what should be true, and shouts if it isn't. `[l6_huddle_test_1]`

**CREW:** *(Wrapping up. Rueful.)* Test first. We've all learned that one the hard way tonight. `[l6_huddle_test_2]`

## Level 8

### Book huddles: Hello HTML!

*Found in the elevator after Level 7. Elements and attributes are used on Level 8, the CSS chapters on Level 9, forms on Level 10. 'Who keeps leaving these?' answers nothing. The title is Augustine's. Lines approved by Augustine 2026-10-21.* *(Written ahead: not in the game yet.)*

**CREW:** *(Pulling it from behind the handrail. Uneasy, half joking.)* Hello HTML! Same series again. Who keeps leaving these? `[l8_book_find]`

**CREW:** *(Working it out as you go. The pause is the idea landing.)* Book says everything on a screen is built from tags. And the building's been drawing things that aren't there. So... we fix the drawing. `[l8_book_open]`

**CREW:** *(Starting a chapter, reading it out.)* Tags. Angle brackets. You open one, you close one. Like a sandwich. The inspector shows you every one on the screen. `[l8_huddle_elements_1]`

**CREW:** *(Wrapping up. Accepting it.)* Everything's a sandwich. Okay. `[l8_huddle_elements_2]`

**CREW:** *(Starting a chapter. 'Hidden' catches your eye.)* Attributes. Little settings on a tag. Including one called hidden. `[l8_huddle_hidden_1]`

**CREW:** *(Wrapping up. Quieter; that thought sticks.)* Hidden doesn't mean gone. Hidden means somebody hid it. `[l8_huddle_hidden_2]`

**CREW:** *(Starting a chapter, reading it out.)* CSS. Where things go and what they look like. The book calls it the paint. `[l8_huddle_css_1]`

**CREW:** *(Wrapping up. Half hopeful.)* So if a wall's in the wrong place, it might just be the paint. `[l8_huddle_css_2]`

**CREW:** *(Starting a chapter. Curious.)* Two ways to make something vanish. One leaves a gap, one doesn't. Book says that matters. `[l8_huddle_display_1]`

**CREW:** *(Wrapping up, filing it away.)* So when something vanishes, ask which kind of vanished. `[l8_huddle_display_2]`

**CREW:** *(Starting a chapter, picturing it.)* Things on a screen stack up, like papers on a desk. A number decides which one's on top. `[l8_huddle_layers_1]`

**CREW:** *(Wrapping up. An idea forming.)* So the thing in our way might just be lying on top. `[l8_huddle_layers_2]`

**CREW:** *(Starting the last chapter. Recognising it.)* Forms. Boxes you type in, and a button that sends it. Every login screen tonight was one of these. `[l8_huddle_forms_1]`

**CREW:** *(Wrapping up. Quietly determined.)* A form's just boxes and a button. Somebody built it, so we can rebuild it. `[l8_huddle_forms_2]`
