# Little Pilot — Game Design Document

| | |
|---|---|
| **Version** | 0.1 (pre-production draft) |
| **Engine** | Godot 4 (GDScript, Mobile renderer) |
| **Primary platform** | Steam Deck |
| **Target player** | Age 4 |

---

## 1. Game Vision

> **A relaxing 3D flying sandbox for young children.**

Little Pilot is the feeling of flying a toy plane around a sunny island. The child is never wrong, never stuck and never punished. Each minute should hold small moments of delight: a sparkle, a chime, a lighthouse beam, a whoosh past a wind turbine.

### Design Pillars

| Pillar | What it means in practice |
|---|---|
| **Safe** | The plane cannot crash, stall, run out of fuel or fly off the map. |
| **Simple** | One stick flies the plane. Everything else is optional. |
| **Joyful** | Every action gets a cheerful sound, effect or animation. |
| **Free** | No objectives, no timers, no required order. |

### Design Test

For any new feature, ask: **"Could a 4-year-old trigger this by accident and get upset?"** If yes, redesign it or cut it.

---

## 2. Player Experience

### 2.1 Easy to Learn
- The plane is flying within **10 seconds** of launch, with no tutorial screens.
- Pushing the stick visibly moves the plane right away. The child learns by doing.
- On-screen hints are pictures, such as an animated stick icon. They appear only if the child hasn't touched the controls for a while.

### 2.2 Impossible to Crash

The flight controller is **kinematic and arcade-style**, not a physics simulation. These safety systems always run:

| System | Behaviour |
|---|---|
| **Minimum speed** | The plane never drops below cruise speed, so it can't stall. |
| **Ground and water avoidance** | Rays sample the terrain below and ahead. As the plane gets close, it gently pitches up on its own. It cannot go below a minimum clearance. |
| **Obstacle avoidance** | Landmarks such as the lighthouse and turbines have soft "push" volumes that nudge the plane around them. It never hits a hard collision. |
| **Auto-level** | When the stick is released, the plane smoothly returns to level flight. |
| **Altitude ceiling** | Above a set height, the plane gently levels off and stops climbing. |
| **World boundary** | Near the edge of the map, the plane curves back toward the island in a wide, natural turn. There is no wall and no warning. |
| **Spin protection** | Roll and pitch are clamped. The plane can't go upside down or get disoriented. Loops may come later as a scripted trick. |

> **Rule:** If the child holds the stick in any direction indefinitely, the result must still look fun and safe, such as a steady circle or a gentle climb that levels out.

### 2.3 Free Exploration
- The island is open from the start. Nothing is locked.
- Landmarks are visible from far away, so they work as natural goals.
- Paths of stars lead toward interesting places without forcing a route.

### 2.4 Discover Landmarks
- Each landmark has a **discovery radius**. The first time the plane enters it in a session:
  - a short celebratory jingle plays
  - the landmark does something, for example the lighthouse beam flashes, turbines spin faster, farm animals hop, or a boat toots
- **Stretch goal:** a picture-based "Sticker Book" that fills in as landmarks are discovered.

### 2.5 Collect Stars
- Stars float in the air across the island. See [Section 7](#7-collectibles).
- Collecting one is instant and satisfying: sparkle, rising chime, counter bump.

---

## 3. Aircraft

Both aircraft share the same controller code and differ only in a tuning resource (`AircraftStats.tres`). Adding a new aircraft is a data change, not a code change.

| Stat | Prop Plane | Fighter Jet |
|---|---|---|
| Cruise speed | Medium | Fast (~1.6× prop) |
| Boost speed | 1.5× cruise | 1.5× cruise |
| Turn rate | Gentle | Quick |
| Responsiveness (input smoothing) | Soft, floaty | Snappy |
| Bank angle (visual) | Large and swoopy | Moderate and sharp |
| Auto-level speed | Fast (forgiving) | Medium |
| Camera distance | Close | Slightly further back |
| Engine sound | Buzzy propeller | Smooth whoosh |
| Trail effect | Small puffs | Contrail streaks |

### 3.1 Prop Plane — *the default*
- **Medium speed, easy control.**
- Wide, forgiving turns. Inputs are heavily smoothed so jerky stick movements still look graceful.
- Bright primary colours with a spinning propeller and a friendly face (optional).

### 3.2 Fighter Jet — *the exciting one*
- **Faster, more responsive.**
- Tighter turns and less smoothing. The world rushes past for a strong sense of speed.
- Still has every safety system. Ground avoidance looks further ahead to cover the higher speed.
- Toy-like, rounded, non-military look. Cartoon proportions and no weapons.

### 3.3 Tuning Notes
- Tune the feel with **the actual child**, not just the developer. Adults usually tune too fast and too sensitive.
- Turn tuning values into `@export` variables so they can be adjusted live in the editor.

---

## 4. Controls

### 4.1 Steam Deck (Primary)

The Steam Deck uses the standard gamepad layout. Godot sees it as an Xbox-style controller through Steam Input.

| Input | Action | Notes |
|---|---|---|
| **Left stick** | Fly: up/down = climb/dive, left/right = turn | The plane banks into turns on its own. **Up = climb** by default, not inverted. |
| **Right stick** | Look around | The camera drifts back behind the plane when released. |
| **R2 (right trigger)** | Boost | Speeds up while held. Releasing returns to cruise speed. |
| **A** | Boost (alternate) | Small hands may struggle with triggers |
| **B** | Honk / beep 🎺 | Pure fun. No gameplay effect. |
| **X** | Do a trick (future) | For example a barrel roll. Scripted and safe. |
| **Y** | Change camera | Cycles chase-close → chase-far |
| **L2 (left trigger)** | Slow down | Never below minimum cruise speed |
| **Menu (≡)** | Pause menu | Big picture buttons: *Resume*, *Change Plane* |
| **View (⧉)** | No action | Avoids accidental actions |
| **D-pad** | No action at launch | Reserved for paint colours later |
| **Trackpads / Gyro** | Not used | Gyro steering is a possible future option, off by default |

#### Control Design Rules
- **No button is ever required.** The game is fully playable with the left stick alone.
- **No input is ever harmful.** Mashing every button at once must not cause anything bad.
- **Large dead zone** (~0.2) on the sticks, so a resting thumb doesn't steer.
- **Quitting needs a deliberate parent action.** For example, the pause menu has a "Quit" button that must be held for 2 seconds.
- **Known limitation:** The Steam and Quick Access (`...`) buttons are system buttons and the game cannot block them. A child can leave the game this way.

### 4.2 Keyboard (Development / Linux desktop)

| Key | Action |
|---|---|
| WASD / Arrow keys | Fly |
| Shift / Space | Boost |
| H | Honk |
| C | Change camera |
| Esc | Pause |

### 4.3 iPad (Future)
- A **virtual joystick** on the left half of the screen. Wherever the thumb lands becomes its centre.
- A big **boost** button and a **honk** button on the right.
- An alternative to consider: "tilt to fly" using the gyro, though it is often too hard for young children.

---

## 5. Camera

- **Chase camera** behind and slightly above the plane, using a spring arm with smoothing.
- Field of view widens slightly during boost to add a sense of speed.
- The camera **never clips into terrain**. A spring-arm collision pulls it closer instead.
- No sudden cuts and no camera shake, to avoid motion sickness.
- Two presets: **Close** (default) and **Far**.

---

## 6. Environment

A single **handcrafted island** surrounded by ocean, roughly 2–3 km across. Every landmark is reachable within about 60 seconds of flying from the start point at the runway.

### 6.1 Layout Sketch

```
                 N
        ~~~~~~~~~~~~~~~~~~~~~~~~
      ~~   ▲▲▲  MOUNTAINS  ▲▲   ~~
     ~~   ▲▲▲▲▲      ▲▲▲▲▲       ~~
    ~~  🌲🌲 FOREST 🌲🌲   ⚡⚡ TURBINES ~~
   ~~  🌲🌲🌲🌲🌲      ⚡⚡⚡ (ridge)   ~~
   ~~       ════ RUNWAY ════        ~~
   ~~   🏠 FARMS 🌾🌾     🛥️         ~~
    ~~   🌾🌾🌾🌾       🗼 LIGHTHOUSE ~~
      ~~~~~~~~~~~~ OCEAN ~~~~~~~~~~~~
```

### 6.2 Areas and Landmarks

| Area | Description | Discovery reaction | Star placement idea |
|---|---|---|---|
| **Airport Runway** | Spawn point. Small tower, windsock, hangar. | Windsock flaps, a ding plays | Arc of stars leading away from the runway |
| **Mountains** | 2–3 rounded, snow-capped peaks. A valley to fly through. | Echo "yoo-hoo!" sound | Stars through the valley, one on top of the peak |
| **Forests** | Clusters of chunky, low-poly trees | Birds fly out of the trees | Stars weaving between treetops |
| **Farms** | Red barn, fields, fences, animals, tractor | Animals hop, rooster crows | Stars over fields in fun shapes (a heart, a circle) |
| **Lighthouse** | On a rocky point by the coast | Beam spins faster, foghorn | A spiral of stars around the tower |
| **Wind Turbines** | A row of 4–6 turbines on a ridge | Blades spin faster with a whoosh | Stars between (never inside) the blade sweep zones |
| **Ocean** | Surrounds the island. Calm waves, a boat, maybe whales. | Whale splashes, boat toots | Low stars skimming above the water |

### 6.3 Visual Style
- **Low-poly, flat-shaded, saturated colours.** Cheap to render, easy to source, and readable for kids.
- Always sunny daytime at launch. Soft shadows. Fog hides the edge of the world.
- Clear silhouettes so each landmark can be recognised from far away.

### 6.4 Performance Budget (Steam Deck)
- **60 FPS at 1280×800.** A 30 FPS cap is an acceptable fallback for battery life.
- Under ~300 draw calls on screen. Use MultiMesh for trees and props.
- Visibility ranges (LOD) on trees and small props.
- Water is a simple shader, with no real-time reflections.

---

## 7. Collectibles

### 7.1 Floating Stars — High-Level Design

| Aspect | Design |
|---|---|
| **Look** | Chunky gold 3D star with soft glow, slowly spinning and bobbing |
| **Size** | Large, about 1.5× the plane's wingspan. Generous pickup radius, roughly 2× the visual size. |
| **Collection** | Fly through it, using an `Area3D` trigger. No button press. |
| **Feedback** | Sparkle burst, a rising chime (pitch climbs with consecutive pickups), and the counter pops |
| **Quantity** | About 50 stars on the island |
| **Placement** | In **trails** (5–10 stars) that guide toward landmarks, plus a few "special" stars in fun spots |
| **Respawn** | When every star is collected, play a big celebration (fireworks, music sting). Then all stars respawn so the game never "runs out". |
| **Persistence** | Lifetime star total saved locally. Per-session stars reset on launch. |

### 7.2 Star Counter UI
- A **star icon plus number** in a corner, sized for a small screen.
- 4-year-olds may not read numbers well, so also show a **"star jar"** that fills up visually.
- **Milestones** at 10, 25 and all stars give a short celebration with no interruption to flying.

### 7.3 Future Collectible Ideas
- Rainbow rings to fly through
- Balloons that pop into confetti
- Hidden "golden star" per landmark

---

## 8. User Interface

| Screen | Contents | Notes |
|---|---|---|
| **Title** | Logo, a big "▶" button, the plane flying in the background | Any button starts the game |
| **Plane Select** | Two large plane pictures. Left/right to pick, A to fly. | No text needed. The choice is saved. |
| **HUD** | Star counter or jar only | Keep the screen clean |
| **Pause** | Resume ▶, Change Plane ✈️, Quit (hold to confirm) | Large icons |

UI rules: big targets, high contrast, icons before text, and every button press makes a sound.

---

## 9. Audio

| Type | Content |
|---|---|
| **Music** | 1–2 gentle, looping, upbeat tracks. A low default volume. |
| **Engine** | Looped. Pitch follows speed. |
| **Wind** | Gets louder with speed |
| **Stars** | Chime with rising pitch |
| **Landmarks** | One signature sound each |
| **Honk** | Silly horn per aircraft |
| **UI** | Soft clicks and pops |

Audio uses three buses: **Master**, **Music** and **SFX**. A parent-only settings screen controls the volumes.

---

## 10. Save Data

- Stored with Godot `ConfigFile` at `user://save.cfg`.
- Contents: selected aircraft, lifetime star count, landmarks discovered, volume settings.
- **Corrupt or missing save → silently use the defaults.** Never show an error to the child.

---

## 11. Accessibility and Child Safety

- No online connectivity, accounts, ads, analytics or purchases.
- No flashing effects faster than 3 Hz. Avoid strobe effects.
- Colours must be readable for common forms of colour blindness. Stars use shape and glow, not colour alone.
- Volume is capped at a sensible maximum.
- Optional **play timer** for parents (future): after X minutes, the plane lands itself gently with a "bedtime" animation.

---

## 12. Future Ideas

| Idea | Description | Complexity |
|---|---|---|
| **Additional aircraft** | Helicopter (can hover), hot-air balloon (very slow), seaplane (lands on water), cartoon rocket | Low–Medium. Data-driven aircraft make this cheap, though a helicopter needs a new controller. |
| **Paint colours** | Choose the plane's colour from big swatches using the D-pad or a paint shop screen. A material colour swap. | Low |
| **Weather** | Gentle rain, snow on the mountains, rainbows after rain, sunset or night with glowing stars. Keep it calm and never scary. Avoid thunder. | Medium |
| **More maps** | Desert canyon, snowy village, city with parks, space level | High (mostly asset work) |
| **Co-op flying** | **Local split-screen** with a second controller for a parent and child. No online play. | High. Split-screen halves performance on the Steam Deck. |
| Sticker book | Picture-based log of discovered landmarks | Low–Medium |
| Photo mode | Freeze and take a picture | Low |
| Landing on the runway | An optional, auto-assisted landing for a celebration | Medium |

---

## 13. Open Questions

- [ ] Should the jet be available from the start, or unlocked after collecting N stars? *(Recommendation: available from the start. Unlocks add friction for a 4-year-old.)*
- [ ] Should there be a voice narrator (for example "You found the lighthouse!")? It helps non-readers but needs recording.
- [ ] Should there be a Steam Deck gyro steering option?
- [ ] Should there be a parent play-time limit feature?
