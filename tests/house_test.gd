extends Node
## Her house (Phase 3: the front door, the ground floor, the stairs and
## the upstairs landing and four bedrooms):
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
##   layout   no furniture, picture or plant stands in any doorway, and
##            nothing hangs over or stands in front of a window
##   play     walking up to the toy box opens it and the toys hop out into a
##            tidy row in front of it (none flung away); walking into the
##            ball kicks it; the fridge opens when you walk up and closes
##            when you go; the pot bubbles; the dining table stays empty
##            until you bring a meal: at the open fridge Y shows three meal
##            pictures, A takes one to carry, walking up to the table serves
##            it at every place; by a chair Y sits you down and you eat it; the TV comes on when you come in and goes off
##            when you leave; landing on the sofa bounces you up high; the
##            trophy shelf has its stands; going out tidies everything away
##   stairs   you can walk up the stairs and down again; downstairs the
##            upstairs is hidden (dollhouse), upstairs it shows and the
##            rooms downstairs are hidden (their wall tops can't show)
##   bedrooms landing on a bed bounces you; standing still on it you lie
##            down, and pushing the stick gets you up; walking into the light switch
##            turns the light off and on; in her room, standing at the easel
##            or the quilt chest and pressing Y opens a colour menu (stick to
##            look, A to keep, B to put back) and walking past them changes
##            nothing; the colours are saved;
##            the hidden star gives reward stars
##   plane    the plane parked on the doorstep is moved before you come out
##   restart  stopping the game while inside starts you outside the front
##            door next time
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_house.cfg"

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
	print("  note: arrived in %s, on floor %s, at %s" % [_main.interior.room_at(_w.global_position).get("id", "?"), _on_floor(),
			str((_w.global_position - _main.interior.global_position).round())])
	# --- every room ----------------------------------------------------------------------
	var interior: Interior = _main.interior
	var ok_rooms := true
	var lowest := INF
	var visited := []
	for room in interior.rooms:
		var here: String = interior.room_at(_w.global_position).get("id", "hall")
		var goal: Vector3 = interior.inside_point(room.id, here) if room.id != here else _w.global_position
		var reached := true
		for p in interior.route(here, room.id) + [goal]:
			if not await _walk_to(p, 2.5, 700):
				reached = false
			lowest = minf(lowest, _w.global_position.y - interior.global_position.y)
		if reached and interior.room_at(_w.global_position).get("id", "") == room.id:
			visited.append(room.id)
		else:
			ok_rooms = false
			print("    couldn't reach ", room.id, " (at ", (_w.global_position - interior.global_position).round(), ")")
			for q in interior.route(here, room.id) + [goal]:
				print("      via ", (q - interior.global_position).round())
	print("  note: walked to ", ", ".join(visited))
	_check("you can walk to every room through the doorways and up the stairs (%d rooms)" % interior.rooms.size(), ok_rooms
			and interior.rooms.size() >= 11)
	await _go_to_room("hall")
	_check("the floor holds you everywhere (never through it)", lowest > -0.5 and _on_floor())
	# Bump along every wall of the playroom: never inside or through one.
	var through := false
	var pr: Dictionary = {}
	for r in interior.rooms:
		if r.id == "playroom":
			pr = r
	var rect: Rect2 = pr.rect
	await _go_to_room("playroom")
	await _walk_to(interior.room_centre("playroom"), 2.5, 300)
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
	# Near the playroom's south wall, the camera behind you (to the south).
	await _walk_to(interior.room_centre("playroom") + Vector3(0, 0, 14.0), 2.0, 300)
	_main.indoor_camera.snap_to(0.0)  # camera to the south: the south wall is between
	await _frames(60)
	var faded := false
	for w in interior.walls:
		if w.room == "playroom" and (w.inward as Vector2).is_equal_approx(Vector2(0, -1)):
			faded = (w.pieces[0] as GeometryInstance3D).transparency > 0.5
	_check("the wall between the camera and you fades away", faded)
	# --- layout -----------------------------------------------------------------------------
	var blocked := _blocked_doorways(interior)
	_check("no furniture, picture or plant stands in any doorway", blocked.is_empty())
	for b in blocked:
		print("    blocked: ", b)
	var covered := _covered_windows(interior)
	_check("nothing hangs over or stands in front of a window", covered.is_empty())
	for c in covered:
		print("    window: ", c)
	# --- play -------------------------------------------------------------------------------
	var tb: ToyBox = interior.toy_boxes[0]
	await _walk_to(tb.global_position + tb.global_transform.basis.z * 6.0, 1.5, 400)
	await _frames(30)
	var popped := tb.is_open() and tb._toys.size() == ToyBox.TOYS
	await _frames(150)
	# Landed in front of the box, near it, on the floor (not flung about).
	var tidy := true
	for toy in tb._toys:
		var local := tb.to_local((toy as Node3D).global_position)
		if local.z < -1.0 or local.length() > 12.0 or local.y > 2.5 or local.y < -1.0:
			tidy = false
	_check("walking up to the toy box opens it and the toys hop out into a tidy row", popped and tidy)
	if not tidy:
		for toy in tb._toys:
			print("    toy at ", tb.to_local((toy as Node3D).global_position).snappedf(0.1))
	var ball: BouncyBall = interior.balls[0]
	# The ball back where it starts (it may have rolled into a corner while
	# the test walked about), then a run-up from the open middle of the
	# room, straight through it.
	ball.reset()
	await _frames(20)
	var from_mid := (ball.global_position - interior.room_centre("playroom")) * Vector3(1, 0, 1)
	if from_mid.length() < 1.0:
		from_mid = Vector3(1, 0, 0)
	await _walk_to(ball.global_position - from_mid.normalized() * 7.0, 0.8, 400)
	var ball_at := ball.global_position
	await _walk_to(ball.global_position + from_mid.normalized() * 3.0, 0.5, 300)
	await _frames(60)
	_check("walking into the ball kicks it", ball.global_position.distance_to(ball_at) > 3.0)
	# Kitchen: the fridge and the pot.
	await _go_to_room("kitchen")
	var fridge: KitchenFridge = interior.fridges[0]
	var pot: BubblingPot = interior.pots[0]
	_check("the pot bubbles", pot.bubbles.emitting and pot.bubbles.amount > 0)
	await _walk_to(fridge.global_position + fridge.global_transform.basis.z * 7.0, 1.5, 400)
	await _frames(30)
	var opened := fridge.is_open()
	await _walk_to(interior.room_centre("kitchen") + Vector3(8, 0, 6), 1.5, 400)
	await _frames(30)
	_check("the fridge opens when you walk up and closes when you go", opened and not fridge.is_open())
	# Dining room: empty until you bring a meal from the fridge.
	var table: SettableTable = interior.tables[0]
	await _go_to_room("dining")
	await _frames(60)
	var empty_first := not table.is_set() and table._items.is_empty()
	await _go_to_room("kitchen")
	await _walk_to(fridge.global_position + fridge.global_transform.basis.z * 7.0, 1.5, 400)
	await _frames(20)
	var food_prompt: bool = _main.hud.prompt_kind() == "food"
	var food_menu: bool = _main.open_colour_menu() and _main.colour_menu.is_open() and _main.colour_menu.kind == "meal"
	var choices: int = _main.colour_menu.count()
	_main.colour_menu.confirm()  # the first one: pizza
	await _frames(10)
	var carrying_meal := _w.model.carrying and _w.model.carry_item == "Meal_Pizza"
	await _go_to_room("dining")
	await _walk_to(table.global_position + Vector3(0, 0, 9.0), 1.5, 400)
	await _frames(120)
	_check("the table stays empty until you choose a meal at the fridge (Y, three pictures, A) and carry it in; then it's served at every place",
			empty_first and food_prompt and food_menu and choices == 3 and carrying_meal and table.meal == "Meal_Pizza"
			and table._items.size() == table.places.size() and not _w.model.carrying)
	print("  note: empty %s, prompt %s, menu %s (%d), carrying %s, served %s x%d" % [empty_first, food_prompt, food_menu, choices,
			carrying_meal, table.meal, table._items.size()])
	# Sit at a chair (Y) and eat: three bites, then it's gone; the stick gets you up.
	var seat := 0
	var seat_stand := table.stand_point(seat)
	await _walk_to(seat_stand, 1.0, 400)
	await _walk_to(table.seat_point(seat).lerp(seat_stand, 0.4), 0.8, 200)
	await _frames(10)
	var sit_prompt: bool = _main.hud.prompt_kind() == "sit"
	var sat: bool = _main.open_colour_menu() and _w.sitting
	var ate := [false]
	table.ate.connect(func(_i): ate[0] = true, CONNECT_ONE_SHOT)
	await _frames(60 * 7)
	var eaten: bool = ate[0] and not table.has_food_at(seat)
	_w.override_move = Vector2(0, -1)
	await _frames(20)
	_w.override_move = Vector2.ZERO
	await _frames(70)
	_check("by a chair Y sits you down at the table and you eat your meal; the stick gets you up again",
			sit_prompt and sat and eaten and not _w.sitting and _on_floor())
	print("  note: sit prompt %s, sat %s, ate %s, sitting now %s" % [sit_prompt, sat, eaten, _w.sitting])
	# Living room: the TV, then bounce on the sofa; the trophy shelf.
	var tv: TVSet = null
	for t in interior.tvs:
		if interior.room_at(t.global_position).get("id", "") == "living":
			tv = t
	await _go_to_room("living")
	await _frames(30)
	var tv_on := tv != null and tv.is_on()
	await _go_to_room("hall")
	await _frames(30)
	_check("the TV comes on when you come in and goes off when you leave", tv_on and not tv.is_on())
	await _go_to_room("living")
	var sofa: Node3D = interior.sofas[0]
	var front := sofa.global_transform.basis.z.normalized() * Vector3(1, 0, 1)
	# From the gap between the sofa and the coffee table.
	await _walk_to(sofa.global_position + front * 4.2, 0.8, 400)
	var bounces := [0]
	var on_bounce := func(): bounces[0] += 1
	_w.bounced.connect(on_bounce)
	var top := -INF
	var floor_y := _w.global_position.y
	for i in 240:
		var d := sofa.global_position - _w.global_position
		d.y = 0.0
		_w.camera_yaw = atan2(-d.x, -d.z)
		_main.indoor_camera.yaw = _w.camera_yaw
		_w.override_move = Vector2(0, 1) if d.length() > 1.0 else Vector2.ZERO
		_w.override_jump = i % 25 == 5
		await get_tree().physics_frame
		top = maxf(top, _w.global_position.y - floor_y)
	_w.override_jump = false
	_w.override_move = Vector2.ZERO
	_w.bounced.disconnect(on_bounce)
	print("  note: highest %.1f m above the floor (a plain jump is about 2.2 m)" % top)
	_check("landing on the sofa bounces you up high", bounces[0] > 0 and top > 4.0)
	var shelf: TrophyShelf = interior.trophy_shelf
	shelf.show_trophies(2)
	await _frames(2)
	var shown := 0
	for s in shelf._stands:
		if s.get_node_or_null("Treasure") != null:
			shown += 1
	shelf.show_trophies(0)
	_check("the trophy shelf has stands for dragon treasure", shelf.stand_count() >= 5 and shown == 2)
	# --- upstairs ------------------------------------------------------------------------------
	await _go_to_room("stairwell")
	var upstairs_hidden := not _visible_floor(1)
	await _go_to_room("landing")
	var up_y := _w.global_position.y - interior.global_position.y
	_check("you can walk up the stairs", interior.storey_at(_w.global_position) == 1 and up_y > 10.0 and _on_floor())
	_check("downstairs the upstairs is hidden; upstairs it shows and downstairs is hidden",
			upstairs_hidden and _visible_floor(1) and not (interior.find_room("playroom").node as Node3D).visible)
	# A bed: jump onto it and bounce.
	var her: Dictionary = interior.her_room
	await _go_to_room(her.id)
	var bed: Node3D = null
	for b in interior.beds:
		if interior.room_at(b.global_position).get("id", "") == her.id:
			bed = b
	var bed_front := bed.global_transform.basis.z.normalized() * Vector3(1, 0, 1)
	await _walk_to(bed.global_position + bed_front * 7.5, 0.8, 400)
	var bed_bounces := [0]
	var on_bed_bounce := func(): bed_bounces[0] += 1
	_w.bounced.connect(on_bed_bounce)
	var bed_top := -INF
	var bed_floor_y := _w.global_position.y
	for i in 240:
		var d := bed.global_position - _w.global_position
		d.y = 0.0
		_w.camera_yaw = atan2(-d.x, -d.z)
		_main.indoor_camera.yaw = _w.camera_yaw
		_w.override_move = Vector2(0, 1) if d.length() > 1.0 else Vector2.ZERO
		_w.override_jump = i % 25 == 5
		await get_tree().physics_frame
		bed_top = maxf(bed_top, _w.global_position.y - bed_floor_y)
	_w.override_jump = false
	_w.override_move = Vector2.ZERO
	_w.bounced.disconnect(on_bed_bounce)
	_check("landing on a bed bounces you", bed_bounces[0] > 0 and bed_top > 4.0)
	# Stand still on it: lie down; push the stick: up again.
	var lay := false
	for i in 400:
		await get_tree().physics_frame
		if _w.lying:
			lay = true
			break
	await _frames(60)
	_w.override_move = Vector2(0, -1)
	await _frames(90)
	_w.override_move = Vector2.ZERO
	_check("standing still on a bed you lie down, and the stick gets you up", lay and not _w.lying)
	# Her colours: stand at the easel or the quilt chest and press Y; walking
	# past them never changes anything.
	await _go_to_room(her.id)
	var easel: PaintStation = her.wall_station
	var chest: PaintStation = her.bed_station
	var walls_before := _her_wall_colour(her)
	var easel_front := easel.global_transform.basis.z.normalized() * Vector3(1, 0, 1)
	await _walk_to(easel.global_position + easel_front * 3.5, 0.8, 400)
	await _frames(10)
	var prompt_shown: bool = _main.hud.prompt_kind() == "paint"
	await _walk_to(interior.room_centre(her.id), 2.0, 300)
	await _frames(10)
	var unchanged: bool = _her_wall_colour(her).is_equal_approx(walls_before) and _main.hud.prompt_kind() != "paint"
	_check("by the easel the Y prompt shows; walking past changes nothing", prompt_shown and unchanged)
	print("  note: prompt by the easel %s, unchanged after %s, easel near %s, at %s, easel %s" % [prompt_shown, unchanged, easel.is_player_near(),
			str((_w.global_position - interior.global_position).round()), str((easel.global_position - interior.global_position).round())])
	# Y: the menu opens and she stands still; the stick shows each colour on
	# the walls; B puts it back.
	await _walk_to(easel.global_position + easel_front * 3.5, 0.8, 400)
	await _frames(10)
	var menu_opened: bool = _main.open_colour_menu()
	var menu: ColourMenu = _main.colour_menu
	var stand := _w.global_position
	_w.override_move = Vector2(1, 0)
	await _frames(30)
	_w.override_move = Vector2.ZERO
	var held := _flat_dist(stand, _w.global_position) < 0.2
	menu.move(1)
	menu.move(1)
	var previewed := _her_wall_colour(her).is_equal_approx((PaintStation.COLOURS[2] as Color).lightened(0.35))
	menu.cancel()
	await _frames(10)
	var put_back := _her_wall_colour(her).is_equal_approx(walls_before) and SaveManager.house_wall == -1
	_check("Y opens the colour menu (she stands still), the stick shows each colour, B puts it back",
			menu_opened and held and previewed and put_back and not menu.is_open())
	# Choose with A: walls colour 2, quilt colour 4.
	_main.open_colour_menu()
	menu.move(2)
	menu.confirm()
	await _frames(10)
	var chest_front := chest.global_transform.basis.z.normalized() * Vector3(1, 0, 1)
	await _walk_to(chest.global_position + chest_front * 4.0, 0.8, 400)
	await _frames(10)
	var chest_opened: bool = _main.open_colour_menu()
	menu.move(4)
	menu.confirm()
	await _frames(10)
	var wall_col := _her_wall_colour(her)
	print("  note: walls %s (want %s), quilt %s (want %s), saved wall %d bed %d, menu at the chest %s" % [wall_col.to_html(false),
			(PaintStation.COLOURS[2] as Color).lightened(0.35).to_html(false), (her.quilt as StandardMaterial3D).albedo_color.to_html(false),
			(PaintStation.COLOURS[4] as Color).to_html(false), SaveManager.house_wall, SaveManager.house_bed, chest_opened])
	_check("A keeps the colour: the easel colours the walls and the quilt chest the quilt", chest_opened and wall_col.is_equal_approx(
			(PaintStation.COLOURS[2] as Color).lightened(0.35)) and (her.quilt as StandardMaterial3D).albedo_color.is_equal_approx(PaintStation.COLOURS[4]))
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("her colours are saved", SaveManager.house_wall == 2 and SaveManager.house_bed == 4)
	# The light switch.
	var sw: LightSwitch = null
	for s in interior.switches:
		if s.get_parent() == her.node:
			sw = s
	var sw_front := sw.global_transform.basis.z.normalized() * Vector3(1, 0, 1)
	await _walk_to(sw.global_position + sw_front * 1.5, 0.8, 400)
	await _frames(10)
	var off_now := not sw.on and not (sw.light as OmniLight3D).visible
	await _walk_to(sw.global_position + sw_front * 8.0, 1.0, 300)
	await _walk_to(sw.global_position + sw_front * 1.5, 0.8, 300)
	await _frames(10)
	_check("walking into the light switch turns the light off, and on again", off_now and sw.on)
	# The hidden star.
	var star: HouseStar = interior.house_star
	await _go_to_room(interior.room_at(star.global_position).get("id", "bedroom_se"))
	var lifetime := SaveManager.lifetime_stars
	await _walk_to(star.global_position, 0.8, 600)
	await _frames(10)
	_check("the hidden star is found", star.is_taken())
	# And back down the stairs.
	await _go_to_room("hall")
	_check("you can walk back down the stairs", interior.storey_at(_w.global_position) == 0 and _on_floor()
			and interior.room_at(_w.global_position).get("id", "") == "hall")
	# --- out, and in and out again -----------------------------------------------------------
	await _walk_out()
	_check("walking into the doorway comes out on the doorstep", _main.state == _main.State.ON_FOOT
			and _flat_dist(_w.global_position, house.doorstep()) < 3.0)
	_check("outside on safe dry ground, never inside the house", _safe_outside())
	_check("going out tidies everything away", not tb.is_open() and tb._toys.is_empty() and ball.global_position.distance_to(
			ball.get_parent().to_global(ball.home)) < 1.0 and not table.is_set() and table._items.is_empty() and not fridge.is_open())
	var cycles_ok := true
	for i in 3:
		await _walk_up_to_door()
		var inside := await _until(func(): return _main.state == _main.State.INDOORS, 240)
		await _frames(40)
		await _walk_out()
		if not (inside and _main.state == _main.State.ON_FOOT and _safe_outside()):
			cycles_ok = false
			print("  note: cycle %d: in %s, state %s, safe outside %s, at %s" % [i, inside, _main.state, _safe_outside(), str(_w.global_position.round())])
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
	# --- stopping the game inside ----------------------------------------------------------------
	await _walk_up_to_door()
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(20)
	_check("inside, the save remembers it", SaveManager.house_inside)
	_main.queue_free()
	await _frames(3)
	SaveManager.use_path(PATH)
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_w = _main.walker
	_main.title.hide()
	await _frames(5)
	_main._on_plane_confirmed("prop")
	await _frames(20)
	_check("next time you start outside the front door", _main.state == _main.State.ON_FOOT
			and _flat_dist(_w.global_position, _main.house.doorstep()) < 3.0 and _safe_outside() and not SaveManager.house_inside)


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
	await _walk_to(house.to_global(house.door_local()), 0.6, 300)


## Walk from wherever you are to the middle of `room_id`, through the doorways.
func _go_to_room(room_id: String) -> void:
	var interior: Interior = _main.interior
	var here: String = interior.room_at(_w.global_position).get("id", "hall")
	for p in interior.route(here, room_id) + [interior.inside_point(room_id, here)]:
		await _walk_to(p, 2.5, 700)


## Walk into the doorway you came in by, and wait to be outside.
func _walk_out() -> void:
	var interior: Interior = _main.interior
	var door := interior.door_point("hall", "S", 0.5)
	await _go_to_room("hall")
	await _walk_to(door, 0.5, 400)
	if not await _until(func(): return _main.state == _main.State.ON_FOOT, 240):
		var touching := []
		for i in _w.get_slide_collision_count():
			var c := _w.get_slide_collision(i)
			touching.append("%s %s" % [(c.get_collider() as Node).get_parent().name, c.get_normal().round()])
		print("    didn't get out: at ", (_w.global_position - interior.global_position).round(), " in ",
				interior.room_at(_w.global_position).get("id", "?"), " vel ", _w.velocity.round(), " floor ", _w.is_on_floor(),
				" touching ", touching, " move ", _w.override_move)
	_w.override_move = Vector2.ZERO
	await _frames(30)


## Is storey `f` showing (any of its rooms visible)?
func _visible_floor(f: int) -> bool:
	for r in _main.interior.rooms:
		if r.floor == f and (r.node as Node3D).visible:
			return true
	return false


func _on_floor() -> bool:
	return _w.is_on_floor()


## On the island's ground, dry, on foot, and not inside the house's walls.
func _safe_outside() -> bool:
	var p := _w.global_position
	var house: HerHouse = _main.house
	var inside_walls := house.is_inside_walls(p)
	var ground := IslandShape.height(p.x, p.z)
	return _main.map.visible and not inside_walls and absf(p.y - ground) < 2.5 and ground > Walker.SHORE_LEVEL


## Walk (sprinting) towards `p`; the camera follows. False if it never got there.
func _walk_to(p: Vector3, radius: float, max_frames: int) -> bool:
	var start_state = _main.state
	for i in max_frames:
		# Went in or out on the way (through a door): stop there.
		if _main.state != start_state:
			_w.override_move = Vector2.ZERO
			_w.override_sprint = false
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
		# Stuck against furniture? Step round it like a child would.
		if i % 30 == 0:
			_side = 0.0 if i == 0 or _w.global_position.distance_to(_side_from) > 1.0 else (1.0 if _side <= 0.0 else -1.0)
			_side_from = _w.global_position
		_w.override_move = Vector2(_side, 0.4 if _side != 0.0 else 1.0).normalized()
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


## Doorways with something standing in them: every piece of furniture,
## picture or plant (not walls, floors or flat rugs) whose box overlaps the
## clear space through a doorway (a little narrower than the door, 2.5 m
## either side, up to the top of the door).
func _blocked_doorways(interior: Interior) -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = interior.data
	var door_w: float = data.get("door_width", 7.0)
	var door_h: float = data.get("door_height", 8.0)
	var wall_bits := {}
	for w in interior.walls:
		for gi in w.pieces:
			wall_bits[gi] = true
	for room: Dictionary in data.rooms:
		var r: Array = room.rect
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var info: Dictionary = interior.find_room(str(room.id))
		for d: Dictionary in room.get("doors", []):
			var at := float(d.at)
			var c: Vector2
			var along_x := str(d.side) in ["N", "S"]
			match str(d.side):
				"N": c = Vector2(rect.position.x + at * rect.size.x, rect.position.y)
				"S": c = Vector2(rect.position.x + at * rect.size.x, rect.end.y)
				"W": c = Vector2(rect.position.x, rect.position.y + at * rect.size.y)
				_: c = Vector2(rect.end.x, rect.position.y + at * rect.size.y)
			var half := Vector2((door_w - 1.0) * 0.5, 2.5) if along_x else Vector2(2.5, (door_w - 1.0) * 0.5)
			var clear := AABB(Vector3(c.x - half.x, float(info.base) + 0.3, c.y - half.y), Vector3(half.x * 2.0, door_h - 0.6, half.y * 2.0))
			for other in interior.rooms:
				if other.floor != info.floor:
					continue
				for gi: GeometryInstance3D in (other.node as Node).find_children("*", "GeometryInstance3D", true, false):
					if wall_bits.has(gi):
						continue
					var box: AABB = interior.global_transform.affine_inverse() * gi.global_transform * gi.get_aabb()
					if box.size.y < 0.5 or box.size.x > 30.0 or box.size.z > 30.0:
						continue  # floors, rugs, ceilings
					if box.intersects(clear):
						out.append("%s door %s: %s" % [room.id, d.side, gi.get_parent().name])
	return out


func _her_wall_colour(her: Dictionary) -> Color:
	for m: StandardMaterial3D in her.mats:
		if m.get_meta("wall", false):
			return m.albedo_color
	return Color.BLACK


## Windows with something in front of them: any piece (not walls, floors or
## rugs, and not the wall the window is in) overlapping the window's opening
## from the wall out to 2 m into the room.
func _covered_windows(interior: Interior) -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = interior.data
	var ws := BuildingGenerator.WINDOW_SIZE
	var wall_bits := {}
	for w in interior.walls:
		for gi in w.pieces:
			wall_bits[gi] = true
	for room: Dictionary in data.rooms:
		var r: Array = room.rect
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var info: Dictionary = interior.find_room(str(room.id))
		var y := float(info.base) + BuildingGenerator.WINDOW_Y
		for w: Dictionary in room.get("windows", []):
			var at := float(w.at)
			var box: AABB
			match str(w.side):
				"N": box = AABB(Vector3(rect.position.x + at * rect.size.x - ws.x * 0.5, y - ws.y * 0.5, rect.position.y + 0.3), Vector3(ws.x, ws.y, 2.0))
				"S": box = AABB(Vector3(rect.position.x + at * rect.size.x - ws.x * 0.5, y - ws.y * 0.5, rect.end.y - 2.3), Vector3(ws.x, ws.y, 2.0))
				"W": box = AABB(Vector3(rect.position.x + 0.3, y - ws.y * 0.5, rect.position.y + at * rect.size.y - ws.x * 0.5), Vector3(2.0, ws.y, ws.x))
				_: box = AABB(Vector3(rect.end.x - 2.3, y - ws.y * 0.5, rect.position.y + at * rect.size.y - ws.x * 0.5), Vector3(2.0, ws.y, ws.x))
			for gi: GeometryInstance3D in (info.node as Node).find_children("*", "GeometryInstance3D", true, false):
				if wall_bits.has(gi) or gi.get_parent() is LightSwitch:
					continue
				var b: AABB = interior.global_transform.affine_inverse() * gi.global_transform * gi.get_aabb()
				if b.size.y < 0.5 or b.size.x > 30.0 or b.size.z > 30.0:
					continue
				# The window's own frame and glass sit in the wall: skip pieces
				# that are flat against it.
				if (str(w.side) in ["N", "S"] and b.size.z < 0.6) or (str(w.side) in ["E", "W"] and b.size.x < 0.6):
					continue
				if b.intersects(box):
					out.append("%s window %s %.2f: %s" % [room.id, w.side, at, gi.get_parent().name])
	return out
