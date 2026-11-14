# Credits

Every third-party asset must be listed here **before** it is committed.

## Code

Little Pilot code is © 2026 Shane Wastasecoot, released under the MIT License (see `LICENSE`).

## Engine

- [Godot Engine](https://godotengine.org) — MIT License

## Assets

| Asset | File(s) in repo | Author | Source URL | License | Attribution required? |
|---|---|---|---|---|---|
| *(none yet)* | | | | | |

### Licence rules
- **CC0**: no attribution required, but list it here anyway so we know where it came from.
- **CC-BY**: attribution required. Copy the author's requested credit text into this file.
- **Do not use** assets marked "non-commercial", "no derivatives", or with no clear licence.


## Third-party assets

| Asset | File | Author | License | Source |
|---|---|---|---|---|
| Biplane ("plane 2") | `assets/aircraft/biplane.glb` | Jake Blakeley | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [Poly Pizza](https://poly.pizza/m/amIu9ua-L0A) |
| Jet trainer ("Jet") | `assets/aircraft/jet_trainer.glb` | Poly by Google | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [Poly Pizza](https://poly.pizza/m/3B3Pa6BHXn1) |

Changes: the biplane gets an added spinning propeller; the jet is recoloured from red to blue at load time (`scripts/aircraft/model_recolor.gd`). Both are rescaled and reoriented in their model scenes.

## Generated in code

Everything in the game so far is made by the project's own code (MIT), with no third-party assets:

- **3D art:** island terrain, landmarks, trees and stars are built from Godot primitives and generated meshes.
- **Sound effects and music:** synthesised at startup by `scripts/core/sfx.gd` and `scripts/core/music.gd`.
- **Font:** Godot's built-in default font.
