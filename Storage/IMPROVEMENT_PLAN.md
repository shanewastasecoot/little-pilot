# Little Pilot: Improvement Plan

This file is a prompt for Claude Code. It merges three independent reviews of the repo (November 2026), with their errors corrected and my decisions locked in.

**How to use it:** start each Claude Code session with:

> Read Storage/IMPROVEMENT_PLAN.md and continue with Phase N.

Start with Phase 0.

The "Notes for me" section at the bottom is for me, not for Claude.

---

You are working on Little Pilot, a Godot 4 flying game for a 4-year-old, in this repo. Before changing anything, read README.md, CREDITS.md, everything in docs/, and this file. I'm a beginner and mostly vibe coding, so at the end of each phase, explain what you did and why in plain language.

## Ground rules (apply to every phase)

- Work one phase at a time, each on its own git branch. Stop after each phase, summarise it, and wait for me to say "continue".
- BEFORE building anything, search the codebase for an existing implementation. For example, flight_audio.gd already changes engine pitch with speed; boost trails, water spray (water_spray.gd), the boost FOV kick and timed autosaves already exist. If something exists, extend or tune it. Never build a second version of it. Tell me what you found.
- Run `./dev.sh check` and `./dev.sh test` before finishing each phase. Everything must pass.
- NEVER delete, skip, or loosen a test to make it pass. Fix the code, or stop and explain why you think the test is wrong.
- Don't rewrite working systems (flight controller, flight safety, save manager, the state machine in main.gd) unless a phase requires it. Prefer small, additive changes.
- The performance target is the Steam Deck at 90 FPS most of the time (a median of at least 90 FPS in every area, with 1% lows of at least 60 FPS), 1280x800, Mobile renderer. Don't use Forward+-only features (e.g. the normal-roughness screen texture).
- Every new third-party asset must be CC0 or CC-BY and recorded in the credits data (see Phase 7) before it is committed.
- If a phase needs an asset or model change you can't do well in code, stop and tell me rather than faking it. No runtime geometry tricks, and no scripts that auto-split meshes someone else made.

## Design decisions already made (don't change these)

- Crashing and the dragon blowing up the plane stay, ON by default. My child asked for them and seeks them out. Parents can already turn them off.
- Crash rules (from playtesting): flat, landable ground never causes a crash. Touching it always becomes a landing, even if she comes in fast, diving or boosting. Buildings, trees, water, steep cliffs and the dragon still cause crashes.
- No stealing from people or houses. The "take things" urge goes to the dragon's treasure instead (Phase 4).
- Buildings: her house is two floors (4 bedrooms upstairs; playroom, kitchen, living room and dining room downstairs). Other houses are single floor or at most two floors, with at most 2 bedrooms. Shops are single floor.
- Little Pilot is NOT a toy-plane game. Aircraft must look like real civilian aircraft: realistic proportions, panel lines, real details (lights, moving control surfaces, gear), friendly bright paint schemes, no weapons, no military markings. Flying stays easy and arcade-like. Only the LOOK is realistic. Don't describe the aircraft as "toy", "cartoon" or "rattly" anywhere in code, UI or docs. The world itself can stay bright and friendly.
- No face or eyes on the plane.
- Keep the honk hop and the rainbow boost trails unless I say otherwise.
- The plane cannot fly real loops (pitch is capped at max_pitch_deg on purpose). Don't change that. A loop can only ever be a scripted trick.
- Voice narration is postponed. Don't add it.
- Fully offline. No accounts, no analytics, nothing sent online.

## Phase 0: Remove the "toy plane" framing (do this first)

The docs currently describe the aircraft as toys, and every Claude session reads them, so this comes before everything else. Don't change any game code or assets in this phase, only words.

1. Search the whole repo (docs, README, comments, UI strings, file names) for "toy", "cartoon" and similar words used about the AIRCRAFT. Known hits include:
   - docs/GAME_DESIGN.md: "the feeling of flying a toy plane"
   - docs/GAME_DESIGN.md: "Toy-like, rounded, non-military look. Cartoon proportions and no weapons."
   - docs/GAME_DESIGN.md: "a spinning propeller and a friendly face (optional)"
   - README.md: "a cartoon **toy biplane**"
   - docs/ASSET_LIST.md: "silly toy horn"
   List every hit for me and wait before changing anything. Leave unrelated uses alone (e.g. the city's "toy shop" in city_plan.gd).
2. Rewrite those passages to match the "Design decisions already made" section of this file: realistic civilian aircraft that are easy to fly, with bright friendly paint, no weapons and no military markings, in a bright, friendly world. Keep the tone of each doc; change only what it says about the aircraft.
3. Don't rename asset files yet (e.g. toy_biplane.glb). That happens when the model is replaced in Phase 9, because renaming an LFS asset and its .import file now would just be churn.
4. Open issues: list the open GitHub issues with a one-line note on each saying whether the feature already exists in the game, is covered by a phase of this plan, or is still needed. Wait for me before closing anything. When I approve, close them with a comment pointing to Storage/IMPROVEMENT_PLAN.md.
5. Commit on a branch and open a PR.

## Phase 1: Truthful checks and CI

1. Fix `./dev.sh check`. It currently pipes into `grep ... || echo "No errors."`, which can report success after Godot fails. It must keep Godot's real exit status, fail on "ERROR" or "SCRIPT ERROR", print warnings without failing, and never print "No errors" after a failure. Prove it works: show that a deliberately broken script makes it exit non-zero, then remove the broken script.
2. Make dev.sh respect a GODOT environment variable everywhere, so CI can use a non-Flatpak Godot.
3. Add .github/workflows/test.yml, running on every push and pull request:
   - Check out with LFS downloading DISABLED (actions/checkout's default).
   - Compute a hash of `git lfs ls-files -l` and restore a cache of .git/lfs keyed on it.
   - Then run `git lfs pull` and `git lfs checkout`.
   - Fail if any LFS pointer files remain in the working tree.
   - Install the exact Godot version pinned in project.godot/README (standard, not .NET), then run `./dev.sh check` and `./dev.sh test`.
4. Add .github/workflows/release.yml, triggered by tags like v1.5.0:
   - Fail if the tag doesn't match config/version in project.godot.
   - Export the Linux build and package it as a .tar.gz containing LittlePilot.x86_64 (with its executable bit set), CREDITS.md, a short INSTALL.md, and a SHA-256 checksum file.
   - Attach the package to a GitHub Release.
5. Add a beginner-friendly "How CI works" section to the README.

## Phase 2: Playtest fixes (from my daughter's play session)

These are real problems she hit. Fix them in this order, with a test for each where possible.

1. Landing is too hard, and with crashes OFF she couldn't land at all.
   - Cause found in aircraft_controller.gd: in can't-crash mode, the plane only lands while "slow" is held (safety.landing needs throttle < -0.2), otherwise FlightSafety's hard floor holds it up. A 4-year-old doesn't know about the slow button. With crashes ON, coming in steeper than LAND_MAX_DIVE_DEG or faster than LAND_MAX_SPEED x cruise counts as a crash.
   - New rule, both modes: if the plane is low over landable ground (can_land_on) and heading down toward it, without pulling up, it lands. Holding slow is a bonus, not a requirement. Don't treat boosting or a dive onto flat ground as a crash: auto-flare (level the nose and scrub off speed) during the last few metres, then touch down and roll as normal.
   - Crashes still happen on buildings, trees, water, steep cliffs and the dragon, as now.
   - Flying low on purpose (skimming meadows) must still be possible. If an automatic landing happens when she didn't mean it, boost takes off again from the roll, which already works. Tell me if you think it will trigger too often.
   - Add a soft blob shadow under the plane that fades with height, so she can judge how high she is.
   - Tests: scripted "child-style" approaches (nose down, boost held, no slow button) onto the runway and onto flat grass on at least three islands must land, not crash, in both modes. The existing landing tests must still pass.
2. Running is too slow. walker.gd has WALK_SPEED 5 and SPRINT_SPEED 9 for a 5 m tall character, and sprint needs B held. Raise both speeds (suggest about 8 and 15), and make the walker break into a run by itself after about 1.5 seconds of the stick pushed fully, so no button is needed. Scale the walk and run animation speeds to match so the feet don't slide.
3. She couldn't find the post office. When she isn't carrying a parcel, show a beacon over the nearest post office with a parcel waiting (reuse DeliveryBeacon, in a different colour from the delivery beacon, e.g. red like the mailbox), seen from the air and on foot. Hide it while she's carrying a parcel, because then the delivery beacon shows the way.
4. "Random packages around the city that she can't grab." I don't know yet which objects she means. First, list every parcel-shaped thing that can appear in the city (e.g. the spinning parcel DeliveryBeacon puts over a recipient, the parcel on a post office pad, parcels on other post office pads while she's already carrying one, any city props or decorations that look like boxes) and say when each one shows. Wait for me to confirm which one confused her. The rule after that: only things she can actually pick up may look like parcels. Destination markers should use a different shape (e.g. a big glowing heart or arrow).
5. She lost the plane after walking too far. On foot:
   - Show a beacon over the parked plane when she's more than about 60 m away from it.
   - Holding Y for 1 second when far from the plane calls it: a quick fade, and the plane appears parked on clear, flat, landable ground near her (use can_land_on-style checks and keep it out of buildings and water). If there's no safe spot nearby, show the beacon instead and don't move it.
   - Tests: the call never places the plane in water, inside a building or on a steep slope.

## Phase 3: Her house (enterable, two floors)

Her own house on the main island, near the airport, that she can walk into. It's the first enterable building, so build the system here in a way that later buildings can reuse (Phase 5).

How it works:
- The door is a doorway into a separate interior. When she walks into the front door: a quick fade, and she's inside. The outdoor world (terrain, city, crowd, ocean, dragon) is hidden and stops processing while she's inside. Walking out through the front door: a fade, and she's back on the step outside.
- Add an INDOORS state to the state machine in main.gd, with its own Environment .tres for indoor lighting.
- The house is a special landmark placed outside CityPlan. Don't touch CityPlan.make(): it would change saved cities.
- The exterior: a clearly bigger-than-normal two-storey house. Find 2-3 CC0/CC-BY candidates (or build one with BuildKit / the Blender props pipeline), show me screenshots next to the airport and the city houses, and wait for me to choose.

Layout (rooms built from data, see "Generator" below):
- Ground floor: entrance hall with the stairs, playroom, kitchen, living room, dining room.
- Upstairs: landing and 4 bedrooms.
- Size everything for her 5 m tall character. Being bigger inside than the outside suggests is fine.

Generator (this is what later buildings reuse):
- Describe a building as data: a list of rooms, each with a type, size, floor, and doorways, plus stairs. Use a resource or JSON file, not hand-placed scene nodes.
- One generator script builds walls, floors, ceilings, doorways, windows and stairs from that data, then places furniture per room type. Use a CC0 furniture pack that matches her KayKit character style (e.g. KayKit's furniture packs; check the licence) and record it in the credits data.
- Furniture variation (colours, arrangement) comes from a seed, so the same layout can look different in different buildings later.
- Stairs: visible steps with an invisible ramp for collision, so the walker climbs smoothly without snagging or jumping.

Camera (the hard part, so solve it first):
- An indoor camera mode: closer than the outdoor walk camera, never clipping through walls, and fading out any walls or furniture between the camera and her.
- Floors: while she's on the ground floor, hide the upstairs (dollhouse style), and while she's upstairs, keep the view clear. Switch smoothly as she goes up and down the stairs.

Things to do in the rooms (start small, add more after she plays):
- Playroom: a toy box with toys that bounce and squeak, and a ball to kick.
- Kitchen: a fridge that opens, and a pot that bubbles.
- Living room: a trophy shelf showing the dragon treasure she's collected (Phase 4), and a sofa to jump on.
- Dining room: a table she can set.
- Bedrooms: beds to bounce on, and lights to switch on and off. One bedroom is hers: she picks its bed and wall colours (picture-only), and the choice is saved.
- One hidden star in the house.

Saving and edge cases:
- Store house data (her room's colours, trophies) in NEW save keys only. Don't change the meaning of any existing key.
- Quitting or crashing the game while inside: she starts outside the front door next time.
- The plane-call (Y hold, Phase 2) doesn't work indoors. The dragon ignores her while she's inside.
- When she comes out, make sure nothing (crowd people, the plane) is standing on the doorstep.
- Tests: enter and exit repeatedly; she can reach every room on both floors; walk up and down the stairs; she never gets stuck in a wall or falls through a floor; exiting always puts her on safe ground outside.

Checkpoints (stop and wait for me after each):
1. The front door, entrance hall and playroom only, with the indoor camera working. I'll have her try it.
2. The rest of the ground floor.
3. The stairs and the upstairs.

## Phase 4: Her feature requests

1. Mermaid mail. Mermaids become delivery recipients. They sit in the water, so delivery is an air drop: when carrying a parcel for a mermaid, flying low over her beacon drops the parcel, she leaps up and catches it, and the usual cheer, confetti and reward stars follow. Reuse DeliveryManager, the beacons and the existing Mermaid wave animation. No new failure: a missed pass just means flying round again.
2. Townspeople in her character's style. The city crowd uses different people models (assets/characters/people/) from her KayKit character. Bake KayKit Adventurers characters, with varied outfits and colours from outfit_data.gd, into the existing vertex-animation crowd pipeline (the same one that made beach_vat.res), so the crowd stays cheap. Before and after, compare draw calls and FPS in the city using the F3 debug overlay, and tell me the difference.
3. Dragon's treasure (the safe outlet for her stealing idea). The dragon's lair already has a glowing gold hoard. On foot, she can sneak into the cave while the dragon is out or asleep and grab a piece of treasure. The dragon then wakes with a big roar, stomps and huffs smoke (it never hurts her on foot), then goes hunting her plane when she takes off, as usual. The treasure goes on the trophy shelf in her house (Phase 3). Only available when the dragon is switched on. One piece per visit, and it refills over time.

## Phase 5: Other enterable buildings (only if she uses her house)

Before starting, ask me whether she's actually been going into her house. If not, skip this phase.

Reuse the Phase 3 door, INDOORS state, camera and generator. Nothing new should be needed except layouts, door positions and furniture.
- Door positions: add a table of front-door positions per building MODEL (house_a, house_b, the shops, and so on), kept separate from CityPlan so saved cities don't change. Every building of the same model uses the same interior layout, with furniture varied by a seed from the building's position.
- Houses: mostly single floor; some (chosen by model) two floors. Maximum 2 bedrooms. Kitchen and living room, plus 1-2 bedrooms.
- Shops: single floor. Start with the post office (a sorting room with the postie) and one shop, e.g. a bakery or a toy shop where she can trade stars for hats or decals.
- Each interior has an owner (a KayKit character) who waves and gives her a sticker on her first visit, and one hidden star per building type.
- No stealing. Objects she picks up go back where they were when she leaves.
- Do this one building type at a time, and stop after the post office so I can check she enjoys it.

## Phase 6: World reactions and small forgiveness fixes (kid-visible)

1. On foot, X makes the character wave or cheer (the Cheer animation already exists). Nearby people wave back.
2. Create one world-event signal (e.g. on an autoload) that broadcasts honks, low passes, landings and crashes with a position. Make the dragon's existing honk listening (dragon.gd) use it instead of a direct reference to the plane's input.
3. Hook reactions to it: sheep scatter, cows moo, birds lift off from trees, city people wave, dinosaurs call, boats toot, penguins slide, the whale spouts, castle flags flap. Start with three or four, keep each one small, and make the rest easy to add.
4. Honk echoes: add audio-bus echo or reverb zones so honking near the mountains echoes, and the dragon's cave and the city reverberate. Use Godot audio buses and Area3D zones. No new sound files needed.
5. Ocean crash view: when the plane crashes into the sea, show a short underwater moment during the existing respawn fade (blue tint, bubbles, a few fish silhouettes, muffled sound). Keep the total crash-to-runway time the same as now. A volcano crash gets a brief lava-glow flash instead.
6. Takeoff dust when lifting off from grass or dirt, and small dust puffs when the character runs.
7. Forgiveness fixes:
   - If Y (get out) is pressed while the plane is still rolling, remember it and get out once the plane stops.
   - Check the parcel pickup, delivery hand-off and get-back-in radii, and make them generous if they aren't.
   - Add a parent "max volume" setting (default 100%) that caps overall loudness. This is separate from the existing hard limiter, which only stops clipping.

## Phase 7: Truthful docs and credits

1. Update README.md, docs/GAME_DESIGN.md, docs/STEAM_DECK.md and docs/ASSET_LIST.md so they match the real game:
   - Crashing and the dragon are on by default and parents can turn them off. Reword the philosophy as "failure is quick, silly and never punishing".
   - The real controls come from project.godot's input map (e.g. Y gets in and out of the plane; right-stick click changes the camera).
   - The performance target is 90 FPS most of the time everywhere (median at least 90, 1% lows at least 60).
   - The world size is correct.
2. Check that the Phase 0 wording changes are still in place, and that nothing added since then describes the aircraft as toys.
3. Move the old DEVELOPMENT_ROADMAP.md to docs/HISTORY.md and replace it with a short, current roadmap based on this plan.
4. Create resources/credits.json as the single source of truth for asset credits. Generate both CREDITS.md and an in-game Credits screen (reachable from the parent settings) from it. Add a test that every CC-BY entry has an author, a licence and a source URL. Remove the stale "(none yet)" table.

## Phase 8: Measurement

1. `./dev.sh bench-sim`: headless. Measures physics, flight safety, city simulation, crowds and dragon AI along a fixed route. Runs in CI. Headless mode doesn't render, so it must NOT claim to measure FPS.
2. `./dev.sh bench-render`: runs visibly at 1280x800 with the Mobile renderer, meant for the Steam Deck. It flies a fixed route through the airport, the fully grown city, the ocean and Dragon Peak, warming up each area for a few seconds. It reports, per area:
   - median frame time, 95th-percentile frame time and 1%-low FPS
   - draw calls
   It reports a cold run (first launch) separately from a warm run, saves the results to a JSON file, and prints a comparison with the previous run.
3. Add bench toggles (not default changes) for: 4096 vs 2048 shadows, MSAA vs screen-space AA vs both, ocean refraction on/off, simplified far-ocean waves on/off, glow on/off, and crowd draw radius.
4. Measure the time from launch to the first controllable frame.
5. Optional, debug builds only: a local playtest recorder that saves the route, crashes, landings and landmarks visited to a local JSON file. Nothing is ever sent online.

## Phase 9: Realistic aircraft (kid-visible)

1. The current biplane is a toy-plane model ("Toy plane" on Sketchfab, toy_biplane.glb) and can't become realistic by adding parts. Find 2-3 CC0 or CC-BY candidate replacements for a realistic civilian biplane or light aircraft, with separate control surfaces and propeller if possible (one option to evaluate: the CC0 low-poly An-2 on OpenGameArt, repainted in a civilian scheme; verify its licence). Show me screenshots of each next to the existing jet and buildings, at the same scale, and wait for me to choose. Do the same review for the jet. When a model is replaced, rename its file away from "toy_" and update the credits data.
2. Write an aircraft model audit command that reports each model's node hierarchy, mesh names, animations, materials, triangle counts, and whether the propeller, wheels, control surfaces and gear are separate parts. Show me the report and STOP.
3. Propose a standard aircraft model contract (Body, Propeller, wheels, Aileron_L/R, Elevator, Rudder, optional Gear, CockpitCameraMarker, Wingtip_L/R markers) and tell me which models meet it. If a model needs editing, tell me what's needed.
4. Then add, only where the model supports it:
   - control surfaces that move with the stick
   - red/green wingtip lights, a white tail light and a beacon
   - spinning wheels and a steerable nose or tail wheel
   - fixed gear stays fixed; only aircraft designed with retractable gear retract it
   - a cockpit camera in the camera cycle, with convincing moving gauges (speed, altitude, heading, artificial horizon). My child wanted a realistic simulator, so this view matters.
   - wingtip vapour in hard, fast turns, as its own effect separate from the boost trails
5. Rename "Fighter Jet" in the UI to "Trainer Jet".
6. Run bench-render before and after, and report the difference.

## Phase 10: Save safety

1. Add CITY_PLAN_VERSION and store it in the save. If it changes, keep the existing saved city rather than silently regenerating a different one.
2. Make the save loader read meta/version, and add a migration hook (even if it's empty for now).
3. Keep a save.cfg.bak of the last good save. Handle a failed final rename without losing data.
4. Add tests: generate save fixtures that represent the current format, and prove that they load, that corrupt files fall back to defaults, and that the .bak is used if save.cfg is broken.

## Phase 11: Visual consistency

1. Move the Environment (sky, fog, glow, tonemap) from code in island_map.gd into a .tres file that the code loads, so I can tune it live in the editor. The game must look identical after this step.
2. Replace ProceduralSkyMaterial with a custom sky shader: a soft gradient, a sun disc with glow, and a subtle high cloud layer. Start from the current colours. Tune the fog so far islands read as hazy and "over there" rather than vanishing.
3. Add style profiles (STATIC_WORLD, FOLIAGE, GLASS, AIRCRAFT, ANIMATED_CHARACTER, EMISSIVE, WATER, UNTREATED), assigned per asset or folder. Only STATIC_WORLD and FOLIAGE get harmonised: consistent roughness, no stray specular, and textures and vertex colours brought into a shared saturation and brightness range. Cache materials so identical assets still batch. Add tests proving glass, water, characters and aircraft materials are unchanged.
4. Add a debug-overlay (F3) toggle comparing the Linear and AgX tonemappers. Don't change the default.
5. Add foliage-only wind sway: masked by height, phased by world position, small trunk movement, more on the leaves, fading out with distance.
6. Run bench-render after each step, and report the results.

## Phase 12: Audio

1. Replace the synthesised sounds in sfx.gd, and the generated loops used by flight_audio.gd, with real CC0 sounds (Kenney audio packs are a good source) in assets/audio/ under Git LFS:
   - Keep flight_audio.gd's existing speed and boost modulation.
   - Keep all Sfx.play() names, so nothing else has to change.
   - Keep the synthesiser as a fallback if a file is missing.
2. Give each aircraft its own honk sound, with a small random pitch variation each time.
3. Add quiet ambient sound zones (AudioStreamPlayer3D): birds at the farm, a murmur in the city, waves at the shore, a rumble at the volcano, wind in the forest, drips and snoring in the dragon's cave.

## Phase 13: Airport and liveries (kid-visible)

1. Airport service loop: land, taxi to the hangar, the doors open, a marshaller waves, the plane gets washed and refuelled, then it rolls back out. No menus, no failure, repeatable.
2. Liveries: keep the current main paint colour and add a trim colour plus realistic decals (stripe, checker tail, rescue stripe, registration-style letters), picked with pictures only. Award a new decal at star milestones (50, 100, 150, 220), but never lock the basic colours. Save liveries with the same corrupt-file safety as everything else.

## Phase 14: New play

Do each of these on its own branch, in this order, and check with me before starting each one:

1. Sky-writing: hold a button to leave a smoke trail in the current paint colour that lingers for about 60 seconds. Tell me which button you chose and why it doesn't clash.
2. Sticker book plus postcard camera: a picture-only book (from the pause menu) of discovered landmarks, animals and recipients, plus a camera button that saves screenshots into it.
3. Parent summary screen: a picture-based "today" page in the pause menu showing islands visited, stars, deliveries, crashes and time played, using data the game already tracks.
4. Parachute drops to boats and other hard-to-reach places, extending the mermaid air drop from Phase 4.
5. A seaplane that can land on and take off from the ocean, reusing the flight controller and the Gerstner waves.
6. A scripted loop trick (like the barrel roll), only if it can be done without changing the pitch limits or flight safety.
7. Follow-the-leader: birds, a balloon or a friendly plane invite the player to follow a loose path. No timer and no penalty.
8. All-stars reward: after collecting all 220 stars, something in the world changes permanently (e.g. the rainbow always sparkles and flying through it sets off fireworks).
9. Gentle weather: a rain cloud that washes the paint off, then a rainbow. No thunder.
10. Optional sunset and night modes (daytime by default): city windows, a lighthouse beam, runway lights and aircraft nav lights. Use the play-time setting to fade into sunset when time is up, without forcing a stop.
11. Birthday easter egg: on a date the parent sets, the world gets decorations and the honk plays a birthday tune.
12. Same-screen co-op (not split-screen): a second controller co-pilots by honking, dropping parcels and setting off fireworks.

---

## Notes for me (not for Claude)

- PRs: I've closed the superseded ones. Still to do: 17 old pre-1.0 roadmap issues (#26-#42) are open. Phase 0 has Claude sort them out with my approval.
- Ask my kid about the honk hop and the rainbow boost trails before Phase 9.
- Ask her: does she like crashing into the GROUND, or mostly into buildings, the sea and the dragon? Phase 2 assumes the ground doesn't matter to her.
- Ask her to show me (or screenshot) the "packages" she couldn't grab, for Phase 2 item 4.
- Ask her which bedroom is hers, and who the other three are for (so Claude can theme them).
- Map honk or boost to a Steam Deck back button in Steam's controller settings for the game. No code needed.
- This repo is public, so anything in this file is public too.
