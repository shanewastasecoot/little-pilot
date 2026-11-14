# Little Pilot — Asset List

This file tracks every asset the game needs, from placeholder to final.

## How to Use This List

Each asset has two checkboxes:

- **Placeholder Asset**: a quick stand-in (Godot primitives, CSG or a free pack) so gameplay can be built and tested.
- **Final Asset**: the version that ships.

**Status** values:

| Status | Meaning |
|---|---|
| ⬜ Not started | Nothing in the project yet |
| 🟨 Placeholder | Placeholder in game, final pending |
| 🟦 In progress | Final asset being made or integrated |
| ✅ Final | Final asset in game and license recorded |

### Asset Rules
1. **Record the license for every third-party asset** in `CREDITS.md` before committing it.
2. Prefer **CC0** (no attribution needed). CC-BY is fine with credit. **Avoid** "non-commercial" and unclear licenses.
3. Use a **consistent low-poly, flat-shaded style.** Mixing packs from different artists can look messy, so prefer one or two main sources.
4. 3D models are imported as **`.glb`**, textures as **`.png`**, sound effects as **`.wav`**, and music as **`.ogg`**.
5. All binary assets are stored with **Git LFS**.

### Suggested Free Sources
| Source | Licence | Good for |
|---|---|---|
| Kenney.nl | CC0 | Aircraft, nature, buildings, UI, audio |
| Quaternius | CC0 | Low-poly nature, animals, buildings |
| Poly Pizza | Mixed (check each asset) | Individual low-poly models |
| OpenGameArt.org | Mixed (check each asset) | Audio, music, textures |
| Freesound.org | Mixed (check each asset) | Sound effects |
| Poly Haven | CC0 | Skyboxes and HDRIs, textures |

---

## 1. Aircraft Models

- **Prop Plane** · Status: ✅ Final · Phase 2
  - [x] Placeholder Asset: CSG boxes and cylinders (body, wings, tail, propeller)
  - [x] Final Asset: red biplane `.glb` (Jake Blakeley, CC-BY 3.0) + code-built spinning propeller
- **Fighter Jet** · Status: ✅ Final · Phase 3
  - [x] Placeholder Asset: CSG shapes in a different colour from the prop plane
  - [x] Final Asset: trainer jet `.glb` (Poly by Google, CC-BY 3.0), recoloured blue, no weapons
- **Propeller spin effect** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: rotating mesh
  - [ ] Final Asset: blurred disc texture shown at speed
- **Engine trail / contrail particles** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: default `GPUParticles3D` quads
  - [ ] Final Asset: puff texture (prop) and streak texture (jet)
- **Plane select previews** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: live 3D model in a `SubViewport`
  - [ ] Final Asset: polished turntable or rendered `.png` per plane

## 2. Terrain Assets

- **Island terrain mesh / heightmap** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: greybox plane with primitive hills (Phase 2)
  - [ ] Final Asset: sculpted island (Blender mesh or Terrain3D heightmap)
- **Terrain textures / vertex colours** (grass, rock, sand, snow, dirt) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: flat colour materials
  - [ ] Final Asset: stylised flat-shaded materials
- **Ocean water** · Status: ⬜ Not started · Phase 2/5
  - [ ] Placeholder Asset: flat blue plane
  - [ ] Final Asset: stylised water shader (gentle waves and foam at the shoreline)
- **Rocks / cliffs** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: grey spheres
  - [ ] Final Asset: low-poly rock set (3–5 variants)
- **Runway surface and markings** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: dark grey box
  - [ ] Final Asset: runway mesh with centreline and numbers
- **Farm fields** (crop rows, fences) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: coloured flat quads
  - [ ] Final Asset: crop meshes and fence pieces

## 3. Trees

- **Pine / conifer trees** (2–3 variants) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: green cone on a brown cylinder
  - [ ] Final Asset: low-poly pine set
- **Round deciduous trees** (2–3 variants) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: green sphere on a brown cylinder
  - [ ] Final Asset: low-poly broadleaf set
- **Snowy pine trees** (mountain tops) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: white-tinted cone
  - [ ] Final Asset: snow-capped pine variant
- **Bushes / shrubs** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: small green spheres
  - [ ] Final Asset: low-poly bush set
- **Palm trees** (beach, optional) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: cylinder with flat leaves
  - [ ] Final Asset: low-poly palm
- **Tree LOD / impostors** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: visibility range culling only
  - [ ] Final Asset: lower-poly LOD versions for distant trees

## 4. Buildings

- **Lighthouse** (with rotating beam) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: white/red striped cylinder with a cone light
  - [ ] Final Asset: lighthouse `.glb` with a separate lamp node and beam mesh
- **Wind turbines** (with spinning blades) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: tall cylinder with 3 thin boxes
  - [ ] Final Asset: turbine `.glb` with a separate rotor node
- **Control tower** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: box with a glass-coloured top
  - [ ] Final Asset: low-poly tower
- **Hangar** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: half-cylinder
  - [ ] Final Asset: low-poly hangar
- **Windsock** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: pole with an orange cone
  - [ ] Final Asset: animated windsock
- **Red barn** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: red box with a prism roof
  - [ ] Final Asset: low-poly barn
- **Farmhouse** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: box house
  - [ ] Final Asset: low-poly farmhouse
- **Silo** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: cylinder with a dome
  - [ ] Final Asset: low-poly silo
- **Farm animals** (cow, sheep, chicken, pig) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: coloured capsules
  - [ ] Final Asset: low-poly animated animals (idle and hop)
- **Tractor** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: boxes and cylinders
  - [ ] Final Asset: low-poly tractor
- **Boat** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: box hull
  - [ ] Final Asset: low-poly fishing boat
- **Whale** (optional) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: dark capsule
  - [ ] Final Asset: friendly low-poly whale with a splash animation

## 5. Audio

### Music
- **Gameplay music loop** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: any CC0 loop
  - [ ] Final Asset: gentle, upbeat seamless loop (`.ogg`)
- **Menu music loop** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: none (silence)
  - [ ] Final Asset: calmer seamless loop (`.ogg`)
- **Celebration sting** (all stars) · Status: ⬜ Not started · Phase 4/6
  - [ ] Placeholder Asset: generic jingle
  - [ ] Final Asset: short triumphant tune

### Aircraft SFX
- **Prop engine loop** · Status: ⬜ Not started · Phase 2/6
  - [ ] Placeholder Asset: synthesised buzz
  - [ ] Final Asset: friendly propeller loop
- **Jet engine loop** · Status: ⬜ Not started · Phase 3/6
  - [ ] Placeholder Asset: noise loop
  - [ ] Final Asset: smooth, non-harsh jet whoosh loop
- **Boost whoosh** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: generic whoosh
  - [ ] Final Asset: tuned whoosh
- **Wind loop** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: white noise
  - [ ] Final Asset: soft wind ambience
- **Honk — prop plane** · Status: ⬜ Not started · Phase 2/6
  - [ ] Placeholder Asset: any horn
  - [ ] Final Asset: silly toy horn
- **Honk — jet** · Status: ⬜ Not started · Phase 3/6
  - [ ] Placeholder Asset: any horn
  - [ ] Final Asset: different silly horn

### Gameplay SFX
- **Star collect chime** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: single bell
  - [ ] Final Asset: chime set or a single note pitched up at runtime
- **Milestone jingle** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: generic jingle
  - [ ] Final Asset: short happy jingle
- **Fireworks** · Status: ⬜ Not started · Phase 4/6
  - [ ] Placeholder Asset: pop sound
  - [ ] Final Asset: soft, non-scary firework pops

### Landmark SFX
- **Landmark discovery jingle** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: generic chime
  - [ ] Final Asset: signature discovery sound
- **Lighthouse foghorn** (gentle) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: low tone
  - [ ] Final Asset: soft foghorn
- **Turbine whoosh** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: whoosh
  - [ ] Final Asset: rhythmic blade whoosh
- **Farm animals** (moo, baa, cluck, rooster) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: any animal sound
  - [ ] Final Asset: friendly animal sound set
- **Birds** (forest) · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: chirp
  - [ ] Final Asset: bird flutter and chirps
- **Mountain echo "yoo-hoo"** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: any voice clip
  - [ ] Final Asset: recorded or licensed echo clip
- **Boat toot / whale splash** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: generic horn and splash
  - [ ] Final Asset: tuned versions
- **Ocean waves ambience** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: noise
  - [ ] Final Asset: gentle wave loop

### UI SFX
- **UI move / confirm / back** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: Kenney UI pack
  - [ ] Final Asset: consistent soft pop / click set

## 6. UI Icons

- **Game logo** ("Little Pilot") · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: text label in a bold font
  - [ ] Final Asset: illustrated logo `.png`
- **Play button** (▶) · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: Godot button with "▶"
  - [ ] Final Asset: large rounded icon
- **Prop plane icon** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: screenshot of the placeholder model
  - [ ] Final Asset: illustrated or rendered icon
- **Jet icon** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: screenshot of the placeholder model
  - [ ] Final Asset: illustrated or rendered icon
- **Star counter icon** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: Kenney star icon
  - [ ] Final Asset: icon matching the 3D star
- **Star jar** (empty, fill stages, full) · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: `ProgressBar`
  - [ ] Final Asset: illustrated jar with a fill mask
- **Pause / Resume / Change Plane / Quit icons** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: Kenney UI icons
  - [ ] Final Asset: consistent rounded icon set
- **Gamepad hint icons** (stick, A, B, R2) · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: Kenney input prompts
  - [ ] Final Asset: same set (Kenney input prompts are CC0 and good enough)
- **Settings / volume icons** · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: text buttons
  - [ ] Final Asset: speaker and music note icons
- **UI font** · Status: ⬜ Not started · Phase 3
  - [ ] Placeholder Asset: Godot default font
  - [ ] Final Asset: rounded, child-friendly font under the OFL licence
- **Steam library artwork** (grid, hero, logo, icon) · Status: ⬜ Not started · Phase 6
  - [ ] Placeholder Asset: none
  - [ ] Final Asset: images at Steam's non-Steam game artwork sizes

## 7. Skyboxes

- **Daytime sky** · Status: ⬜ Not started · Phase 2/5
  - [ ] Placeholder Asset: Godot `ProceduralSkyMaterial`
  - [ ] Final Asset: tuned procedural sky or a stylised panorama
- **Clouds** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: none
  - [ ] Final Asset: low-poly cloud meshes (fly-through, no collision)
- **Distant horizon / fog** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: default fog
  - [ ] Final Asset: tuned depth fog colour that matches the sky
- *(Future)* **Sunset sky** · Status: ⬜ Not started · Post-1.0
  - [ ] Placeholder Asset: tinted procedural sky
  - [ ] Final Asset: sunset sky preset
- *(Future)* **Night sky with stars** · Status: ⬜ Not started · Post-1.0
  - [ ] Placeholder Asset: dark procedural sky
  - [ ] Final Asset: starry night panorama

## 8. Collectibles

- **Floating star model** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: yellow `PrismMesh` or CSG star
  - [ ] Final Asset: chunky extruded star `.glb`
- **Star material / glow** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: emissive yellow `StandardMaterial3D`
  - [ ] Final Asset: tuned emissive with a fresnel rim shader
- **Star idle sparkle particles** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: none
  - [ ] Final Asset: subtle twinkle particles
- **Star collect burst** · Status: ⬜ Not started · Phase 4
  - [ ] Placeholder Asset: default particle burst
  - [ ] Final Asset: gold sparkle burst with a star-shaped particle texture
- **Celebration fireworks** · Status: ⬜ Not started · Phase 4/6
  - [ ] Placeholder Asset: coloured particle burst
  - [ ] Final Asset: multicolour firework particles (slow, no strobing)
- **Landmark discovery effect** · Status: ⬜ Not started · Phase 5
  - [ ] Placeholder Asset: none
  - [ ] Final Asset: rising sparkle ring at the landmark

---

## Summary

| Category | Total Items | Placeholder Done | Final Done |
|---|---|---|---|
| Aircraft Models | 5 | 0 | 0 |
| Terrain Assets | 6 | 0 | 0 |
| Trees | 6 | 0 | 0 |
| Buildings | 12 | 0 | 0 |
| Audio | 22 | 0 | 0 |
| UI Icons | 11 | 0 | 0 |
| Skyboxes | 5 | 0 | 0 |
| Collectibles | 6 | 0 | 0 |
| **Total** | **73** | **0** | **0** |

*Update this table when an asset's status changes.*
