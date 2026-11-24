class_name Aircraft
extends CharacterBody3D
## Arcade flight controller shared by every aircraft. It always flies forward
## and never stalls. With `crashes` on (the default) it can bump into the
## ground, water or buildings: `crashed` fires and the game puts it back on
## the runway. With crashes off, FlightSafety steers it away from everything.
## Take-off is the player's: from PARKED, boost (or push the stick) to roll
## along the ground, then pull up once fast enough. Differences between
## planes live in `stats`.
##
## Landing: come down gently (not boosting, not diving) onto flat ground
## anywhere (grass, sand, the runway) and the wheels touch down instead of
## crashing. In can't-crash mode the plane only lands on purpose: hold slow
## while low over flat ground and the safety system lets it down. The plane rolls along the ground, slowing by itself (hold slow
## to brake harder), and parks when it stops. Boost during the roll to go
## round again. Steep ground, buildings, water, or coming in too fast or
## too steeply are still a bump (see can_land_on).
##
## Children it expects: FlightInput, FlightSafety, Sensor (Area3D),
## Model (with an AircraftVisuals script). The model is replaced by
## stats.model_scene, so swapping planes is just set_stats().

signal stats_changed(stats: AircraftStats)

@export var stats: AircraftStats

signal takeoff_finished
## Wheels touched the ground in a landing (the roll-out follows).
signal touched_down
## The plane has stopped and parked. after_landing: it just landed (false
## when placed on the runway by the game).
signal parked(after_landing: bool)
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
## Landing. Low over landable ground (flat island terrain, not a roof or
## the sea; can_land_on) and heading down without pulling up: it lands, in
## both modes, even diving or boosting in (it flares in the last few metres
## and lands at no more than LAND_MAX_SPEED x cruise). Holding slow lands
## too. Ground steeper than LAND_MAX_SLOPE_DEG, buildings, trees and the
## sea are still a bump. On the ground: ROLL_FRICTION slows a landing roll on its own,
## the plane stops for water/cliffs/walls ahead (ROLL_STOP_BRAKE), and
## won't roll onto ground steeper than ROLL_MAX_SLOPE_DEG.
const LAND_MAX_SLOPE_DEG := 14.0
const LAND_MAX_SPEED := 1.12
const LAND_MIN_HEIGHT := 1.2      # above the waves: no landing in the surf
## Coming in to land within this height over landable ground.
const LAND_ASSIST_HEIGHT := 30.0
## Heading down: nose down more than LAND_NOSE_DOWN_DEG (or the stick
## pushed down), sinking faster than LAND_SINK m/s, and not pulling up
## (stick up more than LAND_PULL_UP). Level flight, skimming the grass with
## the stick let go, never lands by itself.
const LAND_NOSE_DOWN_DEG := 3.0
const LAND_SINK := 0.5
const LAND_PULL_UP := 0.15
## Just lifted off: no automatic landing for this long (a dip after
## take-off isn't "coming in to land").
const LAND_AFTER_LIFTOFF := 2.0
## Automatic landings only where there's this much room ahead to roll out
## (no building, wall or steep bank): not in city streets.
const LAND_ROOM := 60.0
## Flare: the lower it is, the slower it may sink: FLARE_SINK_PER_M m/s for
## each metre above touchdown, never less than FLARE_MIN_SINK.
const FLARE_SINK_PER_M := 0.8
const FLARE_MIN_SINK := 1.8
## Boosting within this height of touchdown is eased back to LAND_MAX_SPEED.
const FLARE_SPEED_HEIGHT := 8.0
const ROLL_FRICTION := 3.0
const ROLL_STOP_BRAKE := 30.0
const ROLL_MAX_SLOPE_DEG := 24.0
const ROLL_SETTLE := 8.0          # m/s the wheels settle onto the ground
const ROLL_PIVOT_DEG := 55.0      # turn rate when nosing away from a wall
enum Ahead { CLEAR, EDGE, WALL }
## Seconds after lift-off / respawn when touching the ground can't crash.
const CRASH_GRACE := 1.5
## Crashes below this height count as landing in the sea.
const WATER_LEVEL := 0.6
## Seaplane on the water: how fast it turns while taxiing, how deep the
## floats sit (fraction of ground_offset above the waves), and how far it
## keeps from beaches and anything solid.
const WATER_TURN_DEG := 32.0
const FLOAT_RIDE := 0.97
const SHORE_MARGIN := 10.0

## Can the plane crash? Off = always steered clear (the original mode).
var crashes := true:
	set(v):
		crashes = v
		if safety:
			safety.assist = not v
## The player may start a take-off roll (false behind the menus).
var ground_controls := false
var mode: Mode = Mode.FLYING
## A "low pass" (WorldEvents) is sent when lower than this over the ground,
## faster than LOW_PASS_SPEED, at most every LOW_PASS_EVERY seconds.
const LOW_PASS_HEIGHT := 22.0
const LOW_PASS_SPEED := 18.0
const LOW_PASS_EVERY := 1.5
var _low_pass_cool := 0.0
var _ground_y := 0.0
## The current ground roll is a landing (slowing down), not a take-off.
var _landing := false
## Landed with boost held: ignore boost until it's let go once (then
## pressing it again takes off), so holding boost all the way down still
## ends in a landing.
var _roll_await_release := false
## On the water (a seaplane that landed on the sea): taxiing or bobbing.
var _on_water := false
var _spray_t := 0.0
## Floats ignore the sea's flat collision surface (they ride the real waves).
var _water_exc := false
## Just lifted off the water: climb gently clear of the waves by itself for
## this long (so it doesn't skim straight back down onto them).
var _climb_out := 0.0
const CLIMB_OUT_TIME := 2.5
const CLIMB_OUT_DEG := 8.0
## Holding the stick this far towards climb when X is pressed: a loop.
const LOOP_STICK := 0.5
## Seconds in the air since the last lift-off (large after a teleport).
var _airborne := 99.0
## Parked after landing: wait for the stick and triggers to be let go
## before a push counts as "let's go" (they were still held from flying).
var _await_release := false
## Seconds before the release check starts (fresh input after getting in).
var _release_delay := 0.0
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
const BODY_RADIUS := 1.4
## The last crash was an explosion (dragon), not a bump.
var exploded := false
const SENSOR_RADIUS := 1.6


func _ready() -> void:
	# A livery picked on the plane-select screen shows straight away.
	SaveManager.settings_changed.connect(func(): if visuals and stats: visuals.show_livery(stats))
	if stats == null:
		stats = AircraftStats.new()
	add_to_group("aircraft")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = GameSettings.LAYER_AIRCRAFT
	collision_mask = GameSettings.LAYER_WORLD
	heading = rotation.y
	visuals = $Model
	input.honk_pressed.connect(_on_honk)
	input.trick_pressed.connect(trick)
	_apply_stats(stats)
	add_child(WaterSpray.new())
	add_child(BlobShadow.new())
	safety.assist = not crashes
	speed = stats.cruise_speed
	velocity = _forward() * speed


func _physics_process(delta: float) -> void:
	if stats.floats != _water_exc:
		_update_water_exception()
	if mode == Mode.PARKED:
		speed = 0.0
		boost_amount = 0.0
		visuals.update_visuals(0.0, 6.0, stats, delta)  # propeller idles
		if _on_water:
			_ride_waves(global_position, delta)
		var pushing := input.throttle > 0.2 or absf(input.stick.y) > 0.35
		if _await_release:
			# Raw input: the smoothed stick starts near zero after a state
			# change and would look "let go" while it's still held.
			_release_delay -= delta
			if _release_delay <= 0.0 and input.raw_stick.length() < 0.25 and absf(input.raw_throttle) < 0.2:
				_await_release = false
		elif ground_controls and pushing:
			mode = Mode.ROLLING  # the player wants to go
			_landing = false
			Sfx.play("whoosh", 0.7)
		return
	if mode == Mode.ROLLING:
		if _on_water:
			_water_step(delta)
		else:
			_roll_step(delta)
		return
	if mode == Mode.CRASHED:
		_crashed_step(delta)
		return
	_grace -= delta
	# Coming in to land (low over landable ground, and heading down without
	# pulling up, or holding slow): the safety system flares the descent
	# and, in can't-crash mode, lets us down.
	var below := _surface_ray(global_position)
	_airborne += delta
	var height := global_position.y - (below.position as Vector3).y if not below.is_empty() else INF
	# Sweeping low and fast over the ground: the world notices (sheep
	# scatter, people cheer...). Not while coming in to land.
	_low_pass_cool -= delta
	if height < LOW_PASS_HEIGHT and speed > LOW_PASS_SPEED and not safety.landing and _low_pass_cool <= 0.0 and not below.is_empty():
		_low_pass_cool = LOW_PASS_EVERY
		WorldEvents.send("low_pass", below.position, {"height": height})
	var nose_down := pitch < -deg_to_rad(LAND_NOSE_DOWN_DEG) or input.stick.y < -0.1
	var heading_down := nose_down and velocity.y < -LAND_SINK and input.stick.y < LAND_PULL_UP \
			and _airborne > LAND_AFTER_LIFTOFF
	var start_landing := height < LAND_ASSIST_HEIGHT and can_land_on(below) \
			and (input.throttle < -0.2 or (heading_down and _room_to_roll(below)))
	# Once coming in, stay coming in until touchdown, unless she pulls up or
	# flies off the landable ground: the flare slows the sink below LAND_SINK
	# just before touchdown, and dropping out of landing then would pop the
	# plane back up off the ground (a hiccup in the landing).
	var keep_landing := safety.landing and height < LAND_ASSIST_HEIGHT and can_land_on(below) \
			and input.stick.y < LAND_PULL_UP
	safety.landing = start_landing or keep_landing
	safety.evaluate(global_position, velocity, turn)
	# Auto-flare: the lower it is, the slower it may sink (so a dive onto a
	# meadow eases into a landing); boosting is eased off near the ground.
	var flare_pitch := -INF
	var flare_slow := false
	if safety.landing:
		var above := maxf(height - _touch_height(), 0.0)
		var allowed := maxf(FLARE_MIN_SINK, above * FLARE_SINK_PER_M)
		flare_pitch = -rad_to_deg(asin(clampf(allowed / maxf(speed, 1.0), 0.0, 1.0)))
		flare_slow = above < FLARE_SPEED_HEIGHT

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
	if _climb_out > 0.0:
		_climb_out -= delta
		if input.stick.y > -0.3:
			target_deg = maxf(target_deg, CLIMB_OUT_DEG)
	target_deg = clampf(target_deg, safety.pitch_floor_deg, safety.pitch_ceiling_deg)
	if target_deg < flare_pitch:
		target_deg = flare_pitch
		rate = maxf(rate, stats.pitch_rate_deg * 2.0)
	if target_deg > rad_to_deg(pitch) and safety.pitch_floor_deg > -stats.max_pitch_deg:
		rate *= 1.6  # rescue climbs respond a little quicker
	pitch = move_toward(pitch, deg_to_rad(target_deg), deg_to_rad(rate) * delta)
	rotation = Vector3(pitch, heading, 0.0)

	# Speed: boost or slow, but always moving.
	var throttle := input.throttle
	var mult := 1.0 + (throttle * (stats.boost_multiplier - 1.0) if throttle > 0.0 else throttle * (1.0 - stats.slow_multiplier))
	var target_speed := stats.cruise_speed * mult * safety.speed_factor
	if flare_slow:
		target_speed = minf(target_speed, stats.cruise_speed * LAND_MAX_SPEED)
	# Brake for walls faster than we normally change speed.
	var response := stats.speed_response * (3.0 if target_speed < speed and safety.speed_factor < 1.0 else 1.0)
	speed = lerpf(speed, target_speed, 1.0 - exp(-response * delta))
	boost_amount = clampf((speed - stats.cruise_speed) / (stats.cruise_speed * (stats.boost_multiplier - 1.0)), 0.0, 1.0)

	velocity = _forward() * speed
	if _grace <= 0.0 and _climb_out <= 0.0 and velocity.y <= 0.5 and _try_touch_down(delta):
		return
	move_and_slide()
	if crashes and _grace <= 0.0 and (get_slide_collision_count() > 0 or global_position.y < _water_y()):
		_crash()
		return
	# Coming in to land but now over ground you can't land on (a slope, the
	# water's edge, a roof): the usual floor applies again straight away.
	if safety.landing and not can_land_on(_surface_ray(global_position)):
		safety.landing = false
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
	if visuals:
		visuals.show_livery(stats)
	visuals.base_scale = stats.model_scale
	# Bigger plane, bigger bumper (shapes are per instance so menus are unaffected).
	var body := SphereShape3D.new()
	body.radius = BODY_RADIUS * stats.model_scale
	$CollisionShape3D.shape = body
	var sense := SphereShape3D.new()
	sense.radius = SENSOR_RADIUS * stats.model_scale
	$Sensor/CollisionShape3D.shape = sense
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
	# Through the echo of wherever the plane is (mountains, cave, city).
	# Its own horn, a touch higher or lower each time.
	Sfx.play(stats.honk_sound, stats.honk_pitch * randf_range(0.96, 1.04), 0.0, EchoZone.honk_bus())
	WorldEvents.send("honk", global_position)


## Sit on the ground (runway) at `pos`, facing `yaw`, engine idling. The
## player takes off from here (see _roll_step).
func park(pos: Vector3, yaw: float) -> void:
	_on_water = false
	_ground_y = pos.y
	speed = 0.0
	teleport(pos + Vector3.UP * stats.ground_offset, yaw)
	mode = Mode.PARKED
	_landing = false
	_await_release = false
	parked.emit(false)


## Move the parked plane to `ground_pos` facing `yaw` and keep it parked
## (taxiing under someone else's control: the hangar service). Smooth: no
## physics reset, so it glides frame to frame.
func taxi_to(ground_pos: Vector3, yaw: float) -> void:
	_on_water = false
	_ground_y = ground_pos.y
	speed = 0.0
	velocity = Vector3.ZERO
	mode = Mode.PARKED
	_landing = false
	global_position = ground_pos + Vector3.UP * stats.ground_offset
	heading = yaw
	pitch = 0.0
	rotation = Vector3(0.0, heading, 0.0)


## True while on the ground (parked or rolling).
func on_ground() -> bool:
	return mode == Mode.PARKED or mode == Mode.ROLLING


## Is this ground (a _ground_ray hit) somewhere the plane can land? Island
## terrain only (not roofs), flat enough, and clear of the sea.
func can_land_on(hit: Dictionary) -> bool:
	if hit.get("water", false):
		return true  # (only a seaplane is offered the water: _surface_ray)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("terrain"):
		return false
	var n: Vector3 = hit.normal
	var p: Vector3 = hit.position
	return n.y >= cos(deg_to_rad(LAND_MAX_SLOPE_DEG)) and p.y > Waves.height(p.x, p.z) + LAND_MIN_HEIGHT


## Room ahead to roll out after landing: a low ray along the heading from
## just above the ground under the plane meets nothing (or only gentle
## terrain) within LAND_ROOM.
func _room_to_roll(below: Dictionary) -> bool:
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var from: Vector3 = (below.position as Vector3) + Vector3.UP * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * LAND_ROOM, GameSettings.LAYER_WORLD)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return (hit.collider as Node).is_in_group("terrain") and (hit.normal as Vector3).y >= cos(deg_to_rad(ROLL_MAX_SLOPE_DEG))


## The world straight below `pos` (from a little above it): {} or a ray hit.
func _ground_ray(pos: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 6.0, pos + Vector3.DOWN * 60.0, GameSettings.LAYER_WORLD)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


## What's below `pos` to land on: the ground, or for a seaplane the sea
## when it's open water there ({position, normal, water: true}).
func _surface_ray(pos: Vector3) -> Dictionary:
	var hit := _ground_ray(pos)
	if not stats.floats:
		return hit
	var wy := Waves.height(pos.x, pos.z)
	if hit.is_empty() or (hit.collider as Node).is_in_group("water") or (hit.position as Vector3).y < wy - 1.5:
		return {"position": Vector3(pos.x, wy, pos.z), "normal": Vector3.UP, "water": true}
	return hit


## A seaplane doesn't bump into the sea's flat collision surface (it lands on
## the waves instead); other planes do (and splash).
func _update_water_exception() -> void:
	var found := false
	for w in get_tree().get_nodes_in_group("water"):
		if w is PhysicsBody3D:
			found = true
			if stats.floats:
				add_collision_exception_with(w)
			else:
				remove_collision_exception_with(w)
	if found or not stats.floats:
		_water_exc = stats.floats


## A seaplane landed on the water (taxiing or parked).
func on_water() -> bool:
	return _on_water and on_ground()


## Height of the plane's origin above the ground at which the wheels (or
## the belly, for low planes) touch.
func _touch_height() -> float:
	return maxf(stats.ground_offset, BODY_RADIUS * stats.model_scale) + 0.35


## About to meet the ground this tick? Land if it's a fair landing: on
## landable ground, and (when crashes are on) not diving or boosting in.
## Anything else is left to the normal collision (bump) or safety system.
func _try_touch_down(delta: float) -> bool:
	var next := global_position + velocity * delta
	var hit := _surface_ray(next)
	if hit.is_empty() or next.y - hit.position.y > _touch_height() or not can_land_on(hit):
		return false
	# Flat, landable ground is always a landing, never a crash (however
	# fast or steep). Can't-crash mode keeps the plane up unless it's
	# coming in to land (safety.landing), so this only happens on purpose.
	if not crashes and not safety.landing:
		return false
	speed = minf(speed, stats.cruise_speed * LAND_MAX_SPEED)
	_roll_await_release = input.raw_throttle > 0.2
	global_position = next
	_ground_y = hit.position.y
	mode = Mode.ROLLING
	_landing = true
	boost_amount = 0.0
	_on_water = hit.get("water", false)
	if _on_water:
		Sfx.play("splash", 0.9)
		_spray(26, 9.0)
	else:
		Sfx.play("pop", 0.55)
	touched_down.emit()
	WorldEvents.send("landing", global_position, {"water": _on_water})
	return true


## What's in the way within `dist` m along the ground: nothing; an EDGE
## (water, a drop, no ground); or a WALL (a building, a steep bank).
func _ahead(dir: Vector3, dist: float) -> Ahead:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (dist + BODY_RADIUS * stats.model_scale), GameSettings.LAYER_WORLD)
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if not wall.is_empty() and (wall.normal as Vector3).y < cos(deg_to_rad(ROLL_MAX_SLOPE_DEG)):
		return Ahead.WALL
	var hit := _ground_ray(from + dir * dist)
	if hit.is_empty():
		return Ahead.EDGE
	var p: Vector3 = hit.position
	if p.y < Waves.height(p.x, p.z) + LAND_MIN_HEIGHT or p.y < _ground_y - maxf(dist * 0.6, 2.5):
		return Ahead.EDGE
	if p.y > _ground_y + maxf(dist * 0.6, 2.5):
		return Ahead.WALL
	if (hit.normal as Vector3).y < cos(deg_to_rad(ROLL_MAX_SLOPE_DEG)):
		# Too steep to roll on: a bank to stop for if it goes up, an edge
		# to fly off if it falls away.
		return Ahead.WALL if p.y > _ground_y else Ahead.EDGE
	return Ahead.CLEAR


## Player-driven ground roll, following the ground. Taking off: boost
## speeds up, slow brakes, the stick steers a little; pull up once fast
## enough to lift off (off the runway it lifts off by itself at speed, and
## at water's edge straight away). Landing: it slows down by itself (slow
## brakes harder) and parks when it stops; boost to take off again, or pull
## up while still fast for a touch-and-go. It stops for anything in the
## way, and on take-off noses round away from walls.
func _roll_step(delta: float) -> void:
	var lift_speed := stats.cruise_speed * LIFTOFF_FRACTION
	if _roll_await_release and input.raw_throttle < 0.2:
		_roll_await_release = false
	var boosting := input.throttle > 0.2 and not _roll_await_release
	var braking := input.throttle < -0.2
	if _landing and boosting:
		_landing = false  # changed their mind: off we go again
		Sfx.play("whoosh", 0.7)
	if braking:
		speed = maxf(speed - ROLL_BRAKE * delta, 0.0)
	elif _landing:
		speed = maxf(speed - ROLL_FRICTION * delta, 0.0)
	else:
		speed = minf(speed + (ROLL_BOOST_ACCEL if boosting else ROLL_ACCEL) * delta, stats.cruise_speed * (stats.boost_multiplier if boosting else 1.0))
	var steer := input.stick.x * deg_to_rad(ROLL_TURN_DEG) * clampf(speed / 10.0, 0.0, 1.0)
	var flat := Vector3(-sin(heading), 0.0, -cos(heading))
	# Anything in the way within stopping distance?
	var stop_dist := speed * speed / (2.0 * ROLL_STOP_BRAKE) + 5.0
	var ahead := _ahead(flat, stop_dist)
	if ahead != Ahead.CLEAR:
		if not _landing and ahead == Ahead.EDGE and not braking:
			speed = maxf(speed, lift_speed * 0.6)
			lift_off()  # water's edge: up we go, like the end of the runway
			return
		speed = maxf(speed - ROLL_STOP_BRAKE * delta, 0.0)
		if not _landing and ahead == Ahead.WALL and not braking:
			# Nose round away from the wall (the stick picks the side).
			steer = deg_to_rad(ROLL_PIVOT_DEG) * (signf(input.stick.x) if absf(input.stick.x) > 0.2 else 1.0)
			speed = minf(speed, 1.0)
	heading = wrapf(heading - steer * delta, -PI, PI)
	flat = Vector3(-sin(heading), 0.0, -cos(heading))
	var pos := global_position + flat * speed * delta
	var ground := _ground_ray(pos)
	var slope_pitch := 0.0
	if not ground.is_empty() and (ground.position as Vector3).y > _ground_y - 3.0 and (ground.position as Vector3).y < _ground_y + 3.0:
		_ground_y = ground.position.y
		slope_pitch = asin(clampf(-flat.dot(ground.normal), -1.0, 1.0))
	else:
		pos = global_position  # nothing sensible to roll onto: stay put
		speed = 0.0
	# Wheels on the ground (settling down gently right after touchdown).
	var wheels := _ground_y + stats.ground_offset
	pos.y = wheels if global_position.y <= wheels else move_toward(global_position.y, wheels, ROLL_SETTLE * delta)
	global_position = pos
	pitch = move_toward(pitch, slope_pitch, deg_to_rad(40.0) * delta)
	rotation = Vector3(pitch, heading, 0.0)
	velocity = flat * speed
	boost_amount = 0.0
	visuals.update_visuals(input.stick.x * 0.3, speed + 6.0, stats, delta)
	if speed <= 0.01 and (_landing or braking):
		_park_here()
		return
	var off_runway := not IslandShape.on_runway(pos.x, pos.z)
	if speed >= lift_speed and (input.stick.y > 0.2 or (off_runway and not _landing)):
		lift_off()


## A seaplane on the water: like the ground roll (boost to go, slow brakes,
## it slows by itself after landing and parks bobbing on the waves), but it
## follows the waves, turns more readily, throws up spray, and noses round
## before beaches, piers and boats instead of running onto them. Fast
## enough (and pulling up, or not landing): lift off.
func _water_step(delta: float) -> void:
	var lift_speed := stats.cruise_speed * LIFTOFF_FRACTION
	if _roll_await_release and input.raw_throttle < 0.2:
		_roll_await_release = false
	var boosting := input.throttle > 0.2 and not _roll_await_release
	var braking := input.throttle < -0.2
	if _landing and boosting:
		_landing = false
		Sfx.play("whoosh", 0.7)
	if braking:
		speed = maxf(speed - ROLL_BRAKE * delta, 0.0)
	elif _landing:
		speed = maxf(speed - ROLL_FRICTION * 1.4 * delta, 0.0)  # water slows it quicker
	else:
		speed = minf(speed + (ROLL_BOOST_ACCEL if boosting else ROLL_ACCEL) * delta, stats.cruise_speed * (stats.boost_multiplier if boosting else 1.0))
	var steer := input.stick.x * deg_to_rad(WATER_TURN_DEG) * clampf(speed / 8.0, 0.35, 1.0)
	var flat := Vector3(-sin(heading), 0.0, -cos(heading))
	if _shore_ahead(flat, speed * speed / (2.0 * ROLL_STOP_BRAKE) + SHORE_MARGIN):
		speed = maxf(speed - ROLL_STOP_BRAKE * delta, 0.0)
		if not _landing and not braking:
			steer = deg_to_rad(ROLL_PIVOT_DEG) * (signf(input.stick.x) if absf(input.stick.x) > 0.2 else 1.0)
			speed = minf(speed, 2.0)
	heading = wrapf(heading - steer * delta, -PI, PI)
	flat = Vector3(-sin(heading), 0.0, -cos(heading))
	_ride_waves(global_position + flat * speed * delta, delta)
	velocity = flat * speed
	boost_amount = 0.0
	visuals.update_visuals(input.stick.x * 0.3, speed + 6.0, stats, delta)
	_spray_t -= delta
	if speed > 5.0 and _spray_t <= 0.0:
		_spray_t = 0.18
		_spray(6, 3.0 + speed * 0.15)
	if speed <= 0.01 and (_landing or braking):
		_park_here()
		return
	if speed >= lift_speed and (input.stick.y > 0.2 or not _landing):
		lift_off()


## Floats on the waves at `pos`: the right height, nose following the swell.
func _ride_waves(pos: Vector3, delta: float) -> void:
	var flat := Vector3(-sin(heading), 0.0, -cos(heading))
	pos.y = Waves.height(pos.x, pos.z) + stats.ground_offset * FLOAT_RIDE
	global_position = pos
	_ground_y = pos.y - stats.ground_offset
	var fore := Waves.height(pos.x + flat.x * 4.0, pos.z + flat.z * 4.0)
	var aft := Waves.height(pos.x - flat.x * 4.0, pos.z - flat.z * 4.0)
	pitch = move_toward(pitch, atan2(fore - aft, 8.0), deg_to_rad(30.0) * delta)
	rotation = Vector3(pitch, heading, 0.0)


## A beach (shallow water or land), a pier, a boat or anything solid within
## `dist` m ahead on the water?
func _shore_ahead(dir: Vector3, dist: float) -> bool:
	var p := global_position + dir * dist
	if DeliveryManager.ground_at(p.x, p.z) > Waves.height(p.x, p.z) - 1.5:
		return true  # the beach (shallows, then land)
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * dist, GameSettings.LAYER_WORLD)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## White spray round the floats.
func _spray(count: int, strength: float) -> void:
	var s := PickupBurst.new(count, strength, [Color.WHITE, Color("dff4ff")])
	s.gravity = Vector3(0, -14, 0)
	s.lifetime = 0.9
	s.position = global_position - Vector3.UP * stats.ground_offset * 0.8  # set before adding
	get_parent().add_child(s)


## Stay parked until the stick and triggers have been let go once (used
## when the player climbs back in: the stick was pushed to walk here).
func hold_until_release() -> void:
	_await_release = true
	_release_delay = 0.2  # let the input catch up with the real stick first


## Where someone getting out would stand: beside the cockpit, on the left
## (or the right, behind or in front if that's no good). `fits` is asked
## about each spot (Vector3 on the ground -> bool).
func exit_spots() -> Array[Vector3]:
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var left := Vector3(-cos(heading), 0.0, sin(heading))
	var reach := BODY_RADIUS * stats.model_scale + 3.5
	var out: Array[Vector3] = []
	for off in [left, -left, -fwd, fwd, (left - fwd).normalized(), (-left - fwd).normalized()]:
		out.append(global_position + off * reach)
	return out


## Stopped: sit here with the engine idling until the player wants to go.
func _park_here() -> void:
	var was_landing := _landing
	speed = 0.0
	velocity = Vector3.ZERO
	mode = Mode.PARKED
	_landing = false
	_await_release = true
	_release_delay = 0.2  # the game switching state can blank the input for a tick
	parked.emit(was_landing)


## Leave the ground: normal flight, nose up, a moment's grace from crashes.
func lift_off() -> void:
	mode = Mode.FLYING
	_airborne = 0.0
	_landing = false
	pitch = deg_to_rad(LIFTOFF_PITCH_DEG)
	_grace = CRASH_GRACE
	global_position.y += 0.5
	# Airborne now: the usual floor (can't-crash mode) applies from this
	# moment, not a frame later.
	safety.landing = false
	safety.enforce()
	Sfx.play("whoosh", 1.0)
	takeoff_finished.emit()
	var on_tarmac := IslandShape.on_runway(global_position.x, global_position.z)
	var surface := "water" if _on_water else ("runway" if on_tarmac else "grass")
	if _on_water:
		_spray(30, 8.0)
		Sfx.play("splash", 1.2, -4.0)
		_climb_out = CLIMB_OUT_TIME
	_on_water = false
	WorldEvents.send("takeoff", global_position - Vector3.UP * stats.ground_offset, {"surface": surface})


func _crash() -> void:
	var into_water := global_position.y < _water_y() + 1.5
	mode = Mode.CRASHED
	visuals.cancel_tricks()
	_crash_spin = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(6, 10) * (1.0 if randf() < 0.5 else -1.0))
	velocity = Vector3.ZERO
	boost_amount = 0.0
	crashed.emit(global_position, into_water)
	WorldEvents.send("crash", global_position, {"water": into_water})


## X: a barrel roll, or (holding the stick to climb) a loop, if there's
## room above for it. Both are visual only: flight is unchanged.
func trick() -> void:
	if mode == Mode.FLYING and input.raw_stick.y > LOOP_STICK and _room_for_loop() and visuals.loop():
		return
	visuals.barrel_roll()


## Clear sky above for a loop (no cave roof, overhang or the sky's ceiling)?
func _room_for_loop() -> bool:
	var top := AircraftVisuals.LOOP_RADIUS * 2.0 + 6.0
	if global_position.y + top > safety.ceiling_height:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.UP * top, GameSettings.LAYER_WORLD)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Blown up (by the dragon): the plane vanishes in a fireball. main.gd
## plays the explosion (see `exploded`) and respawns it like a crash.
func explode() -> void:
	if mode == Mode.CRASHED:
		return
	exploded = true
	visuals.visible = false
	mode = Mode.CRASHED
	_crash_spin = Vector3.ZERO
	velocity = Vector3.ZERO
	boost_amount = 0.0
	crashed.emit(global_position, false)
	WorldEvents.send("crash", global_position, {"water": false})


## Below this height the plane is in the sea (waves included).
func _water_y() -> float:
	var p := global_position
	return Waves.height(p.x, p.z) + WATER_LEVEL * stats.model_scale


## A tumble on the spot while the game fades back to the runway.
func _crashed_step(delta: float) -> void:
	speed = move_toward(speed, 0.0, 40.0 * delta)
	visuals.rotation += _crash_spin * delta
	_crash_spin *= exp(-1.5 * delta)


## Instantly place the plane (spawning, respawning, plane swap).
## Also puts the plane in normal flying mode.
func teleport(pos: Vector3, yaw: float) -> void:
	mode = Mode.FLYING
	if visuals:
		visuals.cancel_tricks()
	_on_water = false
	_climb_out = 0.0
	_airborne = 99.0
	_grace = CRASH_GRACE
	exploded = false
	if visuals:
		visuals.rotation = Vector3.ZERO
		visuals.visible = true
	global_position = pos
	heading = yaw
	pitch = 0.0
	rotation = Vector3(0.0, heading, 0.0)
	velocity = _forward() * speed
	reset_physics_interpolation()


func _forward() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, heading, 0.0)).z
