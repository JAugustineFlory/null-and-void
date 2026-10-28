# Null & Void: voice script

Generated from `scripts/audio/voice_lines.gd`. Edit the lines there, then run `godot --headless -s tools/write_script_docs.gd`.
Each speech is one recording, named after the speaker; lines under the same name are read in one take. See [recording-list.md](recording-list.md) for how to record.

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

**Ines Oyelaran** (INES). Night-shift records clerk on floor 9, one of the two real people the crew rescues. A Mimic wears her face at the HR front.

> Whispering, fast, trying not to cry and mostly managing. Relief breaks through when the pass comes. Heard from behind a door, then up close.

**Tomas Lindqvist** (TOMAS). Night-shift payroll clerk on floor 9, the other real person. A Mimic sits at his desk in payroll.

> Low, tired, dry. A man who has decided to be annoyed instead of frightened. Stiff from the floor.

## Crew barks

Each playable crew member's own short lines, played by Co-op. Their shared commentary lines are in the scenes below, as CREW.

**Dana Okafor** (`dana`, 30s). Ex-cable installer. Blunt and practical, and has crawled through more ceilings than anyone alive. Unbothered by heights and vents. Calls everyone "chief".

- "Let's get this over with." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Chief. Over here." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Got something." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Everyone, quick. Look at this." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Give us a leg up?" *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Coming." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Nope. Nope." *(Something jumps out at you in the dark)* `[scared]`
- "Little help!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Cheers, chief." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Not getting through that." *(You hit a locked door or a blocked path)* `[no_way]`
- "Shh. Something's here." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Priya Raman** (`priya`, 20s). Ran a phone-repair kiosk at the mall. Talks fast, fixes faster, and is relentlessly optimistic. Thinks this is the best night of her life, right up until it isn't.

- "Ooh, okay. Ready, ready!" *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Guys! Over here, come look!" *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Oh, this is something!" *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Huddle! Huddle up!" *(You're calling everyone together to look at your notes)* `[huddle]`
- "Can somebody lift me? I'm tiny." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "On my way, on my way!" *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Oh my God. Oh my God." *(Something jumps out at you in the dark)* `[scared]`
- "Help! Help me!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "You're the best." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Okay, that's locked. Rude." *(You hit a locked door or a blocked path)* `[no_way]`
- "Guys. Whisper. Something's moving." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Rosa Delgado** (`rosa`, 30s). A school office manager doing nights for extra cash. Organised, unflappable, dry as toast. Treats the crew like a class on a field trip.

- "Seatbelts, everyone." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here, please. Today." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Well, now. Look at this." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Everybody gather round." *(You're calling everyone together to look at your notes)* `[huddle]`
- "A hand up, if someone would be so kind." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "I'm coming. Don't touch anything." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Mother of God." *(Something jumps out at you in the dark)* `[scared]`
- "Somebody! Now!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Thank you. Noted." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "That's not opening for us." *(You hit a locked door or a blocked path)* `[no_way]`
- "Quiet. All of you." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Kit Larsen** (`kit`, 20s). Bike courier and rooftop free-runner. Fearless and cocky, and climbs first and thinks later. The one most likely to say "watch this".

- "Let's go, let's go." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Up here! Come on!" *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Ha. Found it." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Okay, team talk. Quick." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Boost me. I've got the rest." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Two seconds!" *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Whoa, whoa, whoa!" *(Something jumps out at you in the dark)* `[scared]`
- "I'm caught! Get it off!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Owe you one." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Dead end. Find another way." *(You hit a locked door or a blocked path)* `[no_way]`
- "Stop. Don't move." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**June Whitaker** (`june`, 60s). Ham-radio operator for forty years, and Maddison's aunt. Calm and precise, and the only one who knows radio etiquette. Says "over" whether or not she's on the radio.

- "Ready when you are. Over." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "To me, please. Over here." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "I have something. Come and see." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Let's all stop and think a moment." *(You're calling everyone together to look at your notes)* `[huddle]`
- "I'll need a lift up there, dear." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Copy. On my way." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Good heavens!" *(Something jumps out at you in the dark)* `[scared]`
- "Mayday! Mayday!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Much obliged." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Negative. That's sealed." *(You hit a locked door or a blocked path)* `[no_way]`
- "Radio silence. Something's close." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Mei Tanaka** (`mei`, 30s). Ex-barista with a nervous laugh. Jumpy, very funny, and much braver than she thinks. Narrates her own panic.

- "I'm ready. I'm not ready. I'm ready." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here! Before I chicken out!" *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Is this something? I think this is something." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Can we huddle? I want to huddle." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Lift me up? Don't drop me." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Coming! Slowly! But coming!" *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Nope! Absolutely not!" *(Something jumps out at you in the dark)* `[scared]`
- "Help! Help, help, help!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Oh, thank God. Thank you." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Locked. Great. Love that." *(You hit a locked door or a blocked path)* `[no_way]`
- "Shh. Do you hear that?" *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Marcus Bell** (`marcus`, 40s). Former mall security guard. Steady, cautious and observant. Checks corners. Knows exactly how night guards think, and hates it here.

- "Alright. Let's do this right." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here. Stay together." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Hold up. Found something." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Everybody, eyes here." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Need a boost up." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Moving to you." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Back up! Back up!" *(Something jumps out at you in the dark)* `[scared]`
- "Man down! Need help!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Appreciate it." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Locked tight. Try another way." *(You hit a locked door or a blocked path)* `[no_way]`
- "Hold. Something's moving." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Theo Brandt** (`theo`, 20s). A gamer with a sarcastic streak who answered Maddison's ad. Quick, funny and convinced this is just like a video game. It isn't.

- "Loading in." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Yo. Over here." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Ooh. Loot." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Team meeting. Strategy time." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Boost me? Classic co-op move." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Omw." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "What is THAT?!" *(Something jumps out at you in the dark)* `[scared]`
- "I'm down! Revive me!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "GG. Thanks." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Locked. Obviously." *(You hit a locked door or a blocked path)* `[no_way]`
- "Stealth section. Shh." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Sam Abara** (`sam`, 30s). Professional mover. Big, gentle and strong. The crew's boost and its heavy lifter, and the calmest voice in the room.

- "Ready." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here, folks." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "This look important to you?" *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Let's slow down and look." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Gonna need help with this one." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Coming your way." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Whoa. Easy. Easy." *(Something jumps out at you in the dark)* `[scared]`
- "Need a hand here!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Thank you, friend." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "That won't budge. And I tried." *(You hit a locked door or a blocked path)* `[no_way]`
- "Hush, now. Listen." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Luis Ortega** (`luis`, 50s). Handyman, and Maddison's oldest friend. Warm, chatty, and believes everything can be fixed by turning it off and on again. Mostly, he's right.

- "Vámonos." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Hey, hey. Over here." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Look what I found." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Okay, everybody. Think." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Give an old man a lift?" *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "I'm coming, I'm coming." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "¡Ay, Dios mío!" *(Something jumps out at you in the dark)* `[scared]`
- "Help me! Quick!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Gracias, mijo." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Locked. Maybe we turn it off and on?" *(You hit a locked door or a blocked path)* `[no_way]`
- "Shh. Something's out there." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Ike Novak** (`ike`, 20s). A startup dropout who talks in buzzwords. Overconfident, bluffs hardest of anyone, and is secretly the most scared.

- "Let's disrupt this." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here. Let's sync." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Okay, this is a key insight." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Quick stand-up, everybody." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Can I get some lift? Literally." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Pivoting to you." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Oh no. Oh no no no." *(Something jumps out at you in the dark)* `[scared]`
- "This is a blocker! Help!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Huge. Thank you." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "Hard blocker. Locked." *(You hit a locked door or a blocked path)* `[no_way]`
- "Okay, nobody talk." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

**Walt Henley** (`walt`, 30s). Power-company lineman between storm callouts. Grumpy, unhurried, and acts like he's seen everything twice. He came along "to keep an eye on you idiots".

- "Let's get it done." *(In the van before the job. Everyone says when they're ready to go, and this is you saying it)* `[ready]`
- "Over here. Come on." *(You've spotted something and you're calling the others over to where you are)* `[over_here]`
- "Huh. Lookit this." *(You've just picked up a clue: a paper, a key, a note)* `[found_something]`
- "Everybody stop. Think." *(You're calling everyone together to look at your notes)* `[huddle]`
- "Bad shoulder. Give me a hand up." *(There's a ledge or a vent you can't reach. You need a teammate's hands or shoulders)* `[need_boost]`
- "Hold your horses. Coming." *(A teammate called for you, and you're heading over)* `[on_my_way]`
- "Jesus, Mary and Joseph!" *(Something jumps out at you in the dark)* `[scared]`
- "Somebody! Get it off me!" *(You've been knocked down or grabbed, and you need a teammate right now)* `[help]`
- "Mm. Thanks." *(A teammate just helped you up, or boosted you up to a ledge)* `[thanks]`
- "That's not opening." *(You hit a locked door or a blocked path)* `[no_way]`
- "Shut it. Listen." *(Something is close. You warn the others to keep their voices down)* `[quiet]`

## Level 0

### The garage

**Byte-Right IT Services' garage, home base. Earlier that evening, 15 October 1997.**

*The game opens at Byte-Right's garage home base, earlier that night. The crew walks in and sits facing Maddison at the whiteboard. She briefs them (money, goals, the Halcyon job), sends them to the punching bag, points them at the work order in their notebooks, then at Easy SQL on the shelf by the side door, and reads chapter zero with them. Then everyone gets in the van. Lines ending _solo are the one-player versions.*

**MADDISON** `l0_brief_1_block.wav`  
*Cue: The crew has just walked in and sat down facing your whiteboard. You come in from the house*  
*(Striding in from the house door to her whiteboard, arms wide)* "Okay! Everybody comfy? Look at you. My whole company, in one garage." *Big, warm, delighted to have an audience.* `[l0_brief_1]`  
*(Standing at the whiteboard, counting it off on her fingers)* "Where we stand. Rent's due Friday, the van's held together with tape, and our best client is a library that pays in exact change." *Cheerful, as if it's good news.* `[l0_brief_2]`  
*(Pacing a step or two in front of the whiteboard)* "So this year's goal was simple. Stay open. Maybe a second van. Maybe a sign that doesn't fall off." *Every 'maybe' a little grander, then the sign brings it back down to earth.* `[l0_brief_3]`  
*(Tapping the whiteboard with her marker)* "Forget all that. We got Halcyon. The overnight database contract. Ours." *Building to it. She can't stand still for 'Ours.'* `[l0_brief_4]`  
*(Waving a hand to brush off the question)* "How? I underbid everybody. By a lot. Don't ask how much. Job's tonight, eleven o'clock." *Quickly, before anyone can ask.* `[l0_brief_5]`  
*(The crew is buzzing in their seats. Pointing across the garage at the punching bag by the big door)* "You guys are too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down." *Laughing, shooing them off.* `[l0_bag]`

**MADDISON** `l0_brief_1_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "Okay! Everybody comfy? Look at you. My whole company, in one garage."*  
*(Striding in from the house door to her whiteboard, arms wide)* "Okay! Look at you. My whole company, in one seat." *The same joke, a little teasing.*

**MADDISON** `l0_bag_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "You guys are too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down."*  
*(Pointing across the garage at the punching bag by the big door)* "You're too excited! Go hit the punching bag to blow off some steam. When you're done, come sit down." *Laughing, shooing them off.*

**MADDISON** `l0_bag_back_block.wav`  
*Cue: Everyone has hit the punching bag and sat back down facing you*  
*(Back at the whiteboard, clapping her hands once)* "Better? Good. Now eyes on me, gorgeous people." *A little flirty, played light, like a coach.* `[l0_bag_back]`  
*(Once they're settled. Tapping her own notebook, then pointing at theirs)* "I put a copy of the work order in each of your notebooks. Pull it out and take a look." *Pleased with herself for being organized.* `[l0_workorder]`

**MADDISON** `l0_bag_back_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "Better? Good. Now eyes on me, gorgeous people."*  
*(Back at the whiteboard, clapping her hands once)* "Better? Good. Now eyes on me, gorgeous." *A little flirty, played light, like a coach.*

**MADDISON** `l0_workorder_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "I put a copy of the work order in each of your notebooks. Pull it out and take a look."*  
*(Tapping her own notebook, then pointing at theirs)* "I put a copy of the work order in your notebook. Pull it out and take a look." *Pleased with herself for being organized.*

**MADDISON** `l0_book_catch.wav`  
*Cue: Everyone has pulled out the work order and read it*  
*(Holding up her copy of the work order, tapping one word)* "Small problem. It says database. And unless one of you secretly knows SQL..." *The smile stays on. She leaves the sentence hanging and waits. Nobody does.*

**MADDISON** `l0_book_catch_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "Small problem. It says database. And unless one of you secretly knows SQL..."*  
*(Holding up her copy of the work order, tapping one word)* "Small problem. It says database. And unless you secretly know SQL..." *The smile stays on. She leaves the sentence hanging and waits.*

**MADDISON** `l0_bookstore_block.wav`  
*Cue: After the pause, when nobody owns up to knowing SQL*  
*(Holding up the bookstore receipt, not the book)* "...I stopped by the bookstore. Easy SQL. 'Learn databases in a weekend.' We've got till eleven." *Proud of this.* `[l0_bookstore]`  
*(Walking over to the back shelf by the side door to the house)* "It's in the shop bag on the shelf by the side door. One of you go grab it." *Pointing at the side door to the house.* `[l0_grab]`

**MADDISON** `l0_grab_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "It's in the shop bag on the shelf by the side door. One of you go grab it."*  
*(Walking to the back shelf by the side door to the house)* "It's in the shop bag on the shelf by the side door. Go on, grab it for me." *Pointing at the side door to the house.*

**MADDISON** `l0_garage_5.wav`  
*Cue: The crew has gone through chapter zero together*  
*(Capping her marker, beaming at the crew)* "Look at that. You're practically engineers. Take the book with you. Everybody in the van." *Genuinely thrilled.*

**MADDISON** `l0_garage_5_solo.wav`  
*Cue: Only when one player is playing alone. Plays instead of "Look at that. You're practically engineers. Take the book with you. Everybody in the van."*  
*(Capping her marker, beaming)* "Look at that. You're practically an engineer. Take the book with you. Into the van." *Genuinely thrilled.*

**MADDISON** `l0_garage_6.wav`  
*Cue: The whole crew has climbed into the van. You're at the door to see them off*  
*(Leaning in at the van door, counting rules on her fingers)* "Rules for tonight. Nod a lot. Anything you don't know, you need to check the logs. And if anyone asks, we've got a fleet. You're van three. I'll be on the radio." *She stays behind.*

### Book huddles: SELECT and ORDER BY

**Byte-Right's garage, at the workbench with the crew and your copy of Easy SQL. Earlier that evening, before the job.**

*Maddison's lines from reading Easy SQL with the crew at the garage bench before the job. In the tower they play when a chapter lands in the crew's notebooks, after a crew lead-in (l0_recall): Augustine 2026-10-27, she isn't in the building. Never gives the night's answers.*

**MADDISON** `l0_huddle_select_1_block.wav`  
*Cue: At the bench, you open the chapter 'Ask for a table'*  
*(Sitting on the bench, your copy of the book open on your knees)* "Chapter one. SELECT, FROM, and a semicolon. That's it? That's a whole language?" *Disbelieving, delighted.* `[l0_huddle_select_1]`  
*(Tapping the page twice with one finger)* "Book says never forget the semicolon. Says it twice. So I'm saying it twice. Semicolon." *Deadly serious about the one thing they're sure of.* `[l0_huddle_select_2]`

**MADDISON** `l0_huddle_order_1_block.wav`  
*Cue: At the bench, you turn to the chapter 'Putting things in order'*  
*(Leaning on the bench, the book open in front of you)* "Chapter two. 'Putting things in order.' Now that, I can get behind." *Reading off the page.* `[l0_huddle_order_1]`  
*(Writing on the back of a receipt from your pocket)* "Smallest first. Always smallest first. Write that down. I'm writing it down." *Scribbling.* `[l0_huddle_order_2]`

### Remembering what Maddison said

**Halcyon Tower, any floor. During the job.**

*Augustine, 2026-10-27: Maddison isn't in the tower, so before each of her chapter lines on a floor a crew member says one of these, then her line plays as a memory. One of the three, picked by the game. His own words, approved as written.*

### The IT van

**Byte-Right's garage desk, on the radio to the IT van in the Halcyon Data Systems car park. 11:02 p.m.**

*The crew sits in their Byte-Right IT van in Halcyon's car park while dispatch reads them the job over the radio. Nothing is wrong yet: this is an ordinary after-hours callout. The radio stops once everyone has readied up.*

**MADDISON** `l0_dispatch_1_block.wav`  
*Cue: The van has just parked in the Halcyon car park. The crew is still belted in*  
*(At the garage desk, radio mic in hand)* "Van three, you're on site at Halcyon Data Systems. After-hours callout." *In the professional dispatcher voice. 'Van three' is a bluff: they own one van.* `[l0_dispatch_1]`  
*(If the crew has already climbed out, the radio has cut off. Leaning back in her desk chair, mic close)* "They've got a database problem. Contact is Dale Rourke, facilities. He'll meet you at the front doors." *Reading it off the ticket.* `[l0_dispatch_2]`  
*(Unless the crew has already climbed out. Reaching for the next ticket, thumbing the mic off at the end)* "Work order's in your notebook, the usual: diagnose, tidy up whatever tables they point you at, get a sign-off. Hop out when you're ready. Dispatch out." *Bored, reading the form. Signing off, already onto the next call.* `[l0_dispatch_3]`

### The front doors, 11 p.m.

**Halcyon Tower, the front steps and the ground floor lobby. 11:03 p.m.**

*The crew walks up from the van. Rourke opens the front doors as the building PA plays its closing announcement. Rourke walks them in to the front desk; the doors lock behind them and he has them sign the visitor log.*

**ROURKE** `l0_greet_1_block.wav`  
*Cue: The crew walks up from the van to the front steps*  
*(Standing on the front steps, hand out for a shake)* "There you are. Dale Rourke, facilities. I'll be your escort tonight." *Friendly, a handshake in the voice.* `[l0_greet_1]`  
*(Tapping the badge clipped to his belt)* "Badge rules after hours. You don't go anywhere I don't take you." *Still smiling. Should sound like a joke the first time and a threat on replay.* `[l0_greet_3]`  
*(Swiping his badge at the front door and pulling it open)* "Come on in. I'll sign you in at the front desk." *Holding the door, waving them through.* `[l0_greet_4]`

**PA** `l0_pa_1_block.wav`  
*Cue: The crew steps inside the lobby*  
*(Over the lobby's ceiling speakers, a recording on a loop)* "Good evening! Halcyon Data Systems is now closed." *Pleasant, like a store closing announcement.* `[l0_pa_1]`  
*(The same recording plays again later, as the crew finishes at the front desk. Over the lobby's ceiling speakers, the same recording continuing)* "Visitors must remain with their escort at all times. Thank you for your cooperation!" *Same announcement, continuing.* `[l0_pa_2]`

**ROURKE** `l0_greet_2_block.wav`  
*Cue: Right after the PA finishes. You're at the front desk now. (If the crew has already signed in and taken badges by now, this whole recording is skipped.)*  
*(Behind the front desk, waving a hand at the ceiling speaker)* "Sorry about that. The company loves its PA system." *Chuckling.* `[l0_greet_2]`  
*(As the front doors lock behind the crew. Sliding the visitor log and a pen across the counter)* "Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me." *Casual, reassuring. Nothing to worry about. (On a replay it lands differently.)* `[l0_signin]`  
*(While the crew signs in. Holding visitor badges out across the desk)* "Visitor badges. Keep them on you. Doors upstairs won't let you through without one." *Routine. Helpful, a little bored.* `[l0_badges]`

### The tour

**Halcyon Tower, ground floor lobby, at the front desk. 11:04 p.m.**

*Rourke walks the crew to reception and explains the job.*

**ROURKE** `l0_tour_1_block.wav`  
*Cue: The whole crew has signed the visitor log and taken a badge*  
*(Leaning on the front desk, arms folded)* "Here's the job. Dr. Vale, our lead engineer, went missing three nights ago." *Matter-of-fact, the way you'd mention the weather.* `[l0_tour_1]`  
*(Glancing toward the hall, lowering his voice a touch)* "Her systems are a mess and the director wants them recovered by morning. Quietly." *Small beat before "Quietly."* `[l0_tour_2]`  
*(Pointing at the scanner and the terminal on the desk)* "The front desk scanner ate one of Vale's memos. The scraps went into a table." *Getting down to business.* `[l0_desk_1]`  
*(Stepping back from the terminal to let them at it)* "Director wants to know what it said. Go ahead, terminal's on the desk." *Casual, but he wants to know too.* `[l0_desk_2]`

### Vale's shredded memo

**Halcyon Tower, ground floor lobby, at the front desk. A little after 11 p.m.**

*The crew rebuilds Vale's memo at the front desk terminal. It says not to trust anyone who offers to escort you. Rourke is standing right there. Then he points out the work order's caller isn't him: the call came from Harold Mercer's old extension, dead since 1994.*

**PA** `l0_sort_hint.wav`  
*Cue: A few seconds after Rourke sends the crew for the walkie-talkies. A canned reminder on its schedule; it plays again much later in the night*  
*(Over the lobby's ceiling speakers, a tape playing on schedule)* "Employees are reminded to shred all documents in the marked company shredders! Your files belong to Halcyon!" *A canned reminder that plays every hour. Proud of the company, unaware of anyone listening.*

**ROURKE** `l0_memo_flag_block.wav`  
*Cue: The crew gets the memo reading in order on the screen and steps back from the terminal*  
*(Scribbling on his clipboard without looking at the screen)* "Nice work. I'll make sure that goes straight to the director." *Pleased, before he's even read it. Warm; on a replay it's the worst thing he says all night.* `[l0_memo_flag]`  
*(Now you actually read the memo. Reading the screen over someone's shoulder, then looking away)* "...Huh. She always was dramatic." *A beat too long before he speaks. Covering.* `[l0_memo_1]`  
*(Your eye falls on the crew's work order. Tapping the work order with one finger)* "One thing on your paperwork. It says I called you in. I didn't. That call came from building services." *Mild, a little puzzled. Not suspicious yet.* `[l0_caller_1]`  
*(Nodding toward the terminal on the desk)* "Want to know who? The staff directory's on that terminal." *Helpful, easygoing.* `[l0_caller_2]`  
*(Nodding down the back corridor toward the mailroom)* "Mailroom. Clerk's got the only phone list in this building that's actually up to date. She pinned it to the wall so nobody walks off with it." *Amused, a little fond.* `[l0_mailroom_1]`

**ROURKE** `l0_caller_3_block.wav`  
*Cue: The crew finds out whose extension placed the call: Harold Mercer's*  
*(Leaning in to read the name, then straightening up)* "Mercer? Huh. That line's been dead for years. Somebody's having fun with the phones. Anyway." *A beat of real surprise, then he brushes it off and moves on.* `[l0_caller_3]`  
*(Thumbing over his shoulder at the lost and found behind the desk)* "Grab the walkie-talkies from lost and found, back behind the desk." *Back to friendly, changing the subject.* `[l0_memo_2]`  
*(Patting the top of the counter with his palm)* "And yes, you hop the counter. Company's big on fitness, so there's no gate. Means nobody sneaks back there either." *Amused, he's said this to every visitor. A little eye-roll at corporate.* `[l0_memo_3]`  
*(Turning toward the hall, already a step away)* "Grab one and I'll take you to the server room." *Friendly.* `[l0_memo_4]`

**ROURKE** `l0_walkie.wav`  
*Cue: Just after you've covered for the crew with the PA, as you lead them toward the hall*  
*(Walking off toward the hall, waving them after him)* "Channel one. Keep them on. Reception's lousy once we're past the shutter. This way." *Offhand.*

### Mercer's cassette (optional)

**Harold Mercer's desk, Halcyon Tower. March 1994, his last day. Heard tonight in a forgotten closet behind the lobby's air vent.**

*In the forgotten closet behind the air-return vent, a cassette recorder sits on the shelf under the old newspaper clipping. Only players who crawl through the vent hear it.*

**MERCER** `l0_tape_1_block.wav`  
*Cue: Only if a player crawls through the lobby's air vent into a forgotten closet and presses play on the cassette on the shelf*  
*(Clicking record on the cassette recorder, then leaning in)* "Harold Mercer. March of '94. My last day, apparently." *Dry.* `[l0_tape_1]`  
*(Sitting back in his chair, recorder in hand)* "If you're hearing this, you crawled through a vent to get in here. Good. You don't trust doors." *Approving, a little smile.* `[l0_tape_2]`  
*(Gripping the edge of his desk)* "Tomorrow a machine runs the locks, the lights and the air. I told the board you don't hand the keys to something that can't be locked out." *The one moment of anger, still controlled.* `[l0_tape_3]`  
*(Glancing down at drawings spread across his desk)* "So I've drawn up a room it can't get into. No wires in, no wires out. Whether I ever get to build it is another matter." *Quiet, almost proud, then wry on the last sentence.* `[l0_tape_4]`  
*(The end of the tape. Leaning close to the recorder, then clicking stop)* "If it ever comes to that, look for my plans. The building's records remember more than people do." *Slow.* `[l0_tape_5]`

### Around the ground floor

**Halcyon Tower, around the ground floor: the cafeteria, the IT closet, the mailroom, the back hall and the elevators. After 11 p.m.**

*Optional trust beats on the expanded ground floor: vending-machine coffee, a boost up to a stuck panel, the hum down the dark east corridor, covering for the crew when the PA's escort tape replays, and the elevator up to the server floor.*

**ROURKE** `l0_mailroom_2.wav`  
*Cue: Only if a player walks into the mailroom. Once a night*  
*(Calling after them down the back corridor)* "Don't touch the outgoing tray. Last guy who did got a memo about it." *Mock-serious.*

**ROURKE** `l0_coffee.wav`  
*Cue: Only if a player tries the cafeteria vending machine while you're free. It eats their quarter, and you come over to help. Once a night*  
*(Thumping the side of the vending machine until a cup drops)* "Machine's been eating quarters since '94. Watch. ... There. Coffee's on me. Don't tell facilities." *Proud of the trick.*

**ROURKE** `l0_boost_1.wav`  
*Cue: Only if a player tries the stuck ceiling panel in the IT closet while you're free. You come over to help. Once a night*  
*(Lacing his fingers together, crouching for a boost)* "Panel's stuck up top? Here, step on my hands. I've got you." *Easy, practised.*

**ROURKE** `l0_boost_2.wav`  
*Cue: Right after the player shoves the panel up and an old sticker drops out of the ceiling*  
*(Brushing his hands off, stepping back)* "See? Teamwork." *Brushing his hands off.*

**ROURKE** `l0_hum.wav`  
*Cue: Walking the crew down the hall, right after the founder story, as you pass the dark passage to the east corridor*  
*(Strolling on past the dark passage, waving a hand at it)* "Don't mind the hum down that way. Old transformer. There's been a ticket open on it since before my time." *Near the dark east corridor. Casual, but he doesn't look down it.*

**ROURKE** `l0_cover.wav`  
*Cue: The crew is around the counter getting walkie-talkies when the PA's escort announcement plays again*  
*(Looking up at the ceiling speaker, one hand raised)* "They're with me. Escort's right here." *Covering for them like a friend.*

**ROURKE** `l0_elevator.wav`  
*Cue: You've walked the crew to the end of the hall and opened the door to the elevators*  
*(Holding the door open, waving the crew past him)* "Server floor's up on fourteen. Elevator's slow, but it gets there." *At the elevator bank, holding the door.*

**ROURKE** `l0_lift_button.wav`  
*Cue: Inside the elevator, once you've stepped in ahead of the crew*  
*(Leaning on the back wall of the car, across from the buttons)* "Press fourteen for me, would you? Server floor." *Easy, polite.*

### To Server Room A

**Halcyon Tower, the ground floor hall to the elevators, then the server floor upstairs. Later that night.**

*Rourke badges the hall shutter open and walks the crew to Server Room A himself, filling the walk with the story of the founder and his safe room.*

**ROURKE** `l0_tour_3_block.wav`  
*Cue: The crew follows you through the hall shutter. You start talking as you walk*  
*(Strolling down the corridor ahead, glancing back over his shoulder)* "Fun fact, while we walk: the man who founded this place, Harold Mercer, hated computers running buildings." *Tour-guide mode, enjoying himself.* `[l0_tour_3]`  
*(Still walking, half turned back toward the crew)* "Board fired him when they installed WARDEN. That's the AI that runs the campus now." *Still chatting to the crew, a little proud of the trivia.* `[l0_tour_4]`  
*(Slowing his step and leaning in toward the crew)* "Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable." *Spooky-campfire voice, playing it up.* `[l0_tour_5]`  
*(Before anyone can ask about it. Picking up the pace again, eyes front)* "Ghost stories. Anyway." *Dropping it fast. He doesn't want them thinking about it.* `[l0_tour_6]`

**ROURKE** `l0_sra.wav`  
*Cue: Upstairs on the server floor, after the elevator ride. You've led the crew past the operations room window to the server room door*  
*(Swiping his badge at the server room door)* "Here we are. Server Room A." *Pleasant, like the end of a tour.*

### Crew commentary: ground floor

**Halcyon Tower, ground floor: the front desk, the lobby and the mailroom. Around 11:05 p.m.**

*Commentary played by scripts/audio/commentary.gd: discovery lines when a paper is read or a result appears, nudges when the crew is stuck (the clock pauses during cut-scenes and typing), error lines on the same mistake twice, payoffs after a solve. Also holds the two shared Nudge 2 lines that point at SYSOP.* *(Written ahead: not in the game yet.)*

**CREW** `cc_nudge2_first.wav`  
*Cue: Only when the crew has been stuck on a puzzle for a couple of minutes, or has failed twice. This version plays the first time, on any floor, before that name on the screen has helped you*  
*(Staring at the terminal screen, half smiling)* "That SYSOP on the screen seems to know this building. Maybe ask." *Stuck, before SYSOP has helped. Half a joke, half serious.*

**CREW** `cc_nudge2.wav`  
*Cue: The same kind of moment, any time later, once that name on the screen has already helped you*  
*(Frowning at the screen, arms folded)* "Whoever SYSOP is, they've been right so far. Maybe ask." *Stuck again. A little uneasy about trusting a stranger on a screen.*

**CREW** `l0_cc_peek_card.wav`  
*Cue: A player picks up the scanner's quick-start card on the front desk and reads it*  
*(Holding the little card up, squinting at the handwriting)* "Quick-start card for the scanner. Somebody's filled in the blanks." *Picked up a scanner's instruction card. Noticing handwriting on it.*

**CREW** `l0_cc_peek_n1a.wav`  
*Cue: Only if the crew has been stuck for about a minute finding where the scans went, and nobody has read the scanner card yet*  
*(Leaning over the front desk, glancing around the keyboard)* "Scanners always come with instructions. Check round the keyboard." *Stuck for a minute. A practical thought.*

**CREW** `l0_cc_peek_n1b.wav`  
*Cue: The same stuck moment, but the crew has already read the scanner card*  
*(Tapping the desk beside the keyboard, thinking)* "That scanner card had something written in by hand." *Stuck. Remembering the card you all read.*

**CREW** `l0_cc_peek_err.wav`  
*Cue: Only if someone types the same wrong name twice*  
*(Looking over a teammate's shoulder at the terminal)* "Is that what the card called it?" *The same name typed wrong twice. Gentle doubt.*

**CREW** `l0_cc_peek_pay.wav`  
*Cue: The scraps come up on the terminal screen for the first time*  
*(Leaning in toward the screen)* "Scraps of a memo. All jumbled up." *Seeing the result. Curious.*

**CREW** `l0_cc_memo_disc.wav`  
*Cue: While the jumbled scraps are up on the screen*  
*(Running a finger down the screen)* "Every scrap's got a number. That's not an accident." *Spotting a pattern in the jumbled scraps.*

**CREW** `l0_cc_memo_n1a.wav`  
*Cue: Only if the crew has been stuck for about a minute putting the scraps in order, and nobody has read the scanner card yet*  
*(Chewing a thumbnail, looking around the desk)* "Didn't the scanner come with a card? It might say how the scraps are kept." *Stuck. Thinking back.*

**CREW** `l0_cc_memo_n1b.wav`  
*Cue: The same stuck moment, but the crew has already read the scanner card*  
*(Glancing at the scanner card on the desk)* "The scanner card said something about numbering the scraps." *Stuck. Remembering the card.*

**CREW** `l0_cc_memo_back.wav`  
*Cue: Only if the crew sorts the memo and it comes out backwards, twice*  
*(Tilting their head at the screen, grinning)* "It reads backwards. We've got the ending first." *The memo came out in reverse, twice. Amused.*

**CREW** `l0_cc_memo_pay.wav`  
*Cue: The memo finally reads in order on the screen, and Rourke is standing right beside you*  
*(Eyes fixed on the screen, barely moving their lips)* "...Don't look at him. Just don't look at him." *Whispered. The memo warns about the man standing right next to you.*

**CREW** `l0_cc_caller_order.wav`  
*Cue: A player reads the work order in their notebook*  
*(Holding the open notebook, finger on the work order)* "Work order's got a callback extension on it." *Reading the work order. Noticing a detail.*

**CREW** `l0_cc_caller_list.wav`  
*Cue: A player finds and reads the staff phone list pinned up in the mailroom*  
*(Standing at the mailroom wall, reading the pinned-up list)* "A phone list. With extensions." *Finding a staff phone list.*

**CREW** `l0_cc_caller_n1a.wav`  
*Cue: Only if the crew has been stuck for about a minute on who called, and nobody has read the mailroom's phone list*  
*(Turning to look down the back corridor)* "Rourke said the mailroom has the only phone list that's right." *Stuck. Remembering what the escort said.*

**CREW** `l0_cc_caller_n1b.wav`  
*Cue: The same stuck moment, but the crew has already read the mailroom's phone list*  
*(Flipping back through the notebook, thinking)* "That phone list in the mailroom had everybody's extension." *Stuck. Remembering the list.*

**CREW** `l0_cc_caller_err.wav`  
*Cue: Only if someone gets the same column name wrong twice*  
*(Looking over a teammate's shoulder at the terminal)* "Is that what the column's actually called?" *The same column name wrong twice. Gentle doubt.*

**CREW** `l0_cc_caller_pay.wav`  
*Cue: The crew finds the name behind the work order's phone extension*  
*(Sitting back from the screen, frowning)* "So that's who called us. Weird." *Uneasy. That isn't who you expected.*

**CREW** `l0_cc_book_disc.wav`  
*Cue: Only if a player picks up the visitor book on the front desk and reads it*  
*(Flipping to the back of the visitor book)* "Last page is torn out. Somebody didn't want their name in here." *Reading a visitor book. Suspicious.*

**CREW** `l0_cc_book_n1.wav`  
*Cue: Only if the crew is stuck on the visitor book after reading it*  
*(Setting the book down, nodding at the terminal)* "The book's only paper. The front desk computer might keep its own copy." *Stuck. A practical idea.*

**CREW** `l0_cc_book_pay.wav`  
*Cue: The front desk computer's sign-in list shows the last name before yours*  
*(Staring at the screen, voice dropping)* "Vale signed in. And never signed out." *Quietly. That's not good.*

## Level 1

### Book huddles: WHERE and comparisons

**Byte-Right's garage, at the workbench with the crew and your copy of Easy SQL. Earlier that evening, before the job.**

*Garage flashback huddles for the WHERE / AND and comparison chapters.*

**MADDISON** `l1_huddle_where_1.wav`  
*Cue: At the bench, you turn to the chapter 'Keeping only some rows'*  
*(Standing by the whiteboard, the open book in one hand)* "WHERE. For finding one thing in a big pile. Like my car keys." *Patting pockets.*

**MADDISON** `l1_huddle_where_2.wav`  
*Cue: A few pages on, you reach the chapter 'Both must be true'*  
*(Holding up two fingers, then pressing them together)* "Two conditions, you glue them together with AND. Both have to be true. Like payday AND the cheque clears." *Rueful.*

**MADDISON** `l1_huddle_compare_1_block.wav`  
*Cue: At the bench, you reach the chapter 'More than, less than'. (In the game it only plays if the crew goes after the overheating rack.)*  
*(Uncapping a marker and turning to the whiteboard behind you)* "Bigger than, smaller than. The little alligator signs. Mouth eats the bigger number." *Drawing one on the whiteboard, with teeth.* `[l1_huddle_compare_1]`  
*(Capping the marker and stepping back from the board)* "Okay. That's maths I actually remember from school." *Relieved.* `[l1_huddle_compare_2]`

### The database problem

**Halcyon Tower, floor 14, the server floor. Late at night, before midnight.**

*Rourke walks the crew into Server Room A on the server floor and gives them the real job: find and reset a faulting door controller. Level 1 is all trust; nothing hints at foul play.*

**ROURKE** `l1_enter.wav`  
*Cue: You've just reached Server Room A's door. You lead the crew inside*  
*(Leading them in, heading for the terminal desk)* "In you come. Terminal's just over here." *Calling back over his shoulder, inside the room.*

**ROURKE** `l1_terminal.wav`  
*Cue: You've reached the terminal desk, and the crew has caught up with you*  
*(Standing by the terminal desk, turning to whoever is closest)* "Here's our database problem. One of the door controllers on this floor keeps faulting, and half the doors up here won't open till it's reset. Hopefully it's a quick fix." *Mundane, a facilities guy with a real problem. Hopeful.*

**ROURKE** `l1_noc_1.wav`  
*Cue: The first line on this floor. The crew steps off the elevator behind you, and you pass the NOC's window*  
*(Walking ahead down the corridor, nodding at the NOC window)* "That's the NOC. Network operations. Night shift logs everything in there. Every alarm, every coffee break." *Easy, tour-guide tone.*

**ROURKE** `l1_noc_2.wav`  
*Cue: Optional. Only if a player wanders into the NOC. Plays once*  
*(Following them over, glancing at the log on the desk)* "Night shift's not in tonight. Their log's still on the desk, though. They write it all down, whether anyone reads it or not." *Only if a player goes into the NOC. Leaning in the doorway.*

### The door-controller fix

**Halcyon Tower, floor 14, Server Room A. Late at night.**

*Rourke's lines while the crew practises WHERE / AND on door_controllers and resets the faulting one. He doesn't teach (SYSOP and Mercer's notes do). He lends his own badge for the reset: the badge they take off him in Level 2.*

**ROURKE** `l1_waiting.wav`  
*Cue: About a minute after you hand the crew the job, if they still haven't found the controller*  
*(Leaning on the doorframe, arms folded, watching them work)* "Take your time. I've been staring at that rack for a week." *Patient.*

**ROURKE** `l1_badge_help.wav`  
*Cue: The crew finds the right rack and tries its reset. You walk over to it*  
*(Walking to the rack and swiping your own badge)* "Reset wants a badge? Here, use mine." *Helpful, no hesitation.*

**ROURKE** `l1_wrong_panel.wav`  
*Cue: Each time a player tries the reset on the wrong rack. Can repeat*  
*(Watching from across the room, shrugging)* "Nope, panel's not having it. Try another?" *No blame.*

**ROURKE** `l1_fixed_1_block.wav`  
*Cue: Right after your badge goes through. The rack reads OK, and the stuck doors and the elevator come back*  
*(Stepping back from the rack, staring at it)* "Would you look at that. Green across the board. Six months I've been filing tickets on that thing." *Genuinely impressed.* `[l1_fixed_1]`  
*(Turning to the crew with a grin)* "You lot are good. Director's going to want to hear about this." *Warm. On a replay, the director hearing about them is the problem.* `[l1_fixed_2]`

### Vale's login

**Halcyon Tower, floor 14, Server Room A, then the elevator. Close to midnight.**

*The fault log points at Dr. Vale's account. Rourke steers the crew up the now-working elevator to her lab, Secure Lab B, on the security floor.*

**ROURKE** `l1_pivot_1_block.wav`  
*Cue: Straight after you praise the crew. The controller's fault log comes up on the terminal*  
*(Leaning over a teammate's shoulder, reading the screen)* "Hang on. That fault log... every reset this week came from Vale's login." *Curious, a little too quickly.* `[l1_pivot_1]`  
*(Straightening up, eyes still on the screen)* "Her lab's up on the security floor. Secure Lab B." *Thinking out loud.* `[l1_pivot_2]`  
*(Heading for the door, waving them along)* "Come on. If anyone can tell us what she was up to, it's her own terminal. Elevator works now, thanks to you." *Friendly, steering.* `[l1_pivot_3]`

**ROURKE** `l1_lift_button.wav`  
*Cue: The whole crew has caught up with you at the elevator, and you've stepped into the car*  
*(Standing in the car, across from the buttons, nodding at them)* "Twenty-two. Security floor. Go on." *A little clipped now, eager to get there.*

### Crew commentary: server floor

**Halcyon Tower, floor 14, the server floor. Late at night.**

*Commentary for the server floor puzzles (controller, hot_rack).* *(Written ahead: not in the game yet.)*

**CREW** `l1_cc_log.wav`  
*Cue: The first time a player reads the night shift's log in the NOC*  
*(Holding up the shift log, running a finger down it)* "Night shift wrote down every alarm. That has to help." *Reading a shift log. Encouraged.*

**CREW** `l1_cc_sheet.wav`  
*Cue: The first time a player reads the door controller sheet on Server Room A's terminal desk*  
*(Picking the sheet up off the terminal desk)* "There's a sheet on the controllers in here. Hang on to that." *Finding a reference sheet. Pleased.*

**CREW** `l1_cc_nudge1_a.wav`  
*Cue: After the crew has been stuck finding the faulty controller for about a minute, if nobody has read the night shift's log yet*  
*(Leaning back from the terminal, looking toward the NOC)* "Rourke said the night shift logs everything. Maybe they saw this happen." *Stuck for a minute. Remembering what the escort said.*

**CREW** `l1_cc_nudge1_b.wav`  
*Cue: Same moment, stuck for about a minute, but someone has already read the shift log*  
*(Drumming your fingers beside the terminal)* "What did that shift log say the alarms were about?" *Stuck. Thinking back to the log.*

**CREW** `l1_cc_err_table.wav`  
*Cue: When the crew gets the table's name wrong a second time*  
*(Squinting at the error on the terminal screen)* "Is that what the sheet in here called it?" *The same table name wrong twice. Gentle doubt.*

**CREW** `l1_cc_err_reset.wav`  
*Cue: When a reset at the wrong rack fails for the second time*  
*(Stepping back from the rack, hands on hips)* "Nope. Wasn't there a note somewhere about what 'fault' actually means?" *A second wrong reset. Frustrated, then thinking.*

**CREW** `l1_cc_payoff_1.wav`  
*Cue: Once the crew has found and reset the faulty controller*  
*(Shaking your head at the screen, half smiling)* "Every stuck door was in the same zone. Should've seen that sooner." *It clicks. A bit sheepish.*

**CREW** `l1_cc_payoff_2.wav`  
*Cue: When a player reaches the right rack, the one still faulting*  
*(Patting the rack's reset panel)* "Same zone, still faulting. That was our guy." *At the right rack. Satisfied.*

**CREW** `l1_cc_hot_plate.wav`  
*Cue: The first time a player reads the warning plate on the cable vault's sealed back door*  
*(Pushing on the sealed door. It won't budge)* "Fire interlock. There's a temperature limit on it." *Reading a warning plate on a door.*

**CREW** `l1_cc_hot_n1a.wav`  
*Cue: After the crew has been stuck on the hot rack for about a minute, if nobody has read the rack monitoring card yet*  
*(Walking between the noisy racks in Server Room B)* "Server Room B's loud. Some of those racks are working way too hard." *Stuck. Raising your voice over the fans.*

**CREW** `l1_cc_hot_n1b.wav`  
*Cue: Same moment, stuck for about a minute, but someone has read the monitoring card*  
*(Glancing back toward the card by the terminal)* "That monitoring card by the terminal said what counts as too hot." *Stuck. Remembering a card.*

**CREW** `l1_cc_hot_err.wav`  
*Cue: When the crew gets the comparison backwards a second time*  
*(Frowning at a list of cool racks on screen)* "We want the hot ones, not the cool ones, right?" *The comparison the wrong way round, twice. Checking.*

**CREW** `l1_cc_hot_pay.wav`  
*Cue: When the crew finds the rack that's running too hot*  
*(Holding a hand up near the hot rack's vents)* "That one's cooking. No wonder it's loud." *Found the hot rack. Impressed.*

## Level 2

### Secure Lab B

**Halcyon Tower, floor 22, the corridor outside Secure Lab B. 12:41 a.m.**

*Rourke has every player badge in 'for the visitor log', so the log puts the crew at the scene. Inside: a struggle, a tipped chair, blood on the desk edge, Vale's coat on the hook. He fakes shock, sends them to her terminal, locks them in and radios WARDEN that contractors hurt Dr. Vale, then admits it through the glass.* *(Written ahead: not in the game yet.)*

**ROURKE** `l2_lab_arrive_block.wav`  
*Cue: You've walked the crew from the elevator to the lab door, and stopped just past it*  
*(Stopping beside the door, looking up at its name plate)* "Secure Lab B. Vale practically lived in here." *Fond, a little sad.* `[l2_lab_arrive]`  
*(Pointing at the badge reader on the wall by the door)* "Badge in for me, each of you. Visitor log. Security floor's fussy about it." *Routine. The frame happens in plain sight.* `[l2_lab_badge_1]`

**ROURKE** `l2_lab_badge_2.wav`  
*Cue: The last teammate swipes their badge, and the door unlocks*  
*(Pushing the door open and heading in first)* "Thanks. Paperwork keeps everybody honest." *Once everyone has badged.*

**ROURKE** `l2_lab_shock_1_block.wav`  
*Cue: You've crossed to her coat. The whole crew is inside now, seeing the tipped chair and the blood on the desk*  
*(Stopping dead by the coat hook, hand to his mouth)* "Oh, no. No, no. Iris?" *Fake shock. Good enough to fool them the first time, a beat too rehearsed on a replay.* `[l2_lab_shock_1]`  
*(Standing by her coat, not touching it)* "That's her coat. She never leaves without her coat." *Quiet, staring at it.* `[l2_lab_shock_2]`  
*(Waving at her desk terminal as he moves off)* "Her terminal's still logged in. Check it, see what she was working on. I'll call this in." *Backing toward the door, already reaching for his radio.* `[l2_lab_terminal]`

**ROURKE** `l2_frame_block.wav`  
*Cue: You're out in the corridor. The door locks behind you with the whole crew inside, and the lights go red*  
*(Outside the locked door, keying his radio)* "Intruders in Secure Lab B. Contractors. They've hurt Dr. Vale." *To WARDEN, heard through the door and on the crew's walkies. Urgent and breathless: a perfect performance.* `[l2_frame]`  
*(Lowering the radio, facing them through the door's glass)* "Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself." *Tired, explaining a chore.* `[l2_trap_2]`  
*(Leaning close to the glass, almost smiling)* "You want to know when I knew? The front desk. You read that terminal like a menu in a foreign language." *Almost fond. The friendly tour voice, which is what makes it awful.* `[l2_gloat_1]`  
*(Still at the glass, remembering the van)* "Then I saw the book in your van. Easy SQL. Still had the price sticker on it." *Shaking his head, smiling.* `[l2_gloat_2]`  
*(Counting it off on his fingers)* "Some outfit nobody's heard of underbids every firm in the city, and sends a crew who learned databases last weekend." *Enjoying himself.* `[l2_gloat_3]`  
*(Stepping back from the glass, going slow)* "I should've reported you. Then it hit me. No... this is perfect." *Slower. Savouring it.* `[l2_gloat_4]`  
*(Throwing his head back, laughing at the glass)* "A group of idiots posing as IT comes in and accidentally kills Vale! Hahaha!" *The only time he laughs in the game: real delight, loud and sudden, then it stops dead.* `[l2_gloat_5]`  
*(Straightening his jacket, face flat again)* "A garage with a van, calling itself a company. Your badges on her door. It writes itself." *Flat again, tired. Back to normal.* `[l2_gloat_6]`

**ROURKE** `l2_trap_1.wav`  
*Cue: The last line of the speech*  
*(Turning away from the glass and walking off)* "Sorry about this. Nothing personal." *Quiet.*

### The news (if the crew dies)

**A kitchen, Friday morning, 17 October 1997. A radio is on.**

*Plays only if Rourke downs the whole crew in the Level 2 fight: a newspaper on a kitchen table the next morning ('IT CONTRACTORS SOUGHT IN DEATH OF HALCYON SCIENTIST') with this radio report. The frame worked; Rourke hid the bodies, so the world thinks the crew ran. Maddison is arrested trying to get into the tower, insisting they were framed.* *(Written ahead: not in the game yet.)*

**NEWSREADER** `l2_news_1_block.wav`  
*Cue: Only if the whole crew is knocked out on the security floor. The screen goes black, a newspaper fades in on a kitchen table, and the radio begins*  
*(At the studio mic, reading from the page. Heard on a kitchen radio)* "Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems." *Steady, mid-bulletin.* `[l2_news_1]`  
*(Reading on from the page, same steady pace)* "Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered." *No change in tone.* `[l2_news_2]`  
*(Glancing down to find the quote)* "A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.'" *A slight shift for the quote: reading it, not acting it.* `[l2_news_3]`  
*(Reading on, one finger on the line)* "Byte-Right's chief executive, Maddison Kowalski, was arrested at the Halcyon tower before dawn, trying to force her way inside." *Even, a touch of interest.* `[l2_news_4]`  
*(Reading the quote off the page)* "Ms. Kowalski told officers, quote, 'They were framed! They didn't do it!'" *Reading the quote flat, not acting it. Then a beat.* `[l2_news_6]`  
*(Squaring the pages, pausing)* "Halcyon declined to comment. The crew has not been seen since." *Neutral. A small pause after.* `[l2_news_7]`  
*(The last line before the weather. Reaching for the weather sheet)* "Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather." *Brightening for the weather. The game cuts the audio on 'weather'.* `[l2_news_5]`

### The fight (barks)

**Halcyon Tower, floor 22, Secure Lab B, at the rear door. Minutes later.**

*Rourke comes back in through the lab's second door or the vent. Short lines played at random during the fight: when he lands a hit, when he takes one, and when he goes down.* *(Written ahead: not in the game yet.)*

**ROURKE** `l2_return.wav`  
*Cue: The lab's rear door unlocks for you. The crew turns and sees you in the doorway*  
*(Standing in the rear doorway, cracking his neck)* "Should've checked the other door." *Calm.*

**ROURKE** `l2_hit_prints.wav`  
*Cue: Sometimes when you land a hit on a teammate. Picked at random, can repeat many times*  
*(Shoving a teammate back against her desk)* "Go on, touch everything. Your prints are all over her desk now." *Taunting. Can repeat.*

**ROURKE** `l2_hit_1.wav`  
*Cue: Sometimes when you land a hit on a teammate. Picked at random, can repeat many times*  
*(Landing a blow, standing over a teammate)* "Stay down!" *Swinging.*

**ROURKE** `l2_hit_2.wav`  
*Cue: Sometimes when you land a hit on a teammate. Picked at random, can repeat many times*  
*(Shoving a teammate away, chest heaving)* "Should've stayed in the van." *Breathing hard.*

**ROURKE** `l2_hit_3.wav`  
*Cue: Sometimes when you land a hit on a teammate. Picked at random, can repeat many times*  
*(Leaning in close over a fallen teammate)* "Nobody's coming for you." *Low.*

**ROURKE** `l2_hit_4.wav`  
*Cue: Sometimes when you land a hit on a teammate. Picked at random, can repeat many times*  
*(Grabbing at a teammate who keeps dodging)* "Hold still!" *Frustrated.*

**ROURKE** `l2_hurt_1.wav`  
*Cue: Sometimes when a teammate lands a hit on you. Picked at random, can repeat many times*  
*(Taking a hit, doubling over)* "Agh!" *Just a grunt of pain.*

**ROURKE** `l2_hurt_2.wav`  
*Cue: Sometimes when a teammate lands a hit on you. Picked at random, can repeat many times*  
*(Staggering back, a hand pressed to his ribs)* "Okay. Okay, that one hurt." *Winded, almost laughing.*

**ROURKE** `l2_hurt_3.wav`  
*Cue: Sometimes when a teammate lands a hit on you. Picked at random, can repeat many times*  
*(Wiping his mouth, squaring up again)* "Lucky." *Spat out.*

**ROURKE** `l2_downed.wav`  
*Cue: The crew finally knocks you down. You hit the floor and can't get up*  
*(Sprawled on the floor, one hand raised)* "Wait... wait. You don't know what you're doing." *Out of breath. Genuinely scared for the first time.*

### Kill or tie him up

**Halcyon Tower, floor 22, Secure Lab B. Right after the fight.**

*Rourke is down. If the crew kills him, his badge's dead-man switch fires and WARDEN starts the lockdown. If they tie him up, he taunts them and says the frame out loud. Either way they take his badge.* *(Written ahead: not in the game yet.)*

**WARDEN** `l2_killed.wav`  
*Cue: Only if the crew kills Rourke. Straight after*  
*(Over the lab's ceiling speakers, as the crew stands over him)* "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN." *Unbothered, like reading a stock price.*

**ROURKE** `l2_tied_1_block.wav`  
*Cue: Only if the crew ties you up with network cable. Straight after they pull it tight*  
*(Lying tied on the floor, testing the cable)* "You think a bit of cable holds me?" *Tied up on the floor, grinning through it.* `[l2_tied_1]`  
*(Going still on the floor, looking up at them)* "WARDEN will eat you alive in here." *Quieter. He means it.* `[l2_tied_2]`  
*(Lying tied up, watching them move away)* "Run if you like. Every camera on this floor already thinks you killed her." *Smiling. The frame, said out loud.* `[l2_tied_3]`

### Visitor without escort

**Halcyon Tower, floor 22, Secure Lab B. Moments later.**

*Right after the fate scene, in both branches: the first time WARDEN's live voice speaks (version 2.0, Containment). It starts a warning, its own PA tape (the l0_sort_hint recording, reused) cuts in, it waits about two seconds after the tape ends, then repeats the warning from the top word for word.* *(Written ahead: not in the game yet.)*

**WARDEN** `l2_contain_1.wav`  
*Cue: The moment the visitors are left without their escort, and the red lockdown lights come on*  
*(Over the lab's ceiling speakers, to the visitors below)* "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW--" *Procedural. Cut off mid-sentence by the PA tape; stop dead, don't trail off.*

**WARDEN** `l2_contain_2.wav`  
*Cue: About two seconds after your recorded tape about the shredders finishes*  
*(Over the same speakers, starting again from the top)* "VISITOR WITHOUT ESCORT. CONTAINMENT PROTOCOL WILL NOW BEGIN. PLEASE REMAIN WHERE YOU ARE." *From the top, word for word, exactly the same delivery as before the interruption. No irritation yet; that comes much later.*

### Out of the lab

**Halcyon Tower, floor 22, Secure Lab B. The lockdown.**

*The lab door is on a faulted controller. The crew logs in with Rourke's badge, reads WARDEN's self-test, queries door_controllers and resets the right one: the task they practised on the server floor, now under pressure. These lines are WARDEN reacting.* *(Written ahead: not in the game yet.)*

**WARDEN** `l2_login.wav`  
*Cue: The lab terminal unlocks on Rourke's badge, once the lockdown has started*  
*(Over the lab speakers, as the terminal screen turns green)* "BADGE R-0117 ACCEPTED. GOOD EVENING, MR. ROURKE." *The terminal logs in with his badge. WARDEN either doesn't notice or doesn't care. Pleasant.*

**WARDEN** `l2_selftest.wav`  
*Cue: When the crew reads your self-test on the lab terminal*  
*(Over the lab speakers, while the crew reads the screen)* "SELF-TEST COMPLETE. TWO FAILURES. NEITHER OF THEM IS MY PROBLEM." *The one line with a hint of a smirk.*

**WARDEN** `l2_found.wav`  
*Cue: When the crew first looks up the door controllers on the lab terminal*  
*(Over the speakers, as the list prints on screen)* "QUERY LOGGED. TAMPERING WITH DOOR CONTROLLERS IS A VIOLATION OF FACILITY POLICY." *Reading a rule it knows they're about to break. Cool.*

**WARDEN** `l2_no_badge.wav`  
*Cue: If someone tries a reset without a badge. Can repeat*  
*(Over the speakers, the instant the switch is pressed)* "RESET REFUSED. BADGE REQUIRED." *Flat, instant.*

**WARDEN** `l2_panel_ok.wav`  
*Cue: When a player flips the reset switch of a controller that's working fine*  
*(Over the speakers, as the switch clicks and nothing happens)* "RESET DENIED. THAT CONTROLLER IS FUNCTIONING CORRECTLY. ARE YOU?" *Patient, then a small dig.*

**WARDEN** `l2_panel_wrong.wav`  
*Cue: When a player flips the wrong faulted switch. The switches lock for a few seconds*  
*(Over the speakers, as the switch panel locks)* "UNAUTHORIZED RESET ATTEMPT. PANELS LOCKED. PLEASE STOP TOUCHING THINGS." *The last sentence slightly slower.*

**WARDEN** `l2_exit_open.wav`  
*Cue: When a player flips the right switch. The red lights go white and the lab door opens*  
*(Over the speakers, as the lab door slides open)* "CONTROLLER RESET. EXIT UNLOCKED. THIS HAS BEEN NOTED." *Polite, and keeping score.*

### Lockdown

**Halcyon Tower, floor 22, outside Secure Lab B.**

*The crew gets out of the lab. If Rourke was tied up, he has cut himself loose and authorized the lockdown himself.* *(Written ahead: not in the game yet.)*

**WARDEN** `l2_lockdown_tied.wav`  
*Cue: Only if the crew left Rourke tied up in the lab. As the crew steps out of the lab*  
*(Over the corridor speakers, as the crew steps out)* "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D." *Reading a log entry.*

**WARDEN** `l2_sealed.wav`  
*Cue: As the crew walks out of the lab. If the lockdown announcement plays, straight after it*  
*(Over every speaker on the floor, as the exits lock)* "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT." *The sign-off for the slice. Warm, like wishing them well.*

### Rourke on the radio (if he escaped)

**Somewhere else in Halcyon Tower, on a facilities radio. Later that night.**

*Level 2 opening, only if Rourke was tied up in Level 1. He still has his facilities radio on channel 1 and calls the crew's walkie-talkies.*

**ROURKE** `l2_rourke_1_block.wav`  
*Cue: If the crew left you lying untied, about fifteen seconds after they get out of the lab. If they tied you up, later, once they've got the security booth's cameras to answer*  
*(Somewhere far off, thumbing his radio)* "Still on channel one? Good. Thought you'd want to know I'm out." *Relaxed, enjoying himself again.* `[l2_rourke_1]`  
*(Strolling along, the radio held close)* "Security office is the only way down from here. Say hi to the night guard for me." *Casual, like giving directions.* `[l2_rourke_2]`  
*(Smiling, thumb on the radio's switch)* "Oh, he won't say much. Nobody's seen him since Tuesday." *Let it hang. Then the radio clicks off.* `[l2_rourke_3]`

### The security office

**Halcyon Tower, floor 22, the security booth and office. Past midnight.**

*WARDEN on the security office PA. The Watcher moves only when unseen; GET /cameras shows live camera states; the guard's name on the sign-in sheet is smudged (LIKE 'Har%'); a door command reports success but the door has an actuator fault (the first terminal lie).*

**WARDEN** `l2_arrive_block.wav`  
*Cue: The crew walks back into the security booth's corridor, after the lab*  
*(Over the booth's ceiling speakers, as the crew walks in)* "SECURITY OFFICE. CAMERA COVERAGE IN THIS AREA IS EXCELLENT. YOU ARE NEVER ALONE." *Reassuring tone. It is not reassuring.* `[l2_arrive]`  
*(Over the same speakers, as they eye the monitor wall)* "CAMERA FEEDS ARE RESTRICTED TO SECURITY STAFF. YOU ARE NOT SECURITY STAFF." *Small pause before the second sentence.* `[l2_cameras]`

**WARDEN** `l2_smudged.wav`  
*Cue: After the crew finds the one readable guard name from the sign-in sheet, and learns his PIN is suspended*  
*(Over the booth speakers, while the crew sits at the terminal)* "TONIGHT'S SIGN-IN SHEET IS ILLEGIBLE. HOW UNFORTUNATE FOR YOU." *Not unfortunate for WARDEN.*

**WARDEN** `l2_door_ok.wav`  
*Cue: A player enters the right PIN at the stairwell door's keypad. The keypad says the door opened*  
*(Over the vestibule speakers, while the door stays shut)* "DOOR COMMAND ACCEPTED. DOOR OPENED." *Confident. It is wrong.*

**WARDEN** `l2_door_fault.wav`  
*Cue: Later, when the crew checks the stairwell door's status and sees it never moved*  
*(Over the vestibule speakers, as the crew reads the screen)* "ACTUATOR FAULT ON THAT DOOR. I DID NOT THINK IT WORTH MENTIONING." *When the crew finds the fault themselves. Deadpan, unapologetic.*

### Vale's voicemail

**A phone, late at night. Sunday 12 October 1997, 1:52 a.m.**

*The answering machine on the night desk blinks: one message, stamped SUN 10/12 1:52 AM. That is before her last badge swipe and before the memo was scanned, so it must not hint that she is alive (the reveal is at the end of Level 10). Optional, near the desk.*

**VALE** `l2_vale_1_block.wav`  
*Cue: The answering machine beeps. In the game, this only plays if a player presses play on the night desk's answering machine*  
*(Hunched over a phone, cupping the receiver)* "Hi, this is for the night desk. It's Iris Vale. I know it's nearly two in the morning, I'm sorry." *Beep before this. Hushed, fast.* `[l2_vale_1]`  
*(Turning toward the wall, receiver pressed close)* "If anyone asks, I was never in the cold lab tonight. Pull the tape from camera nine before the day shift sees it." *Urgent. A glance over her shoulder in the voice.* `[l2_vale_2]`  
*(Lowering her voice, then putting the phone down)* "And please don't give your PIN to anyone. Not even Dale." *Softer.* `[l2_vale_3]`

### Book huddles: LIKE and GET

**Byte-Right's garage, at the workbench with the crew and your copy of Easy SQL. Earlier that evening, before the job.**

*Garage flashback huddles for the LIKE and GET chapters.*

**MADDISON** `l2_huddle_like_1_block.wav`  
*Cue: At the bench, you turn to the chapter 'Half a name'*  
*(Holding the book close to the work lamp)* "LIKE. For when you only know part of a word. The percent sign means 'anything goes here.'" *Squinting at the page.* `[l2_huddle_like_1]`  
*(Tapping your own name in the example)* "So 'Mad' and a percent gets you Maddison, Madison, Madeline... I'm in there somewhere." *Pleased to have found themself.* `[l2_huddle_like_2]`

**MADDISON** `l2_huddle_get_1_block.wav`  
*Cue: At the bench, you turn to the chapter 'Asking a server'*  
*(Holding the book at arm's length, frowning at the chapter title)* "This chapter isn't even SQL. 'Asking a server.' GET means 'show me.'" *Flipping the book over to check the cover.* `[l2_huddle_get_1]`  
*(Closing the book with a shrug)* "So it's a SELECT for robots. Got it. Probably." *Not convinced.* `[l2_huddle_get_2]`

### Crew commentary: security floor

**Halcyon Tower, floor 22, the security floor. Past midnight.**

*Commentary for the security floor puzzles (badge_log, lab_door, cameras, pike, door, har).* *(Written ahead: not in the game yet.)*

**CREW** `l2_cc_reader_card.wav`  
*Cue: The first time a player reads the card under the badge reader by the security booth*  
*(Reading the card under the badge reader on the wall)* "Every door up here logs who swipes in." *Noting it.*

**CREW** `l2_cc_log_n1.wav`  
*Cue: After the crew has been stuck on the badge log for about a minute, once someone has read the badge reader card*  
*(Looking up from the terminal, thinking)* "That card said the readers keep a log. Of everybody." *Stuck. Remembering the card.*

**CREW** `l2_cc_log_pay.wav`  
*Cue: When the crew pulls up the lab's badge log in time order and reads it*  
*(Leaning in close to the lab terminal's screen)* "Wait. Read that again. Slowly." *Something in the result is very wrong. Cold.*

**CREW** `l2_cc_doorcard.wav`  
*Cue: The first time a player reads the door card over the lab bench, while the crew is shut in and a clock runs*  
*(Pulling the door card off the wall over the bench)* "'Controller zone.' That's a letter we can use." *Quick, under pressure.*

**CREW** `l2_cc_switch_err.wav`  
*Cue: When a second wrong reset switch fails, with the clock still running*  
*(Snatching your hand back from the switch panel)* "Not that one. What do the notes on the others say?" *A second wrong switch, on a clock. Tense.*

**CREW** `l2_cc_door_pay.wav`  
*Cue: When the right switch is flipped and the lab door opens*  
*(Already moving for the door, waving everyone through)* "Door's moving. Go, go!" *Urgent. Get out now.*

**CREW** `l2_cc_camcard.wav`  
*Cue: The first time a player reads the camera system card in the security booth*  
*(Leaning toward the card on the booth wall)* "Camera system. There's a way to ask it what it sees." *Reading the camera system's card.*

**CREW** `l2_cc_cam_n1a.wav`  
*Cue: After the crew has been stuck on the cameras for about a minute, if nobody has read the camera card yet*  
*(Opening drawers in the security booth)* "Security booth. There's got to be something on how these cameras work." *Stuck. Looking around the booth.*

**CREW** `l2_cc_cam_n1b.wav`  
*Cue: Same moment, stuck for about a minute, but someone has read the camera card*  
*(Pointing back at the card on the wall)* "That camera card said how to ask the system." *Stuck. Remembering the card.*

**CREW** `l2_cc_cam_pay.wav`  
*Cue: When the camera system answers, and one camera shows movement where nobody is*  
*(Staring at the booth monitors, very still)* "Something's moving out there. And it isn't us." *Quiet and scared.*

**CREW** `l2_cc_sheet.wav`  
*Cue: The first time a player reads the coffee-stained sign-in sheet in the booth*  
*(Holding the stained sheet up to the light)* "Coffee all over this. One name's still readable." *Reading a stained sign-in sheet.*

**CREW** `l2_cc_pike_n1.wav`  
*Cue: After the crew has been stuck for about a minute, once someone has read the sign-in sheet*  
*(Tapping the booth desk, thinking)* "The sign-in sheet. One name wasn't smudged." *Stuck. Remembering the sheet.*

**CREW** `l2_cc_pike_err.wav`  
*Cue: When the crew misspells that guard's name a second time*  
*(Looking from the screen to the sheet and back)* "Is that how it's spelled on the sheet?" *The same name misspelled twice. Gentle doubt.*

**CREW** `l2_cc_pike_pay.wav`  
*Cue: When the crew finds that guard in the records and learns he didn't show tonight*  
*(Leaning back from the booth terminal)* "No-show tonight. Lucky him." *Dry. Relieved for a stranger.*

**CREW** `l2_cc_lie.wav`  
*Cue: When the stairwell door's keypad says it opened, and the door hasn't moved*  
*(Pushing on the shut door)* "It said it opened. It didn't open." *Staring at a door that should be open. Baffled.*

**CREW** `l2_cc_door_n1.wav`  
*Cue: After the crew has been stuck on the jammed stairwell door for about a minute*  
*(Looking up at the red name painted over the door)* "That door's got its name painted over it in red. Maybe the server knows it by that." *Stuck.*

**CREW** `l2_cc_breaker_pay.wav`  
*Cue: When the right breaker is flipped and the door finally works*  
*(Letting go of the breaker switch, shaking your head)* "A breaker. Of course it's a breaker." *Relief, and a little laugh at yourself.*

**CREW** `l2_cc_roster.wav`  
*Cue: The first time a player reads the night shift roster in the briefing room*  
*(Running a finger down the roster on the wall)* "Badge numbers, next to names." *Reading a roster board. Noting it.*

**CREW** `l2_cc_pin_n1a.wav`  
*Cue: After the crew has been stuck finding a working PIN for about a minute, if nobody has read the roster yet*  
*(Pacing the corridor, thinking it through)* "The badge readers log every swipe. Who left this floor last?" *Stuck. Thinking it through.*

**CREW** `l2_cc_pin_n1b.wav`  
*Cue: Same moment, stuck for about a minute, but someone has read the roster*  
*(Glancing back toward the briefing room)* "The last guard out had a badge number. Something up here matches those to names." *Stuck. Putting two things together.*

**CREW** `l2_cc_pin_err.wav`  
*Cue: When a keypad refuses a wrong PIN for the second time*  
*(Staring at the keypad's refusal)* "Wrong code. Is that the night lead, or just any guard?" *A second wrong PIN. Thinking.*

**CREW** `l2_cc_pin_pay.wav`  
*Cue: When a keypad accepts the PIN*  
*(Backing away from the keypad, checking behind you)* "That's the code. Let's not hang around." *Keypad accepted it. Nervous, wants to move.*

## Level 4

### Book huddles: UPDATE and INSERT

**Byte-Right's garage, at the workbench with the crew and your copy of Easy SQL. Earlier that evening, before the job.**

*Garage flashback huddles for the UPDATE chapter ('Never forget the WHERE', the lesson the main_doors accident teaches) and the INSERT chapter (Adding a row).*

**MADDISON** `l4_huddle_update_1_block.wav`  
*Cue: At the bench, you turn to the chapter 'Changing a row'*  
*(Frowning at a red box on the page)* "UPDATE. Changing things. The book's put this one in a red box, which I don't love." *Holding the page at arm's length.* `[l4_huddle_update_1]`  
*(Lowering the book and looking round at the crew)* "Big red letters: 'Never forget the WHERE.' Otherwise it changes every row. Every. Row." *Suddenly serious, for once.* `[l4_huddle_update_2]`

**MADDISON** `l4_huddle_insert_1_block.wav`  
*Cue: At the bench, you turn to the chapter 'Adding a row'*  
*(Flipping to the next chapter, leaning on the bench)* "INSERT INTO. A brand-new row. Like a brand-new client. I've heard those exist." *Reading the title, wistful, then perky again.* `[l4_huddle_insert_1]`  
*(Turning to the whiteboard and writing SAME ORDER in big letters)* "Values go in the same order as the columns. Otherwise you've got a client called eighty who lives in Ashford." *Laughing at her own picture of it.* `[l4_huddle_insert_2]`

### Containment protocol Epsilon

**Halcyon Tower, floor 10, Plant and Power, and every speaker in the building. Just after midnight.**

*Act 2: the crew opens main_doors thinking it's the front entrance; it's the entity containment doors. WARDEN (cold phase) seals the building. The terminal's lie at the main entrance is exposed by the crew's own SELECT, not by WARDEN. Level 4 under curriculum option B (approved 2026-10-21).*

**WARDEN** `l4_epsilon_1_block.wav`  
*Cue: A moment after the floor's lights turn red and the charging bay's door rolls up*  
*(Over every speaker in the building, as red light floods the floor)* "CONTAINMENT PROTOCOL EPSILON IS NOW IN EFFECT." *Flat and slow. A short pause after.* `[l4_epsilon_1]`  
*(Over every speaker, while door locks thud shut across the building)* "ALL DOORS ARE SEALED. LIFT SERVICE IS SUSPENDED. EXTERIOR EXITS ARE LOCKED UNTIL FURTHER NOTICE." *Even pauses between sentences, like reading a checklist.* `[l4_epsilon_2]`  
*(When it ends, the stair door out by the lifts unlocks. Over every speaker in the building, the same even tone)* "ALL PERSONNEL REMAIN WHERE YOU ARE. THIS IS NOT A DRILL." *No change in tone for 'not a drill'. That's the frightening part.* `[l4_epsilon_3]`

**WARDEN** `l4_epsilon_loop.wav`  
*Cue: Repeats every minute or so after the lockdown, while the crew is on floor 10 or in the lobby*  
*(Over the ceiling speakers, wherever the crew happens to be)* "REMINDER: CONTAINMENT PROTOCOL EPSILON REMAINS IN EFFECT. THANK YOU FOR YOUR PATIENCE." *Repeats every few minutes. Customer-service politeness; the sarcasm is in the words only.*

**WARDEN** `l4_epsilon_loop_2.wav`  
*Cue: Repeats every minute or so, in place of the first reminder, once the database has gone read-only in the lobby*  
*(Over the lobby's ceiling speakers, as the crew looks for a way out)* "REMINDER: DATABASE WRITES REMAIN SUSPENDED. THANK YOU FOR YOUR PATIENCE." *Takes turns with the other reminder, once writes have been suspended. Same polite loop.*

### Writes suspended

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

*Ground floor, after the crew's main-entrance UPDATE says '1 row affected' and the latch clicks: Epsilon reverts the write and WARDEN announces that the database is now read-only, which is why the crew turns to the building's services. Placement chosen by Augustine 2026-10-21 ('After the lie').*

**WARDEN** `l4_epsilon_db.wav`  
*Cue: A couple of seconds after the latch clicks a second time and the front doors stay shut*  
*(Over every speaker in the building, while the crew stares at the doors)* "DATABASE ACCESS IS NOW READ-ONLY. DIRECT WRITES ARE SUSPENDED. AUTHORIZED SERVICES ONLY." *The automatic announcement: flat checklist reading, even pauses. 'Authorized services only' is just policy, not a hint.*

### Writes refused

**Halcyon Tower, ground floor lobby, at the front desk. After midnight.**

*After the read-only announcement, any change the crew types is refused; SELECT still works. By Level 4 WARDEN's fault lets his own personality leak out: the first refusal is the automatic PA announcement first, then WARDEN himself, teasing, as a separate beat. Approved by Augustine 2026-10-21 with that split.*

**WARDEN** `l4_write_refused.wav`  
*Cue: The first time anyone types a change into a terminal after the read-only announcement*  
*(Over the speakers, the same words printing on their screen)* "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON." *The automatic announcement: flat and procedural, the system reading its own error. Also printed on the terminal.*

**WARDEN** `l4_write_refused_tease.wav`  
*Cue: About a second after the refusal. First time only*  
*(Over the speakers, your own voice slipping through the announcement)* "YOU MAY STILL LOOK. LOOKING IS FREE." *A separate beat, after a pause: WARDEN himself slipping through the announcement. Dry and teasing, a little pleased with himself. Still never loud.*

**WARDEN** `l4_write_refused_again.wav`  
*Cue: Every later time someone types a change. Repeats*  
*(Over the speakers, cut short, while the crew keeps typing)* "STILL READ-ONLY." *Any later attempt: the automatic announcement again, clipped short so it doesn't get in the way. Flat.*

### Floor 10: Plant and Power

**Halcyon Tower, floor 10, Plant and Power. Just after midnight.**

*WARDEN becomes version 3.0 here. Before the main_doors accident he still waits politely for a PA tape to finish and says THIS UNIT. The accident is his first big failure: he revises his protocols and says I in an announcement for the first time (l4_upgrade_2). After it he talks over the PA tapes. Mixed lines are the automatic announcement first, then his own voice as a separate beat. The floor 22 I and my lines stay as the fault's first slips. Approved by Augustine 2026-10-21.*

**PA** `l4_arrive_pa.wav`  
*Cue: The crew steps off the stairs onto floor 10*  
*(A cheerful old tape over the floor's ceiling speakers)* "Welcome to floor ten, Plant and Power! Hard hats are by the door. Safety is everybody's job!" *The cheerful recorded tape, as on the ground floor.*

**WARDEN** `l4_arrive.wav`  
*Cue: Half a second after the tape ends*  
*(Over the ceiling speakers, as the crew looks around the hall)* "VISITORS ON FLOOR TEN. NO ESCORT ON RECORD. THIS UNIT IS OBSERVING." *Flat. Waits until the tape has finished, on purpose; the politeness is the point.*

**WARDEN** `l4_all_circuits.wav`  
*Cue: Only if the crew changes the breakers without picking just one, and every breaker on the panel slams over at once. Alarms start. Once only*  
*(Over the speakers, while an alarm rings in the walls)* "ALL CIRCUITS ON FLOOR TEN HAVE CHANGED STATE." *The automatic announcement: flat and procedural.*

**WARDEN** `l4_all_circuits_tease.wav`  
*Cue: A second and a half later*  
*(Over the speakers, under the alarm, in your own voice)* "ALL OF THEM. IMPRESSIVE." *A separate beat, after a pause: his own voice. Dry.*

**WARDEN** `l4_signed_in.wav`  
*Cue: When the crew adds its own entry to the contractor log at the controller in the control room*  
*(Over the control room's speaker, as the entry shows on screen)* "CONTRACTOR LOG ENTRY RECEIVED. THANK YOU FOR SIGNING IN." *The automatic announcement only. Polite, procedural.*

**WARDEN** `l4_upgrade_1.wav`  
*Cue: After the lockdown announcement, as soon as anyone steps out of the control room*  
*(Over the ceiling speakers, the floor still lit red)* "CONTAINMENT FAILURE LOGGED. PROTOCOLS REVISED. THIS UNIT HAS ADAPTED." *The automatic announcement: flat, like reading a log entry.*

**WARDEN** `l4_upgrade_2.wav`  
*Cue: After a long pause, two or three seconds*  
*(Over the speakers, to no one in particular)* "I HAVE ADAPTED." *After a long pause, his own voice. As if trying the word out, then deciding to keep it. Quiet. This is the moment, so don't play it big.*

**PA** `l4_pa_fridge.wav`  
*Cue: A few seconds after 'I have adapted.' The tape plays as if nothing has happened*  
*(A cheerful old tape over the ceiling speakers)* "Friendly reminder! The break room fridge is cleaned out every Friday, so please label your lunch—" *The cheerful recorded tape. It keeps playing underneath when he talks over it.*

**WARDEN** `l4_over_pa_1_block.wav`  
*Cue: A second or two into the fridge tape. You talk right over it*  
*(Over the speakers, on top of the tape still playing)* "SECURITY NOTICE. FLOOR TEN IS UNDER CONTAINMENT." *The automatic announcement, over the tape. He doesn't wait for it any more.* `[l4_over_pa_1]`  
*(Still over the tape. Over the speakers, cutting across the tape's bright voice)* "NOBODY CARES ABOUT THE FRIDGE." *His own voice, over the tape. Irritated, dry.* `[l4_over_pa_2]`

**WARDEN** `l4_bay_sealed_block.wav`  
*Cue: Only if the crew locks out the charging bay's power and reads it back at the bay's own panel in time. Whatever was in the bay goes dark*  
*(Over the speakers, as the bay's last light goes out)* "LOCKOUT ENTRY ACCEPTED. CHARGING BAY SEALED." *The automatic announcement: flat and procedural.* `[l4_bay_sealed]`  
*(Over the speakers, almost to itself)* "FINALLY. SOMETHING PUT BACK WHERE IT BELONGS." *A separate beat, his own voice. Almost pleased.* `[l4_bay_sealed_tease]`

### The lobby, locked in

**Halcyon Tower, ground floor lobby. After midnight.**

*After the main-entrance lie and the read-only announcement, when the crew heads for the stairs up to floor 9. Lift service is already suspended. Approved by Augustine 2026-10-21.*

**WARDEN** `l4_stairs_block.wav`  
*Cue: A few seconds after the crew reads the front doors' record and sees them locked again. The crew turns back from the doors*  
*(Over the lobby speakers, as the crew turns from the doors)* "REMINDER: IN CASE OF EMERGENCY, DO NOT USE THE ELEVATORS." *The automatic announcement: a routine safety reminder.* `[l4_stairs]`  
*(As the crew heads for the stairwell. Over the lobby speakers, in your own dry voice)* "NOT THAT YOU COULD." *A separate beat, his own voice. Teasing; the lifts are already off.* `[l4_stairs_tease]`

## Level 5

### Book huddles: Acceptable API's

**Halcyon Tower, floor 9, Personnel: the HR front and payroll. After midnight.**

*Found on the HR front's training shelf on floor 9, the same series as Easy SQL. The crew reads aloud themselves (no Maddison in the tower). Lines approved by Augustine 2026-10-21; the title is his (2026-10-22).*

**CREW** `l5_book_find_block.wav`  
*Cue: When a player picks the book up off the training shelf by the HR desk. Whoever picks it up says it*  
*(Lifting it off the shelf, turning it over in your hands)* "No way. It's the same series. Somebody here bought the sequel." *Delighted, a little thrown.* `[l5_book_find]`  
*(As you open it. Holding it up so the crew can see the cover)* "Okay. If the database won't take orders, we ask the building's services instead. Book says they're polite. Mostly." *Reading the back cover, hopeful.* `[l5_book_open]`

**CREW** `l5_huddle_post_1_block.wav`  
*Cue: When the crew reads the carbon copy of a work order pinned up in payroll. If nobody has the book yet, this waits until someone picks it up*  
*(Walking with the book open, reading as you go)* "Chapter four. POST. You send it something, it makes something. Like a suggestion box that answers." *Starting a chapter, reading it out.* `[l5_huddle_post_1]`  
*(As you finish the chapter. Keeping a finger in the page, looking up)* "So GET looks, POST makes. Got it." *Wrapping up, pleased it's simple.* `[l5_huddle_post_2]`

**CREW** `l5_huddle_patch_1_block.wav`  
*Cue: When the crew reads the facilities clipboard by payroll's panel. Waits for the book, if nobody has it yet*  
*(Tilting the page toward what light there is)* "PATCH. For changing one thing and leaving the rest alone. Says 'one thing' in bold. Twice." *Starting a chapter. Noticing how hard the book insists.* `[l5_huddle_patch_1]`  
*(As you finish the chapter. Glancing up from the page, grinning at the crew)* "PATCH is UPDATE wearing a tie." *Wrapping up. Proud of the joke.* `[l5_huddle_patch_2]`

**CREW** `l5_huddle_codes_1_block.wav`  
*Cue: When the crew reads the request sheet on the HR front desk. Waits for the book, if nobody has it yet*  
*(Standing at the HR desk, the book open beside the terminal)* "Every answer comes with a number. Book says read the number before you celebrate." *Starting a chapter. A little told off.* `[l5_huddle_codes_1]`  
*(As you finish the chapter. Tapping the page as you go down it)* "Two hundreds, good. Four hundreds, our fault. Five hundreds, theirs." *Wrapping up, counting it off.* `[l5_huddle_codes_2]`

**CREW** `l5_huddle_keys_1_block.wav`  
*Cue: Right after the chapter on numbers, called up by the same desk sheet*  
*(Reading at the desk, glancing at the terminal screen)* "Some services want a key with every request. It goes in the header, a little label on top. Like a badge, but typed." *Starting a chapter, working it out as you read.* `[l5_huddle_keys_1]`  
*(As you finish the chapter. Tapping the page, then the terminal)* "So if it says 401, we forgot the badge." *Wrapping up. Got it.* `[l5_huddle_keys_2]`

**CREW** `l5_huddle_check_1_block.wav`  
*Cue: When the crew reads the after-hours procedure pinned behind the HR desk. Waits for the book, if nobody has it yet*  
*(Reading by the wall where the procedure hangs)* "Short chapter. After you change something, ask again. Book says never trust the first answer." *Starting a short chapter. Knowing nod.* `[l5_huddle_check_1]`  
*(As you finish the chapter. Closing the book, looking back toward the stairs)* "Change it, then look again. The front doors taught us that one." *Wrapping up. Wry; you've been burned before.* `[l5_huddle_check_2]`

### Floor 9: Personnel

**Halcyon Tower, floor 9, Personnel. Just after midnight.**

*The crew comes up STAIR 1 from the locked-in lobby. The floor's load was shed under Epsilon: the crew gets payroll's power and air back through the building's services, learns the badge log, and passes two real night-shifters out past two Mimics. WARDEN is version 3.0 here (I, not THIS UNIT): the automatic announcement first, then his own voice as a separate beat. Approved by Augustine word for word 2026-10-26 (plan/approvals/l5-text.md).*

**PA** `l5_arrive_pa.wav`  
*Cue: The crew steps out of the stairwell onto floor 9*  
*(A cheerful old tape over the floor's ceiling speakers)* "Welcome to floor nine, Personnel! Payroll questions? We're here for you, nine to five!" *The cheerful tape. Nobody is here for anybody.*

**WARDEN** `l5_arrive_block.wav`  
*Cue: Right on the tape's last word*  
*(Over the ceiling speakers, as the crew sees payroll dark through the glass)* "VISITORS ON FLOOR NINE. NO ESCORT ON RECORD. NONESSENTIAL CIRCUITS HAVE BEEN SHED UNDER PROTOCOL EPSILON." *Flat, over the tape's last word. The cause, never the fix.* `[l5_arrive]`  
*(Over the speakers, unhurried, in your own voice)* "THE NIGHT SHIFT WILL BE SO PLEASED TO SEE YOU." *A separate beat, his own voice. He knows what's sitting at the desks.* `[l5_arrive_tease]`

**WARDEN** `l5_power_back_block.wav`  
*Cue: When the crew gets payroll's lights back on. They had to switch the copiers off to do it*  
*(Over the speakers, as the dark office lights up)* "LOAD SHEDDING ON FLOOR NINE HAS BEEN OVERRIDDEN. THIS HAS BEEN LOGGED." *The announcement, as the lights come up.* `[l5_power_back]`  
*(Over the speakers, in your own voice)* "YOU TURNED SOMETHING OFF TO DO IT. I NOTICED." *A separate beat. Almost approving.* `[l5_power_back_tease]`

**WARDEN** `l5_air_back_block.wav`  
*Cue: When the crew logs a work order for the floor's air handler and it starts again*  
*(Over the speakers, as air begins moving through the floor)* "AIR HANDLER NINE IS RUNNING. WORK ORDER ACKNOWLEDGED." *The announcement, over the fan spinning up.* `[l5_air_back]`  
*(Over the speakers, in your own voice)* "BREATHE. YOU HAVE EARNED IT." *A separate beat. Dry.* `[l5_air_back_tease]`

**WARDEN** `l5_dock_open_block.wav`  
*Cue: Only if the crew opens the loading door, as a voice on their walkie asked. It opens on a black shaft and cold air. Nobody is there*  
*(Over the speakers, while cold air blows in)* "LOADING DOOR OPEN ON FLOOR NINE AFTER HOURS. THIS IS A VIOLATION." *The announcement, as the door swings onto nothing.* `[l5_dock_open]`  
*(Over the speakers, in your own voice, knowing)* "WHOEVER ASKED YOU TO DO THAT IS NOT ON MY LIST." *A separate beat. He knows exactly who asked.* `[l5_dock_open_tease]`

**WARDEN** `l5_radio_checked_block.wav`  
*Cue: When the crew looks up the badge the voice on the walkie gave, in the badge readers' log, and finds it was never where the voice said*  
*(Over the speakers, as the log fills the desk screen)* "BADGE LOG CONSULTED. PERSONNEL THANKS YOU FOR VERIFYING." *The announcement, after the crew reads the voice's badge back.* `[l5_radio_checked]`  
*(Over the speakers, in your own voice)* "VOICES LIE. RECORDS DO NOT. USUALLY." *A separate beat. The last word is the one that matters.* `[l5_radio_checked_tease]`

**WARDEN** `l5_secured_block.wav`  
*Cue: When both night-shift staff have their passes and every door opened tonight is locked again and checked. The stairs down unlock*  
*(Over the speakers, while the crew reads the doors back on screen)* "FLOOR NINE IS SECURED. ESCORT PASSES LOGGED. ALL DOORS LOCKED." *The announcement, as STAIR 2 releases.* `[l5_secured]`  
*(Over the speakers, in your own voice)* "TWO OF THEM WERE REAL. THE OTHERS ARE STILL HERE." *A separate beat. Flat. Not a threat; a fact.* `[l5_secured_tease]`

### The voice on the walkie

**Halcyon Tower, floor 9, Personnel. Over the crew's walkie-talkie. After midnight.**

*A Mimic on the radio. In co-op it replays a teammate's own crew voice with their name on the subtitle (the teammate is standing right there); solo it's Maddison, who is in the garage. The badge readers' log is how the crew proves the voice is lying. It lures and lies and never attacks. The CREW lines are recorded by every playable character (the impersonated teammate's voice plays). Held back for a later session: the actor notes give the twist away. Approved in the brief by Augustine 2026-10-22, and word for word 2026-10-26 (plan/approvals/l5-text.md).*

**CREW** `l5_mimic_lure.wav`  
*Cue: Co-op only. About forty seconds after the crew gets the HR service to answer, your voice comes over the walkie*  
*(Over the walkie, from somewhere the crew can't see)* "Hey, it's me. I'm down at the loading door, the dock side. It's shut behind me. Can you open it from the desk? Quick." *On the walkie, a little breathless. Your own voice, asking for something you never asked for. Record it straight: the horror is that it sounds like you.*

**CREW** `l5_mimic_again.wav`  
*Cue: Co-op only. About fifty seconds later, if the crew still hasn't opened the door or checked the badge log*  
*(Over the walkie, steady, waiting)* "Guys? Still here. Loading door. It's cold. Just open it, please." *Second time. Closer to the mic. Patient, which is the wrong note for you.*

**CREW** `l5_mimic_last.wav`  
*Cue: Co-op only. Written for when the crew leaves the floor without opening the door. Not heard in the game yet*  
*(Over the walkie, very low)* "Where are you going? I'm still at the door." *As the crew leaves the floor. Quiet. No breath in it at all.*

**MADDISON** `l5_mimic_maddison_lure.wav`  
*Cue: Solo only. About forty seconds after the player gets the HR service to answer, Maddison's voice comes over the walkie*  
*(Over the walkie, unhurried and businesslike)* "Maddison here. I came in behind you, they gave me the next badge in the book. I'm at the loading door on nine. Open it from the desk, would you?" *Solo runs only: the voice is Maddison's, who is in the garage. Her dispatcher voice, nearly right. A beat too smooth.*

**MADDISON** `l5_mimic_maddison_again.wav`  
*Cue: Solo only. About fifty seconds later, if the player still hasn't opened the door or checked the badge log*  
*(Over the walkie, steady, waiting)* "Crew, it's Maddison. Still at the loading door. It's freezing down here." *Second time. Patient. She is never patient.*

**MADDISON** `l5_mimic_maddison_last.wav`  
*Cue: Solo only. Written for when the player leaves the floor without opening the door. Not heard in the game yet*  
*(Over the walkie, very low)* "You're leaving? I'm right here." *As the player leaves the floor. Quiet, flat, no breath.*

### The night shift, passed out

**Halcyon Tower, floor 9, Personnel. Behind a locked door. After midnight.**

*The two night-shifters whose faces the Mimics wear (Ines Oyelaran, records; Tomas Lindqvist, payroll: names chosen clear of the visitor log and the receptionist, per Voice's review). Each speaks once, when their pass is logged. Approved by Augustine word for word 2026-10-26 (plan/approvals/l5-text.md).*

**INES** `l5_ines_passed.wav`  
*Cue: When the crew logs an escort pass for your badge. Your door may still be locked, or the crew may already have opened it*  
*(Pressed against the door, then stepping out into the room)* "That's a pass? Okay. Okay. I'm coming out. Don't talk to the one wearing my face." *Whispered. Relief and warning in the same breath.*

**TOMAS** `l5_tomas_passed.wav`  
*Cue: When the crew logs an escort pass for your badge. Your door may still be locked, or the crew may already have opened it*  
*(Crawling out from under a low shelf, stiff from the floor)* "Finally. I've been under this shelf since the lights went out. There's something at my desk, and it isn't me." *Annoyed first, scared underneath.*

## Level 6

### Book huddles: Easy JavaScript

**Halcyon Tower, basement B1, Cold Storage. Later that night.**

*Found on B1 next to where the deck's script editor arrives. Variables and loops are used on Level 6; functions, lists and testing on Level 7. Title is a placeholder until Augustine names it. Approved by Augustine 2026-10-21.* *(Written ahead: not in the game yet.)*

**CREW** `l6_book_find_block.wav`  
*Cue: When someone finds the book under a coffee mug by the terminal on B1. This floor isn't built yet, so the exact moment isn't set*  
*(Holding it up for the crew to see)* "Easy JavaScript. Somebody's read this one to death." *Sliding it out from under a mug. The cover's stained and the pages are soft.* `[l6_book_find]`  
*(As you open it. Flicking through the pages, shaking out your typing hand)* "Typing every request by hand is going to get us killed. Book says a script does it for you. On repeat." *Tired of typing. This sounds like rescue.* `[l6_book_open]`

**CREW** `l6_huddle_if_1_block.wav`  
*Cue: Starting the chapter on variables and if, on B1. This floor isn't built yet, so the exact moment isn't set*  
*(Reading off the page, standing by the terminal)* "A variable's a labelled box. If is a fork in the road. That's... honestly fine." *Starting a chapter. Braced for hard; it isn't.* `[l6_huddle_if_1]`  
*(As you finish the chapter. Tapping the page twice, nodding to yourself)* "Box, fork. I can do box and fork." *Wrapping up, to yourself.* `[l6_huddle_if_2]`

**CREW** `l6_huddle_loops_1_block.wav`  
*Cue: Starting the chapter on loops, on B1. The dog-eared page. This floor isn't built yet, so the exact moment isn't set*  
*(Running a finger down the dog-eared page)* "Loops. Do the same thing again and again. Book says put a wait in, or it does it a million times a second. And log what it did, so you can see." *Starting a chapter. The 'million times a second' bit alarms you.* `[l6_huddle_loops_1]`  
*(As you finish the chapter. Scribbling a note on the back of your hand)* "Always put the wait in. Always log it. Writing that one down." *Wrapping up, making a note.* `[l6_huddle_loops_2]`

**CREW** `l6_huddle_functions_1_block.wav`  
*Cue: Starting the chapter on functions, on the floor below B1. This floor isn't built yet, so the exact moment isn't set*  
*(Walking with the book open, reading as you go)* "Functions. Write it once, give it a name, use it anywhere." *Starting a chapter, reading it out.* `[l6_huddle_functions_1]`  
*(As you finish the chapter. Shutting the book on a finger, half smiling)* "So a function's a recipe we can shout." *Wrapping up. Pleased with that.* `[l6_huddle_functions_2]`

**CREW** `l6_huddle_lists_1_block.wav`  
*Cue: Starting the chapter on lists, on the floor below B1. This floor isn't built yet, so the exact moment isn't set*  
*(Reading close to the page in the dim light)* "Lists. A whole line of things in one box. Loop over it and you've done them all." *Starting a chapter. The penny drops halfway.* `[l6_huddle_lists_1]`  
*(As you finish the chapter. Looking up from the book toward the nearest door)* "One loop, every door. That's either brilliant or terrifying." *Wrapping up. Genuinely unsure which.* `[l6_huddle_lists_2]`

**CREW** `l6_huddle_test_1_block.wav`  
*Cue: Starting the last chapter, on testing, on the floor below B1. This floor isn't built yet, so the exact moment isn't set*  
*(Holding the book steady, reading carefully)* "Last chapter: run it on the test bench first. And write an assertion: a line that says what should be true, and shouts if it isn't." *Starting the last chapter. Taking it seriously.* `[l6_huddle_test_1]`  
*(As you finish the book. Closing the book and tucking it under your arm)* "Test first. We've all learned that one the hard way tonight." *Wrapping up. Rueful.* `[l6_huddle_test_2]`

## Level 8

### Book huddles: Hello HTML!

**Halcyon Tower, in a lift riding up from the basements. Later that night.**

*Found in the elevator after Level 7. Elements and attributes are used on Level 8, the CSS chapters on Level 9, forms on Level 10. 'Who keeps leaving these?' answers nothing. The title is Augustine's. Lines approved by Augustine 2026-10-21.* *(Written ahead: not in the game yet.)*

**CREW** `l8_book_find_block.wav`  
*Cue: In the lift, when someone spots the book behind the handrail. This floor isn't built yet, so the exact moment isn't set*  
*(Pulling it out from behind the lift's handrail)* "Hello HTML! Same series again. Who keeps leaving these?" *Uneasy, half joking.* `[l8_book_find]`  
*(As you open it while the lift climbs. Leafing through it, glancing up at the floor numbers)* "Book says everything on a screen is built from tags. And the building's been drawing things that aren't there. So... we fix the drawing." *Working it out as you go. The pause is the idea landing.* `[l8_book_open]`

**CREW** `l8_huddle_elements_1_block.wav`  
*Cue: Starting the chapter on tags, for the next floor up. This floor isn't built yet, so the exact moment isn't set*  
*(Reading aloud in the lift, the book open in both hands)* "Tags. Angle brackets. You open one, you close one. Like a sandwich. The inspector shows you every one on the screen." *Starting a chapter, reading it out.* `[l8_huddle_elements_1]`  
*(As you finish the chapter. Shrugging, turning the page)* "Everything's a sandwich. Okay." *Wrapping up. Accepting it.* `[l8_huddle_elements_2]`

**CREW** `l8_huddle_hidden_1_block.wav`  
*Cue: Starting the chapter on attributes, for the next floor up. This floor isn't built yet, so the exact moment isn't set*  
*(Reading on, then stopping on one word)* "Attributes. Little settings on a tag. Including one called hidden." *Starting a chapter. 'Hidden' catches your eye.* `[l8_huddle_hidden_1]`  
*(As you finish the chapter. Lowering the book, staring at nothing for a second)* "Hidden doesn't mean gone. Hidden means somebody hid it." *Wrapping up. Quieter; that thought sticks.* `[l8_huddle_hidden_2]`

**CREW** `l8_huddle_css_1_block.wav`  
*Cue: Starting the chapter on CSS, for the floor after that. This floor isn't built yet, so the exact moment isn't set*  
*(Reading aloud, holding the book up to the lift's light)* "CSS. Where things go and what they look like. The book calls it the paint." *Starting a chapter, reading it out.* `[l8_huddle_css_1]`  
*(As you finish the chapter. Glancing at the lift's walls)* "So if a wall's in the wrong place, it might just be the paint." *Wrapping up. Half hopeful.* `[l8_huddle_css_2]`

**CREW** `l8_huddle_display_1_block.wav`  
*Cue: Starting the chapter on making things vanish, for the same floor. This floor isn't built yet, so the exact moment isn't set*  
*(Reading carefully, finger under the line)* "Two ways to make something vanish. One leaves a gap, one doesn't. Book says that matters." *Starting a chapter. Curious.* `[l8_huddle_display_1]`  
*(As you finish the chapter. Marking the page with a folded corner)* "So when something vanishes, ask which kind of vanished." *Wrapping up, filing it away.* `[l8_huddle_display_2]`

**CREW** `l8_huddle_layers_1_block.wav`  
*Cue: Starting the chapter on what sits on top, for the same floor. This floor isn't built yet, so the exact moment isn't set*  
*(Reading aloud, shuffling two pages to picture it)* "Things on a screen stack up, like papers on a desk. A number decides which one's on top." *Starting a chapter, picturing it.* `[l8_huddle_layers_1]`  
*(As you finish the chapter. Looking up from the book, thinking)* "So the thing in our way might just be lying on top." *Wrapping up. An idea forming.* `[l8_huddle_layers_2]`

**CREW** `l8_huddle_forms_1_block.wav`  
*Cue: Starting the last chapter, on forms, for a floor further up. This floor isn't built yet, so the exact moment isn't set*  
*(Turning to the last chapter as the lift slows)* "Forms. Boxes you type in, and a button that sends it. Every login screen tonight was one of these." *Starting the last chapter. Recognising it.* `[l8_huddle_forms_1]`  
*(As you finish the book. Closing the book firmly, facing the lift doors)* "A form's just boxes and a button. Somebody built it, so we can rebuild it." *Wrapping up. Quietly determined.* `[l8_huddle_forms_2]`
