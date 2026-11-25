# Little Pilot — Game Design Document

| | |
|---|---|
| **Version** | Living document: describes the game as it is (1.6 and the work after it). Plans are in [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md). |
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Primary platform** | Steam Deck (1280×800) |
| **Target player** | Age 4 |

---

## 1. Game Vision

> **A relaxing 3D flying sandbox for young children.**

Little Pilot is the feeling of flying a real little plane around sunny islands, then landing anywhere and walking about. Each minute should hold small moments of delight: a sparkle, a chime, a lighthouse beam, sheep scattering under a low pass, a townsperson cheering back.

### Design Pillars

| Pillar | What it means in practice |
|---|---|
| **Forgiving** | Failure is quick, silly and never punishing. Crashing and the dragon are on by default: a crash is a bonk or a splash, and less than two seconds later the plane is back on the runway with nothing lost (stars, parcels, everything kept). Flat, landable ground never crashes the plane. Parents can turn crashing and the dragon off (then the plane steers itself away from the ground, the sea and buildings). |
| **Simple** | One stick flies the plane. Everything else is optional. |
| **Joyful** | Every action gets a cheerful sound, effect or animation, and the world reacts to what she does. |
| **Free** | No objectives, no timers, no required order. Nothing is locked. |

### Design Test

For any new feature, ask: **"Could a 4-year-old trigger this by accident and get upset?"** If yes, redesign it or cut it. (So choices are made on purpose: room colours, meals and hats are picked with Y and a picture menu, never by walking past something.)

---

## 2. Player Experience

### 2.1 Easy to Learn
- The plane is ready to fly a few seconds after launch, with no tutorial screens.
- Pushing the stick visibly moves the plane right away. The child learns by doing.
- On-screen hints are pictures (an animated stick when the plane is waiting; the A/B/Y buttons with little figures on foot).

### 2.2 Forgiving Flight

The flight controller is **kinematic and arcade-style**, not a physics simulation.

| System | Behaviour |
|---|---|
| **Minimum speed** | The plane never drops below cruise speed in the air, so it can't stall. |
| **Auto-level** | When the stick is released, the plane smoothly returns to level flight. |
| **Altitude ceiling** | Above a set height, the plane gently levels off and stops climbing. |
| **World boundary** | Near the edge of the map (4.7 km from the middle), the plane curves back in a wide, natural turn. No wall, no warning. |
| **Spin protection** | Roll and pitch are clamped. The plane can't go upside down or get disoriented. The barrel roll (X) is a scripted trick. |
| **Landing** | Low and slow over flat ground (or holding slow), the plane flares and lets itself down onto it: landing anywhere flat never crashes. |
| **Crashes on (default)** | Hitting a mountain, a building, the sea, the volcano or the dragon's fire is a crash: a bonk with dizzy stars, a splash and a moment under the sea, or an orange glow on the volcano, then back to the runway (1.75 s in all). |
| **Crashes off (parent)** | The uncrashable mode: rays sample the ground and obstacles ahead and the plane pitches up and steers around them on its own, keeping a minimum clearance; tall things have soft "push" volumes. |

> **Rule:** If the child holds the stick in any direction indefinitely, the result must still look fun and safe, such as a steady circle or a gentle climb that levels out.

### 2.3 Free Exploration
- The whole world is open from the start. Nothing is locked.
- Landmarks are visible from far away, so they work as natural goals.
- Paths of stars lead toward interesting places without forcing a route.
- Land anywhere flat, press Y, and walk: into her house, the post offices, the city's houses, the hat shop.

### 2.4 Discover Landmarks
- Each landmark has a **discovery radius**. The first time the plane enters it, a short jingle plays and the landmark does something (the lighthouse beam flashes, farm animals hop, the boat toots, birds fly out of the forest).
- Beyond discovery, the world keeps reacting to honks, low passes and her cheering (see [13c](#13c-the-world-reacts-phase-6)).

### 2.5 Collect Stars
- Stars float in the air across the islands. See [Section 7](#7-collectibles).
- Collecting one is instant and satisfying: sparkle, rising chime, counter bump. Stars can be spent on hats at the hat shop.

---

## 3. Aircraft

Both aircraft share the same controller code and differ only in a tuning resource (`resources/aircraft/*.tres`, `AircraftStats`). Adding a new aircraft is a data change, not a code change.

| Stat | Prop Plane | Trainer Jet |
|---|---|---|
| Cruise speed | Medium | Faster |
| Boost | Speeds up while held | Speeds up while held |
| Turn rate | Gentle | Quicker |
| Responsiveness (input smoothing) | Soft | Snappier |
| Engine sound | Buzzy propeller | Smooth whoosh |
| Trails | Rainbow boost trails | Rainbow boost trails |

### 3.1 Prop Plane — *the default*
- **Medium speed, easy control.** Wide, forgiving turns; jerky stick movements still look graceful.
- A realistic vintage two-seat biplane (vinish.dev, CC BY 4.0): navy fuselage, the wings and stripes in her paint colour (8 colours), a radial engine with a spinning propeller, and **her own character in the rear cockpit** (her outfit, hair and hat; `PilotSeat`). No face on the plane. In the hangar it's called "Biplane" (its save id is still `prop`).
- **Light Plane** (vinish.dev, CC BY 4.0): a high-wing four-seat trainer, white with blue and red cheat lines (the white is her paint colour). Flies like the biplane, a touch faster. The **Seaplane** is this plane on floats.

### 3.2 Trainer Jet — *the zippy one*
- **Faster, more responsive.** Tighter turns and less smoothing.
- A civilian trainer jet: bright paint, no weapons and no military markings.

### 3.3 Real-aircraft touches (Phase 9)
- **Navigation lights** on both: red on the left wingtip, green on the right, a white tail light, and a red beacon on top that flashes (glowing dots: almost free to draw).
- **Wingtip vapour**: thin white streams off the wingtips in hard, fast turns (its own effect, separate from the rainbow boost trails).
- **Cockpit view**: the camera button's third press (after close and far). The camera sits at the pilot's eyes (`AircraftStats.cockpit_eye`, or a `CockpitCameraMarker` in the model) and banks and rolls with the plane; the right stick still looks around. An instrument panel along the bottom: airspeed (km/h, green and yellow arcs), an artificial horizon (sky and ground tilt with the bank and slide with the pitch), an altimeter (two needles and the height) and a compass rose (N E S W). In the biplane you look out under the top wing past the struts and the propeller; in the jet over its nose.
- Moving control surfaces, spinning and steering wheels, and retracting gear need models with those parts: the models' contract and the audit are in [`AIRCRAFT_MODELS.md`](AIRCRAFT_MODELS.md) (`./dev.sh audit-aircraft`). Both current models are one mesh each, so they get the lights, vapour and cockpit view but not moving parts; replacement models are waiting for the parent's choice.

### 3.4 Tuning Notes
- Tune the feel with **the actual child**, not just the developer. Adults usually tune too fast and too sensitive.

---

## 4. Controls

Taken from the input map in `project.godot` (and checked by `controller_test` on the Deck's controls and an Xbox-layout pad).

### 4.1 Steam Deck (Primary)

| Input | Flying | On foot / indoors |
|---|---|---|
| **Left stick** | Up/down = climb/dive (up = climb, not inverted), left/right = turn | Walk (further push = faster) |
| **Right stick** | Look around (drifts back when released) | Turn the camera |
| **A** or **R2** | Boost (A for small hands) | A = jump |
| **L2** | Slow down; low over flat ground, flare and land, then brake | — |
| **B** | Honk 🎺 (the world reacts) | Sprint |
| **X** (hold climb + X: a loop) | Barrel roll | Cheer (people nearby cheer back) |
| **Y** | Get out when parked (pressed while still rolling: as soon as it stops) | Get back in beside the plane; hold Y to call the plane when it's far; at the end of a pier: sail (or call the boat); sailing: step off at a dock; indoors: use what's here (paint easel, quilt chest, fridge, sit at the table, hat mirror) |
| **Right-stick click** | Change camera: close, far, cockpit (with instruments) | — |
| **D-pad ◀ ▶** | Paint colour (each plane remembers its own) | — |
| **LB / RB** | LB: take a postcard; hold RB: sky-writing (smoke in the paint colour) | Change tab on the character screen; decals on plane select |
| **Menu (≡)** | Pause menu | Pause menu |

#### Control Design Rules
- **No button is ever required.** Flying needs only the left stick.
- **No input is ever harmful.** Mashing every button at once must not cause anything bad.
- **Large dead zone** on the sticks, so a resting thumb doesn't steer.
- **Quitting needs a deliberate parent action** (hold the quit button).
- **Known limitation:** the Steam and Quick Access (`...`) buttons are system buttons and the game cannot block them.

### 4.2 Keyboard (Development / Linux desktop)

| Key | Action |
|---|---|
| WASD / Arrow keys | Fly / walk |
| Space | Boost / jump |
| Shift | Boost (flying) / sprint (on foot) |
| Ctrl | Slow down |
| H | Honk |
| R | Barrel roll / cheer |
| F | Get out / in / use |
| C | Change camera |
| I J K L | Look around |
| Q / E | Paint colour |
| Z / X | Character screen tabs |
| Esc | Pause |
| F3 | Debug overlay |

### 4.3 iPad (Future)
- A virtual joystick on the left half of the screen, a big boost button and a honk button on the right.

---

## 5. Camera

- **Chase camera** behind and slightly above the plane, smoothed; the field of view widens a little when boosting. Right-stick click cycles close, far and the **cockpit view** (at the pilot's eyes, with the instrument panel). No sudden cuts, no shake.
- **Walk camera** behind her on foot (speed and up/down direction are parent settings).
- **Indoor camera**: closer, looking down into the rooms dollhouse-style; walls between the camera and her fade away; upstairs hides while she's downstairs. At the hat shop's mirror it comes round in front of her, close up.

---

## 6. Environment

A world of islands about 9 km across (the boundary is 4.7 km from the middle), all open from the start:

- **Main island** (about 3.7 km): the airport (runway, hangar, control tower), her house and fenced garden, the airport post office and the hat shop, snowy mountains with a valley, a pine forest, the farm, a wind-turbine ridge, the lighthouse, and the **city** that grows while she plays (shops, houses, apartments, towers, parks, a plaza, a Ferris wheel, townspeople). **Dragon Peak** and the dragon's cave on a northern headland.
- **Palm Island**, **Volcano Island** (it erupts), the giant **rainbow**, **Mermaid Lagoon** (an atoll with a rock arch).
- **Ice Island** (penguins, igloos), **Dino Island** (dinosaurs), **Castle Island**, **Town Island** (hot-air balloons, a post office).
- 15 islets with palms, seals, crabs and mermaid coves; dolphins, a whale, a sail boat and a pirate ship at sea.

### 6.1 Visual Style
- **Low-poly, saturated colours,** toon-shaded characters. Readable for kids and cheap to render.
- Always sunny daytime. Soft shadows. Clear silhouettes so each landmark can be recognised from far away.
- **The sky and air** (Phase 11): `resources/world_environment.tres` holds the sky, fog, glow and tonemap (open it in the editor to tune them live; `tools/make_environment.tscn` writes the starting values). The sky is `shaders/sky.gdshader`: a soft gradient in the old sky's colours, a sun disc with a warm glow, and faint wispy high cloud (drawn once, not every frame). The fog takes the sky's colour in the direction you look (aerial perspective), so far islands read as hazy and "over there" rather than vanishing.
- **Style profiles** (`StyleProfiles`, applied by AssetLib as models load): each asset is STATIC_WORLD, FOLIAGE, GLASS, AIRCRAFT, ANIMATED_CHARACTER, EMISSIVE, WATER or UNTREATED, by file or folder. Only STATIC_WORLD (buildings, rocks, props: consistent roughness, low specular, colours inside a shared saturation and brightness range) and FOLIAGE (the same, plus wind) are changed; changed materials are cached so identical assets still share them and batch. Glass, water, characters, animals and aircraft are left exactly as they are (`style_test` proves it).
- **Trees in the wind** (`shaders/foliage.gdshader`): a gentle sway, none at the foot, a little in the trunk, more in the leaves, each tree out of step with its neighbours, fading out with distance.
- **Tonemap comparison**: with the F3 overlay showing, T flips Linear (the game's) and AgX, to compare. Never saved.

### 6.2 Performance Budget (Steam Deck)
- **90 FPS everywhere at 1280×800** (the OLED Deck's refresh rate), with the Mobile renderer. A 30 FPS battery saver is a parent setting.
- MultiMesh for trees and the crowd (one draw per townsperson look); visibility ranges on trees and small props; people far away aren't drawn or moved.
- New work is measured before it ships: `./dev.sh bench-render` (frame times per area, cold and warm, 1 % lows, draw calls) and `./dev.sh bench-sim` (simulation cost, headless, in CI). First results on the Deck (desktop mode, vsync off): median frame time 7.6-10.5 ms (the fully grown city the slowest, about 96 FPS median), 1 % lows 64-83 FPS, 170-535 draw calls; physics about 1.2-2.2 ms and game logic 4.5-7 ms a frame, the city's crowd update the biggest single cost (1.4 ms). Turning shadows, glow, refraction and anti-aliasing down barely moves the numbers: the game is limited by the processor, not the graphics, so that's where speed-ups belong.

---

## 7. Collectibles

### 7.1 Floating Stars

| Aspect | Design |
|---|---|
| **Look** | Chunky gold 3D star with a soft glow, spinning and bobbing |
| **Collection** | Fly through it (an `Area3D`). No button press. |
| **Feedback** | Sparkle burst, a rising chime (pitch climbs with quick pickups), the counter pops and the star jar fills |
| **Quantity** | 220 stars, in trails that lead from place to place, plus one hidden star in each building type |
| **Respawn** | When every star is collected: fanfare, then they all come back, so it never runs out |
| **Persistence** | Lifetime star total saved; she can spend stars on hats (the purse is lifetime stars minus stars spent, so collecting never stops counting) |
| **Parties** | Every 30 stars the city throws a fireworks party (an optional arrow and a 30 s countdown point the way) |

### 7.2 Star Counter UI
- A **star icon plus number** in a corner, and a **star jar** that fills up visually (numbers are optional for a 4-year-old).
- Milestones give a short celebration with no interruption to flying.

---

## 8. User Interface

| Screen | Contents | Notes |
|---|---|---|
| **Title** | Logo, a big "▶" button | Any button starts |
| **Plane Select** | Two large plane pictures. Left/right to pick, A to fly | No text needed; the choice is saved |
| **Character screen** | Picture tabs: face, hair, outfit; the character spins with the right stick | First Start press, and from the pause menu |
| **HUD** | Star counter and jar; button hints with pictures; prompts (get out, get in, call the plane, paint, food, sit, hat) | Clean screen |
| **Pause** | Resume ▶, change plane ✈️, character (orange person), parent settings (grey gear), quit (hold to confirm) | Large icons |
| **Parent settings** | Music, sounds, the loudest it ever gets; battery saver, city arrow, crashes, dragon and its difficulty; time played, restart the city (press twice), walking camera speed and invert, delivery arrow, credits (a heart) | Changes save automatically |
| **Credits** | Everyone whose work is in the game, from `resources/credits.json` | For grown-ups |
| **Pickers** | Colour, meal and hat menus: pictures only, stick to look, A to keep, B to put back | Opened with Y |

UI rules: big targets, high contrast, icons before text, and every button press makes a sound.

---

## 9. Audio

| Type | Content |
|---|---|
| **Music** | Gentle generated music (`scripts/core/music.gd`), a low default volume |
| **Engine and wind** | Generated loops; pitch and volume follow speed and boost |
| **Stars** | Chime with rising pitch |
| **Landmarks** | One signature sound each |
| **Honk** | Each aircraft its own horn (a bright "beep-beep" for the biplane, a deeper one for the jet), a touch higher or lower each time, echoing in the mountains, booming in the dragon's cave, ringing in the city |
| **Places** | Quiet sounds heard only nearby (`AmbientZone`): birdsong at the farm, the city's murmur, wind in the forest, the volcano's rumble, drips and a sleepy snore in the dragon's cave, waves at three shores |
| **UI** | Soft clicks and pops |

All sound effects are synthesised at startup (`scripts/core/sfx.gd`). A real recording replaces any of them by being dropped into `assets/audio/` with the same name (loops in `assets/audio/loops/`); the synthesised one stays as the fallback, and every `Sfx.play()` name keeps working (see `assets/audio/README.md` for the names and CC0 sources; Kenney's packs need a browser to download, so none are in yet). Buses: **Master** (with a hard limiter, a muffle for under the sea, and the parent's volume cap), **Music**, **SFX**, and the honk echo buses **HonkEcho**, **HonkCave** and **HonkCity** (into SFX).

---

## 10. Save Data

- Stored with Godot `ConfigFile` at `user://save.cfg` (on Linux: `~/.local/share/godot/app_userdata/Little Pilot/save.cfg`), written to a temporary file and swapped in, so a crash mid-write can't break it. Saved a moment after anything changes, and on quit.
- Sections: `meta` (version), `player` (plane, paints), `progress` (lifetime stars, playtime, city time and seed), `settings` (volumes and the cap, battery saver, arrows, crashes, dragon and difficulty, camera), `character` (body, hair, outfit), `delivery` (the parcel being carried, deliveries, who's had one), `house` (her room's colours, whether she was inside), `stickers`, `shop` (stars spent, hats owned, the hat she wears), `dragon` (treasure).
- New features use **new keys only**; an existing key never changes meaning.
- **Save safety (Phase 10):** the file records its format version (`meta/version`, now 2) and the loader runs a migration hook for older versions (version 1 saves load unchanged; new keys start at their defaults). Each save first checks the new file reads back, keeps the last good save as `save.cfg.bak`, then swaps the new one in; if the swap fails it copies instead, and if that fails too the new save stays beside it as `save.cfg.tmp` and is loaded next time. Loading tries `save.cfg`, then `.tmp`, then `.bak`, then the defaults.
- **Her city stays her city:** the save records which version of the city plan made her city (`progress/city_plan_version`, `CityPlan.VERSION`), and the plan itself is kept beside the save (`save_city.cfg`). If an update changes how cities grow (and raises the version), her saved city keeps its own plan instead of silently turning into a different city. Restarting the city makes and keeps a new plan.
- Tests (`save_safety_test`) load fixtures of the current and previous formats (`tests/fixtures/`), and prove corrupt files fall back to defaults, the backup is used when `save.cfg` is broken, and a failed swap loses nothing.
- **Corrupt or missing save → silently use the defaults.** Never show an error to the child.

---

## 11. Accessibility and Child Safety

- No online connectivity, accounts, ads, analytics or purchases. Fully offline.
- No flashing effects faster than 3 Hz. No strobe effects.
- Colours must be readable for common forms of colour blindness. Stars use shape and glow, not colour alone.
- Parents can cap how loud the game ever gets (and a limiter stops clipping).
- Optional **play timer** for parents (future): fade into a sunset when time is up.

---

## 12. Deliveries

A gentle job to do, never a chore: pick up a parcel and carry it to someone.

| Rule | In practice |
|---|---|
| **Optional** | A parcel only becomes yours if you walk into it. Ignore the post office and nothing happens. |
| **No failure** | No timers. The parcel can't be lost, dropped or broken: it stays with you in the plane, through crashes, pauses and quitting (it's saved). Walking up to the wrong person just gets a wave. |
| **No reading** | The bubble (top left) shows a picture of who it's for, ringed in their colour; an arrow round it points their way; a column of light in their colour shines over them from far away, with a big heart over their head (a heart, not a parcel: only parcels you can pick up look like parcels). When you're not carrying one, a red beacon shows the nearest post office with a parcel waiting. |
| **No buttons** | Walk into the parcel to pick it up, walk up to them to hand it over. |
| **Joyful** | They reach out, take it and cheer; confetti, a fanfare, and reward stars fly into the star jar. |

- **Post offices** at the airport (by the runway's west end, where the plane waits), just west of the city, and at the east end of Town Island's main street: a postie at each door and a parcel bobbing on a golden pad.
- **One parcel at a time**, nearest first: the first two go to people a short walk from the airport (a kid with a balloon, a grandma in a sun hat); then the rest of the main island (the mechanic at the hangar, the farmer, the lighthouse keeper, a painter at the city's edge); then the other islands, where you fly, land and walk up (the baker on Town Island, an explorer among the penguins on Ice Island, a ranger by the Dino Island landing meadow, a knight at the foot of the castle hill). After everyone has had one, anyone, never the same person twice in a row.
- **In the plane** the parcel rides on top, behind the pilot. On **Easy**, the dragon leaves a plane carrying a parcel alone.
- **Where:** a little picture in the bubble (barn, lighthouse, city, town, snowflake, dinosaur, castle) shows which place they're in.
- **Reward stars** count in the lifetime total and towards city parties, but not towards the floating stars' "all found".
- **Parents** can switch the arrow off (parcel button in settings); the picture and the column of light stay.
- People are KayKit characters dressed like the player (palette + Blender props), animate only near the player and stop drawing far away.
- **Mermaid mail:** three mermaids sit on rocks out at sea (off the main island's east beach, outside the north mermaid cove, south of the lagoon). Their parcels are air drops: carry one for a mermaid, fly low over her beacon (within 40 m, under 70 m up) and the parcel leaves the plane on a little parachute in her colour and floats down into her hands; she leaps up out of the water to catch it and splashes back waving; then the usual cheer, confetti and reward stars. No button, and no failure: a pass that's too high or wide just means going round again. Her bubble shows her portrait with a picture of waves and a rock. The one off the east beach comes early (with the rest of the main island); the others with the other islands.
- Coming next (see the roadmap): parachute drops to boats, themed parcels, more people, rewards and stickers.

## 12b. The Dragon's Treasure

The safe outlet for "taking things": only from the dragon. A piece of its treasure (a crown, then a cup, a gem, a pile of coins, a necklace) glows and turns in front of its hoard in the cave. On foot, walk in and grab it: a sparkle and a fanfare, and it goes on the trophy shelf in her house (saved, `[dragon] treasures`). The dragon, asleep at home, wakes grumpy: it turns to face her, roars, stomps and huffs smoke every couple of seconds, but it never hurts her on foot. When her plane takes off it comes out and hunts it, as usual (if it was out flying when she took it, it roars and hunts the plane as soon as it sees it fly). Only while the dragon is switched on. One piece per visit: the next is back after a couple of minutes of play, once she's left the cave.

---

## 13. Her House (enterable buildings)

Her own house south-west of the runway is the first building you can walk into.

- **Outside matches inside:** the outside is built from the same floor plan as the inside (`scripts/buildings/house_exterior.gd`), so every outside wall, window and the front door are exactly where they are inside. It's a real two-storey house: the upstairs sits wholly on the ground floor, with pitched roofs (the big one with a chimney over the upstairs, smaller ones over the single-storey wings), a blue front door with a porch, and flower boxes under the ground-floor windows.
- **The garden** (`scripts/buildings/house_garden.gd`): a big yard round the house with a white picket fence and a gate where the front path goes out towards the runway; flower beds along the walls; and a backyard to play in: a swing set, a trampoline (it bounces you), a sandpit with a bucket, and trees in the corners. The house and yard sit on their own flattened pad (`IslandShape.HOUSE_YARD`).

- **Going in and out:** walk into the front door: a quick fade, and you're in the hall (the outdoor world is hidden and paused, indoor lighting on). Walk into the bright doorway to come back out onto the doorstep. Nothing standing on the doorstep (a parked plane is moved aside).
- **Indoor camera:** closer than the walk camera, looking down over the walls from behind you (no ceilings, dollhouse style). The right stick swings it round; left alone it drifts back behind you. Any wall between the camera and you fades away.
- **Built from data:** a building is a list of rooms (type, size, storey, doorways, windows) in a JSON file (`resources/buildings/her_house.json`). One generator (`scripts/buildings/building_generator.gd`) builds the floors, walls, doorways, windows and furniture (KayKit Furniture Bits, varied by a seed), so later buildings only need a layout.
- **Sized for her:** rooms are built for her 5 m character (11 m storeys, 7 m wide doorways); furniture is scaled to match.
- **Ground floor:**
  - **Entrance hall** (the front door; doorways to every other room).
  - **Playroom:** a toy box: walk up and the lid opens, and five toys hop out one by one into tidy rows either side of it (gently, then they can be pushed about); a ball to kick.
  - **Kitchen** (KayKit Restaurant Bits): the fridge's doors swing open with a cool glow when you walk up, and the Y prompt shows a plate: press Y and a menu shows three meals drawn big, **pizza**, **chicken fingers** and **breakfast** (eggs, bacon, pancakes). The stick picks one, A takes it out to carry, B closes the menu. A pot of stew bubbles on the stove.
  - **Dining room:** the table is empty until you bring a meal; walk up to it carrying one and it's served at every place, one after another with rising chimes. Bring a different meal later and it's swapped. The chairs face the table. **Sit down and eat:** by a chair the Y prompt shows a chair; press Y and she sits at the table, and if there's food at her place she eats it in three munchy bites (it gets smaller each time), then a little burst of hearts and a happy chime. The stick or A gets her up.
  - **Living room:** a TV on the east wall with the sofa facing it across a low table and armchairs either side. The TV comes on when you come in and plays a little cartoon (drawn in code, no words): a plane looping over the sea with dolphins, a mermaid waving from a rock, a dinosaur bobbing through the jungle; it switches off when you leave (costs nothing when nobody's watching). Jump onto the sofa and it bounces you up high; a trophy shelf on the north wall with five golden stands shows the dragon treasure she's brought home (section 12b).
  - Nothing stands in a doorway (a test checks every doorway).
  - Nothing stands in front of or hangs over a window (a test checks every window).
  - Everything goes back as it was when you leave (toys in the box, the table cleared, a meal in your arms left behind, the fridge shut, the TVs off).
- **Stairs:** in a stairwell between the hall and the living room, up the middle with walkways either side. Stepped blocks to see, a smooth solid ramp to walk on (no snagging, nothing to get under), banisters on both sides, and railings round the opening upstairs.
- **Upstairs** (dollhouse: hidden while you're downstairs, fading in as you climb; once you're up, the rooms downstairs fade out except the stairwell, so their wall tops never show through the floor). Walls stop just under the floor above.
  - **Landing** over the hall and stairwell; the two east bedrooms have their doors right beside the top of the stairs.
  - **Four bedrooms**, each with a bed, a nightstand and lamp, a rug, and a big light switch beside the door: walk into it and the room dims, walk into it again and it's bright. Jump onto a bed and it bounces you (each bounce a little lower); stand still on it for a moment and you **lie down** (head on the pillow); push the stick or press A to get up.
  - **Sophia's room** (the pink one, top right coming up the stairs; set in `resources/buildings/her_house.json` with `"hers": true`), bigger than the others: a painter's easel by the west wall (the walls) and a pink toy chest of folded quilts beside the bed (her quilt). Stand by one and the Y prompt shows a palette; press Y and a colour menu opens with six big paint blobs and a picture of a wall or the bed: the stick moves between them and the room shows each colour straight away, A (green tick) keeps it with a sparkle, B (red cross) puts back what was there. Walking past them never changes anything. Saved (`[house] wall`, `bed`); her own TV with the cartoon; a bookshelf full of books by the door; three mermaid toys round a little blue play pool; stuffies (a teddy and a bunny on the bed by the pillows, another teddy and a dolphin on the floor).
  - **A hidden star** in a corner of the south-east bedroom: three reward stars, back every visit.
- **Her family** (`scripts/buildings/family.gd`, `family_member.gd`): Mum, Dad, a big brother and a little sister (KayKit characters in their own outfits) live in the house, Sim-style. Each has needs that slowly run down (hungry, sleepy, bored, lonely) and picks something to do by what they need most, what they like and a bit of chance: Mum or Dad cooks at the stove, they sit at the dining table (and eat the food at their place when there is some: only Sophia serves food, from the fridge, and when she does they all come to eat with her), watch TV on the sofa, sleep in their own beds (z z z), read on the rug in their room, and the kids play in the playroom (opening the toy box, kicking the ball) and bounce on their beds. They walk room to room through the doorways and up and down the stairs, share out the chairs and beds (nobody takes the chair Sophia's in), wait politely when she's in their way, and when she comes up to them they turn and cheer with a burst of hearts. Being near each other keeps them from getting lonely. They show only on the storey you can see, and the house (and they) pause while you're outside.
- **Out of the windows:** the island isn't loaded indoors, so the same garden is built round the inside too: the fenced yard, the path, the flower beds and the backyard swings, trampoline and sandpit, with a lawn, trees, a beach and the sea out to the horizon beyond it, clouds and a soft sky. Unshadowed and cheap.
- **Saving:** her room's colours, and whether she was inside (new `[house]` keys only). Stopping the game inside starts her outside the front door next time, the plane parked safely nearby.
- **Edge cases:** calling the plane doesn't work indoors; the dragon (with the rest of the outdoor world) is paused while she's inside; nothing stands on the doorstep when she comes out.

---

## 13b. Other Buildings (Phase 5)

Any building with a front door, a doorstep and a floor plan can be walked into the same way as her house (`main.enter_building`): its inside is built the first time she goes in, high above the building, and kept; coming out puts her on its doorstep. A building's inside is usually its outside's size; the city's houses are 1.6 times bigger inside each way (`CityHouseLayouts.INSIDE_SCALE`), so their rooms feel like a home rather than a little shack (with an armchair, a cabinet and a plant in the living room, chairs at the kitchen table and a bedside cabinet in the bedroom).

- **The post offices** (all three): one sorting room the size of the shop outside. The postie stands behind a blue counter with parcels waiting on it and a wall of pigeonholes full of coloured letters behind him; he turns and cheers when she comes up. On her very first visit to a post office he gives her the **post office sticker** (a white envelope on blue): it pops up big on the screen, wiggles and flies into the corner (saved, `[stickers] have`; one per kind of building). The fun things are all walk-into: parcels ride a conveyor belt along the wall; standing on the big scales swings the needle round with a ding; walking into the pile of letters takes one, and walking it to the red post box posts it (whoosh, sparkle, the postie cheers), as many as she likes. A hidden star is tucked behind the end of the counter. A letter in her arms stays inside when she goes out. Outside, the parcel pad sits to the left of the front path, so walking in never picks up a parcel by accident.
- **The city's houses:** every finished house can be walked into. Each house MODEL has one floor plan (`scripts/buildings/city_house_layouts.gd`, kept apart from CityPlan so saved cities don't change), the size of the model as the city places it, with its front door where the model's door is (measured from front views, `docs/images/door_*.png`); the furniture varies with where the house stands. Mostly one floor: a living room across the front and a kitchen and a bedroom behind (the wide, shallow home_3 has them in a row); home_4 has two floors (stairs up the side, two bedrooms upstairs). Small rooms are furnished so nothing ever stands in a doorway or in front of a window (`SmallRoomFurnisher`). Each has an owner (a townsperson in one of six looks) who turns and cheers, and gives her the **house sticker** (a little house on green) on her first visit; one hidden star per house (floating low, under the windows). The way out is the doorway itself (walk into it), so crossing a small living room never takes her outside by accident.
- **The hat shop** (beside the airport post office, `HatShop`; a big straw hat turns slowly on its roof and a pink-and-white awning hangs over the windows): one room the size of the shop (`HatShopLayout`, `HatShopFurnisher`). The milliner, in a pink robe and a sun hat, stands behind a striped counter with hat boxes on the shelf behind her; she gives the **hat shop sticker** (a straw hat on pink) on the first visit. Hat stands with the hats on them line the walls; one hidden star sits behind the counter's end. The try-on **mirror** (`HatMirror`) stands against the wall on the door's side: walking past it does nothing; standing at it shows the Y hat prompt, and Y opens the **hat chooser** (`HatMenu`, all pictures): the camera comes round in front of her, close up and low, with the mirror behind her; the stick slides through the hats (each goes on her head straight away; the first is "no hat", her outfit's own); under the middle one a green tick if it's hers, or its price as little stars (gold if she has enough, grey if not); her stars to spend are in the corner. A wears it; a new one is bought first (the stars fly from her purse to the hat, she cheers); one she can't afford yet wobbles. B puts back the hat she came in with. The 12 hats (`Hats`: straw hat, beanie, flat cap, beret, sun hat, postie cap, ranger hat, chef's hat, pilot cap, dino hood, tiara, astronaut helmet) cost 3 to 10 stars; the menu pictures (`assets/ui/hats/`) are renders of the game's own props (`tools/hat_icons.tscn` remakes them). Her purse is her lifetime stars minus what she's spent, so collecting never stops counting; saved in new keys only (`[shop] stars_spent`, `hats_owned`, `hat`). The hat she wears replaces her outfit's headgear everywhere, flying and walking. In the city, a shop the news called a "hat shop" is the same inside (a straw hat on its roof too; the tall model, which has no ground-floor door, gets a blue door with an awning).
- Coming next (after she's tried the hat shop): more shops (a bakery, a toy shop...) on the same pattern.

---

## 13c. The World Reacts (Phase 6)

- **WorldEvents** (autoload, `scripts/core/world_events.gd`): one signal, `happened(kind, where, info)`, for what she does: `honk`, `low_pass` (lower than 22 m over the ground, faster than 18 m/s, at most every 1.5 s, not while landing), `landing`, `takeoff` (`info.surface` = runway or grass), `crash` (`info.water`), and `cheer` (her, on foot). The dragon hears honks through it now (not the plane's input).
- **Reactions** (`WorldReaction.add(node, radius, kinds, cooldown, callback)`: one line per reaction, so more are easy to add): the farm's sheep hop away and the cows trot off mooing, then wander back (honk or low pass within 170 m); a flock of white birds flaps up out of the forest below the plane (`BirdFlock`); townspeople within 70 m of a honk, 60 m of a low pass, or 28 m of her cheer stop, turn to face it and cheer (a third loop baked into the crowd's vertex animation, `tools/bake_kaykit_people.tscn`); the boat toots back with a puff of steam; the whale spouts; the penguins hop and slide off on their tummies, then waddle back; the dinosaurs call back. Not yet: castle flags.
- **Cheering**: X on foot (or indoors) makes her cheer, arms up; townspeople and delivery recipients nearby cheer back (mermaids wave).
- **Honk echoes** (`EchoZone`, buses made by GameSettings): over the mountains and Dragon Peak the honk comes back twice (delay); in the dragon's cave it booms (big reverb); over the city it rings off the buildings (short reverb); elsewhere, plain. Same honk sound, no new files.
- **Crash moments**: into the sea, a moment under the water (blue, light rays, bubbles, fish swimming by, everything muffled) inside the crash's usual pause, so it's still 1.75 s from the splash to the runway; on the volcano, a hot orange glow and embers.
- **Dust**: a cloud billows out from the wheels lifting off from grass (not the runway), puffs behind them on a fast grass roll, and little puffs at her feet when she runs.
- **Forgiveness**: Y while the plane is still rolling is remembered (the get-out prompt shows) and she hops out as soon as it stops (forgotten if she takes off again or pushes on). The parcel pickup (6.5 m, round a 4.6 m pad), hand-over (8.5 m) and get-back-in (9 m) distances were checked: already generous (a bigger pickup would grab a parcel walking straight into the post office). Parents have a third volume bar, the **loudest it ever gets** (a speaker under a ceiling line; 20-100 %, default 100 %), a cap on everything through the Master bus, separate from the limiter that only stops clipping (saved, `[settings] max_volume`).

## 13d. The Airport and Liveries (Phase 13)

- **The service loop** (`HangarService`, a child of the hangar): land, roll onto the big yellow pad in front of the hangar (a water drop and a fuel can painted inside the ring) and stop. The hangar's big sliding doors open (they're shut, and solid, the rest of the time), the marshaller in orange waves you in with his wands, the plane rolls inside (lights come on), gets a wash (jets of spray from both sides, bubbles everywhere, a sparkle), fills up with fuel (the gauge on the red pump fills, ding), turns round and rolls back out onto the pad facing the runway, parked and ready to go. No menus, nothing to get wrong, as often as she likes; Y can't get her out halfway through (she gets out once it's done). About 20 seconds.
- **Liveries**: the main paint stays as it is (D-pad); each plane also has a **trim colour** (X on the plane-select screen: the same eight colours, never locked) and one **decal** in the trim colour (LB / RB): a cheat-line stripe (always), a chequered band round the tail (50 stars), a broad rescue band (100), registration-style letters "LP-STAR" on both sides (150), a gold star on the tail (220). Earned with lifetime stars, kept once earned. The plane-select screen shows them all as pictures (padlocks and the stars needed on the ones still to come). Decals sit on each aircraft's fuselage box (`AircraftStats.livery_body`), so a new model only needs its box. Saved in new keys (`[livery] trims`, `decals`) with the same safety as everything else.

## 13e. Sky-writing (Phase 14, item 1)

- Hold **RB** while flying and the plane leaves puffs of smoke in its paint colour behind its tail; they hang in the sky for about a minute, slowly spreading and fading, so she can draw loops and squiggles. **Why RB:** nothing uses LB or RB while flying (they only change tabs on the character screen and decals on the plane-select screen), so it can't clash with A (boost), B (honk), X (roll) or Y (get out), and holding a shoulder button is easy alongside the stick. Keyboard: X.
- One MultiMesh for the whole sky (up to 1300 puffs, one draw call); their fading is updated four times a second. `SkyWriter`, `skywriting_test`.

## 13f. Today, for the parent (Phase 14, item 3)

- A calendar button beside the gear in the pause menu opens **Today**: big pictures with numbers for the stars collected, parcels delivered, crashes and minutes played today, and a row of the islands (lit with a tick when she visited them today). From data the game already tracks: stars, deliveries and time where they're counted, crashes from WorldEvents, islands from a tracker that checks where she is every few seconds (`TodayTracker`). A new day starts afresh. New save keys only (`[today] date`, `counts`). `SummaryScreen`, `summary_test`.

## 13g. Sticker book and postcard camera (Phase 14, item 2)

- **The book**: a big purple book button in the pause menu. All pictures, five tabs (LB / RB, or tap the tab pictures): **places** (every landmark), **animals** (farm animals, penguins, dinosaurs, the whale, dolphins, the dragon), **friends** (everyone she can deliver to), **stickers** (from the buildings) and **postcards**. Things not found yet are "?" cards; the stick moves round the page; B closes. Small names under the pictures, for the grown-up reading along.
- **Pictures that take themselves** (`Spotter`): the first time a place, animal or friend is near and on screen, the game snaps its picture into the book (the HUD hidden for that one frame); a friend is snapped when she hands them a parcel. Places she found before this existed get their picture the next time she's near.
- **Postcards**: **LB** while playing (flying, on foot or indoors) takes a photo, with a click and a white flash; the newest 48 are kept. Why LB: it's free everywhere in play (RB is sky-writing).
- Saved as small pictures in `user://book/` and `user://postcards/`; which ones exist in new save keys (`[book] seen`, `postcards`). Nothing leaves the computer. `StickerBook`, `sticker_book_test`.

## 13h. Parachute drops (Phase 14, item 4)

Mermaid mail grew into **parachute mail** for friends where the plane can't land. Fly low over them with their parcel and it floats down on a parachute into their arms. It follows them while it falls, so a moving boat still catches it.
- **The sailor** rides the little sail boat off the south coast (main island, so early on).
- **The hiker** stands on the tallest mountain's snowy summit.
- **The pirate captain** stands on the friendly pirate ship's deck (other islands, later). The pass can be a little higher and wider, because the ship nudges planes away from its masts.
- "Low" means low *above them*, not above the sea, so the summit works. The beacon rides along with the boats.
- `RecipientData.by_air` / `ride` / `drop_radius` / `drop_height`; the delivery bubble has new boat and mountain pictures. `parachute_test`.

## 13i. Sailing and docks (Phase 14)

- **Docks**: a wooden pier on every major island. Main (the beach past the farm: her boat's home), Palm, Volcano, Ice, Dino, Castle and Town. Each is a walkway from the beach out to deep water, a platform at the end, lanterns and a flag in the island's colour. Spots were chosen by scanning each coast for a gentle beach with deep water a short pier's length out, facing home where possible (`Dock.SPOTS`).
- **Her sail boat** (the same CC0 sail boat as the one cruising off the south coast). Walk to the end of the pier and press **Y** to sail. She stands at the helm in her own clothes and hat.
  - It always sails gently forward (like the plane flies). Stick up goes faster, back slows (and backs up a little), left/right steers, and RT is a gust of wind.
  - The **honk** button toots the horn, which things nearby hear.
  - It leans in the turns and leaves a white wake.
  - It stops softly before shallow water and piers, so it never runs aground.
- **Arriving**: near any dock, **Y** glides it into the berth and she steps off onto the pier. Where it's moored is saved (`[boat] dock`).
- **Calling it**: if she flew to an island and her boat is moored somewhere else, **Y** at the end of that pier calls it, and it sails in tooting. So every dock always works.
- `State.SAILING`, `SailBoat`, `SailCamera` (right stick looks around), `boat_test`.

## 13j. Seaplane (Phase 14, item 5)

- A third plane in the hangar: the **Seaplane**, the prop plane on two white floats (like a real amphibious floatplane, the wheels stay, so it still uses the runway). Slightly gentler and slower than the prop plane.
- It reuses the flight controller and the waves: for a plane with floats (`AircraftStats.floats`), open sea counts as a landable surface.
  - Coming down onto the sea is a splashy **landing**, never a crash (both modes, like flat ground).
  - It slows on the water and parks, **bobbing on the waves**.
  - Boost and it speeds across the water in spray and lifts off, then climbs gently clear of the waves by itself for a moment so it doesn't skim straight back down.
  - On the water it turns more readily, and noses round before beaches, piers and boats (never runs aground).
- Afloat at sea there's nowhere to stand, so she stays in (no Y to get out). Other planes still splash into the sea as before.
- `SeaplaneFloats`, `seaplane.tres`, `seaplane_test`.

## 13k. The loop trick (Phase 14, item 6)

- **X while holding the stick to climb** does a loop; X on its own is still the barrel roll.
- **Purely visual, like the barrel roll.** The plane can't fly real loops (its pitch limit is untouched), and its real flight path, pitch limits and safety system don't change. The model swings up and over in a circle about 9 m across *above* the real path, never below it, so it can't hit the ground.
  - It goes upside down at the top and really travels backwards there.
  - It lands back on the path after 2.6 s, while the rainbow trails draw the loop.
- **Camera:** the chase camera rises part way with it, to keep it in the picture.
- **Room:** under a roof or overhang, or near the sky's ceiling, it does a barrel roll instead. A crash or respawn mid-loop puts the model straight back.
- `AircraftVisuals.loop()`, `Aircraft.trick()`, `loop_test`.

## 13l. Fixes round 1 (after the user's playtest)

- **See-through houses**: the city's walk-in house models are hollow shells with open window holes, drawn from outside only, so you could see straight through them. They now draw both sides of their walls (the tinted roofs' recolour shader too), plus a dim "room" box inside each (sized from the model's own walls), so the windows look like windows (`CityGrowth.double_sided`, `walls_of`).
- **Boats sailed backwards**: the sail boat model's bow is +Z; her boat and the cruising boat now sail bow first (and she faces forward at the helm). The **dolphins** leapt tail first: turned round too.
- **Boats through small islands and other boats**: `DeliveryManager.ground_at` now knows the islets and the lagoon atoll; boats (and the seaplane taxiing) stop for the cruising boat, the pirate ship, the whale, the mermaids' rocks (`SeaTraffic`) and piers; a boat sailing into hers nudges it aside.
- **Red and green circles on the planes**: the Phase 9 navigation-light dots read as stray circles on the models and were removed.
- **Her attic**: a third floor up a second flight of stairs from the landing (`"attic": true` in her_house.json: inside the roof, so the outside builds no walls for it; round windows in the gables).
- **Bigger city house insides** (1.6x, see above).
- Also: swapping out of the seaplane while afloat lifts the new plane into the air; the sticker book camera no longer prints an error in headless test runs.

## 13m. Fixes round 2: realistic planes (vinish.dev models)

- The parent pointed at vinish.dev's free models (CC BY 4.0: credit required, already allowed by the asset rules). Its **Biplane** replaces the old biplane (her character flies it from the rear cockpit), its **Light Plane** is a new plane in the hangar, and the **Seaplane** is now the light plane on floats (a real floatplane shape). The jet stays (theirs is a military fighter).
- Credited in `resources/credits.json` / CREDITS.md with what was changed.

## 13n. Follow-the-leader (Phase 14, item 7)

- Every few minutes of free flying (first after about 2 minutes, then every 4), a **friendly plane** (the Light Plane in bright orange, with bold rainbow trails) pulls up just ahead of her, toots twice and waggles its wings: follow me!
- It flies a loose scenic loop, chosen by where she is: **round the city and the lighthouse**, **over the farm and the forest**, or **through the mountain valley**. It always stays well above the ground (at least 60 m over the highest ground near its path).
- **No timer and no penalty.** Close behind, it matches her speed. If she lags, it slows down. Far away (or out of the plane), it circles where it is and waits. If she's been far away for a while (she went off to do something else), it waggles goodbye, climbs away and comes back another time.
- At the end of the loop: bursts of colour in the sky, booms and a fanfare, and **5 bonus stars**. Honk at it and it toots back.
- `FollowLeader` (`main.leader`), `follow_test`.

## 13o. All-stars reward (Phase 14, item 8)

- Every floating star she's ever picked up is remembered (by where it sits: `[progress] stars_found`), across all her days of play, so "all the stars" means **every star found at least once**, not all in one go. (There are 224 at the moment.)
- **Finding the last new one changes the world for good** (`[progress] all_stars`): a fanfare and a news line ("Every star found! The rainbow sparkles for ever."). From then on:
  - the **rainbow arch sparkles for ever**: gold and white twinkles all over it;
  - **flying through it sets off fireworks**: big bursts all round the arch straight away, and a show of rockets high above it for ten seconds.
- The parent's **Today** page shows how many she's found ("150 / 224 stars found").
- `StarManager.every_star_found`, `RainbowArch.set_golden`, `all_stars_test`.

## 13p. Gentle weather (Phase 14, item 9)

- Every few minutes of play (first after about 3, then every 6) a **soft grey rain cloud** drifts slowly across near her (4 m/s, at least 135 m up), rain streaks falling from it with a quiet shower hiss (`amb_rain`; a real `assets/audio/loops/amb_rain.ogg` replaces it). **No thunder, no lightning**, and the sky stays bright.
- **Flying under it washes the paint off**: a splash, and the plane is plain white. Only for now: her chosen colour is kept in the save.
- Then **a rainbow** grows up just ahead of her, tall enough to fly under its arch. **Flying through it brings her colour back** with a sparkle and a fanfare. If she doesn't, the colour comes back by itself when the rainbow fades after a minute (and the D-pad still paints the plane any time). On foot nothing is washed.
- `Weather` (`main.weather`), `weather_test`.

## 14. Future Ideas

| Idea | Description | Complexity |
|---|---|---|
| **Additional aircraft** | Helicopter (can hover), hot-air balloon (very slow), seaplane (lands on water), a small rocket | Low–Medium. Data-driven aircraft make this cheap, though a helicopter needs a new controller. |
| **Paint colours** | Choose the plane's colour from big swatches using the D-pad or a paint shop screen. A material colour swap. | Low |
| **Weather** | Gentle rain, snow on the mountains, rainbows after rain, sunset or night with glowing stars. Keep it calm and never scary. Avoid thunder. | Medium |
| **More maps** | Desert canyon, snowy village, city with parks, space level | High (mostly asset work) |
| **Co-op flying** | **Local split-screen** with a second controller for a parent and child. No online play. | High. Split-screen halves performance on the Steam Deck. |
| Sticker book | Picture-based log of discovered landmarks | Low–Medium |
| Photo mode | Freeze and take a picture | Low |
| Landing on the runway | An optional, auto-assisted landing for a celebration | Medium |

---

## 15. Open Questions

- [ ] Should the jet be available from the start, or unlocked after collecting N stars? *(Recommendation: available from the start. Unlocks add friction for a 4-year-old.)*
- [ ] Should there be a voice narrator (for example "You found the lighthouse!")? It helps non-readers but needs recording.
- [ ] Should there be a Steam Deck gyro steering option?
- [ ] Should there be a parent play-time limit feature?
