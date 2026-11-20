extends Node
## Her house (Phase 3, checkpoint 1: front door, hall, playroom):
##   outside  the house stands on its pad near the airport, outside the
##            city plan, with its door facing the runway
##   in/out   walking into the front door goes in (INDOORS: outdoor world
##            hidden and paused, indoor camera live); walking into the
##            doorway from inside comes out on the doorstep, on safe dry
##            ground, never inside the house; again and again
##   rooms    from the front door you can walk to every room through the
##            doorways, and the floor holds you everywhere (never through
##            the floor, never stuck in a wall)
##   view     a wall between the camera and you fades away
##   play     walking up to the toy box opens it and toys pop out; walking
##            into the ball kicks it; going out tidies them away
##   plane    the plane parked on the doorstep is moved before you come out
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_house.cfg"

var _main: Node
var _w: Walker
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_w = _main.walker
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_w.override_enabled = true
	_main.walk_camera.override_enabled = true
	_main.indoor_camera.override_enabled = true
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nHOUSE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var house: HerHouse = _main.house
	_check("her house stands near the airport, outside the city plan", house != null
			and Vector2(house.global_position.x, house.global_position.z).distance_to(IslandShape.HOUSE) < 0.5
			and not IslandShape.in_city_area(IslandShape.HOUSE.x, IslandShape.HOUSE.y, 30.0))
	# --- in through the front door ------------------------------------------------------
	await _walk_up_to_door()
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(60)
	_check("walking into the front door goes in", _main.state == _main.State.INDOORS)
	_check("inside: the outdoor world is hidden and paused, the indoor camera is live", not _main.map.visible
			and _main.map.process_mode == Node.PROCESS_MODE_DISABLED and _main.indoor_camera.cam.current)
	_check("you stand on the hall floor", _on_floor() and _main.interior.room_at(_w.global_position).get("id", "") == "hall")
	# --- every room ----------------------------------------------------------------------
	var interior: Interior = _main.interior
	var ok_rooms := true
	var lowest := INF
	for route in [["playroom", [interior.door_point("hall", "W", 0.5)]], ["hall", [interior.door_point("hall", "W", 0.5)]]]:
		var goal: Vector3 = interior.room_centre(route[0])
		var reached := true
		for p in route[1] + [goal]:
			if not await _walk_to(p, 2.5, 600):
				reached = false
			lowest = minf(lowest, _w.global_position.y - interior.global_position.y)
		if not reached or interior.room_at(_w.global_position).get("id", "") != route[0]:
			ok_rooms = false
			print("    couldn't reach ", route[0], " (at ", (_w.global_position - interior.global_position).round(), ")")
	_check("you can walk to every room through the doorways", ok_rooms)
	_check("the floor holds you everywhere (never through it)", lowest > -0.5 and _on_floor())
	# Bump along every wall of the playroom: never inside or through one.
	var through := false
	var pr: Dictionary = {}
	for r in interior.rooms:
		if r.id == "playroom":
			pr = r
	var rect: Rect2 = pr.rect
	await _walk_to(interior.door_point("hall", "W", 0.5), 2.5, 600)
	await _walk_to(interior.room_centre("playroom"), 2.5, 600)
	for corner in [Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y),
			Vector2(rect.position.x, rect.end.y)]:
		await _walk_to(interior.room_centre("playroom"), 2.5, 300)
		var target := interior.to_global(Vector3(corner.x, 0.0, corner.y))
		await _walk_to(target, 1.0, 240)
		var lp := interior.to_local(_w.global_position)
		if not rect.grow(0.2).has_point(Vector2(lp.x, lp.z)):
			through = true
			print("    left the room at ", lp.round())
	_check("walking into the walls never goes through them", not through and _on_floor())
	# --- the view --------------------------------------------------------------------------
	await _walk_to(interior.room_centre("playroom"), 2.0, 300)
	_main.indoor_camera.snap_to(0.0)  # camera to the south: the south wall is between
	await _frames(60)
	var faded := false
	for w in interior.walls:
		if w.room == "playroom" and (w.inward as Vector2).is_equal_approx(Vector2(0, -1)):
			faded = (w.pieces[0] as GeometryInstance3D).transparency > 0.5
	_check("the wall between the camera and you fades away", faded)
	# --- play -------------------------------------------------------------------------------
	var tb: ToyBox = interior.toy_boxes[0]
	await _walk_to(tb.global_position + tb.global_transform.basis.z * 6.0, 1.5, 400)
	await _frames(30)
	_check("walking up to the toy box opens it and toys pop out", tb.is_open() and tb._toys.size() == ToyBox.TOYS)
	var ball: BouncyBall = interior.balls[0]
	var ball_at := ball.global_position
	var to_ball := ball.global_position - _w.global_position
	await _walk_to(ball.global_position + to_ball.normalized() * 3.0, 0.5, 300)
	await _frames(60)
	_check("walking into the ball kicks it", ball.global_position.distance_to(ball_at) > 3.0)
	# --- out, and in and out again -----------------------------------------------------------
	await _walk_out()
	_check("walking into the doorway comes out on the doorstep", _main.state == _main.State.ON_FOOT
			and _flat_dist(_w.global_position, house.doorstep()) < 3.0)
	_check("outside on safe dry ground, never inside the house", _safe_outside())
	_check("going out tidies the toys away", not tb.is_open() and tb._toys.is_empty() and ball.global_position.distance_to(
			interior.to_global(ball.home) if false else ball.get_parent().to_global(ball.home)) < 1.0)
	var cycles_ok := true
	for i in 3:
		await _walk_up_to_door()
		var inside := await _until(func(): return _main.state == _main.State.INDOORS, 240)
		await _frames(40)
		await _walk_out()
		if not (inside and _main.state == _main.State.ON_FOOT and _safe_outside()):
			cycles_ok = false
	_check("in and out again and again", cycles_ok)
	# --- the plane on the doorstep ---------------------------------------------------------
	await _walk_up_to_door()
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(30)
	var step := house.doorstep()
	_main.aircraft.park(Vector3(step.x, IslandShape.height(step.x, step.z), step.z), 0.0)
	await _walk_out()
	_check("the plane parked on the doorstep is moved before you come out",
			_flat_dist(_main.aircraft.global_position, step) > 15.0 and _safe_outside())


## Out of the plane beside the house, then walk into the front door.
func _walk_up_to_door() -> void:
	var house: HerHouse = _main.house
	if _main.state != _main.State.ON_FOOT:
		var step := house.doorstep()
		var spot := step + (step - house.global_position).normalized() * 40.0
		_main.aircraft.park(Vector3(spot.x, IslandShape.height(spot.x, spot.z), spot.z), 0.0)
		_main._enter(_main.State.FLYING)
		await _frames(3)
		_main.toggle_plane()
		await _frames(10)
	await _walk_to(house.doorstep(), 2.0, 600)
	await _walk_to(house.to_global(HerHouse.DOOR), 0.6, 300)


## Walk into the doorway you came in by, and wait to be outside.
func _walk_out() -> void:
	var interior: Interior = _main.interior
	var door := interior.door_point("hall", "S", 0.5)
	await _walk_to(interior.room_centre("hall"), 3.0, 600)
	await _walk_to(door, 0.5, 400)
	await _until(func(): return _main.state == _main.State.ON_FOOT, 240)
	_w.override_move = Vector2.ZERO
	await _frames(30)


func _on_floor() -> bool:
	return _w.is_on_floor()


## On the island's ground, dry, on foot, and not inside the house's walls.
func _safe_outside() -> bool:
	var p := _w.global_position
	var house: HerHouse = _main.house
	var lp := house.to_local(p)
	var inside_walls := absf(lp.x) < HerHouse.SIZE.x * 0.5 and absf(lp.z) < HerHouse.SIZE.z * 0.5
	var ground := IslandShape.height(p.x, p.z)
	return _main.map.visible and not inside_walls and absf(p.y - ground) < 2.5 and ground > Walker.SHORE_LEVEL


## Walk (sprinting) towards `p`; the camera follows. False if it never got there.
func _walk_to(p: Vector3, radius: float, max_frames: int) -> bool:
	for i in max_frames:
		var d := p - _w.global_position
		d.y = 0.0
		if d.length() < radius:
			_w.override_move = Vector2.ZERO
			_w.override_sprint = false
			return true
		var yaw := atan2(-d.x, -d.z)
		if _main.state == _main.State.INDOORS:
			_main.indoor_camera.yaw = yaw
		else:
			_main.walk_camera.snap_to(yaw)
		_w.camera_yaw = yaw
		_w.override_move = Vector2(0, 1)
		_w.override_sprint = d.length() > 8.0
		await get_tree().physics_frame
	_w.override_move = Vector2.ZERO
	_w.override_sprint = false
	return false


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
