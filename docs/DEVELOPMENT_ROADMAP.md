# Little Pilot — Development Roadmap

## Planning Assumptions

| Assumption | Value |
|---|---|
| Team | 1 hobby developer |
| Available time | **~6 hours per week** (evenings and weekends) |
| Experience | Comfortable with programming, new or moderate with Godot |
| Assets | Free CC0 placeholder and final packs first. Custom art is optional. |

Estimates below are **hours of focused work**, with calendar weeks at ~6 h/week. Hobby projects usually overrun by 30–50%, so treat these as targets, not deadlines.

| Phase | Effort | Calendar (approx.) |
|---|---|---|
| 1 — Project Setup | 4–6 h | 1 week |
| 2 — Basic Flight | 20–30 h | 3–5 weeks |
| 3 — Plane Selection | 8–12 h | 1.5–2 weeks |
| 4 — Collectibles | 8–12 h | 1.5–2 weeks |
| 5 — Island Environment | 25–40 h | 4–7 weeks |
| 6 — Polish | 15–25 h | 3–4 weeks |
| **Total** | **80–125 h** | **~3.5–5 months** |

## Guiding Practices (All Phases)

- **Playable on the Steam Deck at the end of every phase.** Every phase ends with a build you can play.
- **Playtest with the child** at the end of Phases 2, 4, 5 and 6. Watch without helping. Their confusion is the bug list.
- **Small commits, one feature per branch,** merged to `main` when it works.
- **Placeholders first.** Don't spend time on final art until the gameplay is fun.
- **Track work in GitHub Issues** with one milestone per phase.

---

## Phase 1 — Project Setup

### Objectives
Create a clean, version-controlled Godot 4 project that builds and runs on both Linux desktop and the Steam Deck.

### Goals
- GitHub repository
- Godot setup
- Project structure

### Tasks
- [ ] Create GitHub repository `little-pilot` (private or public)
- [ ] Add `README.md` and `docs/` (`GAME_DESIGN.md`, `DEVELOPMENT_ROADMAP.md`, `ASSET_LIST.md`)
- [ ] Add a Godot `.gitignore` (ignore `.godot/`, `*.import` is **kept**, exports ignored)
- [ ] Configure **Git LFS** and `.gitattributes` for `*.glb *.gltf *.png *.jpg *.wav *.ogg *.blend`
- [ ] Add `LICENSE` (MIT recommended) and an empty `CREDITS.md`
- [ ] Install the latest stable **Godot 4.x** and record the exact version in the README
- [ ] Create the project with the **Mobile** renderer
- [ ] Set the project defaults: 1280×800 window, `canvas_items` stretch mode, `expand` aspect
- [ ] Create the folder structure:
  ```
  little-pilot/
  ├── assets/          # imported art & audio (LFS)
  │   ├── aircraft/
  │   ├── environment/
  │   ├── audio/
  │   └── ui/
  ├── scenes/          # .tscn files
  │   ├── aircraft/
  │   ├── world/
  │   ├── collectibles/
  │   └── ui/
  ├── scripts/         # .gd files mirroring scenes/
  ├── resources/       # .tres data (aircraft stats, etc.)
  ├── docs/
  └── project.godot
  ```
- [ ] Define the input map actions: `fly_up`, `fly_down`, `turn_left`, `turn_right`, `boost`, `slow`, `honk`, `camera`, `look_*`, `pause`
- [ ] Create a "Hello World" main scene (a cube in front of a camera)
- [ ] Set up a **Linux x86_64 export preset** and export a build
- [ ] Copy the build to the Steam Deck, add it as a non-Steam game, and confirm it launches in Game Mode
- [ ] Optional: a GitHub Actions workflow that exports a Linux build on push using a Godot CI image

### Expected Time
**4–6 hours** (~1 week)

### Definition of Done
- [ ] The repository is on GitHub with docs, `.gitignore`, `.gitattributes` (LFS) and a license
- [ ] The project opens without errors in the pinned Godot version
- [ ] The folder structure is in place and committed
- [ ] The test scene runs on Linux desktop **and** the Steam Deck in Game Mode
- [ ] The Steam Deck deployment steps are written down in `docs/STEAM_DECK.md`

---

## Phase 2 — Basic Flight

### Objectives
Build the core of the game: an **arcade flight controller that feels great and cannot crash**, with a smooth chase camera, playable on the Steam Deck controls.

> This is the riskiest phase. If flying isn't fun here, nothing later will fix it. Spend the time to get it right.

### Goals
- Plane controls
- Camera
- Steam Deck support

### Tasks
**Test environment**
- [ ] Greybox test map: a flat ground plane, a few hills (primitives), a few tall pillars, a water plane
- [ ] Simple sky using a procedural `Sky` resource

**Flight controller (`aircraft_controller.gd`)**
- [ ] Kinematic movement: the plane always moves forward at `cruise_speed`
- [ ] Pitch and yaw from the left stick, with automatic visual banking
- [ ] Input smoothing and dead zone
- [ ] Boost and slow down, with speeds clamped (never stops)
- [ ] Auto-level when there is no input
- [ ] Pitch clamp (no loops or inversions)
- [ ] `AircraftStats` resource holding all tuning values as `@export`

**Safety systems**
- [ ] Ground and water avoidance using a downward and forward raycast, with a smooth pull-up
- [ ] Minimum clearance enforced as a hard floor, so the plane can't get through even if smoothing fails
- [ ] Altitude ceiling with a soft level-off
- [ ] World boundary that steers the plane back toward the centre
- [ ] Soft push-away volumes around tall obstacles

**Camera**
- [ ] `SpringArm3D` chase camera with position and rotation smoothing
- [ ] Right-stick look-around with auto-recenter
- [ ] Field of view increases during boost
- [ ] Close and Far camera presets on the camera button

**Steam Deck support**
- [ ] Map all actions to gamepad and keyboard
- [ ] Verify the Steam Input default gamepad template works with no extra config
- [ ] Measure FPS on the Steam Deck using the Performance Overlay

**Validation**
- [ ] "Stress test": hold each stick direction for 60 seconds. The plane must stay safe and look good.
- [ ] Mash every button at once. Nothing breaks.
- [ ] **Child playtest #1**

### Expected Time
**20–30 hours** (~3–5 weeks)

### Definition of Done
- [ ] The plane can be flown around the greybox map with the left stick only
- [ ] The plane **cannot** touch the ground or water, pass through pillars, stall, or leave the map. The stress tests pass.
- [ ] The camera never clips through terrain and never makes sudden jumps
- [ ] Runs at a steady 60 FPS on the Steam Deck
- [ ] The child can fly for 5 minutes without adult help and wants to keep playing

---

## Phase 3 — Plane Selection

### Objectives
Add the second aircraft and a child-friendly way to choose between them that is remembered across launches.

### Goals
- Menu
- Plane switching
- Save selection

### Tasks
- [ ] Create a `fighter_jet.tres` stats resource and tune it (faster, more responsive)
- [ ] Placeholder jet model (a different shape and colour from the prop plane)
- [ ] Refactor the aircraft scene so the model and stats are swappable and the controller is shared
- [ ] **Title screen**: logo, big play button, any button starts
- [ ] **Plane select screen**: two large plane previews (spinning 3D or rendered images), left/right to choose, A to confirm, a sound on every change
- [ ] **Pause menu**: Resume, Change Plane, Quit (hold to confirm)
- [ ] Switch planes at runtime without restarting the world (keep position and heading)
- [ ] `SaveManager` autoload using `ConfigFile` at `user://save.cfg`
- [ ] Save and load the selected aircraft. Fall back to defaults if the file is missing or corrupt.
- [ ] Menus can be fully navigated with the gamepad (focus handling) and keyboard

### Expected Time
**8–12 hours** (~1.5–2 weeks)

### Definition of Done
- [ ] Both aircraft can be flown and feel clearly different
- [ ] The child can pick a plane **without reading** and without help
- [ ] The selected plane is remembered after quitting and relaunching on the Steam Deck
- [ ] Deleting or corrupting `save.cfg` doesn't crash the game. It loads the defaults.
- [ ] Every menu works with the gamepad alone

---

## Phase 4 — Collectibles

### Objectives
Give exploration a purpose by adding floating stars, satisfying collection feedback and a visible counter.

### Goals
- Stars
- Counter
- UI

### Tasks
- [ ] `star.tscn`: mesh, spin and bob animation, glow, `Area3D` with a generous radius
- [ ] Collection effect: particle burst, chime (pitch rises on quick consecutive pickups), star shrinks or pops
- [ ] `StarManager`: tracks collected and total stars, emits signals
- [ ] **Star trail** helper: place stars along a `Path3D` to make level design easy
- [ ] Place ~20 test stars on the greybox map
- [ ] **HUD**: star icon plus count, with a pop animation on increment
- [ ] **Star jar**: a visual fill indicator for non-readers
- [ ] Milestone celebrations (10 / 25 / all) that don't interrupt play
- [ ] "All collected" celebration, then all stars respawn
- [ ] Save the lifetime star total
- [ ] **Child playtest #2**

### Expected Time
**8–12 hours** (~1.5–2 weeks)

### Definition of Done
- [ ] Stars can be collected by flying through them with no precision required
- [ ] Every collection gives clear visual and audio feedback
- [ ] The counter and jar update correctly. The lifetime total persists.
- [ ] The all-stars celebration plays and the stars respawn
- [ ] The child goes after stars **on their own** during the playtest

---

## Phase 5 — Island Environment

### Objectives
Replace the greybox map with the real island: terrain, landmarks and a cohesive low-poly look, while keeping 60 FPS on the Steam Deck.

### Goals
- Terrain
- Landmarks
- Visual improvements

### Tasks
**Terrain**
- [ ] Choose a terrain approach. *Recommended:* sculpt in Blender and import as a mesh, or use the **Terrain3D** plugin. Avoid writing a custom terrain system.
- [ ] Block out the island layout from the GDD (runway, mountains, forest, farm, coast)
- [ ] Terrain material (grass, rock, sand, snow) using vertex colours or splat
- [ ] Ocean plane with a simple stylised water shader
- [ ] Terrain collision for the avoidance raycasts

**Landmarks**
- [ ] Airport runway: tower, windsock, hangar, spawn point
- [ ] Mountains with a fly-through valley
- [ ] Forest using `MultiMeshInstance3D`
- [ ] Farm: barn, fields, fences, animals
- [ ] Lighthouse with a rotating beam
- [ ] Wind turbines with spinning blades and safe push-volumes
- [ ] Boat and/or whale in the ocean
- [ ] Discovery triggers with a unique reaction and sound per landmark

**Visual improvements**
- [ ] `WorldEnvironment`: sky, fog to hide the map edge, tonemapping, gentle glow
- [ ] Directional light and shadow tuning for the Steam Deck
- [ ] Aircraft trails and particles
- [ ] Replace placeholder aircraft with final models
- [ ] Final star placement (~50) in trails leading to landmarks

**Performance**
- [ ] Visibility ranges (LOD) on trees and props
- [ ] Profile on the Steam Deck. Fix anything below 60 FPS.
- [ ] **Child playtest #3**

### Expected Time
**25–40 hours** (~4–7 weeks). This phase depends most on how much is custom-built and how much comes from asset packs.

### Definition of Done
- [ ] All 7 environment areas from the GDD exist and can be reached
- [ ] Every landmark has a discovery reaction
- [ ] Safety systems still work on real terrain and landmarks. Repeat the stress tests.
- [ ] ~50 stars placed, all reachable
- [ ] Steady 60 FPS on the Steam Deck in the heaviest view (over the forest towards the turbines)
- [ ] All assets are recorded in `docs/ASSET_LIST.md` and `CREDITS.md` with licenses

---

## Phase 6 — Polish

### Objectives
Make the game feel finished and joyful through sound, music and full Steam Deck testing, and produce a stable "1.0" build for the child.

### Goals
- Sound effects
- Music
- Steam Deck testing

### Tasks
**Sound effects**
- [ ] Engine loops per aircraft, with pitch following speed
- [ ] Wind loop, louder with speed
- [ ] Star chimes, milestone and celebration jingles
- [ ] Landmark signature sounds
- [ ] Honk sounds per aircraft
- [ ] UI sounds (move, confirm, back)
- [ ] Audio buses (Master / Music / SFX) and volume balancing

**Music**
- [ ] 1–2 looping background tracks (CC0 / CC-BY, credited)
- [ ] Separate, calmer track for the menu
- [ ] Smooth crossfades between menu and gameplay

**Steam Deck testing**
- [ ] Full play session of 30+ minutes on the Steam Deck: FPS, heat and battery drain
- [ ] Suspend and resume (sleep mode) works without a crash or broken audio
- [ ] Controller disconnect and reconnect handled
- [ ] Optional 30 FPS cap setting for battery life
- [ ] Custom Steam library artwork (grid, hero, logo) for the non-Steam game entry
- [ ] Short `docs/STEAM_DECK.md` install guide for reinstalling later

**General polish**
- [ ] Title screen animation and logo
- [ ] Idle hint (animated stick icon after 10 seconds without input)
- [ ] Parent settings screen (volume), reached from pause
- [ ] Fix every bug from the playtests
- [ ] Tag release `v1.0.0` on GitHub with the Linux build attached
- [ ] **Final child playtest**

### Expected Time
**15–25 hours** (~3–4 weeks)

### Definition of Done
- [ ] Every player action has audio feedback. Music loops seamlessly.
- [ ] No crashes or blockers in a 30-minute Steam Deck session, including a suspend and resume
- [ ] Battery life of 3+ hours, or a clear note of the real figure
- [ ] `v1.0.0` release tagged with the build attached
- [ ] **The child asks to play it again** 🎉

---

## After 1.0

Candidates for later milestones, in rough priority order:

1. **Paint colours.** Cheap and very popular with kids.
2. **Additional aircraft** (helicopter, hot-air balloon)
3. **Windows build.** Mostly export and test.
4. **Weather and time of day**
5. **Local co-op split-screen**
6. **iPad port.** Touch controls, Mac and Xcode setup, Apple Developer account.
7. **More maps**
