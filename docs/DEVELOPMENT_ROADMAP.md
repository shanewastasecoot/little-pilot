# Development Roadmap

The current plan, in short. The full plan with every detail is `Storage/IMPROVEMENT_PLAN.md`;
how the game got here (the original pre-1.0 roadmap) is in [`HISTORY.md`](HISTORY.md).

Ground rules for every phase: one phase per branch and pull request; `./dev.sh check` and
`./dev.sh test` pass; tests are never loosened; 90 FPS on the Steam Deck (Mobile renderer);
only CC0 / CC-BY assets, recorded in `resources/credits.json`.

## Done

| Phase | What | Version |
|---|---|---|
| 0 | Wording (the aircraft are described as real civilian aircraft), old issues sorted | 1.6.0 |
| 1 | `./dev.sh check` and CI on every push | 1.6.0 |
| 2 | Playtest fixes: landing, running speed, post office beacon, parcels, calling the plane | 1.6.0 |
| 3 | Her house: walk in, two floors, family, her room, meals, garden | 1.6.0 |
| 4 | Mermaid mail by parachute, KayKit townspeople, the dragon's treasure | 1.6.0 |
| 5 | Other buildings: post offices, the city's houses, the hat shop (stars for hats) | next |
| 6 | The world reacts (sheep, birds, townspeople, echoes), crash moments, dust, forgiveness fixes, max volume | next |
| 7 | Truthful docs, `credits.json`, in-game credits | next |

## Next

| Phase | What |
|---|---|
| 8 | Measurement: `bench-sim` (headless, CI) and `bench-render` (on the Deck, per area: frame times, 1 % lows, draw calls), toggles for shadows, AA, ocean, glow, crowd radius; time to first frame |
| 9 | Realistic aircraft: replacement models (chosen by the parent), an audit command, a model contract, moving control surfaces, nav lights, a cockpit view with gauges, "Trainer Jet" |
| 10 | Save safety: city plan version, migrations, `save.cfg.bak`, fixture tests |
| 11 | Visual consistency: Environment in a `.tres`, a custom sky, material profiles, foliage sway |
| 12 | Audio: real CC0 sounds (synth kept as fallback), a honk per aircraft, ambient zones |
| 13 | Airport service loop (taxi in, wash, refuel) and liveries (trim, decals, star milestones) |
| 14 | New play, one at a time with the parent: sky-writing, sticker book and camera, parent summary, parachute drops, seaplane, loop trick, follow-the-leader, all-stars reward, gentle weather, sunset and night, birthday surprise, same-screen co-op |
