class_name Aircraft
extends CharacterBody3D
## Arcade flight controller shared by every aircraft. It always flies forward
## and never stalls. With `crashes` on (the default) it can bump into the
## ground, water or buildings: `crashed` fires and the game puts it back on
## the runway. With crashes off, FlightSafety steers it away from everything.
## Take-off is the player's: from PARKED, boost (or push the stick) to roll
## down the runway, then pull up once fast enough. Differences between
## planes live in `stats`.
##
## Children it expects: FlightInput, FlightSafety, Sensor (Area3D),
## Model (with an AircraftVisuals script). The model is replaced by
## stats.model_scene, so swapping planes is just set_stats().

signal stats_changed(stats: AircraftStats)

@export var stats: AircraftStats

signal takeoff_finished
## The plane bumped into something (only when `crashes` is on).
signal crashed(where: Vector3, into_water: bool)

enum Mode { FLYING, PARKED, ROLLING, CRASHED }

## Ground roll: acceleration (m/s^2) with and without boost, braking, how
## far the stick steers on the ground, and lift-off speed (fraction of
## cruise). Rolling off the end of the runway at speed lifts off by itself.
const ROLL_ACCEL := 4.0
const ROLL_BOOST_ACCEL := 9.0
const ROLL_BRAKE := 8.0
const ROLL_TURN_DEG := 14.0
const LIFTOFF_FRACTION := 0.75
const LIFTOFF_PITCH_DEG := 10.0
## Seconds after lift-off / respawn when touching the ground can't crash.
const CRASH_GRACE := 1.5
## Crashes below this height count as landing in the sea.
const WATER_LEVEL := 0.6

## Can the plane crash? Off = always steered clear (the original mode).
var crashes := true:
	set(v):
		crashes = v
		if safety:
			safety.assist = not v
## The player may start a take-off roll (false behind the menus).
var ground_controls := false
var mode: Mode = Mode.FLYING
var _ground_y := 0.0
var _grace := 0.0
var _crash_spin := Vector3.ZERO

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
	safety.assist = not crashes
	speed = stats.cruise_speed
	velocity = _forward() * speed


func _physics_process(delta: float) -> void:
	if mode == Mode.PARKED:
		speed = 0.0
		boost_amount = 0.0
		visuals.update_visuals(0.0, 6.0, stats, delta)  # propeller idles
		if ground_controls and (input.throttle > 0.2 or absf(input.stick.y) > 0.35):
			mode = Mode.ROLLING  # the player wants to go
			Sfx.play("whoosh", 0.7)
		return
	if mode == Mode.ROLLING:
		_roll_step(delta)
		return
	if mode == Mode.CRASHED:
		_crashed_step(delta)
		return
	_grace -= delta
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
	var target_speed := stats.cruise_speed * mult * safety.speed_factor
	# Brake for walls faster than we normally change speed.
	var response := stats.speed_response * (3.0 if target_speed < speed and safety.speed_factor < 1.0 else 1.0)
	speed = lerpf(speed, target_speed, 1.0 - exp(-response * delta))
	boost_amount = clampf((speed - stats.cruise_speed) / (stats.cruise_speed * (stats.boost_multiplier - 1.0)), 0.0, 1.0)

	velocity = _forward() * speed
	move_and_slide()
	if crashes and _grace <= 0.0 and (get_slide_collision_count() > 0 or global_position.y < WATER_LEVEL):
		_crash()
		return
	safety.enforce()

	visuals.update_visuals(turn, speed, stats, delta, boost_amount, input.trick_held)


## Switch to another aircraft mid-flight. Position, heading and the
## fraction of cruise speed are kept.
func set_stats(new_stats: AircraftStats) -> void:
	if new_stats == null or new_stats == stats:
		return
	var speed_ratio := speed / stats.cruise_speed
	var old_offset := stats.ground_offset
	_apply_stats(new_stats)
	speed = stats.cruise_speed * speed_ratio
	velocity = _forward() * speed
	if on_ground():
		global_position.y += stats.ground_offset - old_offset
		reset_physics_interpolation()


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


## Sit on the ground (runway) at `pos`, facing `yaw`, engine idling. The
## player takes off from here (see _roll_step).
func park(pos: Vector3, yaw: float) -> void:
	_ground_y = pos.y
	speed = 0.0
	teleport(pos + Vector3.UP * stats.ground_offset, yaw)
	mode = Mode.PARKED


## True while on the ground (parked or rolling).
func on_ground() -> bool:
	return mode == Mode.PARKED or mode == Mode.ROLLING


## Player-driven ground roll: boost speeds up, slow brakes, the stick steers
## a little; pull up once fast enough to lift off (or run off the end of the
## runway at speed and it lifts off by itself).
func _roll_step(delta: float) -> void:
	var lift_speed := stats.cruise_speed * LIFTOFF_FRACTION
	var accel := ROLL_BOOST_ACCEL if input.throttle > 0.2 else ROLL_ACCEL
	if input.throttle < -0.2:
		speed = maxf(speed - ROLL_BRAKE * delta, 0.0)
	else:
		speed = minf(speed + accel * delta, stats.cruise_speed * (stats.boost_multiplier if input.throttle > 0.2 else 1.0))
	heading = wrapf(heading - input.stick.x * deg_to_rad(ROLL_TURN_DEG) * delta * clampf(speed / 10.0, 0.0, 1.0), -PI, PI)
	pitch = move_toward(pitch, 0.0, deg_to_rad(10.0) * delta)
	rotation = Vector3(pitch, heading, 0.0)
	var pos := global_position + _forward() * speed * delta
	pos.y = _ground_y + stats.ground_offset  # wheels on the ground
	global_position = pos
	velocity = _forward() * speed
	boost_amount = 0.0
	visuals.update_visuals(input.stick.x * 0.3, speed + 6.0, stats, delta)
	var off_runway := not IslandShape.on_runway(pos.x, pos.z)
	if speed >= lift_speed and (input.stick.y > 0.2 or off_runway):
		lift_off()


## Leave the ground: normal flight, nose up, a moment's grace from crashes.
func lift_off() -> void:
	mode = Mode.FLYING
	pitch = deg_to_rad(LIFTOFF_PITCH_DEG)
	_grace = CRASH_GRACE
	global_position.y += 0.5
	Sfx.play("whoosh", 1.0)
	takeoff_finished.emit()


func _crash() -> void:
	var into_water := global_position.y < WATER_LEVEL + 1.5
	mode = Mode.CRASHED
	_crash_spin = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(6, 10) * (1.0 if randf() < 0.5 else -1.0))
	velocity = Vector3.ZERO
	boost_amount = 0.0
	crashed.emit(global_position, into_water)


## A cartoon tumble on the spot while the game fades back to the runway.
func _crashed_step(delta: float) -> void:
	speed = move_toward(speed, 0.0, 40.0 * delta)
	visuals.rotation += _crash_spin * delta
	_crash_spin *= exp(-1.5 * delta)


## Instantly place the plane (spawning, respawning, plane swap).
## Also puts the plane in normal flying mode.
func teleport(pos: Vector3, yaw: float) -> void:
	mode = Mode.FLYING
	_grace = CRASH_GRACE
	if visuals:
		visuals.rotation = Vector3.ZERO
	global_position = pos
	heading = yaw
	pitch = 0.0
	rotation = Vector3(0.0, heading, 0.0)
	velocity = _forward() * speed
	reset_physics_interpolation()


func _forward() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, heading, 0.0)).z
