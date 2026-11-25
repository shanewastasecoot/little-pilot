# Little Pilot: Graphics Improvement Plan

A prompt for Claude Code. It merges two graphics reviews of the repo (November 2026), checked against the code, with their errors removed.

**How to use it:** start each session with:

> Read Storage/GRAPHICS_PLAN.md and Storage/IMPROVEMENT_PLAN.md (for the ground rules and design decisions), then continue with Graphics Phase N.

---

You are working on Little Pilot (Godot 4, Mobile renderer, Steam Deck at 1280x800). The ground rules and design decisions in Storage/IMPROVEMENT_PLAN.md all still apply: one phase per branch, stop after each phase, never loosen tests, no new failure states, CC0/CC-BY assets recorded in the credits data, aircraft look like real civilian aircraft (not toys), and the world stays bright and friendly.

## The key fact this plan is built on

docs/GAME_DESIGN.md records the first Deck measurements: median frame time 7.6-10.5 ms, but 1% lows of 64-83 FPS (the 90 FPS budget is 11.1 ms per frame). Game logic takes 4.5-7 ms and physics 1.2-2.2 ms per frame, and the city crowd update is the biggest single cost (1.4 ms). Turning shadows, glow, refraction and AA down barely changed anything: **the game is CPU-limited, not GPU-limited.** Those numbers were taken in Desktop Mode with vsync off, on November 22, before Phases 9-14 (new aircraft, sailing, weather and more) were merged, so they're stale. Remeasure before relying on them.

About the 1% lows: I suspect a bug that dropped the game to 1-2 FPS caused them. That's unlikely to explain these particular numbers. bench_render.gd measures 6 seconds per area, and its 1% low averages the slowest ~6 frames. A single 500-1000 ms stall among them would show as a 1% low of roughly 1-11 FPS, not 64-83. The 64-83 values mean the slowest frames were 12-16 ms: ordinary jitter, slightly over budget. The stall may still be real but outside the measured windows (loading, warm-up, normal play). G0 checks both.

What that means for graphics work:
- Per-pixel improvements (shaders, materials, environment settings, baked shading) are relatively affordable right now, because the GPU has headroom. Measure GPU time to confirm.
- Anything that adds objects, nodes, draw calls, scripts, CPU-side culling or per-frame CPU work is expensive, because the CPU is already the bottleneck.
- If the fresh G0 numbers miss the target below, fix that first, or every visual addition makes it worse. If the fresh numbers already meet it, G1 shrinks to whatever the hitch log finds.

## Graphics rules (in addition to the main plan's ground rules)

- Run `./dev.sh bench-render` before and after every change, and report median, p95, 1% low, draw calls, and (once Phase G0 adds them) CPU and GPU time per area. Change one thing at a time.
- The target (changed by the parent after G0, November 25) is a warm-run **median of at least 90 FPS** (11.1 ms) in every area, so it hits 90 most of the time, and a warm-run **1% low of at least 60 FPS**. Short dips are fine; the game should run at 90 most of the time and never feel choppy.
- Every visual change needs before/after screenshots from fixed camera spots (G0 adds them). Show them to me and let me choose before making it the default.
- Prefer per-pixel improvements over adding objects. Don't add new MultiMeshes, scatter layers, lights, nodes or per-object scripts without measuring the CPU cost.
- Keep the Mobile renderer. Don't switch to Forward+ for SSAO, SSR or volumetric fog.
- Don't add these (they're wrong or don't fit this game):
  - ETC2/ASTC texture compression. Those formats are for phones. The Deck is a desktop-class x86 GPU, and Godot's desktop default (S3TC/BPTC) is already the right choice.
  - Occlusion culling (OccluderInstance3D) across the world. It costs CPU, the game is CPU-limited, and most of the view is open sky and sea. Only consider it for the city later, if measurement shows a GPU problem there.
  - A second directional light. It flattens the sun lighting and adds cost. Use ambient and fog tuning instead.
  - Big new grass or flower scatter layers everywhere. Small, local, short-range scatter only, and measured.

## Graphics Phase G0: Measure properly

0. Check for the 1-2 FPS stall bug I think I fixed. Search the git history and the code for it, and tell me what you find. Then add a stall detector to normal debug play (not only the bench): any frame over 250 ms is logged with the time, the game state (flying, on foot, indoors, sailing, loading) and what happened that frame, to user://bench/stalls.log. Play the bench routes and the new ones in G0 item 4, and report any stalls.
1. Make the 1% low trustworthy: raise MEASURE in tools/bench_render.gd from 6 to 30 seconds per area (so the slowest 1% is ~30 frames, not ~6), and also report p99 frame time and the single worst frame, so one stall can't hide in an average or skew it.
2. Add CPU and GPU time per frame to bench-render. Use RenderingServer.viewport_set_measure_render_time() with viewport_get_measured_render_time_cpu() and viewport_get_measured_render_time_gpu(), and report the median and p95 of each per area. This tells us whether each area is CPU- or GPU-bound.
3. Hitch log: for every frame over 11.1 ms in the warm run, record the area, what happened that frame (city building spawn, effect spawn, delivery, dragon fire, weather change, pipeline compilations from the Performance monitors), and the CPU and GPU times. Summarise the most common causes at the end of the run.
4. Add bench routes for scenes the current route doesn't cover (these are also used by item 0): on foot in the city, inside her house, weather (rain), fireworks, and the dragon breathing fire.
5. Add a screenshot mode: a fixed set of camera spots (airport apron, low over the city, low over farmland and meadows, the lagoon shallows, Dragon Peak, a close-up of the plane on the runway, inside the house) that saves PNGs to user://bench/shots/, so every visual change can be compared side by side.
6. Update docs/STEAM_DECK.md: final numbers come from the exported release build, in **Game Mode** at 1280x800 with vsync ON, after warm-up. Note that the Deck's own performance overlay can confirm CPU vs GPU.
7. Run the full bench on the current main branch and show me the results, compared with the November 22 numbers, before G1.

## Graphics Phase G1: Fix the slow frames (CPU)

The goal is a warm-run **median of at least 90 FPS** (11.1 ms) in every area, so it hits 90 most of the time, and a warm-run **1% low of at least 60 FPS** before any visual additions. No visual changes in this phase. If G0 shows every area already meets that, skip item 1 and do only item 2 (plus any stalls G0 found).
1. City crowd: city_crowd.gd loops over every person (the `for p in people` loops) and checks distance per person. Bucket people spatially by city block, visit only blocks near the camera, keep full-rate movement close to the player and lower-rate updates farther away. Keep the existing six MultiMesh batches and the no-shadow setup. Prove with bench-sim that the crowd cost drops, and that behaviour (doors, shrinking at doors, crowd_blocks) is unchanged in the tests.
2. Fix the top causes from the G0 hitch log. Likely candidates:
   - First-use shader pipeline compiles: pre-instantiate hidden examples of every spawned effect (crash smoke, explosion debris, fireworks, dragon fire, smoke trails, sky-writing, parachutes, rain, dust) during loading so their pipelines compile before play.
   - City growth: spread any per-building spawn work across several frames.
3. Rerun bench-render and bench-sim, and report the before/after.

## Graphics Phase G2: Environment and lighting tuning (near-free)

All of these are settings in resources/world_environment.tres and the sun in island_map.gd. Do each as a screenshot A/B, and let me choose:
1. Tonemapper: compare Linear (current), AgX (the F3 overlay's T key already flips these) and Filmic, with saturation re-balanced for each so colours stay bright and kid-friendly.
2. Glow: test intensity 0.7-0.85 with the HDR threshold at 0.9-1.0 (currently 0.6 and 1.1), for softer bloom on stars, fireworks, wave crests and the dragon treasure. Keep it subtle, not neon.
3. Fog: match fog_light_color exactly to the sky's horizon colour, and test slightly more density and aerial perspective so distant islands read as hazy and "over there".
4. Sun and ambient: a slightly warmer, more golden sun, and test ambient_light_energy at 0.6-0.7 (currently 0.55) for softer shadows.
5. Optional: a subtle colour-correction LUT for a warmer storybook grade, only if it beats plain contrast and saturation in the screenshots.
6. Indoor environment: warm, soft lighting in the house, with lamps and TVs as emissive surfaces rather than real lights.

## Graphics Phase G3: Baked contact shading (instead of SSAO)

The Mobile renderer has no SSAO, so bake subtle ambient occlusion into vertex colours instead. It costs nothing at runtime.
1. Terrain: in terrain_builder.gd, darken vertex colours slightly in hollows, at the foot of slopes and in valleys (a cavity term from the height grid).
2. Buildings and props: darken under roof eaves, around windows and doors, and where walls meet the ground, at import time or through the Blender pipeline. Only for the STATIC_WORLD style profile.
3. Subtle ground darkening around trees, rocks and buildings, where they meet the terrain.
Keep it subtle, and screenshot A/B it.

## Graphics Phase G4: Close-up terrain detail

The terrain is a StandardMaterial with vertex colours. The main island is sampled every ~12 m (308 cells over 3.7 km), so it looks plain up close.
1. Replace the terrain material with a small terrain shader: the same vertex colours as the base, plus a low-contrast, stylised world-space detail texture (grass, sand, rock, snow variants picked by the existing colour and slope logic) that fades out with distance. Avoid photo-real tiling textures, which fight the low-poly assets.
2. Authored ground variation where the player gets close: runway and apron wear marks, farm rows, footpaths, rocky ledges, meadow patches. Use vertex colours or the detail shader, not extra objects.
3. Only after measuring: small, short-range, no-shadow scatter (flowers, pebbles) right around the airport, farm and her house, using the existing scatter system.
4. Check that the terrain meets the ocean's shore foam cleanly.
Measure GPU time before and after. This phase is the most likely to cost GPU time.

## Graphics Phase G5: Anti-aliasing and shadows

Currently: 2x MSAA plus FXAA (screen_space_aa=1), and a 4096 soft shadow map.
1. Extend the bench toggles to include 4x MSAA and SMAA (if this Godot version offers it), then compare 2x MSAA + FXAA (current), 2x MSAA + SMAA, and 4x MSAA alone. Use screenshots (FXAA can blur) and bench numbers.
2. Compare 2048 vs 4096 shadows with screenshots. Keep 4096 only if it looks clearly better. Don't go higher.

## Graphics Phase G6: Water tuning

The ocean is already strong (six Gerstner waves, depth colour, foam, Fresnel, refraction). Tune it; don't add expensive features.
1. If the highlights shimmer or sparkle during flight, test raising the near-camera roughness in ocean.gdshader from 0.04 to 0.08-0.12 (screenshots and in motion).
2. Keep refraction on unless G0 shows the ocean is GPU-bound.
3. Optional, only with GPU headroom: cheap animated caustics in the shallows of the lagoon and beaches.

## Graphics Phase G7: Material consistency and aircraft surfaces

1. Audit everything in the UNTREATED and other untouched style profiles for mismatched gloss, brightness and colour response, and fix them by category. No blanket recolouring.
2. Make sure animals, dinosaurs and the dragon use a profile that fits with the characters.
3. Aircraft: improve the material response rather than adding triangles (the planes are already ~12,000 triangles, the jet ~5,200). Use a dedicated AIRCRAFT profile with glossy painted surfaces (slightly shinier than the world), metal parts, glass canopies, and convincing cockpit detail. Use clearcoat only if it works on the Mobile renderer.
4. Reflection probes (optional): a few large probes set to update once, over the airport, the city and the lagoon, if screenshots show glass and paint looking flat. Respect the Mobile renderer's per-object probe limit, and measure.

## Graphics Phase G8: LOD and culling

1. Check how the tree and rock MultiMeshes are batched. A single island-wide MultiMesh has one bounding box and is never frustum-culled. Try chunking batches by area so off-screen chunks are skipped, measuring the trade-off: more chunks means more draw calls (CPU).
2. Add lower-detail meshes or distant silhouettes for trees and larger props. First check which LOD method works with MultiMesh in this Godot version (automatic mesh LOD vs visibility-range LOD), and tell me before building it.
3. Check the visibility ranges and fades on everything distant.

## Graphics Phase G9: Effects polish

1. Improve the existing effects rather than adding new systems: star collect bursts and trails, fireworks variety, the sky-writing smoke texture, crash splash, takeoff dust, dragon embers, rain.
2. Use GPUParticles with short lifetimes. Keep the total under about 1,000-2,000 active particles, and pre-warm every new effect's pipeline (G1).
3. Gentle camera shake only on crashes and fireworks, kept short.

## Graphics Phase G10: Release check

Export the release build, then run it in Game Mode at 1280x800 with vsync on. Run the full bench, including the new routes, and confirm a warm-run **median of at least 90 FPS** (11.1 ms) in every area, so it hits 90 most of the time, and a warm-run **1% low of at least 60 FPS**. Update the numbers in docs/GAME_DESIGN.md and docs/STEAM_DECK.md.

---

## Notes for me (not for Claude)

- Order matters: G0 first. Its fresh numbers decide how much of G1 is needed.
- If I remember when I fixed the 1-2 FPS bug, tell Claude the date so it can find the commit (or push it if it's still only on my machine).
- G2 is the cheapest visible win, and G4 is the most likely to cost frame time.
- When Claude shows screenshot comparisons, have her pick favourites too.
