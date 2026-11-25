class_name Dragon
extends Node3D
## A big fire-breathing dragon that lives in the cave under Dragon Peak.
##
## Its day: it sleeps on its gold, wakes with a roar, flies out and patrols
## the map (visiting landmarks, favouring wherever it last noticed the
## plane), then flies home to rest. While out it is aware of:
##  * the map: it knows the landmarks and its cave, follows the terrain with
##    probes ahead and below, keeps inside the world, and never enters the
##    airport (the runway is always a safe place to flee to);
##  * the plane: it sees in a cone (blocked by terrain), hears it nearby
##    (louder when boosting or honking), builds up alertness before it
##    commits, remembers where it last saw it and predicts where it's going,
##    searches there when it loses it, and gives up after a while. Every so
##    often it also catches the plane's scent: a rough idea of where it is
##    (sharper on harder levels), and it goes to have a look.
## When it catches up it breathes fire (with a warning wind-up). Its fire and
## its body blow the plane up, but only while `dangerous` (parents' Crashes
## setting); otherwise it just chases and roars. Difficulty (Easy/Medium/
## Hard) changes its senses, speed, persistence and aim.

signal plane_hit(where: Vector3, by_fire: bool)
signal state_changed(state: int)

enum State { SLEEP, WAKE, EMERGE, PATROL, INVESTIGATE, HUNT, BREATHE, RETURN, ENTER, GLOAT, GRUMPY }

const MODEL := "res://assets/environment/dragon.glb"
const SCALE := 9.0
const ANIM_FLY := "CharacterArmature|Fast_Flying"
const ANIM_HOVER := "CharacterArmature|Flying_Idle"
const ANIM_WINDUP := "CharacterArmature|Headbutt"
const ANIM_GLOAT := "CharacterArmature|Yes"
const AIRPORT_RADIUS := 470.0
const WORLD_RADIUS := 4200.0
const CEILING := 330.0
const PATROL_SPEED := 15.0
const PATROL_ALT := 55.0
const HUNT_ALT := 16.0
const FIRE_TIME := 1.7
## Hit spheres in model space (x, y, z, radius) before SCALE: body, head,
## wings, tail.
const HIT_SPHERES := [
	Vector4(0.0, 1.3, -0.2, 0.95), Vector4(0.0, 2.2, 0.15, 0.6),
	Vector4(1.1, 1.8, -0.5, 0.55), Vector4(-1.1, 1.8, -0.5, 0.55),
	Vector4(0.0, 0.6, -0.5, 0.5),
]

## Per difficulty: sight range (m), field of view (deg), hearing range (m),
## seconds of noticing before it hunts, memory (s), chase speed (fraction of
## the plane's cruise, boost), turn rate (deg/s), aim lead (0..1), seconds
## before it gives up a chase, fire range (m), fire cone (deg), seconds
## between breaths, wind-up (s), sleep and patrol times (s).
const LEVELS := [
	{"sight": 560.0, "fov": 115.0, "hear": 180.0, "notice": 2.1, "memory": 6.0,
		"scent_every": 34.0, "scent_range": 1300.0, "scent_blur": 220.0,
		"cruise_frac": 0.95, "boost_frac": 0.0, "turn": 43.0, "lead": 0.0, "give_up": 10.0,
		"fire_range": 55.0, "fire_cone": 13.0, "cooldown": 9.0, "windup": 1.4,
		"sleep": 70.0, "patrol": 80.0},
	{"sight": 720.0, "fov": 135.0, "hear": 240.0, "notice": 1.6, "memory": 8.0,
		"scent_every": 30.0, "scent_range": 1500.0, "scent_blur": 160.0,
		"cruise_frac": 0.0, "boost_frac": 0.87, "turn": 62.0, "lead": 0.5, "give_up": 18.0,
		"fire_range": 70.0, "fire_cone": 16.0, "cooldown": 6.5, "windup": 1.0,
		"sleep": 48.0, "patrol": 105.0},
	{"sight": 900.0, "fov": 160.0, "hear": 320.0, "notice": 0.8, "memory": 14.0,
		"scent_every": 19.0, "scent_range": 2200.0, "scent_blur": 85.0,
		"cruise_frac": 0.0, "boost_frac": 1.0, "turn": 82.0, "lead": 0.9, "give_up": 34.0,
		"fire_range": 85.0, "fire_cone": 18.0, "cooldown": 4.5, "windup": 0.7,
		"sleep": 30.0, "patrol": 140.0},
]

## The dragon can hurt the plane (parents' Crashes setting).
var dangerous := true
var level := 0
var state: int = State.SLEEP
## 0..1: how sure it is the plane is there. Hunts at 1.
var alert := 0.0
## Someone took its treasure: it hunts her plane the next time it flies.
var angry := false
var _treasure_at := Vector3.ZERO
var _stomp := 0.0
var lair: DragonLair
var plane: Node3D
var velocity := Vector3.ZERO
var speed := 0.0

var _model: Node3D
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _head_bone := -1
var _fire: CPUParticles3D
var _mouth_light: OmniLight3D
var _ray := PhysicsRayQueryParameters3D.new()
var _t_state := 0.0          # seconds in the current state
var _clock := 0.0            # seconds until the next sleep/wake switch
var _fire_cool := 0.0
var _ignore := 0.0           # seconds to ignore the plane (after a respawn)
var _last_seen := Vector3.ZERO
var _last_vel := Vector3.ZERO
var _seen_ago := 999.0
var _hunt_time := 0.0
var _target := Vector3.ZERO
var _route: Array[Vector3] = []
var _visited: Array[String] = []
var _search_spin := 1.0
var _roll := 0.0
var _yaw_rate := 0.0
var _hit_cool := 0.0
var _honked := 0.0           # seconds since a honk it heard (louder)
var _search_t := 0.0
var _scent_t := 20.0         # seconds until it next sniffs the air


func _ready() -> void:
	WorldEvents.happened.connect(_hear)
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in [ANIM_FLY, ANIM_HOVER]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	_head_bone = _skel.find_bone("Head")
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.extra_cull_margin = 4.0  # wings flap outside the rest pose
	_build_fire()
	_ray.collision_mask = GameSettings.LAYER_WORLD
	SaveManager.settings_changed.connect(_read_settings)
	_read_settings()
	# Start asleep at home; the first outing comes a little sooner.
	_sleep_now()
	_clock = 45.0


## On Easy, a plane carrying a parcel is left alone (DeliveryManager sets
## this): as if it weren't flying, so the dragon stops hunting and wanders.
var parcel_truce := false


func _read_settings() -> void:
	level = clampi(SaveManager.dragon_level, 0, LEVELS.size() - 1)
	dangerous = SaveManager.crashes
	var on := SaveManager.dragon
	if on != visible:
		visible = on
		process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if not on:
			_sleep_now()
			_clock = 30.0


func cfg(key: String) -> float:
	return LEVELS[level][key]


## Ignore the plane for a while (it just respawned at the runway).
func forgive(seconds := 10.0) -> void:
	_ignore = seconds
	alert = 0.0
	_seen_ago = 999.0
	if state in [State.HUNT, State.BREATHE, State.INVESTIGATE]:
		_set_state(State.GLOAT)


## A piece of its treasure was taken (at `at`): woken at home, it's grumpy
## (roars, stomps, huffs smoke at the nest; never hurts anyone on foot),
## then hunts the plane once she takes off. Out flying, it roars and will
## hunt the plane as soon as it sees it fly.
func treasure_taken(at: Vector3) -> void:
	angry = true
	_treasure_at = at
	var home := lair != null and global_position.distance_to(lair.to_global(lair.nest())) < 150.0
	if home and state in [State.SLEEP, State.WAKE, State.ENTER, State.GLOAT, State.GRUMPY]:
		_set_state(State.GRUMPY)
	else:
		Sfx.play_at("roar", global_position, 0.9, 6.0)


## Wake up and come out now (tests, and when the plane buzzes the cave).
func _hear(kind: String, _where: Vector3, _info: Dictionary) -> void:
	if kind == "honk":
		_honked = 1.5


func wake() -> void:
	if state == State.SLEEP:
		_set_state(State.WAKE)


func _physics_process(delta: float) -> void:
	if plane == null:
		plane = get_tree().get_first_node_in_group("aircraft") as Node3D
	_honked = maxf(0.0, _honked - delta)
	_t_state += delta
	_fire_cool = maxf(0.0, _fire_cool - delta)
	_ignore = maxf(0.0, _ignore - delta)
	_hit_cool = maxf(0.0, _hit_cool - delta)
	_seen_ago += delta
	_perceive(delta)
	_sniff(delta)
	match state:
		State.SLEEP: _sleep_step(delta)
		State.WAKE: _wake_step(delta)
		State.EMERGE: _emerge_step(delta)
		State.PATROL: _patrol_step(delta)
		State.INVESTIGATE: _investigate_step(delta)
		State.HUNT: _hunt_step(delta)
		State.BREATHE: _breathe_step(delta)
		State.RETURN: _return_step(delta)
		State.ENTER: _enter_step(delta)
		State.GLOAT: _gloat_step(delta)
		State.GRUMPY: _grumpy_step(delta)
	_check_hits()
	_animate(delta)


# --- Senses ------------------------------------------------------------------

func _plane_flying() -> bool:
	return plane != null and plane.get("mode") == Aircraft.Mode.FLYING and not parcel_truce


func _in_sanctuary(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(IslandShape.RUNWAY) < AIRPORT_RADIUS


## Sight (cone + line of sight past terrain) and hearing build alertness;
## the airport, respawn grace and sleep calm it down.
func _perceive(delta: float) -> void:
	if not _plane_flying() or _ignore > 0.0 or _in_sanctuary(plane.global_position):
		alert = maxf(0.0, alert - delta * 0.5)
		return
	var to := plane.global_position - global_position
	var dist := to.length()
	var noisy: float = 1.0 + float(plane.get("boost_amount")) * 0.6 + (0.8 if _honked > 0.0 else 0.0)
	var heard := dist < cfg("hear") * noisy * (0.6 if state == State.SLEEP else 1.0)
	var seen := false
	if state != State.SLEEP and dist < cfg("sight"):
		var fwd := _forward()
		var angle := rad_to_deg(fwd.angle_to(to))
		if angle < cfg("fov") * 0.5 or dist < 60.0:
			seen = _clear_line(global_position + Vector3.UP * 12.0, plane.global_position)
	if seen or heard:
		_last_seen = plane.global_position
		_last_vel = plane.get("velocity") if plane.get("velocity") != null else Vector3.ZERO
		_seen_ago = 0.0
		# Closer and in plain sight: notices faster.
		var gain := (1.0 if seen else 0.6) * (1.0 + clampf(1.0 - dist / cfg("sight"), 0.0, 1.0))
		alert = minf(1.0, alert + delta * gain / cfg("notice"))
		if state == State.SLEEP and heard:
			wake()
	else:
		alert = maxf(0.0, alert - delta / cfg("memory"))


## Now and then, while patrolling, it smells roughly where the plane is
## and goes to look (never into the airport).
func _sniff(delta: float) -> void:
	_scent_t -= delta
	if _scent_t > 0.0 or state != State.PATROL:
		return
	_scent_t = cfg("scent_every") * randf_range(0.8, 1.2)
	if not _plane_flying() or _ignore > 0.0 or _in_sanctuary(plane.global_position):
		return
	if global_position.distance_to(plane.global_position) > cfg("scent_range"):
		return
	var blur := cfg("scent_blur")
	_last_seen = plane.global_position + Vector3(randf_range(-blur, blur), 0, randf_range(-blur, blur))
	_last_vel = Vector3.ZERO
	_seen_ago = 0.0
	alert = maxf(alert, 0.4)
	Sfx.play_at("roar", global_position, 1.3, -6.0)  # a sniffing growl
	_set_state(State.INVESTIGATE)


func _clear_line(a: Vector3, b: Vector3) -> bool:
	_ray.from = a
	_ray.to = b
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _forward() -> Vector3:
	return velocity.normalized() if velocity.length() > 0.5 else global_basis.z


## Where to aim: where the plane will be by the time we get there.
func _intercept() -> Vector3:
	var p := _last_seen
	if _seen_ago < 0.2 and plane:
		p = plane.global_position
	var t := clampf(global_position.distance_to(p) / maxf(_chase_speed(), 1.0), 0.0, 3.0)
	return p + _last_vel * t * cfg("lead")


func _chase_speed() -> float:
	var st: AircraftStats = plane.get("stats") if plane else null
	var cruise := st.cruise_speed if st else 22.0
	var boost := cruise * (st.boost_multiplier if st else 1.5)
	return cruise * cfg("cruise_frac") if cfg("cruise_frac") > 0.0 else boost * cfg("boost_frac")


# --- States ------------------------------------------------------------------

func _set_state(s: int) -> void:
	if s == state:
		return
	state = s
	_t_state = 0.0
	if lair:
		lair.set_sleeping(s == State.SLEEP)
	match s:
		State.WAKE:
			Sfx.play_at("roar", global_position, 0.8)
		State.INVESTIGATE:
			_search_t = 0.0
		State.HUNT:
			_hunt_time = 0.0
			Sfx.play_at("roar", global_position, 1.0, 4.0)
		State.PATROL:
			_clock = cfg("patrol")
			_plan_route()
		State.GLOAT:
			Sfx.play_at("roar", global_position, 1.15)
		State.GRUMPY:
			_stomp = 0.0
			speed = 0.0
			velocity = Vector3.ZERO
			if lair:
				lair.set_sleeping(false)
	state_changed.emit(s)


func _sleep_now() -> void:
	state = State.SLEEP
	_t_state = 0.0
	alert = 0.0
	speed = 0.0
	velocity = Vector3.ZERO
	_clock = cfg("sleep")
	if lair:
		global_position = lair.to_global(lair.nest())
		global_basis = Basis(Vector3.UP, lair.global_rotation.y + PI)  # face the back wall, curled up
		lair.set_sleeping(true)
	reset_physics_interpolation()
	_fire.emitting = false


func _sleep_step(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		wake()


func _wake_step(_delta: float) -> void:
	# Turn round to face the doorway, then go.
	var out := lair.global_basis.z
	global_basis = global_basis.slerp(Basis.looking_at(-out), 0.05).orthonormalized()
	if _t_state > 2.0:
		_set_state(State.EMERGE)


func _emerge_step(delta: float) -> void:
	# Fly straight out through the mouth (no avoidance inside the cave).
	var exit := lair.to_global(lair.mouth() + Vector3(0, 30, 160))
	_fly_direct(exit, PATROL_SPEED, delta)
	if global_position.distance_to(exit) < 25.0:
		_set_state(State.PATROL)
		_hunt_if_angry()


## Treasure was taken and her plane is flying: straight after it.
func _hunt_if_angry() -> void:
	if angry and _plane_flying() and _ignore <= 0.0:
		angry = false
		alert = 1.0
		_seen_ago = 0.0
		_last_seen = plane.global_position
		_set_state(State.HUNT)


## Woken by a thief: at the nest, facing where the treasure was, a roar, a
## stomp and a huff of smoke every couple of seconds. When her plane takes
## off it flies out after it; if she stays on foot it settles down again
## (still angry: it hunts the plane next time it's out).
func _grumpy_step(delta: float) -> void:
	var to := _treasure_at - global_position
	to.y = 0.0
	if to.length() > 1.0:
		global_basis = global_basis.slerp(Basis.looking_at(-to.normalized()), 0.06).orthonormalized()
	_stomp -= delta
	if _stomp <= 0.0:
		_stomp = 2.4
		Sfx.play_at("roar", global_position, randf_range(0.85, 1.0), 5.0)
		var puff := PickupBurst.new(30, 10.0, [Color("666666"), Color("888888"), Color("ff7b2e")])
		(lair if lair else self).add_child(puff)
		puff.global_position = global_position + _forward() * 22.0 + Vector3.UP * 14.0
		var base := global_position.y
		var tw := create_tween()
		tw.tween_property(self, "global_position:y", base + 4.0, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "global_position:y", base, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play_at("boom", global_position, 0.6, 2.0))
	if _t_state > 6.0 and _plane_flying():
		_set_state(State.EMERGE)
	elif _t_state > 45.0:
		_sleep_now()


func _patrol_step(delta: float) -> void:
	_hunt_if_angry()
	if state != State.PATROL:
		return
	if alert >= 1.0:
		_set_state(State.HUNT)
		return
	if alert > 0.35 and _seen_ago < 1.0:
		# Something caught its eye: go and look.
		_set_state(State.INVESTIGATE)
		return
	_clock -= delta
	if _clock <= 0.0:
		_set_state(State.RETURN)
		return
	if _route.is_empty():
		_plan_route()
	var goal := _route[0]
	_steer(goal, PATROL_SPEED, PATROL_ALT, delta)
	if Vector2(global_position.x, global_position.z).distance_to(Vector2(goal.x, goal.z)) < 90.0:
		_route.pop_front()


## Pick the next few landmarks to visit: nearby ones, ones near where it
## last noticed the plane, not ones it just visited, never the airport.
func _plan_route() -> void:
	_route.clear()
	var here := global_position
	var choices: Array = []
	for l: Node3D in get_tree().get_nodes_in_group("landmarks"):
		if l == lair or _in_sanctuary(l.global_position) or l.name in _visited:
			continue
		if Vector2(l.global_position.x, l.global_position.z).length() > WORLD_RADIUS - 200.0:
			continue
		var score := -here.distance_to(l.global_position) * 0.8 + randf() * 700.0
		# Home turf: prefers the main island over far-off islands.
		score -= Vector2(l.global_position.x, l.global_position.z).length() * 0.3
		if _seen_ago < 120.0:
			score -= l.global_position.distance_to(_last_seen) * 0.6
		choices.append([score, l])
	choices.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(3, choices.size()):
		var l: Node3D = choices[k][1]
		_route.append(l.global_position)
		_visited.append(l.name)
	while _visited.size() > 6:
		_visited.pop_front()
	if _route.is_empty():
		_route.append(lair.to_global(Vector3(0, 80, 400)))


func _investigate_step(delta: float) -> void:
	if alert >= 1.0:
		_set_state(State.HUNT)
		return
	# Searches for a while once it gets there (the trip itself doesn't count).
	if global_position.distance_to(_last_seen) < 220.0:
		_search_t += delta
	if _search_t > cfg("memory") * 2.0 + 15.0 or _t_state > 150.0:
		_set_state(State.PATROL)
		return
	# Fly to where it noticed the plane, then circle there looking.
	var goal := _last_seen
	if global_position.distance_to(goal) < 120.0:
		var around := goal - global_position
		goal = global_position + around.rotated(Vector3.UP, 0.9 * _search_spin)
	_steer(goal, PATROL_SPEED * 1.25, PATROL_ALT * 0.7, delta)


func _hunt_step(delta: float) -> void:
	_hunt_time += delta
	var lost := _seen_ago > cfg("memory") or alert <= 0.05
	if not _plane_flying() or _ignore > 0.0:
		_set_state(State.GLOAT)
		return
	if lost or _hunt_time > cfg("give_up") or _in_sanctuary(_last_seen):
		_search_spin = -_search_spin
		_set_state(State.INVESTIGATE if not _in_sanctuary(_last_seen) else State.PATROL)
		return
	var aim := _intercept()
	_steer(aim, _chase_speed(), HUNT_ALT, delta, true)
	# Close and roughly facing it: take a breath.
	var to := plane.global_position - global_position
	if _fire_cool <= 0.0 and to.length() < cfg("fire_range") * 1.7 and rad_to_deg(_forward().angle_to(to)) < 35.0 and _seen_ago < 0.3:
		_set_state(State.BREATHE)


func _breathe_step(delta: float) -> void:
	var windup := cfg("windup")
	var aim := _intercept() if plane else global_position + _forward() * 50.0
	_steer(aim, _chase_speed() * 0.75, HUNT_ALT, delta, true, 0.6)
	var glow := clampf(_t_state / windup, 0.0, 1.0)
	_mouth_light.light_energy = glow * 6.0
	if _t_state >= windup and not _fire.emitting:
		_fire.emitting = true
		Sfx.play_at("fire", global_position, 1.0, 6.0)
	if _t_state >= windup + FIRE_TIME:
		_fire.emitting = false
		_mouth_light.light_energy = 0.0
		_fire_cool = cfg("cooldown")
		_set_state(State.HUNT if _plane_flying() else State.GLOAT)


func _return_step(delta: float) -> void:
	if alert >= 1.0 and level > 0:
		_set_state(State.HUNT)  # medium/hard: a late chance is still a chance
		return
	var approach := lair.to_global(lair.mouth() + Vector3(0, 30, 200))
	_steer(approach, PATROL_SPEED * 1.2, PATROL_ALT, delta)
	if global_position.distance_to(approach) < 40.0:
		_set_state(State.ENTER)


func _enter_step(delta: float) -> void:
	var door := lair.to_global(lair.mouth() + Vector3(0, 6, 10))
	var goal := door if _t_state < 6.0 and global_position.distance_to(door) > 20.0 else lair.to_global(lair.nest())
	_fly_direct(goal, PATROL_SPEED * 0.7, delta)
	if global_position.distance_to(lair.to_global(lair.nest())) < 12.0 or _t_state > 18.0:
		_sleep_now()


func _gloat_step(delta: float) -> void:
	# A victory loop with a happy wiggle, then off on patrol again.
	var around := global_position + _forward().rotated(Vector3.UP, 0.6) * 80.0
	_steer(around, PATROL_SPEED, PATROL_ALT, delta)
	if _t_state > 4.0:
		_set_state(State.PATROL)


# --- Flying ------------------------------------------------------------------

## Fly toward `goal` at `want_speed`, keeping `min_alt` over the ground,
## dodging terrain ahead, the airport and the edge of the world.
func _steer(goal: Vector3, want_speed: float, min_alt: float, delta: float, hunting := false, turn_mult := 1.0) -> void:
	var pos := global_position
	var desired := goal - pos
	if not hunting:
		desired.y = 0.0  # cruise level; altitude is handled below
	desired = desired.normalized() if desired.length() > 0.1 else _forward()
	var fwd := _forward()
	# Ground below and the floor we must stay above.
	var ground := _ground_y(pos)
	var floor_y := ground + min_alt
	if pos.y < floor_y:
		desired.y = maxf(desired.y, clampf((floor_y - pos.y) / 25.0, 0.2, 0.9))
	elif not hunting:
		desired.y = clampf((floor_y + 20.0 - pos.y) / 60.0, -0.4, 0.4)
	# Probe ahead: steer away from anything solid in the way.
	var look := maxf(speed * 2.5, 50.0) + 30.0
	_ray.from = pos
	_ray.to = pos + fwd * look
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		var close := 1.0 - pos.distance_to(hit.position) / look
		desired = (desired + n * (1.0 + close * 2.0) + Vector3.UP * (0.6 + close)).normalized()
	# Stay out of the airport and inside the world.
	var flat := Vector2(pos.x, pos.z)
	var from_airport := flat - IslandShape.RUNWAY
	if from_airport.length() < AIRPORT_RADIUS + 120.0:
		var push := 1.0 - (from_airport.length() - AIRPORT_RADIUS) / 120.0
		var out := from_airport.normalized()
		desired += Vector3(out.x, 0, out.y) * clampf(push, 0.0, 3.0) * 1.5
	if flat.length() > WORLD_RADIUS:
		desired += Vector3(-flat.x, 0, -flat.y).normalized() * 2.0
	if pos.y > CEILING:
		desired.y = minf(desired.y, -0.3)
	desired = desired.normalized()
	# Turn toward it at the dragon's turn rate.
	var max_turn := deg_to_rad(cfg("turn") * turn_mult) * delta
	var new_fwd := _turn_toward(fwd, desired, max_turn)
	new_fwd.y = clampf(new_fwd.y, -0.55, 0.65)
	new_fwd = new_fwd.normalized()
	_yaw_rate = lerpf(_yaw_rate, fwd.signed_angle_to(new_fwd, Vector3.UP) / maxf(delta, 0.001), 0.1)
	speed = move_toward(speed, want_speed, 10.0 * delta)
	velocity = new_fwd * speed
	global_position += velocity * delta
	# Never sink into the ground, even in a tight spot.
	global_position.y = maxf(global_position.y, ground + 8.0)
	_face(new_fwd)


## Straight-line flight (into and out of the cave), no avoidance.
func _fly_direct(goal: Vector3, want_speed: float, delta: float) -> void:
	var to := goal - global_position
	var fwd := _turn_toward(_forward(), to.normalized(), deg_to_rad(90.0) * delta)
	speed = move_toward(speed, minf(want_speed, to.length() * 1.5 + 3.0), 10.0 * delta)
	velocity = fwd * speed
	global_position += velocity * delta
	_face(fwd)


static func _turn_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle < 0.0001:
		return to
	var axis := from.cross(to)
	if axis.length() < 0.0001:
		axis = Vector3.UP
	return from.rotated(axis.normalized(), minf(angle, max_angle))


func _face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		return
	global_basis = Basis.looking_at(-flat.normalized())  # model faces +Z


func _ground_y(p: Vector3) -> float:
	_ray.from = p + Vector3.UP * 50.0
	_ray.to = p + Vector3.DOWN * 600.0
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return maxf(hit.position.y if not hit.is_empty() else 0.0, 0.0)


# --- Fire, hits and looks ----------------------------------------------------

func mouth_position() -> Vector3:
	var head := _skel.global_transform * _skel.get_bone_global_pose(_head_bone).origin
	return head + _model.global_basis.z.normalized() * 0.45 * SCALE + Vector3.DOWN * 0.1 * SCALE


func _check_hits() -> void:
	if not dangerous or not _plane_flying() or _hit_cool > 0.0 or state == State.SLEEP:
		return
	var p := plane.global_position
	var plane_r := 1.4 * float((plane.get("stats") as AircraftStats).model_scale)
	# Body, head, wings and tail.
	for s: Vector4 in HIT_SPHERES:
		var c := _model.global_transform * Vector3(s.x, s.y, s.z)
		if p.distance_to(c) < s.w * SCALE + plane_r:
			_hit(p, false)
			return
	# Fire: a cone from the mouth, blocked by terrain.
	if _fire.emitting:
		var m := mouth_position()
		var to := p - m
		var dir := _fire_dir()
		if to.length() < cfg("fire_range") and rad_to_deg(dir.angle_to(to)) < cfg("fire_cone") + rad_to_deg(atan2(plane_r, maxf(to.length(), 1.0))):
			if _clear_line(m, p):
				_hit(p, true)


func _hit(where: Vector3, by_fire: bool) -> void:
	_hit_cool = 3.0
	plane_hit.emit(where, by_fire)


func _fire_dir() -> Vector3:
	return (_model.global_basis.z.normalized() + Vector3.DOWN * 0.12).normalized()


func _animate(delta: float) -> void:
	var fast := speed > PATROL_SPEED * 0.8
	var want := ANIM_HOVER
	if state == State.BREATHE and _t_state < cfg("windup"):
		want = ANIM_WINDUP
	elif state == State.GLOAT and _t_state < 1.2:
		want = ANIM_GLOAT
	elif fast:
		want = ANIM_FLY
	if _anim.current_animation != want:
		_anim.play(want, 0.35)
	_anim.speed_scale = 0.35 if state == State.SLEEP else (1.3 if state == State.HUNT else 1.0)
	# Lean into flight: upright when hovering, stretched out when fast;
	# bank into turns.
	var lean := clampf(speed / 30.0, 0.0, 1.0) * 0.95
	if state == State.BREATHE:
		lean *= 0.5
	_roll = lerpf(_roll, clampf(-_yaw_rate * 0.5, -0.6, 0.6), 1.0 - exp(-3.0 * delta))
	var climb := asin(clampf(velocity.normalized().y if speed > 1.0 else 0.0, -1.0, 1.0))
	_model.rotation = Vector3(lean - climb * 0.6, 0.0, _roll)
	if state == State.SLEEP:
		_model.rotation = Vector3(0.0, 0.0, 0.0)
	# Fire follows the mouth.
	_fire.global_position = mouth_position()
	_fire.direction = _fire_dir()
	_mouth_light.global_position = _fire.global_position


func _build_fire() -> void:
	_fire = CPUParticles3D.new()
	_fire.emitting = false
	_fire.amount = 150
	_fire.lifetime = 0.9
	_fire.local_coords = false
	_fire.spread = 9.0
	_fire.initial_velocity_min = 70.0
	_fire.initial_velocity_max = 95.0
	_fire.gravity = Vector3(0, 6, 0)
	_fire.damping_min = 20.0
	_fire.damping_max = 35.0
	_fire.scale_amount_min = 5.0
	_fire.scale_amount_max = 10.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.6))
	_fire.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1.5, 1.25, 0.55, 1), Color(1.4, 0.5, 0.1, 1), Color(0.95, 0.16, 0.04, 0.9), Color(0.22, 0.18, 0.18, 0.0)])
	_fire.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PickupBurst._soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_keep_scale = true
	quad.material = mat
	_fire.mesh = quad
	add_child(_fire)
	_fire.top_level = true
	_mouth_light = OmniLight3D.new()
	_mouth_light.light_color = Color("ff7a2a")
	_mouth_light.light_energy = 0.0
	_mouth_light.omni_range = 40.0
	add_child(_mouth_light)
	_mouth_light.top_level = true
