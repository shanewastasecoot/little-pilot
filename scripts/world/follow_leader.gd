class_name FollowLeader
extends Node3D
## Follow-the-leader (Phase 14, item 7). Every few minutes of free flying a
## friendly plane (the Light Plane in bright orange, rainbow trails on) pulls
## up beside her, toots twice and waggles its wings: "follow me!". Then it
## flies a loose scenic loop (round the city and the lighthouse, over the
## farm and the forest, or through the mountain valley), well above the
## ground. No timer and no penalty:
##   - close behind it, it flies on at a gentle pace (a little faster if
##     she's right on its tail);
##   - falling behind, it slows down; far away (or landed), it circles where
##     it is and waits;
##   - left far behind for a while (she flew off somewhere else), it
##     waggles goodbye, climbs away and comes back another time.
## At the end of the loop: bursts of colour in the sky, a fanfare and a few
## bonus stars; then it climbs away. Honk at it and it toots back.

signal finished(route: String)

enum S { AWAY, INVITE, LEAD, LEAVING }

const FIRST_AFTER := 120.0     # s of free flying before the first invitation
const INVITE_EVERY := 240.0    # ... and between invitations
const WAGGLE_TIME := 3.0       # waggling beside her before it sets off
const GIVE_UP := 50.0          # she's been far away this long: it leaves
const GROUNDED_GIVE_UP := 40.0 # she's out of the plane this long: it leaves
const NEAR := 150.0            # this close counts as following
const WAIT_FAR := 360.0        # further than this: it circles and waits
const FAST := 22.0             # her own cruising speed: close behind, it keeps its distance
const CRUISE := 18.0
const SLOW := 11.0
const CIRCLE_RADIUS := 80.0
const CLEARANCE := 60.0        # at least this far above the ground
const MIN_HEIGHT := 85.0
const REWARD_STARS := 5
const MODEL := "res://scenes/aircraft/models/light_plane_model.tscn"
const PAINT := Color("ff8c42")
## The loops (x, z on the map; heights are worked out from the ground).
const ROUTES := {
	"city": [Vector2(-150, 280), Vector2(160, 460), Vector2(380, 900), Vector2(700, 860), Vector2(980, 700),
		Vector2(860, 300), Vector2(420, 160)],
	"farm": [Vector2(-260, 180), Vector2(-560, 494), Vector2(-880, 260), Vector2(-760, -120), Vector2(-610, -380),
		Vector2(-300, -200)],
	"valley": [Vector2(-360, -330), Vector2(-100, -760), Vector2(160, -1040), Vector2(620, -780), Vector2(520, -380)],
}

var main: Node
var state := S.AWAY
var route := ""
## Metres along the loop, and its length.
var progress := 0.0
var length := 0.0
var speed := CRUISE
## (Tests) seconds until the next invitation.
var countdown := FIRST_AFTER
## 0 = on the loop, 1 = circling and waiting.
var waiting := 0.0
var visuals: AircraftVisuals
var _stats: AircraftStats
var _curve: Curve3D
var _t := 0.0
var _far := 0.0
var _grounded := 0.0
var _circle := 0.0
var _yaw := 0.0
var _turn := 0.0
var _leave_vel := Vector3.ZERO


func _ready() -> void:
	name = "FollowLeader"
	_stats = AircraftCatalog.get_stats("light")
	visuals = (load(MODEL) as PackedScene).instantiate() as AircraftVisuals
	visuals.base_scale = _stats.model_scale
	# Bold, long rainbow trails: easy to see and to follow from behind.
	for t in visuals.boost_trails:
		t.width = 1.1
		t.lifetime = 2.2
	add_child(visuals)
	visuals.set_paint(PAINT)
	top_level = true
	hide()
	WorldReaction.add(self, 320.0, ["honk"], 2.0, func(_k: String, _w: Vector3):
		if state == S.INVITE or state == S.LEAD:
			_toot())


## Pull up beside her and invite her to follow (`which` route, or the one
## nearest her). False if she isn't flying.
func invite(which := "") -> bool:
	var plane: Node3D = main.aircraft if main else null
	if plane == null:
		return false
	route = which if ROUTES.has(which) else _nearest_route(plane.global_position)
	var fwd := Vector3(-sin(plane.heading), 0.0, -cos(plane.heading))
	var left := Vector3(-fwd.z, 0.0, fwd.x)
	# Close, to one side and a little higher: clearly in view, above her plane.
	var start := plane.global_position + fwd * 70.0 + left * 30.0 + Vector3.UP * 8.0
	start.y = maxf(start.y, _safe_y(Vector2(start.x, start.z)))
	_build_curve(start)
	progress = 0.0
	speed = CRUISE
	waiting = 0.0
	_far = 0.0
	_grounded = 0.0
	_t = 0.0
	global_position = start
	_yaw = plane.heading
	rotation = Vector3(0.0, _yaw, 0.0)
	state = S.INVITE
	show()
	_toot()
	get_tree().create_timer(0.45, false).timeout.connect(_toot)
	return true


func _physics_process(delta: float) -> void:
	if main == null:
		return
	match state:
		S.AWAY:
			if _free_flying():
				countdown -= delta
				if countdown <= 0.0:
					countdown = INVITE_EVERY
					invite()
		S.INVITE:
			_t += delta
			# Alongside her for a moment, waggling its wings.
			var plane: Node3D = main.aircraft
			var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
			global_position += fwd * CRUISE * delta
			_turn = sin(_t * 7.0) * 0.9
			_place_on_curve_start(delta)
			if _t >= WAGGLE_TIME:
				state = S.LEAD
			_check_given_up(delta, plane)
		S.LEAD:
			_lead(delta)
		S.LEAVING:
			_t += delta
			global_position += _leave_vel * delta
			_leave_vel.y = move_toward(_leave_vel.y, 14.0, 6.0 * delta)
			_turn = sin(_t * 7.0) * 0.6 if _t < 2.0 else 0.0
			if _t > 9.0:
				state = S.AWAY
				hide()
	if visible:
		visuals.update_visuals(_turn, speed, _stats, delta, 1.0)  # rainbow trails always on: easy to follow


func _lead(delta: float) -> void:
	var plane: Node3D = main.aircraft
	var d := plane.global_position.distance_to(global_position)
	var in_plane: bool = main.has_method("_in_plane") and main._in_plane()
	# Speed: gentle when she's following, slower when she lags, waiting when
	# she's far (or out of the plane).
	var far := d > WAIT_FAR or not in_plane
	var want := FAST if d < 60.0 else (CRUISE if d < NEAR else SLOW)
	speed = move_toward(speed, want, 4.0 * delta)
	waiting = move_toward(waiting, 1.0 if far else 0.0, delta / 2.0)
	if waiting < 0.5:
		progress = minf(progress + speed * delta * (1.0 - waiting), length)
	var on_path := _curve.sample_baked(progress, true)
	_circle += speed / CIRCLE_RADIUS * delta
	var around := on_path + Vector3(cos(_circle), 0.0, sin(_circle)) * CIRCLE_RADIUS
	var target := on_path.lerp(around, smoothstep(0.0, 1.0, waiting))
	var step := target - global_position
	var dir := step.normalized() if step.length() > 0.01 else Vector3(-sin(_yaw), 0, -cos(_yaw))
	global_position = target
	var want_yaw := atan2(-dir.x, -dir.z)
	var dyaw := wrapf(want_yaw - _yaw, -PI, PI)
	_yaw = wrapf(_yaw + clampf(dyaw, -2.0 * delta, 2.0 * delta), -PI, PI)
	_turn = lerpf(_turn, clampf(-dyaw * 3.0, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
	rotation = Vector3(clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.3, 0.3), _yaw, 0.0)
	_check_given_up(delta, plane)
	if progress >= length - 0.5 and state == S.LEAD:
		_finish()


## Still near the start of its loop while it waggles beside her.
func _place_on_curve_start(_delta: float) -> void:
	rotation = Vector3(0.0, _yaw, 0.0)


func _check_given_up(delta: float, plane: Node3D) -> void:
	var in_plane: bool = main.has_method("_in_plane") and main._in_plane()
	_grounded = _grounded + delta if not in_plane else 0.0
	var far := plane != null and plane.global_position.distance_to(global_position) > WAIT_FAR
	_far = _far + delta if far else 0.0
	if _far > GIVE_UP or _grounded > GROUNDED_GIVE_UP:
		leave()
	elif main.get("_dragon") and main._dragon and main._dragon.visible and main._dragon.state in [Dragon.State.HUNT, Dragon.State.BREATHE]:
		leave()  # (the dragon's after her: not now)
	elif plane == null:
		leave()


## Waggle goodbye and climb away (it comes back another time).
func leave() -> void:
	if state == S.AWAY or state == S.LEAVING:
		return
	state = S.LEAVING
	_t = 0.0
	_leave_vel = Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * speed + Vector3.UP * 4.0


func _finish() -> void:
	var at := global_position
	Sfx.play("fanfare")
	for k in 4:
		get_tree().create_timer(0.35 * k, false).timeout.connect(func():
			var b := PickupBurst.new(70, 22.0, [Color("ff3b3b"), Color("ffd23f"), Color("4cc06a"), Color("3f8cff"), Color("ff7eb9"), Color.WHITE])
			b.gravity = Vector3(0, -6, 0)
			b.lifetime = 2.0
			b.scale_amount_min = 1.2
			b.scale_amount_max = 2.4
			b.position = at + Vector3(randf_range(-30, 30), randf_range(10, 35), randf_range(-30, 30))
			get_parent().add_child(b)
			Sfx.play_at("boom", b.position, randf_range(1.2, 1.6), -10.0))
	if main.get("stars"):
		main.stars.add_bonus(REWARD_STARS)
	WorldEvents.send("follow_done", at, {"route": route})
	finished.emit(route)
	leave()


func _toot() -> void:
	Sfx.play_at("honk_prop", global_position, 1.25, 2.0)


func _free_flying() -> bool:
	return main.state == main.State.FLYING and main.aircraft.mode == Aircraft.Mode.FLYING


func _nearest_route(p: Vector3) -> String:
	var best := ""
	var best_d := INF
	for r in ROUTES:
		var d := Vector2(p.x, p.z).distance_to(ROUTES[r][0])
		if d < best_d:
			best_d = d
			best = r
	return best


## The loop from where it is now, through the route's points and back to
## its first one: points every ~80 m, each high enough over the ground near
## it, joined smoothly.
func _build_curve(start: Vector3) -> void:
	var pts: Array[Vector3] = [start]
	var way: Array = ROUTES[route].duplicate()
	way.append(way[0])
	var last := Vector2(start.x, start.z)
	for w: Vector2 in way:
		var n := maxi(int(last.distance_to(w) / 80.0), 1)
		for i in range(1, n + 1):
			var q := last.lerp(w, float(i) / n)
			pts.append(Vector3(q.x, _safe_y(q), q.y))
		last = w
	_curve = Curve3D.new()
	_curve.bake_interval = 4.0
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var h := (next - prev) * 0.25
		_curve.add_point(pts[i], -h, h)
	length = _curve.get_baked_length()


## High enough over the ground around `q` (the highest within 60 m).
func _safe_y(q: Vector2) -> float:
	var g := DeliveryManager.ground_at(q.x, q.y)
	for k in 6:
		var a := TAU * k / 6.0
		g = maxf(g, DeliveryManager.ground_at(q.x + cos(a) * 60.0, q.y + sin(a) * 60.0))
	return maxf(g + CLEARANCE, MIN_HEIGHT)
