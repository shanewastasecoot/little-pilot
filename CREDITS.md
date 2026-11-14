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

| Pine tree | `assets/environment/pine.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/igSu0cPoBz) |
| Round tree | `assets/environment/tree_round.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/9nvGuZlbpE) |
| Sheep | `assets/environment/sheep.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/C39AUXUUes) |
| Cow | `assets/environment/cow.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/5XSc2Fka3F) |
| Barn | `assets/environment/barn.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/vSqQNA7ez6) |
| Silo | `assets/environment/silo.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/5GhLrv5Ce3) |
| Sail boat | `assets/environment/sail_boat.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/BgSZXwmm7k) |
| Whale | `assets/environment/whale.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/JGFwp6xWgk) |
| Clouds | `assets/environment/cloud_a.glb`, `cloud_b.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/KdFNOVn1Gf), [2](https://poly.pizza/m/pjiBiLJwAl) |
| Rocks | `assets/environment/rocks.glb`, `rock.glb` | Quaternius | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/OQvi8PIZ40), [2](https://poly.pizza/m/4MUaQTcDdc) |

| Lighthouse | `assets/environment/lighthouse.glb` | MaverickFX | CC0 1.0 | [Poly Pizza](https://poly.pizza/m/KRebJXIRb8) |
| Wind turbine | `assets/environment/wind_turbine.glb` | Colin Hopkins | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [Poly Pizza](https://poly.pizza/m/3JKnKecvdMI) |
| Control tower ("Radio tower") | `assets/environment/control_tower.glb` | Poly by Google | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | [Poly Pizza](https://poly.pizza/m/44JZ7nNNy_x) |

CC0 assets need no credit; they're listed here so their origin is recorded.

Changes: the biplane gets an added spinning propeller; the jet is recoloured from red to blue at load time (`scripts/aircraft/model_recolor.gd`). Both are rescaled and reoriented in their model scenes. The wind turbine's blades are regrouped around the hub at load time so they can spin.

## Generated in code

Everything in the game so far is made by the project's own code (MIT), with no third-party assets:

- **3D art:** island terrain, runway, the arched hangar (`scripts/world/landmarks/hangar.gd`), windsock, fields and stars are built from Godot primitives and generated meshes. Distant trees use generated cones.
- **Sound effects and music:** synthesised at startup by `scripts/core/sfx.gd` and `scripts/core/music.gd`.
- **Font:** Godot's built-in default font.
