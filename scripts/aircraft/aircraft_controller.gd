class_name Aircraft
extends CharacterBody3D
## Arcade flight controller shared by every aircraft. It always flies forward,
## never stalls, and can't crash. Differences between planes live in `stats`.
##
## Children it expects: FlightInput, FlightSafety, Sensor (Area3D),
## Model (with an AircraftVisuals script). The model is replaced by
## stats.model_scene, so swapping planes is just set_stats().

signal stats_changed(stats: AircraftStats)

@export var stats: AircraftStats

## 0..1, how far into boost we are. The camera uses it for FOV.
var boost_amount: float = 0.0
var speed: float = 0.0
var heading: float = 0.0  # radians, around Y
var pitch: float = 0.0    # radians, around X (+ = nose up)
var turn: float = 0.0     # final turn command after safety blending

@onready var input: FlightInput = $FlightInput
@onready var safety: FlightSafety = $FlightSafety
var visuals: AircraftVisuals


func _ready() -> void:
	if stats == null:
		stats = AircraftStats.new()
	add_to_group("aircraft")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = GameSettings.LAYER_AIRCRAFT
	collision_mask = GameSettings.LAYER_WORLD
	heading = rotation.y
	visuals = $Model
	input.honk_pressed.connect(_on_honk)
	input.trick_pressed.connect(func(): visuals.barrel_roll())
	_apply_stats(stats)
	speed = stats.cruise_speed
	velocity = _forward() * speed


func _physics_process(delta: float) -> void:
	safety.evaluate(global_position, velocity, turn)

	# Turning: safety bias overrides the stick in proportion to its strength.
	var bias := safety.turn_bias
	turn = clampf(input.stick.x * (1.0 - absf(bias)) + bias, -1.0, 1.0)
	turn = lerpf(turn, safety.turn_override, safety.turn_override_weight)
	heading -= turn * deg_to_rad(stats.turn_rate_deg) * delta
	heading = wrapf(heading, -PI, PI)

	# Pitch: follow the stick, level off when released, obey safety limits.
	var target_deg := input.stick.y * stats.max_pitch_deg
	var rate := stats.pitch_rate_deg
	if not input.has_stick_input:
		rate *= stats.auto_level_strength
	target_deg = clampf(target_deg, safety.pitch_floor_deg, safety.pitch_ceiling_deg)
	if target_deg > rad_to_deg(pitch) and safety.pitch_floor_deg > -stats.max_pitch_deg:
		rate *= 1.6  # rescue climbs respond a little quicker
	pitch = move_toward(pitch, deg_to_rad(target_deg), deg_to_rad(rate) * delta)
	rotation = Vector3(pitch, heading, 0.0)

	# Speed: boost or slow, but always moving.
	var throttle := input.throttle
	var mult := 1.0 + (throttle * (stats.boost_multiplier - 1.0) if throttle > 0.0 else throttle * (1.0 - stats.slow_multiplier))
	speed = lerpf(speed, stats.cruise_speed * mult, 1.0 - exp(-stats.speed_response * delta))
	boost_amount = clampf((speed - stats.cruise_speed) / (stats.cruise_speed * (stats.boost_multiplier - 1.0)), 0.0, 1.0)

	velocity = _forward() * speed
	move_and_slide()
	safety.enforce()

	visuals.update_visuals(turn, speed, stats, delta, boost_amount, input.trick_held)


## Switch to another aircraft mid-flight. Position, heading and the
## fraction of cruise speed are kept.
func set_stats(new_stats: AircraftStats) -> void:
	if new_stats == null or new_stats == stats:
		return
	var speed_ratio := speed / stats.cruise_speed
	_apply_stats(new_stats)
	speed = stats.cruise_speed * speed_ratio
	velocity = _forward() * speed


func _apply_stats(new_stats: AircraftStats) -> void:
	stats = new_stats
	input.smoothing = stats.input_smoothing
	safety.setup(self, stats, $Sensor)
	if stats.model_scene and stats.model_scene.resource_path != visuals.scene_file_path:
		var model := stats.model_scene.instantiate() as AircraftVisuals
		var old := visuals
		remove_child(old)
		old.queue_free()
		model.name = "Model"
		add_child(model)
		visuals = model
	visuals.set_paint(Paint.color(SaveManager.get_paint(stats.id, stats.default_paint)))
	stats_changed.emit(stats)


## Next/previous paint colour (D-pad). Saved per plane.
func cycle_paint(direction: int) -> void:
	var idx := SaveManager.get_paint(stats.id, stats.default_paint) + direction
	SaveManager.set_paint(stats.id, idx)
	var c := Paint.color(idx)
	visuals.set_paint(c)
	Sfx.play("pop", 1.0 + posmod(idx, Paint.COLORS.size()) * 0.08)
	var sparkle := PickupBurst.new(20, 7.0, [c, Color.WHITE])
	add_child(sparkle)


func _on_honk() -> void:
	visuals.honk()
	Sfx.play("honk", stats.honk_pitch)


## Instantly place the plane (spawning, respawning, plane swap).
func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	heading = yaw
	pitch = 0.0
	rotation = Vector3(0.0, heading, 0.0)
	velocity = _forward() * speed
	reset_physics_interpolation()


func _forward() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, heading, 0.0)).z
