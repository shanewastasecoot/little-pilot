# Installing Little Pilot on the Steam Deck

1. Switch the Deck to **Desktop Mode** (Steam button → Power → Switch to Desktop).
2. Unpack this folder somewhere you'll keep it, for example `~/LittlePilot-builds/`.
3. Check the download (optional): in a terminal in this folder run
   `sha256sum -c LittlePilot.x86_64.sha256` — it should say `OK`.
4. Make sure the game can run: right-click `LittlePilot.x86_64` → Properties →
   Permissions → tick "Is executable" (or run `chmod +x LittlePilot.x86_64`).
5. Add it to Steam: in Steam (Desktop Mode) choose **Games → Add a Non-Steam Game
   to My Library**, browse to `LittlePilot.x86_64` and add it.
6. Switch back to **Game Mode**; Little Pilot is in your library under Non-Steam.

Saves are kept in `~/.local/share/godot/app_userdata/Little Pilot/`, so replacing
the game file with a newer version keeps your child's progress.

`CREDITS.md` lists everyone whose free assets the game uses.
