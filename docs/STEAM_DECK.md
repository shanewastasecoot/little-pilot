# Steam Deck Setup

How to get a Little Pilot build from the development PC onto the Steam Deck.

## Developing on the Steam Deck itself

If Godot is installed on the Deck (Flatpak), you can skip the copy step:

1. In Desktop Mode, run `./dev.sh export` in the repo. This writes `~/LittlePilot-builds/LittlePilot.x86_64`.
2. **First time only:** in Steam (Desktop Mode), choose **Games → Add a Non-Steam Game**, browse to that file and add it.
3. Switch to Game Mode and launch it. Re-running `./dev.sh export` updates the same file, so the shortcut keeps working.

The Linux export templates live in `~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/`. Only `linux_release.x86_64` and `linux_debug.x86_64` are needed.

## One-time setup (development PC)

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Project → Export → Add… → Linux**.
   - Architecture: `x86_64`
   - **Embed PCK:** on (produces a single file)
   - Export path: a folder **outside** the repo, e.g. `../LittlePilot-builds/LittlePilot.x86_64`
3. Commit `export_presets.cfg` so the preset is shared between machines.

## Each new build

### On the PC
1. **Project → Export → Linux → Export Project**. Untick **Export With Debug** for a release build.
2. Copy `LittlePilot.x86_64` to a USB stick, or upload it to a GitHub Release.

### On the Steam Deck
1. Hold the **power** button and choose **Switch to Desktop**.
2. Copy the file to `~/Games/LittlePilot/LittlePilot.x86_64`. Replace the old file if you're updating.
3. **First time only:**
   1. Right-click the file, choose **Properties → Permissions**, and tick **Is executable**.
   2. Right-click the file and choose **Add to Steam**.
   3. In Steam, open the game's **Properties** and rename it to *Little Pilot* if needed.
4. Double-click **Return to Gaming Mode** on the desktop.
5. Launch it from **Library → Non-Steam**.

> Updating only means replacing the file. The Steam shortcut keeps working as long as the path stays the same.

## Controller

- Steam Input gives the game a standard Xbox-style gamepad. No custom layout is needed.
- If the controls behave strangely, open the game's **Controller Settings** in Steam and choose the **Gamepad** template.

## Checking performance

- Press **`...`** (Quick Access), go to **Performance**, and set the **Overlay Level** to 2+ to see FPS.
- Target: **60 FPS** at 1280×800.

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing happens on launch | The file isn't executable (see step 3.1), or the export wasn't Linux x86_64 |
| Black screen | Try the **Compatibility** renderer in an export to test. Report the Godot version. |
| No controller input | Make sure the game is launched through Steam (Game Mode), not from the desktop file manager |
| Save data location | `~/.local/share/godot/app_userdata/Little Pilot/` |
