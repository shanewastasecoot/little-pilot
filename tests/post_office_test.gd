extends Node
## Going into the post offices (Phase 5):
##   in/out   walking into a post office's front door goes in (its own
##            inside, the same size as the shop outside); walking into the
##            doorway comes out on its doorstep, on safe ground
##   postie   the postie stands behind the counter, cheers when she comes
##            up, and gives her the post office sticker on her first visit
##            (saved; only once)
##   play     walking into the pile of letters takes one; walking it to the
##            post box posts it; standing on the scales swings the needle
##            round; the hidden star is found; a letter in her arms stays
##            inside when she goes out
##   layout   nothing stands in the doorway or in front of a window
##   others   the city's post office has its own inside too
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_post_office.cfg"

var _main: Node
var _w: Walker
var _fails := 0
var _side := 0.0
var _side_from := Vector3.ZERO


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_w = _main.walker
	_main.title.hide()
	_w.override_enabled = true
	_main.walk_camera.override_enabled = true
	_main.indoor_camera.override_enabled = true
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nPOST OFFICE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var po: PostOffice = _main.delivery.post_offices[0]
	await _walk_in(po)
	_check("walking into the post office's door goes in", _main.state == _main.State.INDOORS and _main.building == po)
	var it: Interior = _main.interior
	var r: Array = it.data.rooms[0].rect
	_check("inside, one room the same size as the shop outside", absf(float(r[2]) - 1.64 * PostOffice.SHOP_SCALE) < 0.5
			and absf(float(r[3]) - 0.97 * PostOffice.SHOP_SCALE) < 0.5)
	_check("you stand on its floor", _w.is_on_floor() and it.room_at(_w.global_position).get("id", "") == "sorting")
	# The postie, the sticker.
	var keeper: Shopkeeper = it.shopkeepers[0]
	var things: PostOfficeThings = it.post_office_things[0]
	await _walk_to(keeper.global_position + Vector3(0, 0, 6.0), 1.5, 400)
	await _frames(60)
	_check("the postie behind the counter gives her the post office sticker on her first visit",
			SaveManager.stickers == ["post_office"] and keeper.model.anim in ["Cheer", "Idle"])
	# Letters.
	await _walk_to(things.pile_point(), 1.0, 400)
	await _frames(15)
	var took: bool = _w.model.carrying and _w.model.carry_item == "Letter"
	await _walk_to(things.box_point() + (things.pile_point() - things.box_point()).normalized() * 2.5, 1.0, 500)
	await _frames(15)
	_check("walking into the letters takes one, and walking it to the post box posts it",
			took and things.letters_posted == 1 and not _w.model.carrying)
	# Scales.
	await _walk_to(things.scale_point(), 0.8, 400)
	await _frames(90)
	_check("standing on the scales swings the needle round", things.on_scale() and things.needle_angle() > 1.5)
	# The star.
	var star: HouseStar = it.house_star
	await _walk_to(star.global_position, 0.8, 500)
	await _frames(10)
	_check("the hidden star is found", star.is_taken())
	# Layout.
	var blocked := InteriorChecks.blocked_doorways(it)
	var covered := InteriorChecks.covered_windows(it)
	for b in blocked + covered:
		print("    ", b)
	_check("nothing stands in the doorway or in front of a window", blocked.is_empty() and covered.is_empty())
	# Out, with a letter: it stays inside.
	await _walk_to(things.pile_point(), 1.0, 400)
	await _frames(10)
	await _walk_out(it)
	var step := po.doorstep()
	_check("walking into the doorway comes out on its doorstep, on safe ground", _main.state == _main.State.ON_FOOT
			and Vector2(_w.global_position.x - step.x, _w.global_position.z - step.z).length() < 3.0 and _w.is_on_floor())
	_check("a letter in her arms stays inside", not _w.model.carrying)
	# Second visit: no second sticker.
	await _walk_in(po)
	await _walk_to(keeper.global_position + Vector3(0, 0, 6.0), 1.5, 400)
	await _frames(40)
	_check("only one sticker, however often she comes", SaveManager.stickers.size() == 1)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("the sticker is saved", SaveManager.stickers == ["post_office"])
	await _walk_out(it)
	# The city's post office: its own inside.
	var city_po: PostOffice = _main.delivery.post_offices[1]
	await _walk_in(city_po)
	_check("the city's post office has its own inside", _main.state == _main.State.INDOORS and _main.interior != it
			and _main.interior.shopkeepers.size() == 1)
	await _walk_out(_main.interior)
	_check("and out again onto its doorstep", _main.state == _main.State.ON_FOOT)


## Get out of the plane near `po` and walk in through its front door.
func _walk_in(po: PostOffice) -> void:
	if _main.state != _main.State.ON_FOOT:
		var away := po.doorstep() + po.global_transform.basis.z * 50.0 + po.global_transform.basis.x * 30.0
		_main.aircraft.park(Vector3(away.x, _ground(away), away.z), 0.0)
		_main._enter(_main.State.FLYING)
		await _frames(3)
		_main.toggle_plane()
		await _frames(10)
	var step := po.doorstep()
	_w.place(Vector3(step.x, _ground(step) + 0.2, step.z), po.doorstep_yaw() + PI)
	await _frames(10)
	await _walk_to(po.door_point(), 0.6, 400)
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(60)


func _walk_out(it: Interior) -> void:
	var door: Vector3 = (it.exits[0].trigger as Node3D).global_position
	await _walk_to(door, 0.5, 600)
	await _until(func(): return _main.state == _main.State.ON_FOOT, 240)
	await _frames(60)


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
			_main.indoor_camera.yaw = yaw
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
