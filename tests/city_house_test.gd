extends Node
## The city's houses (Phase 5):
##   plans    every house model has a floor plan the size of the model as
##            the city places it, its front door where the model's is;
##            nothing stands in a doorway or in front of a window; every
##            room can be reached; an owner and a hidden star
##   in/out   walking into a finished house's front door goes in; walking
##            into the doorway comes out on its doorstep
##   owner    the owner gives her the house sticker on her first visit
##   rooms    she can walk to every room (upstairs too in the two-storey
##            house) and find the hidden star
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_city_house.cfg"

var _main: Node
var _w: Walker
var _fails := 0
var _side := 0.0
var _side_from := Vector3.ZERO


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.city_seed = 12345
	SaveManager.playtime = 24.0 * 3600.0
	SaveManager.city_time = SaveManager.playtime
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_w = _main.walker
	_main.title.hide()
	_w.override_enabled = true
	_main.walk_camera.override_enabled = true
	_main.indoor_camera.override_enabled = true
	await _frames(5)
	await _plans()
	await _visit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nCITY HOUSE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


## Every model's plan, built on its own and checked.
func _plans() -> void:
	var problems: Array[String] = []
	var x := 0.0
	for model: String in CityHouseLayouts.MODELS:
		var plan := CityHouseLayouts.layout(model, 7)
		var it := BuildingGenerator.build(plan)
		add_child(it)
		it.global_position = Vector3(5000 + x, 3000, 5000)
		x += 200.0
		await _frames(2)
		var fp := CityHouseLayouts.inside_size(model)  # (the inside is bigger than the outside: INSIDE_SCALE)
		var lo := Vector2(INF, INF)
		var hi := -lo
		for r: Dictionary in plan.rooms:
			var a: Array = r.rect
			lo = lo.min(Vector2(a[0], a[1]))
			hi = hi.max(Vector2(float(a[0]) + float(a[2]), float(a[1]) + float(a[3])))
		if not (hi - lo).is_equal_approx(fp):
			problems.append("%s plan %s, model %s" % [model, str(hi - lo), str(fp)])
		var door_x := CityHouseLayouts.inside_door_x(model)
		var exit_at: Vector3 = it.to_local(it.entry_point())
		if absf(exit_at.x - door_x) > 0.6:
			problems.append("%s front door at x %.1f, model's at %.1f" % [model, exit_at.x, door_x])
		for b in InteriorChecks.blocked_doorways(it) + InteriorChecks.covered_windows(it):
			problems.append("%s %s" % [model, b])
		for r in it.rooms:
			if r.id != "living" and it.route("living", r.id).is_empty():
				problems.append("%s: can't get to %s" % [model, r.id])
		if it.shopkeepers.size() != 1 or it.house_star == null:
			problems.append("%s: owner %d, star %s" % [model, it.shopkeepers.size(), it.house_star != null])
		it.queue_free()
	for p in problems:
		print("    ", p)
	_check("every house model has a plan 1.6x its own size, its door where the model's is (scaled), clear doorways and windows, every room reachable, an owner and a star",
			problems.is_empty())


func _visit() -> void:
	# A finished single-storey house and the two-storey one, if the city has them.
	var one: CityBuild = null
	var two: CityBuild = null
	for b in _find_builds():
		var cb := b as CityBuild
		if cb == null or not cb.done or not cb.is_house():
			continue
		if str(cb.event.model) == "home_4":
			if two == null:
				two = cb
		elif one == null:
			one = cb
	_check("the grown city has houses to go into", one != null)
	if one == null:
		return
	await _walk_in(one)
	_check("walking into a house's front door goes in", _main.state == _main.State.INDOORS and _main.building == one)
	var it: Interior = _main.interior
	await _frames(30)
	var keeper: Shopkeeper = it.shopkeepers[0]
	await _walk_to(keeper.global_position, 4.5, 400)
	await _frames(40)
	_check("the owner gives her the house sticker on her first visit", SaveManager.stickers.has("city_house"))
	var visited := []
	print("  note: arrived at %s in %s" % [str((_w.global_position - it.global_position).round()), it.room_at(_w.global_position).get("id", "?")])
	for r in it.rooms:
		await _go_to_room(it, r.id)
		if it.room_at(_w.global_position).get("id", "") == r.id:
			visited.append(r.id)
	print("  note: %s rooms visited: %s" % [one.event.model, ", ".join(visited)])
	_check("she can walk to every room", visited.size() == it.rooms.size())
	var star: HouseStar = it.house_star
	if star:
		var star_room: String = it.room_at(star.global_position).get("id", "bedroom")
		await _go_to_room(it, star_room)
		# Round the furniture in the middle: along the back of the room to the
		# star's side, then to it (not past the front door).
		var rr: Rect2 = it.find_room(star_room).rect
		var back := it.to_global(Vector3(rr.get_center().x, 0, rr.position.y + 3.0))
		var star_l := it.to_local(star.global_position)
		var side := it.to_global(Vector3(star_l.x, 0, rr.position.y + 3.0))
		await _walk_to(back, 0.5, 300)
		await _walk_to(side, 0.8, 300)
		await _walk_to(star.global_position, 2.5, 400)  # (it's collected from ~3 m)
		await _frames(10)
	if star:
		print("  note: star in %s at %s, she's at %s" % [it.room_at(star.global_position).get("id", "?"), str((star.global_position - it.global_position).round()),
				str((_w.global_position - it.global_position).round())])
	_check("the hidden star is found", star != null and star.is_taken())
	await _go_to_room(it, "living")
	await _walk_out(it)
	var step := one.doorstep()
	_check("walking into the doorway comes out on its doorstep", _main.state == _main.State.ON_FOOT
			and Vector2(_w.global_position.x - step.x, _w.global_position.z - step.z).length() < 3.0)
	if two == null:
		print("  note: no two-storey house in this city")
		return
	await _walk_in(two)
	var it2: Interior = _main.interior
	await _go_to_room(it2, "bedroom2")
	_check("in the two-storey house she can walk upstairs to the bedrooms", it2.room_at(_w.global_position).get("id", "") == "bedroom2"
			and it2.storey_at(_w.global_position) == 1)
	await _go_to_room(it2, "living")
	await _walk_out(it2)
	_check("and out again", _main.state == _main.State.ON_FOOT)


func _find_builds() -> Array:
	return _main.find_children("*", "CityBuild", true, false)


func _walk_in(b: CityBuild) -> void:
	if _main.state != _main.State.ON_FOOT:
		var away := b.doorstep() + b.global_transform.basis.z * 40.0
		_main.aircraft.park(Vector3(away.x, _ground(away), away.z), 0.0)
		_main._enter(_main.State.FLYING)
		await _frames(3)
		_main.toggle_plane()
		await _frames(10)
	var step := b.doorstep()
	_w.place(Vector3(step.x, _ground(step) + 0.2, step.z), b.doorstep_yaw() + PI)
	await _frames(10)
	await _walk_to(b.door_point(), 0.5, 400)
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(60)


func _walk_out(it: Interior) -> void:
	var door: Vector3 = (it.exits[0].trigger as Node3D).global_position
	await _walk_to(door, 0.5, 600)
	await _until(func(): return _main.state == _main.State.ON_FOOT, 240)
	await _frames(60)


func _go_to_room(it: Interior, room_id: String) -> void:
	var here: String = it.room_at(_w.global_position).get("id", "living")
	if here == room_id:
		return
	for p in it.route(here, room_id) + [it.inside_point(room_id, here)]:
		await _walk_to(p, 1.5, 600)


func _walk_to(p: Vector3, radius: float, max_frames: int) -> bool:
	var start_state = _main.state
	for i in max_frames:
		if _main.state != start_state:
			_w.override_move = Vector2.ZERO
			return false
		var d := p - _w.global_position
		d.y = 0.0
		if d.length() < radius:
			_w.override_move = Vector2.ZERO
			_w.override_sprint = false
			return true
		var yaw := atan2(-d.x, -d.z)
		if _main.state == _main.State.INDOORS:
			_main.indoor_camera.snap_to(yaw)  # (no lag: she walks straight)
		else:
			_main.walk_camera.snap_to(yaw)
		_w.camera_yaw = yaw
		if i % 30 == 0:
			_side = 0.0 if i == 0 or _w.global_position.distance_to(_side_from) > 1.0 else (1.0 if _side <= 0.0 else -1.0)
			_side_from = _w.global_position
		_w.override_move = Vector2(_side, 0.4 if _side != 0.0 else 1.0).normalized()
		_w.override_sprint = d.length() > 8.0
		await get_tree().physics_frame
	_w.override_move = Vector2.ZERO
	_w.override_sprint = false
	return false


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 600, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	var hit: Dictionary = _main.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else 0.0


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
