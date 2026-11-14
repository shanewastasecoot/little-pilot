class_name AircraftVisuals
extends Node3D
## Cosmetic-only motion for an aircraft model: banking, propeller and honk hop.
## Never affects flight.

## Optional child spun according to speed.
@export var propeller: Node3D
## Ribbons shown while boosting (usually one per wingtip).
@export var boost_trails: Array[BoostTrail] = []

var _bank: float = 0.0
var _honk_tween: Tween


func update_visuals(turn: float, speed: float, stats: AircraftStats, delta: float, boost: float = 0.0) -> void:
	for trail in boost_trails:
		trail.strength = boost
	var target := -turn * deg_to_rad(stats.max_bank_deg)
	_bank = lerpf(_bank, target, 1.0 - exp(-stats.bank_response * delta))
	rotation.z = _bank
	if propeller:
		propeller.rotate_z(speed * 1.5 * delta)


## A happy little bounce. Sound is added in Phase 4.
func honk() -> void:
	if _honk_tween and _honk_tween.is_running():
		return  # mashing B just keeps the current hop going
	_honk_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_honk_tween.tween_property(self, "scale", Vector3.ONE * 1.25, 0.1)
	_honk_tween.tween_property(self, "scale", Vector3.ONE, 0.25)
