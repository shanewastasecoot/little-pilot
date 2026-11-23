# Aircraft models: the contract

Phase 9 makes the aircraft look and behave like real civilian aircraft. The code can
only move what the model gives it as a separate part, so every aircraft model should
follow this contract. `./dev.sh audit-aircraft` checks the models against it
(node tree, meshes, triangles, materials, animations, and which parts are separate).

## Parts (node names in the model scene; front is −Z, up is +Y, metres)

| Node | Required? | What the game does with it |
|---|---|---|
| `Body` | yes | The airframe (fuselage, wings, tail), repainted by the paint shader |
| `Propeller` | prop aircraft | Spins with engine speed (pivot on the shaft) |
| `Wheel_Nose` or `Wheel_Tail`, `Wheel_L`, `Wheel_R` | yes | Spin when rolling; the nose / tail wheel turns with the stick on the ground |
| `Aileron_L`, `Aileron_R` | for moving surfaces | Tilt opposite ways when turning (pivot on the hinge line) |
| `Elevator` | for moving surfaces | Tilts with climb / dive |
| `Rudder` | for moving surfaces | Turns with the turn |
| `Gear` | only retractable designs | Folds up after take-off, down for landing. Fixed gear stays put |
| `CockpitCameraMarker` | for the cockpit view | Where the pilot's eyes are (the cockpit camera sits here) |
| `Wingtip_L`, `Wingtip_R` | for lights and vapour | Red (left) and green (right) navigation lights, wingtip vapour in hard turns |
| `Tail_Light`, `Beacon` | optional | White tail light, red flashing beacon (placed from the wingtips if missing) |

Pivots: each moving part's origin must sit on its hinge or axle, so turning the node
turns the part about the right line. Control surfaces rest at 0°.

## Where the current models stand

From `./dev.sh audit-aircraft`:

| | Prop Plane | Trainer Jet |
|---|---|---|
| Meshes | `Object_2` (208 tris), `Object_3` (51,221 tris, the whole aircraft), `Blades` (3,027, cut out at load) | `Jet` (928 tris), `Exhaust` (4,224, made in code) |
| Total triangles | about 54,800 | about 5,200 |
| Animations | none | none |
| Separate parts | propeller (cut out in code) | none |
| Wheels, control surfaces, gear, markers | no | no |

- **Prop Plane** (`toy_biplane.glb`, CC-BY, by law): one mesh for the whole
  aircraft; the propeller is cut out of it at load time (`prop_splitter.gd`). No separate
  wheels, control surfaces or markers. It has: lights and vapour (placed from its boost-trail
  markers), the cockpit view (`cockpit_eye`). It can't get moving surfaces or spinning
  wheels without editing the model. The plan replaces it with a more realistic civilian
  aircraft. Its 51,000-triangle body is the heaviest thing on screen for its size.
- **Trainer Jet** (`jet_trainer.glb`, CC-BY, Poly by Google): one mesh, no interior. Same as
  above: lights, vapour and the cockpit view (the eye just above the canopy, looking down
  15° so the nose shows over the instruments); no moving surfaces or wheels.

## Candidate replacements (for the parent to choose)

Realistic civilian light aircraft or biplanes, CC0 or CC-BY, ideally with separate
control surfaces and propeller:

1. **Antonov An-2** low-poly (OpenGameArt, CC0): a big civilian utility biplane; control
   surfaces and propeller already separate with their pivots set. Repainted in a civilian
   scheme. <https://opengameart.org/content/an-2-airplane-lowpoly>
2. **Low-poly biplane** (OpenGameArt, CC0, about 670 triangles): a simple classic biplane.
   <https://opengameart.org/content/low-poly-biplane>
3. **Low-poly biplane** by mujtaba-io (OpenGameArt, CC0, `.blend`).
   <https://opengameart.org/node/168011>

OpenGameArt refuses automated downloads, so these need fetching by hand (a browser) into
a folder; then a Blender pass names the parts to this contract and exports `.glb`.
Each needs a screenshot beside the jet and the buildings, at the same scale, before one
is chosen. When a model is replaced its file loses the `toy_` name and
`resources/credits.json` is updated.
