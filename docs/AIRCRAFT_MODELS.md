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

| | Biplane | Light Plane (and Seaplane) | Trainer Jet |
|---|---|---|---|
| File | `vinish_biplane.glb` (vinish.dev, CC BY 4.0) | `vinish_light_plane.glb` (vinish.dev, CC BY 4.0) | `jet_trainer.glb` (Poly by Google, CC-BY 3.0) |
| Triangles | about 12,800 | about 12,100 | about 5,200 |
| Separate parts | propeller, ailerons, elevator, rudder, wheels | propeller, ailerons, elevator, rudder, gear, wheels | none |
| Paint | material `Paint_Yellow` (wings, stripes) | material `Paint_White` (body) | hue swap |
| Markers | Wingtip_L/R, CockpitCameraMarker, a `PilotSeat` (her) | Wingtip_L/R, CockpitCameraMarker | boost-trail markers, `cockpit_eye` |

- The vinish.dev models face +Z with the origin on the ground and metres for units, so
  each scene (`scenes/aircraft/models/`) turns its model round to face the game's -Z, scales
  it to the game's size (about 10 m wingspan) and lifts it so the middle of the fuselage is
  the model's origin. Their paint is flat, named materials, so `ModelRecolor.materials`
  recolours exactly those surfaces (no hue matching needed).
- The old biplane (`toy_biplane.glb`, 51,000 triangles in one mesh, the propeller cut out at
  load) was replaced in fixes round 2 and removed.
- **Trainer Jet** (`jet_trainer.glb`, CC-BY, Poly by Google): one mesh, no interior; vapour
  and the cockpit view (the eye just above the canopy, looking down 15° so the nose shows
  over the instruments); no moving surfaces or wheels. (vinish.dev's jet is a military
  fighter, so it wasn't used.)
