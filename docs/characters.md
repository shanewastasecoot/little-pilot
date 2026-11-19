# Player character

The character you make and walk around as is built from **KayKit Character Pack:
Adventurers 1.0** by Kay Lousberg (CC0; `assets/characters/kaykit_adventurers/`, licence
file included), dressed in five original outfits whose props are built in Blender.

## How it fits together

- `scenes/characters/player_character.tscn` (`scripts/player/character_model.gd`) is the
  one reusable character: the character screen's preview and the walker both use it.
- Every KayKit character shares one 41-bone rig, so parts mix freely. The **outfit**
  picks a base character (body, arms, legs and its 76 animations); the **hair** choice
  picks a head (moved onto that skeleton):
  `1` Rogue long auburn, `2` Knight short sandy, `3` Mage short black, `4` Rogue repainted golden.
- KayKit parts are coloured by a palette texture: an 8×4 grid of colour swatches. An
  outfit repaints cells of it (`"r<row>c<col>"`), so a tunic can become a bomber jacket.
- `scripts/player/outfits.gd` lists the outfits (`OutfitData`: base, palette repaints,
  props on bones, hidden parts, icon colours):

| # | Outfit | Base | Props (bone) |
|---|---|---|---|
| 1 | Pilot: brown bomber jacket, cream scarf, boots | Rogue | `Pilot_Cap` with goggles (head), `Pilot_Scarf` (chest) |
| 2 | Princess: lilac gown, mint sash and bow | Mage | `Princess_Gown` (hips), `Princess_Tiara` (head) |
| 3 | Astronaut: white and orange suit | Knight | `Astro_Helmet` (head), `Astro_Pack` (chest) |
| 4 | Superhero: blue suit, red boots and gloves | Rogue | `Hero_Cape`, `Hero_Emblem` (chest) |
| 5 | Dino costume | Rogue | `Dino_Hood` (head), `Dino_Tail` (hips) |

  Every look also gets `Face_Smile` (head): a small smile on KayKit's simple oval-eyed faces.

## Props

`tools/blender/build_props.py` builds every prop in Blender; rebuild with `./dev.sh props`
(needs the Blender Flatpak: `flatpak install --user flathub org.blender.Blender`). Each
prop starts as a few rough primitives and becomes **one smooth merged mesh**: Voxel
Remesh → Subdivision Surface → Decimate (to a budget), then the primitives' colours are
copied onto it as vertex colours. Props are modelled in the character's own space (feet at
the origin, ~2.2 m tall), so the game hangs them on a bone and they sit where they were made.

## Delivery people

The people you deliver parcels to (and the airport's postie) use the same parts:
`scripts/delivery/recipients.gd` gives each a base, a palette, props and a head
(any KayKit head, including the bearded Barbarian), and `CharacterModel.look_override` /
`head_override` dress them. `CarryPose` (a SkeletonModifier3D) bends the arms round a
parcel on top of any animation. They use KayKit's `Interact` (taking the parcel) and
`Cheer`.

## Look

`shaders/toon.gdshader` gives every part and prop the same toon look (two soft cel
bands, a gentle rim light) and `shaders/toon_outline.gdshader` adds a soft outline in a
darkened version of each part's own colour.

## Budget

The heaviest look (dino, long hair) is about 7,700 triangles in 9 surfaces (twice that
with the outline pass), and only one player is ever on screen. `./dev.sh test`
(`character_test`) checks every look, the props, the animations and the save.
