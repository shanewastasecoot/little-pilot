# Player characters

The player's on-foot character is built in **Blender, from code**:
`tools/blender/build_characters.py` makes `assets/characters/player/player.glb`.
Rebuild it after changing the script with:

```
./dev.sh characters
```

(needs the Blender Flatpak: `flatpak install --user flathub org.blender.Blender`).

`scripts/player/character_model.gd` loads the file, shows one body + one hair +
the matching outfit, scales it to storybook size (~5 m, like the townspeople) and
plays the animations.

## What's in the file

| Part | Names |
|---|---|
| Armature (one, shared by everything) | `Rig`: hips, spine, chest, neck, head, upperarm/forearm, thigh/shin/foot (`.L`/`.R`) |
| Bodies | `Body_M`, `Body_F` |
| Hair (fits both heads) | `Hair_1` short brown, `Hair_2` black bob, `Hair_3` blonde ponytail, `Hair_4` curly puffs |
| Outfits (one per body) | `Outfit_1_M/F` T-shirt + shorts, `Outfit_2_M/F` hoodie + jeans, `Outfit_3_M/F` pilot jacket + scarf, `Outfit_4_M/F` dungarees + stripy top |
| Animations | `Idle`, `Walk`, `Run` (loops, in place), `Jump` |

## Replacing it with hand-made art

Any model that follows the same rules drops straight in (same file path, or change
`CharacterModel.SCENE`):

- **glTF 2.0 binary (`.glb`)**, Y-up, metres, about **1.85 m** tall at scale 1,
  standing at the origin, facing **+Z** in glTF (−Y in Blender), transforms applied.
- **One armature.** Every body, hair and outfit mesh is skinned to it (bone names
  can differ from ours, but all parts must use the same armature), at most
  4 bone weights per vertex.
- **Mesh object names exactly as in the table above.** Outfits need one version
  per body so nothing pokes through.
- **Animations named `Idle`, `Walk`, `Run`, `Jump`**, in place (no root motion).
  Walk and Run should loop. If your walk or run stride differs from ours, change
  `WALK_NATURAL` / `RUN_NATURAL` in `character_model.gd` so the feet don't slide.
- **Budget:** about 5,000 triangles for the heaviest body + hair + outfit (only one
  player is ever on screen). Flat colours or a small palette texture.

`./dev.sh test` (the `character_test` suite) checks all of these.
