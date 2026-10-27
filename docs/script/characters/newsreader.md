# Radio newsreader

*Your script for Null & Void: 7 lines.*

## Who you are

A local morning-radio newsreader, reading the third story of the hour.

**Background.** A local morning radio newsreader, years into the job. Calm, practised and slightly bored, reading the news between the traffic and the weather.

**Tonight.** It's the next morning, and the third story of the hour is what happened at Halcyon Tower overnight. This only plays if the crew doesn't make it out.

**The people around you.** None. You're reading copy someone handed you five minutes ago.

**What you look like.** Headphones on, a mug of coffee, a stack of paper on the desk.

**How you sound.** Smooth, professional, warm, slightly bored. Calm public-radio delivery with no drama; the flatness is what makes it land.

**Think of.** Public radio at seven in the morning. The flatness is what makes it land, so don't play the drama.

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

Send the files back as they are. They go in `audio/voice/newsreader/` in the game.

## Scene 1: The news (if the crew dies)

**A kitchen, Friday morning, 17 October 1997. A radio is on.**

> You're reading the local morning news on the radio. This is the third story of the hour. In the game it plays over a newspaper lying on a kitchen table. Keep it smooth and even, like any other story.

**[ ] `l2_news_1.wav`**  
**Cue:** Only if the whole crew is knocked out on the security floor. The screen goes black, a newspaper fades in on a kitchen table, and the radio begins.  
*(At the studio mic, reading from the page. Heard on a kitchen radio)*  
**NEWSREADER:** "Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems."  
*How to say it:* Steady, mid-bulletin.

**[ ] `l2_news_2.wav`**  
**Cue:** Straight after.  
*(Reading on from the page, same steady pace)*  
**NEWSREADER:** "Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered."  
*How to say it:* No change in tone.

**[ ] `l2_news_3.wav`**  
**Cue:** Straight after.  
*(Glancing down to find the quote)*  
**NEWSREADER:** "A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.'"  
*How to say it:* A slight shift for the quote: reading it, not acting it.

**[ ] `l2_news_4.wav`**  
**Cue:** Straight after.  
*(Reading on, one finger on the line)*  
**NEWSREADER:** "Byte-Right's chief executive, Maddison Kowalski, was arrested at the Halcyon tower before dawn, trying to force her way inside."  
*How to say it:* Even, a touch of interest.

**[ ] `l2_news_6.wav`**  
**Cue:** Straight after.  
*(Reading the quote off the page)*  
**NEWSREADER:** "Ms. Kowalski told officers, quote, 'They were framed! They didn't do it!'"  
*How to say it:* Reading the quote flat, not acting it. Then a beat.

**[ ] `l2_news_7.wav`**  
**Cue:** Straight after.  
*(Squaring the pages, pausing)*  
**NEWSREADER:** "Halcyon declined to comment. The crew has not been seen since."  
*How to say it:* Neutral. A small pause after.

**[ ] `l2_news_5.wav`**  
**Cue:** Straight after. The last line before the weather.  
*(Reaching for the weather sheet)*  
**NEWSREADER:** "Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather."  
*How to say it:* Brightening for the weather. The game cuts the audio on 'weather'.
