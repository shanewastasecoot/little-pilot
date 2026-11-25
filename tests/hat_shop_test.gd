extends Node
## The hat shop (Phase 5):
##   where    it stands beside the airport post office
##   in/out   walking into its front door goes in (one room the size of the
##            shop); walking into the doorway comes out on its doorstep
##   milliner gives her the hat shop sticker on her first visit
##   layout   hat stands round the walls, the try-on mirror, nothing in the
##            doorway or in front of a window; the hidden star is found
##   mirror   walking past it changes nothing; standing at it shows the Y
##            hat prompt; Y opens the chooser, close up
##   trying   moving through the hats puts each on her head; B puts back
##            the one she came in with and spends nothing
##   buying   a hat she hasn't the stars for stays in the shop; one she can
##            afford: the price comes out of her purse (lifetime stars minus
##            what she's spent; the lifetime count itself never goes down),
##            it's hers and on her head; hers again for free; "no hat" puts
##            her outfit's own back
##   outside  she wears it out of the shop; it's all saved
##   city     a city shop the news called a hat shop has the same inside;
##            both shop models' plans are clear and furnished
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_hat_shop.cfg"

var _main: Node
var _w: Walker
var _fails := 0
var _side := 0.0
var _side_from := Vector3.ZERO


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.lifetime_stars = 5
	# A city old enough to have its first hat shop (a shop_small_a).
	SaveManager.city_seed = 990638
	SaveManager.playtime = 300.0 * 60.0
	SaveManager.city_time = SaveManager.playtime
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
	print("\nHAT SHOP TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	_plans()
	var hs: HatShop = get_tree().get_first_node_in_group("hat_shops")
	var po: PostOffice = _main.delivery.post_offices[0]
	_check("the hat shop stands beside the airport post office", hs != null
			and Vector2(hs.global_position.x - po.global_position.x, hs.global_position.z - po.global_position.z).length() < 120.0)
	await _walk_in(hs)
	_check("walking into the hat shop's door goes in", _main.state == _main.State.INDOORS and _main.building == hs)
	var it: Interior = _main.interior
	var r: Array = it.data.rooms[0].rect
	_check("inside, one room the size of the shop", absf(float(r[2]) - hs.footprint().x) < 0.5 and absf(float(r[3]) - hs.footprint().z) < 0.5)
	_check("you stand on its floor", _w.is_on_floor() and it.room_at(_w.global_position).get("id", "") == "shop")
	# The milliner, the sticker.
	var keeper: Shopkeeper = it.shopkeepers[0]
	await _walk_to(keeper.global_position + Vector3(0, 0, 5.2), 1.5, 400)
	await _frames(60)
	_check("the milliner gives her the hat shop sticker on her first visit", SaveManager.stickers == ["hat_shop"])
	# Layout.
	var stands := it.find_children("HatStand_*", "", true, false)
	print("  note: %d hat stands" % stands.size())
	var blocked := InteriorChecks.blocked_doorways(it)
	var covered := InteriorChecks.covered_windows(it)
	for b in blocked + covered:
		print("    ", b)
	_check("hat stands round the walls, the mirror, and nothing in the doorway or in front of a window",
			stands.size() >= 8 and it.hat_mirrors.size() == 1 and blocked.is_empty() and covered.is_empty())
	# The mirror: walking past changes nothing.
	var mirror: HatMirror = it.hat_mirrors[0]
	var before_hat := _w.model.hat
	await _walk_to(mirror.stand_point(), 1.2, 500)
	await _frames(20)
	_check("walking up to the mirror changes nothing by itself, and shows the Y hat prompt",
			_w.model.hat == before_hat and not _main.hat_menu.is_open() and _main.hud.prompt_kind() == "hat")
	# Y: the chooser, close up.
	_press("interact")
	await _frames(40)
	_check("Y at the mirror opens the hat chooser, close up", _main.hat_menu.is_open() and _main.indoor_camera.close_up)
	# Trying on: each hat on her head; B puts it back, nothing spent.
	var menu: HatMenu = _main.hat_menu
	menu.move(1)
	await _frames(5)
	var tried := menu.current()
	var on_head := _w.model.hat == tried
	menu.move(1)
	await _frames(5)
	on_head = on_head and _w.model.hat == menu.current()
	menu.cancel()
	await _frames(30)
	_check("moving through the hats puts each on her head; B puts back what she had and spends nothing",
			on_head and _w.model.hat == before_hat and SaveManager.star_purse() == 5 and SaveManager.hats_owned.is_empty()
			and not _main.indoor_camera.close_up)
	# Too dear: stays in the shop.
	_press("interact")
	await _frames(20)
	_choose(menu, "astro")
	menu.confirm()
	await _frames(60)
	_check("a hat she hasn't the stars for wobbles and stays in the shop", menu.is_open() and SaveManager.star_purse() == 5
			and SaveManager.hats_owned.is_empty())
	# Affordable: bought, on her head.
	_choose(menu, "beret")
	menu.confirm()
	await _frames(90)
	_check("buying the beret takes its 4 stars from her purse (her lifetime stars stay), and it's on her head",
			not menu.is_open() and SaveManager.star_purse() == 1 and SaveManager.lifetime_stars == 5
			and SaveManager.hats_owned == ["beret"] and SaveManager.hat == "beret" and _w.model.hat == "beret")
	# Hers for free; "no hat" puts the outfit's back.
	await _frames(60)
	_press("interact")
	await _frames(20)
	_choose(menu, "")
	menu.confirm()
	await _frames(30)
	var none_ok := SaveManager.hat == "" and _w.model.hat == "" and SaveManager.hats_owned == ["beret"]
	_press("interact")
	await _frames(20)
	_choose(menu, "beret")
	menu.confirm()
	await _frames(30)
	_check("\"no hat\" puts her outfit's own back; the beret is hers again for free",
			none_ok and SaveManager.hat == "beret" and SaveManager.star_purse() == 1)
	# The star.
	await _frames(60)
	var star: HouseStar = it.house_star
	await _walk_to(star.global_position, 0.8, 600)
	await _frames(10)
	_check("the hidden star is found", star.is_taken())
	# Out, in the hat.
	await _walk_out(it)
	var step := hs.doorstep()
	_check("walking into the doorway comes out on its doorstep, wearing the beret", _main.state == _main.State.ON_FOOT
			and Vector2(_w.global_position.x - step.x, _w.global_position.z - step.z).length() < 3.0 and _w.model.hat == "beret")
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("it's saved: the beret, that it's hers, the stars spent and the sticker", SaveManager.hat == "beret"
			and SaveManager.hats_owned == ["beret"] and SaveManager.stars_spent == 4 and SaveManager.star_purse() == 1
			and SaveManager.stickers.has("hat_shop"))
	# The city's hat shop.
	var city: CityBuild = null
	for b in _main.find_children("*", "CityBuild", true, false):
		if (b as CityBuild).done and (b as CityBuild).is_hat_shop():
			city = b
			break
	_check("the grown city has a hat shop to go into", city != null)
	if city == null:
		return
	await _walk_in(city)
	_check("its front door goes in: the same inside, with the milliner and the mirror", _main.state == _main.State.INDOORS
			and _main.building == city and _main.interior.shopkeepers.size() == 1 and _main.interior.hat_mirrors.size() == 1)
	await _walk_out(_main.interior)
	_check("and out again onto its doorstep", _main.state == _main.State.ON_FOOT)


## Both shop models' plans, built on their own: clear and furnished.
func _plans() -> void:
	var ok := true
	var x := 0.0
	for model in HatShopLayout.MODELS:
		var scale := 22.0 / maxf(1.64 if model == "shop_small_a" else 0.84, 0.968)
		var size := Vector3(1.64 if model == "shop_small_a" else 0.84, 0.88 if model == "shop_small_a" else 1.28, 0.968) * scale
		var plan := HatShopLayout.layout(model, scale, size, 42)
		var it := BuildingGenerator.build(plan)
		add_child(it)
		it.global_position = Vector3(6000 + x, 3000, 6000)
		x += 200.0
		var problems := InteriorChecks.blocked_doorways(it) + InteriorChecks.covered_windows(it)
		var stands := it.find_children("HatStand_*", "", true, false).size()
		var r: Array = plan.rooms[0].rect
		print("    %s: %.1f x %.1f m, %d stands, problems %s, mirror %d keeper %d star %s" % [model, r[2], r[3], stands, problems, it.hat_mirrors.size(), it.shopkeepers.size(), it.house_star != null])
		ok = ok and problems.is_empty() and stands >= 6 and it.hat_mirrors.size() == 1 and it.shopkeepers.size() == 1 \
				and it.house_star != null and absf(float(r[2]) - size.x) < 0.1
		it.queue_free()
	_check("both shop models' hat shops are the shop's size, furnished, and clear of doors and windows", ok)


func _choose(menu: HatMenu, id: String) -> void:
	for i in menu.options.size():
		if menu.current() == id:
			return
		menu.move(1)


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


## Get out of the plane near `b` and walk in through its front door.
func _walk_in(b: Node3D) -> void:
	if _main.state != _main.State.ON_FOOT:
		var away: Vector3 = b.doorstep() + b.global_transform.basis.z * 30.0 + b.global_transform.basis.x * 30.0
		_main.aircraft.park(Vector3(away.x, _ground(away), away.z), 0.0)
		_main._enter(_main.State.FLYING)
		await _frames(3)
		_main.toggle_plane()
		await _frames(10)
	var step: Vector3 = b.doorstep()
	_w.place(Vector3(step.x, _ground(step) + 0.2, step.z), b.doorstep_yaw() + PI)
	await _frames(10)
	await _walk_to(b.door_point(), 0.6, 500)
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(60)


func _walk_out(it: Interior) -> void:
	var door: Vector3 = (it.exits[0].trigger as Node3D).global_position
	await _walk_to(door, 0.5, 700)
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
			_main.indoor_camera.snap_to(yaw)
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
