class_name AircraftStats
extends Resource
## All tuning values for one aircraft. A new aircraft is a new .tres file,
## not new code. Edit these live in the Inspector while the game runs.

## Stable id used in the save file. Never rename once released.
@export var id: String = "prop"
@export var display_name: String = "Prop Plane"
## Visual model; its root must use the AircraftVisuals script.
@export var model_scene: PackedScene
## Colour used behind this plane in menus.
@export var menu_color: Color = Color("ff5a5f")
## Starting paint (index into Paint.COLORS) until the child picks another.
@export var default_paint: int = 0
## Size of the model in flight (the menu shows it at 1.0). Collision and
## ground_offset should match the scaled model.
@export var model_scale: float = 1.0
## Height of the plane's centre above the ground when parked (wheels down).
@export var ground_offset: float = 1.0
## Pitch of the honk sound (1.0 = normal).
@export var honk_pitch: float = 1.0
## This aircraft's own horn (an Sfx sound; Phase 12).
@export var honk_sound: String = "honk"

@export_group("Speed")
## Forward speed with no boost or slow input (m/s). The plane never stops.
@export var cruise_speed: float = 22.0
@export var boost_multiplier: float = 1.5
## Fraction of cruise speed while slowing. Keep > 0.5 so it never feels stalled.
@export var slow_multiplier: float = 0.65
## How quickly speed changes toward the target (per second, higher = snappier).
@export var speed_response: float = 1.5

@export_group("Handling")
## Maximum heading change rate at full stick (degrees/second).
@export var turn_rate_deg: float = 55.0
## Nose up/down limit. Keeps the plane far from loops and inversions.
@export var max_pitch_deg: float = 28.0
## How fast the nose follows the stick (degrees/second).
@export var pitch_rate_deg: float = 40.0
## Stick smoothing (per second). Low = soft and floaty, high = snappy.
@export var input_smoothing: float = 3.0
## How fast the nose returns to level with no input (multiplier on pitch rate).
@export var auto_level_strength: float = 1.2

@export_group("Visuals")
## Visual roll into turns (degrees). Purely cosmetic.
@export var max_bank_deg: float = 40.0
@export var bank_response: float = 3.0

@export_group("Safety")
## Seconds of travel to look ahead for terrain and water.
@export var lookahead_time: float = 1.8
## Height above ground where gentle pull-up begins (m).
@export var safe_clearance: float = 14.0
## Hard floor: the plane is never allowed below this height above ground (m).
@export var min_clearance: float = 4.0
## Steepest climb the safety system may force (degrees).
@export var max_rescue_pitch_deg: float = 35.0

@export_group("Camera")
@export var camera_distance: float = 9.0
@export var camera_height: float = 2.5
@export var camera_fov: float = 70.0
## The cockpit view (Phase 9): where the pilot's eyes are, in the model's
## own space (front is -Z), and the view's field of view. Used when the
## model has no CockpitCameraMarker (docs/AIRCRAFT_MODELS.md).
@export var cockpit_eye: Vector3 = Vector3(0, 1.4, 0.4)
@export var cockpit_fov: float = 78.0
## Tilt the cockpit view down a little (degrees) so the nose shows above
## the instrument panel.
@export var cockpit_look_down_deg: float = 0.0
## Extra field of view at full boost (degrees).
@export var boost_fov_bonus: float = 10.0
