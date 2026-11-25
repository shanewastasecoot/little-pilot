# Real sounds (optional)

Every sound in the game is made in code (`scripts/core/sfx.gd`). A real recording
replaces one simply by being here with the same name: `honk.ogg` (or `.wav`,
`.mp3`) replaces the "honk" sound, and so on. Looping sounds go in `loops/`
(`loops/prop_engine.ogg`, `loops/amb_birds.ogg`...). If a file is missing, the
made-in-code sound plays, so nothing ever goes silent.

Only CC0 or CC-BY sounds, and add each one to `resources/credits.json`
(then `./dev.sh credits`). Kenney's audio packs are CC0 and a good start
(they need downloading in a browser):

- Interface Sounds: <https://kenney.nl/assets/interface-sounds> (clicks, confirm, back)
- Impact Sounds: <https://kenney.nl/assets/impact-sounds> (bonks, pops)
- Music Jingles: <https://kenney.nl/assets/music-jingles> (jingle, fanfare)
- UI Audio: <https://kenney.nl/assets/ui-audio>
- Sci-fi Sounds: <https://kenney.nl/assets/sci-fi-sounds> (engine-like loops)

## The names

One-shots: `chime`, `ui_move`, `ui_confirm`, `ui_back`, `honk`, `honk_prop`,
`honk_jet`, `jingle`, `fanfare`, `ding`, `echo`, `foghorn`, `whoosh`, `moo`,
`chirp`, `toot`, `splash`, `rumble`, `tropical`, `bells`, `rawr`, `lala`, `boom`,
`whistle`, `pop`, `roar`, `fire`, `explode`.

Loops (`loops/`): `prop_engine`, `prop_boost`, `jet_engine`, `jet_boost`, `wind`,
`amb_birds`, `amb_city`, `amb_waves`, `amb_rumble`, `amb_wind`, `amb_cave`.
