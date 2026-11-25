# Little Pilot ✈️

A relaxing 3D flying sandbox for young children, built with Godot 4.

Little Pilot lets a small child fly a little plane around a bright, friendly world of islands, land anywhere and walk about. Failure is quick, silly and never punishing: crashing and a friendly-scary dragon are on by default, but a crash is a bonk or a splash and the plane is back on the runway in under two seconds with nothing lost (parents can turn both off). There are no timers and nothing to lose. The child flies wherever they like, finds landmarks, collects floating stars, delivers parcels and visits buildings.

---

## Project Overview

| | |
|---|---|
| **Genre** | Casual 3D flight / exploration sandbox |
| **Players** | 1 (local co-op is a future idea) |
| **Session length** | 5–20 minutes, whenever the child wants |
| **Monetisation** | None. Hobby project, no ads, no in-app purchases |
| **Online features** | None. Fully offline, no accounts, no data collection |
| **Status** | After v1.6.0 (in pull requests): walk into the post offices, the city's houses and a hat shop (spend stars on 12 hats); the world reacts to honks, low passes and her cheering (sheep, birds, townspeople, the boat, the whale, penguins, dinosaurs), honks echo in the mountains, a moment under the sea after a splash, take-off dust, a parent volume cap and in-game credits. v1.6.0 released (her house: walk in through the front door, two floors with a family living their own lives, Sophia's bedroom with colours she chooses, meals from the fridge to eat at the table, TVs, beds to lie in and a fenced garden; mermaid mail by parachute drop; townspeople in her character's style; the dragon's treasure for her trophy shelf; the plane can be called from anywhere nearby); v1.5.0 added a new player character on a KayKit base (a toon look, 4 hairstyles and 5 original outfits: pilot, princess, astronaut, superhero and a dino costume) and deliveries (pick up parcels at three post offices and carry them on foot or by plane to people around the main island and on four other islands); v1.4.0 added landing anywhere, getting out to walk, and the character screen; v1.3.0 added the growing city; v1.2.0 added the dragon and Dragon Peak; v1.1.0 added crashing, paint, barrel rolls, the city, volcano and Mermaid Lagoon |

## Target Audience

The primary player is a **4-year-old child**. That one fact drives most design decisions:

- **Reading is optional.** Menus and feedback use icons, colours, sounds and animation. Text is only for the parent.
- **Fine motor skills are still developing.** One stick does almost everything. Button presses never punish; choices (colours, meals, hats) are made on purpose with a picture menu, never by walking past something.
- **Attention spans are short.** The plane is flying within seconds of launch. Rewards come often and are easy to see and hear.
- **Frustration ends play.** No game over and no confusing states: a crash costs two seconds and nothing else.
- **A parent is nearby.** Settings and quitting are fine to leave to adults.

The secondary audience is the parent or developer, who should find the project easy to build, run and extend.

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| **Steam Deck** | ✅ Primary target | Native Linux x86_64 build, added as a non-Steam game. 1280×800, kept at 90 FPS everywhere (the OLED panel's refresh rate), Mobile renderer. |
| **Linux (desktop)** | ✅ Supported | Same build as the Steam Deck. Used for day-to-day development. |
| **Windows** | 🔜 Future | Godot exports it with little extra work. Needs controller testing. |
| **iPad** | 🔜 Future | Needs touch controls, a Mac with Xcode, and an Apple Developer account for installs that last longer than 7 days. |

## Core Gameplay Features

- **Gentle arcade flight.** The plane always moves forward and levels itself. Take off yourself from a long runway; bump into something and it's a soft bonk (or a splash and a moment under the sea) and back to the runway. **Land anywhere:** come down gently onto flat ground on any island (hold slow to flare and brake), roll to a stop and park; boost to take off again. Windsocks mark landing meadows on the bumpier islands. **Get out and walk:** parked anywhere, press **Y** to climb out and explore on foot (left stick walks, further push = faster; **B** sprints, **A** jumps, right stick turns the camera); walk back to the plane and press **Y** to get in (hold **Y** to call it when it's far; **X** on foot makes her cheer, and people nearby cheer back). You walk as your own character (KayKit Adventurers base, CC0, with a toon look: 4 hairstyles and 5 original outfits: pilot, princess, astronaut, superhero and a dino costume), made on a picture-only screen the first time you press Start (LB/RB change tab, left/right pick, right stick spins your character, A done) and changeable any time from the pause menu (orange person button). Parents can switch crashing off for the uncrashable mode, where the plane steers away from the ground, water and buildings on its own.
- **Four aircraft:** a vintage **biplane** (she sits in its open cockpit), a high-wing **light plane**, the **seaplane** (the light plane on floats) and a **trainer jet**, each in 8 paint colours (D-pad), with wingtip vapour in hard turns, plus **barrel rolls** (X in the air). Right-stick click changes the camera: close, far, or the **cockpit view** with real-looking instruments (airspeed, artificial horizon, altimeter, compass); **L2** slows down and lands.
- **A world of islands to explore** (about 9 km across):
  - **Main island:** airport and hangar, snowy mountains with a valley, pine forest, farm with animals, wind turbines, lighthouse, and a **city** (5×5 blocks) with skyscrapers, construction cranes, a park and a big turning **Ferris wheel**
  - **Palm Island**, **Volcano Island** (erupts with fire, smoke and ash), and a giant **rainbow** to fly through
  - **Ice Island** (penguins, igloos), **Dino Island** (animated dinosaurs), **Castle Island**, **Town Island** (hot-air balloons)
  - **Mermaid Lagoon**: a big ring-shaped atoll with a rock arch to fly through, coral under a turquoise lagoon, and a giant clam with a pearl
  - **Dragon Peak** on a new northern headland (the main island is bigger now): a dark, ember-streaked mountain with the **dragon's cave** at its foot, full of glowing gold
  - 15 **islets** with palms, seals, crabs and three more **mermaid coves**; the mermaids turn and wave as you fly past; dolphins, a whale, a sail boat and a pirate ship at sea
- **220 floating stars** in trails that lead from place to place, with a star jar and celebrations. Every 30 stars the city throws a **fireworks party** (an optional arrow and a 30 s countdown point the way).
- **The dragon:** a big fire-breathing dragon sleeps in its cave, then wakes with a roar and patrols the islands. It sees in a cone (hills and mountains hide you), hears you nearby (louder when you boost or honk), gets suspicious before it gives chase, predicts where you're going, searches where it lost you and gives up after a while. It never enters the airport, so the runway is always safe. Its fire and its body blow the plane up (with Crashes off it just chases and roars). The screen edges glow and an arrow points at it while it hunts you. Parents can switch it off or pick Easy, Medium or Hard.
- **A living ocean:** six layered Gerstner waves (swells plus chop) that boats, the pirate ship and the whale really ride, sea spray when you skim the water, depth colour, refraction, glowing crests, lapping shore foam and whitecaps.
- **Her house.** A big cream two-storey house with a pink roof stands south-west of the runway. Walk into the front door to go in: a closer camera looks down into the rooms (walls between the camera and you fade away). Downstairs: the entrance hall; a playroom (a toy box that pops open, a ball to kick); a kitchen (a fridge that opens, a pot of stew bubbling on the stove); a dining room (walk up and the table sets itself); and a living room (a sofa to bounce on, and a trophy shelf waiting for dragon treasure). Up the stairs (the upstairs fades in as you climb, dollhouse style): a landing and four bedrooms with beds to bounce on (stand still on one and she lies down) and light switches to walk into. Up a second flight of stairs from the landing is **her attic**: a cosy reading nook, a toy box and a ball, bookshelves, old boxes, a telescope by the window and fairy lights (round attic windows in the roof outside). One bedroom is hers: stand by the easel or the quilt chest and press **Y** to pick its wall or quilt colour from a picture menu (saved); her own TV, books, mermaid toys and stuffies. Meals come from the fridge (Y, pick one) and are eaten sitting at the table. A family (Mum, Dad, a brother and a sister) lives there, Sim-style. A fenced back garden with swings, a trampoline and a sandpit. There's a hidden star upstairs. Stop the game while inside and you start outside the front door next time.
- **Other buildings.** The post offices (a postie, a conveyor belt, scales, letters to post), every house in the city (an owner, rooms, a hidden star) and the **hat shop** by the airport: try hats on at the mirror and buy them with stars (12 hats, worn everywhere). A sticker from each kind of building on the first visit.
- **The world reacts.** Honk or sweep low and the farm's sheep scatter, birds fly up from the forest, townspeople cheer, the boat toots, the whale spouts, penguins slide and dinosaurs call; honks echo in the mountains and boom in the dragon's cave.
- **Deliveries.** A red beacon shows the nearest post office with a parcel waiting. Walk into the glowing parcel at a post office (airport, city or Town Island) and carry it to someone, on foot or by plane to another island (it rides on top of the plane): a picture of who it's for (and an arrow and a column of light) shows the way; walk up to them and they cheer, with confetti and reward stars. No timers and nothing to lose: the parcel stays with you in the plane, through crashes and restarts, and you can always ignore it and just explore.
- **Follow the leader.** Every few minutes a friendly orange plane pulls up beside her and waggles its wings: follow it round a scenic loop (no timer, it waits for her) for a show in the sky and bonus stars.
- **Loop the loop.** Hold the stick to climb and press X: the plane loops the loop (X alone is still a barrel roll).
- **Seaplane.** A third plane, on floats: land on the sea, bob on the waves, and take off again in a burst of spray.
- **Sailing.** Every major island has a dock. Walk out along the pier at the farm beach and press Y to sail her own boat between the islands; Y at any dock to step off (or to call the boat over if it's somewhere else).
- **Parachute mail.** Some friends live where the plane can't land (a sailor on the boat, a hiker on a mountain top, a pirate captain on the ship): fly low over them and their parcel parachutes down.
- **Sticker book.** A purple book in the pause menu fills itself with pictures of the places, animals and friends she finds; **LB** takes postcards for it.
- **Today, for parents.** A calendar button in the pause menu shows what she did today: stars, parcels, crashes, minutes played and which islands she visited.
- **Sky-writing.** Hold **RB** while flying to leave smoke in the plane's paint colour; it hangs in the sky for about a minute.
- **The airport.** Roll onto the yellow pad by the hangar: the doors slide open, the marshaller waves you in, and the plane gets a wash and fills up with fuel, then rolls back out ready to fly. **Liveries**: a trim colour (X on the plane-select screen) and decals earned with stars (LB / RB): a stripe, a chequered tail, a rescue band, registration letters, a gold star.
- **Landmark discovery.** Every landmark has its own sound and animation the first time you arrive.
- **Gentle generated music**, engine and wind sounds, each plane's own honk (B), quiet sounds of places (birds at the farm, the city, waves, wind in the forest, the volcano, a snoring dragon), and parent settings (music and sound volume, the loudest it ever gets, 30 FPS battery saver, city arrow, delivery arrow, crashes on/off, dragon on/off and difficulty, walking camera, restart the city, credits).
- **Gamepad-first controls** designed for the Steam Deck (Xbox controllers work too).

## Technology Stack

| Area | Choice | Why |
|---|---|---|
| Engine | **Godot 4** (latest stable 4.x, pinned per project) | Free, open source, light on resources, good Linux and Steam Deck support |
| Language | **GDScript** | Simplest workflow, best documented, exports to every target including iOS. C# is not used. |
| Renderer | **Mobile** renderer | Good performance on the Steam Deck, and the same renderer will work on iPad later |
| Version control | **Git + GitHub** | History, backups, issue tracking |
| Large files | **Git LFS** for `.glb`, `.png`, `.wav`, `.ogg` | Keeps the repo fast. Watch GitHub's free LFS quota. |
| 3D modelling | Blender (optional) | Only needed for custom final assets |
| Audio editing | Audacity (optional) | Trimming and normalising sound effects |

## Project Goals

1. **Make a game a 4-year-old can play alone and enjoy**, with no adult help after it starts.
2. **Ship a playable Steam Deck build early** (end of Phase 2) and improve it in small steps.
3. **Keep the scope small enough to finish** as a hobby project.
4. **Keep the project maintainable.** Clear structure, few dependencies, documented decisions.
5. **Use free, properly licensed assets** and record every license.

### Non-Goals

- Realistic flight physics or simulation accuracy
- Online multiplayer, leaderboards or accounts
- Commercial release (it may be reconsidered later)
- Procedurally generated worlds

## Development Philosophy

### Fun over realism
The plane flies the way a child imagines a plane flies. Turning feels swoopy, speed feels exciting, and physics only matters when it makes things feel better.

### Failure is quick, silly and never punishing
Crashing and the dragon are on by default, because she enjoys them: a crash is a bonk with dizzy stars or a splash, and two seconds later the plane is back on the runway with everything kept. There's no stalling, no fuel, no timers, no lives and no game over. Flat ground you can land on never crashes the plane. Parents can turn crashing and the dragon off.

### Easy controls
One stick to fly. Optional buttons only add fun, such as boosting or honking. Wrong inputs do nothing harmful.

### Relaxing exploration
The game has soft colours, gentle music and no pressure. The child decides where to go. The game guides with sparkle and sound, never with commands.

## Repository Documents

| File | Purpose |
|---|---|
| [`README.md`](README.md) | This overview |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | Detailed game design document |
| [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md) | The current plan, in short |
| [`docs/HISTORY.md`](docs/HISTORY.md) | The original roadmap: how the game got here |
| [`docs/STEAM_DECK.md`](docs/STEAM_DECK.md) | Getting a build onto the Deck, parent settings |
| [`docs/ASSET_LIST.md`](docs/ASSET_LIST.md) | Asset notes (the credits themselves are in `resources/credits.json`) |
| [`CREDITS.md`](CREDITS.md) | Every third-party asset, made from `resources/credits.json` |

## Getting Started

### Prerequisites
- **Git** with **Git LFS** (Git for Windows includes LFS. On Linux, install `git-lfs`.)
- **Godot 4.x, standard version** (not .NET). Pinned version: **Godot 4.7.2 stable**. On the Steam Deck: `flatpak install flathub org.godotengine.Godot`.

### Clone

```bash
git lfs install
```

```bash
git clone https://github.com/shanewastasecoot/little-pilot.git
```

### Developer commands
`dev.sh` wraps the common Godot commands (it uses the Flatpak Godot; set `GODOT=/path/to/godot` to override):

| Command | What it does |
|---|---|
| `./dev.sh run` / `./dev.sh run full` | Play in a window / fullscreen |
| `./dev.sh props` | Rebuild the player character's outfit props in Blender (see `docs/characters.md`) |
| `./dev.sh city 12` | Play with the city grown 12 hours ahead (a preview: not saved) |
| `./dev.sh editor` | Open the Godot editor |
| `./dev.sh test` | All headless tests (19 suites): gamepad mapping (Deck + Xbox layout), save robustness, crashes, the dragon, autopilot star run (every star reachable), growing city, landing (every island and islet), walking, player character and character screen, deliveries, her house, the dragon's treasure, post offices, the city's houses, the hat shop, world reactions, credits, and a flight stress test (54 cases across both planes, incl. the fully grown city). Exit code 0 = pass. |
| `./dev.sh check` | Import the project, load every script and scene, and start the game headless for a moment; fails (exit code 1) on any error. Only says "No errors." when everything is clean |
| `./dev.sh export` | Release build to `../LittlePilot-builds/LittlePilot.x86_64` (set `BUILD_DIR=...` to build somewhere else) |
| `./dev.sh credits` | Write `CREDITS.md` from `resources/credits.json` (the one place credits are kept; the credits test fails if they differ) |
| `./dev.sh bench-sim` | Headless: what the simulation costs along a fixed route (airport, grown city, ocean, Dragon Peak): physics and game-logic time per frame (median, 95th percentile) and each system on its own (flight safety, the crowd, the growing city, the dragon), compared with the last run. Runs in CI. Never claims FPS (nothing is drawn). |
| `./dev.sh bench-render` | On screen at 1280×800, Mobile renderer, vsync off: flies the same route twice (cold run, then warm) and reports per area the median and 95th-percentile frame time, the 1 % low and draw calls, plus launch-to-first-controllable-frame; saved to `user://bench/render.json` and compared with the last run. Toggles for one run: `./dev.sh bench-render -- --bench-shadows=2048 --bench-aa=msaa\|ssaa\|both\|none --bench-refraction=off --bench-far-waves=simple --bench-glow=off --bench-crowd=150` |
| `./dev.sh audit-aircraft` | What each aircraft model is made of: node tree, meshes, triangles, materials, animations, and which parts (propeller, wheels, control surfaces, gear, markers) are separate. See `docs/AIRCRAFT_MODELS.md` |
| `./dev.sh run -- --record-playtest` | Debug runs only: keep a local playtest diary (route, crashes, landings, landmarks) in `user://playtests/`. Nothing is ever sent anywhere. |

Press **F3** in game to toggle the debug overlay (FPS, speed, clearance, safety state; **T** flips the tonemapper between Linear and AgX to compare). It's on by default in debug runs and off in release builds. The sky, fog and glow live in `resources/world_environment.tres`: open it in the editor to tune the look live.

### How CI works

"CI" (continuous integration) means GitHub runs checks for you on its own computers, so a
mistake gets noticed even if nobody ran the tests by hand. The recipes are in
`.github/workflows/`.

- **Tests** (`test.yml`) run on every push and every pull request. GitHub downloads the exact
  Godot version this project uses (4.7.2, the plain version, not .NET), fetches the big model and
  texture files from Git LFS (keeping a cache so later runs are quicker), makes sure none of them
  are left as small "pointer" placeholders, and then runs `./dev.sh check` and `./dev.sh test`.
  A green tick on a commit or pull request means everything passed; a red cross means
  something failed. Click it to see which step and why.
- **Release** (`release.yml`) runs when a version tag such as `v1.6.0` is pushed. It first checks
  the tag matches `config/version` in `project.godot` (so a wrong tag can't publish the wrong
  version), then exports the Linux build and attaches
  `LittlePilot-<version>-linux-x86_64.tar.gz` to the GitHub Release. Inside: the game
  (`LittlePilot.x86_64`, ready to run), `CREDITS.md`, `INSTALL.md` (Steam Deck steps) and a
  SHA-256 checksum file to check the download.

When the pinned Godot version changes, update `GODOT_VERSION` in both workflow files and the
version in this README together (the test workflow checks they match).

### Steam Deck
See [`docs/STEAM_DECK.md`](docs/STEAM_DECK.md).

## License

Code is released under the **MIT License** (see [`LICENSE`](LICENSE)). Third-party assets keep their own licenses, recorded in [`resources/credits.json`](resources/credits.json) (shown in [`CREDITS.md`](CREDITS.md) and on the in-game credits screen).
