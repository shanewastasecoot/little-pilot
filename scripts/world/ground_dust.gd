class_name GroundDust
extends Node3D
## Dust off the ground (Phase 6):
##   - the plane rolling fast over grass or dirt kicks up puffs behind its
##     wheels, and lifting off from grass leaves a big cloud (WorldEvents
##     "takeoff"); the runway's tarmac stays clean
##   - she runs (sprinting) and little puffs pop at her feet
## Soft beige billboards (PickupBurst), freed when done. main.gd adds one.

const ROLL_SPEED := 8.0
const ROLL_EVERY := 0.12
const RUN_EVERY := 0.28
const DUST := [Color(0.8, 0.68, 0.48, 1.0), Color(0.86, 0.76, 0.58, 0.8), Color(0.92, 0.86, 0.74, 0.0)]

var aircraft: Node3D
var walker: Walker
var _roll_t := 0.0
var _run_t := 0.0
## How many puffs it has made (tests).
var puffs := 0


func _ready() -> void:
	top_level = true  # at the world origin, so a puff's position is its world position
	WorldEvents.happened.connect(func(kind: String, where: Vector3, info: Dictionary):
		if kind == "takeoff" and info.get("surface", "") == "grass":
			# A cloud billowing out to both sides and behind the wheels.
			var basis: Basis = aircraft.global_transform.basis if aircraft else Basis()
			for off in [basis.x * 5.0, -basis.x * 5.0, basis.z * 7.0]:
				burst(where + off, 3.0, 24))


func _process(delta: float) -> void:
	if aircraft and aircraft.get("mode") == Aircraft.Mode.ROLLING and float(aircraft.get("speed")) > ROLL_SPEED:
		var p := aircraft.global_position
		if not IslandShape.on_runway(p.x, p.z) and p.y > 1.0:
			_roll_t -= delta
			if _roll_t <= 0.0:
				_roll_t = ROLL_EVERY
				var back: Vector3 = aircraft.global_transform.basis.z * 3.0
				burst(p + back - Vector3.UP * float(aircraft.stats.ground_offset), 1.8, 10)
	if walker and walker.is_active() and walker.sprinting and walker.is_on_floor():
		_run_t -= delta
		if _run_t <= 0.0:
			_run_t = RUN_EVERY
			burst(walker.global_position + Vector3.UP * 0.2, 0.7, 6)
	else:
		_run_t = 0.05


## A puff of dust at `where` (world), `size` about its width in metres.
func burst(where: Vector3, size: float, count: int) -> void:
	var colors: Array[Color] = []
	colors.assign(DUST)
	var b := PickupBurst.new(count, 2.5 * size, colors).keep_scale()
	b.lifetime = 1.8
	b.spread = 85.0
	b.gravity = Vector3(0, 0.6, 0)
	b.damping_min = 3.0
	b.damping_max = 5.0
	b.scale_amount_min = size * 1.2
	b.scale_amount_max = size * 2.2
	# (Placed before it's added: the particles are in world space and the
	# first ones leave on the first frame, from wherever it is then.)
	b.position = where
	add_child(b)
	puffs += 1
