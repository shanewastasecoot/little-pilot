extends Node
## Sailing (Phase 14): docks on the major islands and her own sail boat.
##   docks     a dock on each major island: a pier she can stand on from the
##             beach to its end, deep water at the berth
##   board     her boat starts at the home dock; she walks out along the
##             pier and Y puts her aboard (the boat camera)
##   sail      it sails forward, faster with the stick, and steers
##   aground   sailing at an island it stops before the shallows, never on land
##   horn      the honk button toots the horn (things nearby hear it)
##   arrive    Y near another island's dock: it glides in and she steps off
##             onto the pier; that's where it's moored now (saved)
##   call      Y at the end of a pier with no boat: it sails over and moors
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_boat.cfg"
var _fails := 0
var _main: Node
var _w: Walker
var _boat: SailBoat


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_w = _main.walker
	_boat = _main.boat
	var docks: Array = _main.docks
	# --- docks ---------------------------------------------------------------------------
	var good := 0
	for d: Dock in docks:
		var end_y := _ground(d.board_point())
		var start_y := _ground(d.global_transform * Vector3(0, 0, 4))
		var berth_depth := DeliveryManager.ground_at(d.berth().origin.x, d.berth().origin.z)
		if end_y > Walker.SHORE_LEVEL and start_y > Walker.SHORE_LEVEL and absf(end_y - d.global_position.y) < 0.3 and berth_depth < -2.5:
			good += 1
		else:
			print("    dock %s: end %.1f start %.1f berth depth %.1f" % [d.island, end_y, start_y, berth_depth])
	var islands := {}
	for d: Dock in docks:
		islands[d.island] = true
	_check("a dock on each major island: a pier to stand on, deep water at the berth", docks.size() == 7 and good == 7
			and islands.has("main") and islands.has("palm") and islands.has("castle") and islands.has("town"))
	# --- board ---------------------------------------------------------------------------
	var home: Dock = docks[0]
	var moored_home := _boat.dock == home and Dock.flat_dist(_boat.global_position, home.berth().origin) < 1.0
	_main._enter(_main.State.FLYING)
	await _frames(2)
	_main._enter(_main.State.ON_FOOT)
	var start := home.global_transform * Vector3(0, 0.3, 2.0)
	_w.place(start, 0.0)
	_w.override_enabled = true
	await _frames(5)
	var walked := await _walk_to(home.board_point(), 3.0, 900)
	var on_pier: bool = _w.global_position.y > Walker.SHORE_LEVEL
	_press("interact")
	await _frames(5)
	var aboard: bool = _main.state == _main.State.SAILING and _boat.driving and _main.sail_camera.cam.current and not _w.is_active()
	print("  note: moored at home %s, walked the pier %s (y %.1f), aboard %s" % [moored_home, walked, _w.global_position.y, aboard])
	_check("her boat is at the home dock; she walks out along the pier and Y puts her aboard", moored_home and walked and on_pier and aboard)
	# --- sail ----------------------------------------------------------------------------
	var p0 := _boat.global_position
	_boat.override_stick = Vector2(0, 1)
	await _frames(240)
	var went := _boat.global_position.distance_to(p0)
	var y0 := _boat.yaw
	_boat.override_stick = Vector2(1, 1)
	await _frames(180)
	var turned := absf(wrapf(_boat.yaw - y0, -PI, PI))
	print("  note: sailed %.0f m in 4 s (%.1f m/s), turned %.0f deg" % [went, _boat.speed, rad_to_deg(turned)])
	_check("it sails forward (faster with the stick) and steers", went > 25.0 and _boat.speed > SailBoat.CRUISE + 1.0 and turned > deg_to_rad(40.0))
	# --- aground ---------------------------------------------------------------------------
	# Off Palm Island's beach, pointing straight at it, full speed ahead.
	var palm: Dock = docks[1]
	var out := -palm.global_basis.z
	var off := palm.global_position + out * 140.0 + palm.global_basis.x * 60.0
	_boat.global_position = Vector3(off.x, 0, off.z)
	_boat.yaw = atan2(out.x, out.z)  # facing back towards the island
	_boat.rotation.y = _boat.yaw
	_boat.speed = SailBoat.FAST
	_boat.override_gust = true
	_boat.override_stick = Vector2(0, 1)
	var deepest := -999.0
	for i in 900:
		await get_tree().physics_frame
		deepest = maxf(deepest, DeliveryManager.ground_at(_boat.global_position.x, _boat.global_position.z))
	_boat.override_gust = false
	print("  note: aground check: shallowest under the boat %.1f m, speed %.1f" % [deepest, _boat.speed])
	_check("sailing at an island it stops before the shallows, never on land", deepest < SailBoat.SHALLOW and absf(_boat.speed) < 1.0)
	# --- horn ------------------------------------------------------------------------------
	var heard := [false]
	WorldEvents.happened.connect(func(k, _w2, _i): if k == "honk": heard[0] = true)
	_press("honk")
	await _frames(3)
	_check("the honk button toots the horn", heard[0])
	# --- arrive at Palm Island ------------------------------------------------------------------
	var near := palm.berth().origin - out * -30.0
	_boat.override_stick = Vector2.ZERO
	_boat.global_position = Vector3(near.x, 0, near.z)
	await _frames(3)
	var offered: bool = _boat.dock_near() == palm
	_press("interact")
	await _until(func(): return _main.state == _main.State.ON_FOOT, 300)
	await _frames(5)
	var stepped: bool = _main.state == _main.State.ON_FOOT and _w.is_active() and _w.global_position.distance_to(palm.step_off()) < 2.0 \
			and _ground(_w.global_position) > Walker.SHORE_LEVEL
	print("  note: offered %s, stepped off %s at %s, moored %s, saved dock %d" % [offered, stepped, str(_w.global_position.round()), _boat.dock == palm, SaveManager.boat_dock])
	_check("Y near another island's dock: it glides in and she steps off onto the pier", offered and stepped and _boat.dock == palm
			and SaveManager.boat_dock == palm.index)
	# --- call it home ---------------------------------------------------------------------------
	_w.place(home.board_point() + Vector3.UP * 0.1, 0.0)
	await _frames(5)
	_press("interact")
	await _until(func(): return _boat.dock == home, 400)
	await _frames(5)
	_check("Y at the end of a pier with no boat: it sails over and moors", _boat.dock == home and not _boat.berthing
			and _main.state == _main.State.ON_FOOT and Dock.flat_dist(_boat.global_position, home.berth().origin) < 1.0)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("where her boat is moored is saved", SaveManager.boat_dock == home.index)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nBOAT TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _walk_to(p: Vector3, radius: float, max_frames: int) -> bool:
	for i in max_frames:
		var d := p - _w.global_position
		d.y = 0.0
		if d.length() < radius:
			_w.override_move = Vector2.ZERO
			return true
		_main.walk_camera.snap_to(atan2(-d.x, -d.z))
		_w.override_move = Vector2(0, 1)
		await get_tree().physics_frame
	_w.override_move = Vector2.ZERO
	return false


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 30, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	var hit: Dictionary = _main.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -100.0


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
