# Little Pilot ✈️

A relaxing 3D flying sandbox for young children, built with Godot 4.

Little Pilot lets a small child fly a cheerful little plane around a bright, friendly world of islands. Nothing can go wrong: the plane can't crash or stall, there are no timers, and the game never ends badly. The child flies wherever they like, finds landmarks, and collects floating stars.

---

## Project Overview

| | |
|---|---|
| **Genre** | Casual 3D flight / exploration sandbox |
| **Players** | 1 (local co-op is a future idea) |
| **Session length** | 5–20 minutes, whenever the child wants |
| **Monetisation** | None. Hobby project, no ads, no in-app purchases |
| **Online features** | None. Fully offline, no accounts, no data collection |
| **Status** | v1.0.0 released; v1.1 (paint, barrel roll, much bigger world, city, mermaids) in progress |

## Target Audience

The primary player is a **4-year-old child**. That one fact drives most design decisions:

- **Reading is optional.** Menus and feedback use icons, colours, sounds and animation. Text is only for the parent.
- **Fine motor skills are still developing.** One stick does almost everything. Button presses never punish.
- **Attention spans are short.** The plane is flying within seconds of launch. Rewards come often and are easy to see and hear.
- **Frustration ends play.** The game has no failure, no game over and no confusing states.
- **A parent is nearby.** Settings and quitting are fine to leave to adults.

The secondary audience is the parent or developer, who should find the project easy to build, run and extend.

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| **Steam Deck** | ✅ Primary target | Native Linux x86_64 build, added as a non-Steam game. 1280×800, kept at 90+ FPS (the OLED panel's refresh rate). |
| **Linux (desktop)** | ✅ Supported | Same build as the Steam Deck. Used for day-to-day development. |
| **Windows** | 🔜 Future | Godot exports it with little extra work. Needs controller testing. |
| **iPad** | 🔜 Future | Needs touch controls, a Mac with Xcode, and an Apple Developer account for installs that last longer than 7 days. |

## Core Gameplay Features

- **Uncrashable arcade flight.** The plane always moves forward, levels itself, and steers or slows away from the ground, water, buildings and the edge of the world on its own.
- **Two aircraft:** a red **biplane** and a zippier blue **jet**, each in 8 paint colours (D-pad), plus **barrel rolls** (X).
- **A world of islands to explore** (about 9 km across):
  - **Main island:** airport and hangar, snowy mountains with a valley, pine forest, farm with animals, wind turbines, lighthouse, and the start of a **city** with skyscrapers and construction cranes
  - **Palm Island**, **Volcano Island**, and a giant **rainbow** to fly through
  - **Ice Island** (penguins, igloos), **Dino Island** (animated dinosaurs), **Castle Island**, **Town Island** (hot-air balloons)
  - 16 **islets** with palms, seals, crabs and four **mermaid coves**; dolphins, a whale, a sail boat and a pirate ship at sea
- **220 floating stars** in trails that lead from place to place, with a star jar and celebrations.
- **Landmark discovery.** Every landmark has its own sound and animation the first time you arrive.
- **Gentle generated music**, engine and wind sounds, honk (B), and parent settings (volume, 30 FPS battery saver).
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

### No failure states
The game has no crashing, stalling, running out of fuel, timers, lives or game over. Whatever the child does, something nice or neutral happens.

### Easy controls
One stick to fly. Optional buttons only add fun, such as boosting or honking. Wrong inputs do nothing harmful.

### Relaxing exploration
The game has soft colours, gentle music and no pressure. The child decides where to go. The game guides with sparkle and sound, never with commands.

## Repository Documents

| File | Purpose |
|---|---|
| [`README.md`](README.md) | This overview |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | Detailed game design document |
| [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md) | Phased development plan |
| [`docs/ASSET_LIST.md`](docs/ASSET_LIST.md) | Asset checklist and status |

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
| `./dev.sh editor` | Open the Godot editor |
| `./dev.sh test` | All headless tests: gamepad mapping (Deck + Xbox layout), save robustness, autopilot star run (every star reachable), flight stress test (17 cases × 60 s per plane, incl. mountains, lighthouse and turbines). Exit code 0 = pass. |
| `./dev.sh check` | Import the project and report script errors |
| `./dev.sh export` | Release build to `../LittlePilot-builds/LittlePilot.x86_64` |

Press **F3** in game to toggle the debug overlay (FPS, speed, clearance, safety state). It's on by default in debug runs and off in release builds.

### Steam Deck
See [`docs/STEAM_DECK.md`](docs/STEAM_DECK.md).

## License

Code is released under the **MIT License** (see [`LICENSE`](LICENSE)). Third-party assets keep their own licenses, recorded in [`CREDITS.md`](CREDITS.md).
