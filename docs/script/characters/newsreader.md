# Radio newsreader: your lines

A local morning-radio newsreader, reading the third story of the hour.

**How they sound:** Smooth, professional, warm, slightly bored. Calm public-radio delivery with no drama; the flatness is what makes it land.

## Recording

- **Format:** WAV, mono, 48 kHz.
- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.
- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.
- **Silence:** half a second at the start and end of every file.
- **Effects:** none. Record dry; the game adds speakers, radio static and so on.
- **Level:** the loudest part should sit around -3 dB, never clipping.

Send the files back as they are. They go in `audio/voice/newsreader/` in the game.

## Your lines (5)

Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.

### 1. A morning radio news bulletin. The third story of the hour.

- [ ] `l2_news_1.wav`  
  "Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems."  
  *Steady, mid-bulletin.*
- [ ] `l2_news_2.wav`  
  "Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered."  
  *No change in tone.*
- [ ] `l2_news_3.wav`  
  "A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.'"  
  *A slight shift for the quote: reading it, not acting it.*
- [ ] `l2_news_4.wav`  
  "Byte-Right's only office, a rented garage, was found empty. The crew has not been seen since."  
  *A beat before the second sentence.*
- [ ] `l2_news_5.wav`  
  "Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather."  
  *Brightening for the weather. The game cuts the audio on 'weather'.*
