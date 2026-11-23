extends Node
## World reactions and forgiveness fixes (Phase 6):
##   events    a honk, a low pass, a take-off, a landing and a crash each go
##             out on WorldEvents with where they happened; the dragon hears
##             honks through it
##   farm      a low pass near the farm: the sheep and cows scatter
##   forest    a honk over the forest: birds fly up
##   city      a honk over the city, or her cheering on foot (X): the
##             townspeople near it cheer back (the baked cheer loop)
##   others    the boat toots, the whale spouts at a honk near them
##   cheer     X on foot: she cheers, and the world hears it
##   echo      a honk goes through the mountains' echo, the cave's reverb,
##             the city's, or plain over the runway
##   dust      lifting off from grass kicks up dust (the runway doesn't);
##             running makes little puffs
##   sea       a sea crash: under the sea for a moment (muffled), then back
##             on the runway in the same time as before
##   volcano   a volcano crash: an orange glow, then the usual white fade
##   get out   Y while the plane is still rolling: out as soon as it stops
##   volume    the parent's loudest-it-gets cap turns Master down, saved,
##             never all the way off
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_reactions.cfg"

var _main: Node
var _plane: Aircraft
var _w: Walker
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = true
	SaveManager.crashes = true
	SaveManager.city_seed = 12345
	SaveManager.playtime = 24.0 * 3600.0
	SaveManager.city_time = SaveManager.playtime
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	_plane = _main.aircraft
	_w = _main.walker
	_w.override_enabled = true
	_main.walk_camera.override_enabled = true
	await _frames(10)
	_main._enter(_main.State.FLYING)
	await _frames(5)
	await _run()
	GameSettings.set_muffled(false)
	SaveManager.set_max_volume(1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nREACTIONS TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	# --- Events, the dragon --------------------------------------------------------
	var dragon: Node = get_tree().get_first_node_in_group("dragon")
	_plane.input.honk_pressed.emit()
	await _frames(2)
	var last: Dictionary = WorldEvents.recent.back()
	_check("a honk goes out on WorldEvents, where the plane is", last.kind == "honk"
			and (last.where as Vector3).distance_to(_plane.global_position) < 5.0)
	_check("the dragon hears the honk through WorldEvents", dragon != null and float(dragon.get("_honked")) > 0.0)
	# --- Farm ------------------------------------------------------------------------
	var farm: Farm = _first(Farm)
	var homes: Array[Vector3] = []
	for a in farm._animals:
		homes.append(a.position)
	WorldEvents.send("low_pass", farm.global_position + Vector3(-30, 0, 20))
	await _frames(100)
	var moved := 0
	for i in farm._animals.size():
		if farm._animals[i].position.distance_to(homes[i]) > 3.0:
			moved += 1
	_check("a low pass near the farm: the sheep and cows scatter (%d of %d)" % [moved, homes.size()], moved == homes.size())
	# --- Forest ----------------------------------------------------------------------
	var forest: Forest = _first(Forest)
	WorldEvents.send("honk", forest.global_position + Vector3(40, 60, 30))
	await _frames(5)
	var flocks := _main.get_tree().root.find_children("*", "BirdFlock", true, false)
	_check("a honk over the forest: birds fly up out of the trees", flocks.size() >= 1)
	# --- City ------------------------------------------------------------------------
	var city: CityDistrict = _first(CityDistrict)
	var crowd: CityCrowd = city.crowd
	var someone: Dictionary = {}
	for p in crowd.people:
		if p.state != CityCrowd.INSIDE and p.size > 0.9:
			someone = p
			break
	var at: Vector3 = crowd.to_global(someone.pos) if not someone.is_empty() else city.global_position
	WorldEvents.send("honk", at + Vector3(0, 40, 0))
	await _frames(2)
	var cheering := crowd.people.filter(func(p): return p.cheer > 0.0).size()
	var mat := (crowd.get_child(0) as MultiMeshInstance3D).material_override as ShaderMaterial
	_check("a honk over the city: the townspeople near it cheer (%d), with the baked cheer loop" % cheering,
			cheering >= 1 and int(mat.get_shader_parameter("cheer_frames")) > 0)
	# --- Boat, whale ----------------------------------------------------------------
	var boat: Node3D = _first(Boat)
	var whale: Node3D = _first(Whale)
	var boat_r: WorldReaction = boat.get_node("Reaction")
	var whale_r: WorldReaction = whale.get_node("Reaction")
	var b0 := boat_r.count
	var w0 := whale_r.count
	WorldEvents.send("honk", boat_r.centre.global_position + Vector3(20, 30, 0))
	WorldEvents.send("honk", whale_r.centre.global_position + Vector3(20, 30, 0))
	await _frames(2)
	_check("a honk near the boat: it toots back; near the whale: she spouts", boat_r.count == b0 + 1 and whale_r.count == w0 + 1)
	# --- Low pass, landing, take-off off grass, dust -----------------------------------
	var meadow := Vector3(-120, 0, 160)
	meadow.y = _ground(meadow)
	_plane.teleport(meadow + Vector3(0, 14, 0), 0.0)
	_plane.speed = 30.0
	var lp0 := WorldEvents.count("low_pass")
	await _frames(30)
	_check("sweeping low and fast over the ground sends a low pass", WorldEvents.count("low_pass") > lp0)
	_plane.park(meadow, 0.0)
	await _frames(5)
	var puffs0: int = _main.ground_dust.puffs
	_plane.lift_off()
	await _frames(3)
	var take: Dictionary = _last_of("takeoff")
	_check("lifting off from grass: a take-off on the grass, and dust", not take.is_empty() and take.info.surface == "grass"
			and _main.ground_dust.puffs > puffs0)
	_plane.park(_main.map.runway_start(), _main.map.spawn_heading())
	await _frames(5)
	puffs0 = _main.ground_dust.puffs
	_plane.lift_off()
	await _frames(3)
	_check("lifting off from the runway: no dust", _last_of("takeoff").info.surface == "runway" and _main.ground_dust.puffs == puffs0)
	# --- Echoes ----------------------------------------------------------------------
	_plane.park(_main.map.runway_start(), _main.map.spawn_heading())
	await _frames(6)
	var on_runway := EchoZone.honk_bus()
	_plane.teleport(Vector3(75, 460, -880), 0.0)
	await _frames(6)
	var mountains := EchoZone.honk_bus()
	_plane.park(Vector3(IslandShape.LAIR.x, IslandShape.LAIR_FLOOR, IslandShape.LAIR.y), 0.0)
	await _frames(6)
	var cave := EchoZone.honk_bus()
	_plane.teleport(Vector3(IslandShape.CITY.x, 180, IslandShape.CITY.y), 0.0)
	await _frames(6)
	var over_city := EchoZone.honk_bus()
	print("  note: buses runway %s, mountains %s, cave %s, city %s" % [on_runway, mountains, cave, over_city])
	_check("honks echo in the mountains, boom in the cave, ring in the city, plain over the runway",
			on_runway == GameSettings.BUS_SFX and mountains == GameSettings.BUS_HONK_ECHO and cave == GameSettings.BUS_HONK_CAVE
			and over_city == GameSettings.BUS_HONK_CITY and AudioServer.get_bus_index(GameSettings.BUS_HONK_ECHO) != -1)
	# --- Get out while rolling ---------------------------------------------------------
	_plane.park(_main.map.runway_start(), _main.map.spawn_heading())
	_main._enter(_main.State.LANDED)
	await _frames(10)
	_plane.mode = Aircraft.Mode.ROLLING
	_plane._landing = true
	_plane.speed = 12.0
	_main.toggle_plane()
	await _frames(2)
	var queued: bool = _main.exit_queued and _main._in_plane()
	await _until(func(): return _main.state == _main.State.ON_FOOT, 600)
	_check("Y while the plane is still rolling: she gets out as soon as it stops", queued and _main.state == _main.State.ON_FOOT)
	# --- Cheer on foot; running puffs ---------------------------------------------------
	await _frames(20)
	var ch0 := WorldEvents.count("cheer")
	_press("trick")
	await _frames(10)
	_check("X on foot: she cheers, and the world hears it", _w.model.anim == "Cheer" and WorldEvents.count("cheer") == ch0 + 1)
	await _frames(100)
	puffs0 = _main.ground_dust.puffs
	_w.camera_yaw = 0.0
	_w.override_move = Vector2(0, 1)
	_w.override_sprint = true
	await _frames(90)
	_w.override_move = Vector2.ZERO
	_w.override_sprint = false
	_check("running makes little dust puffs at her feet", _main.ground_dust.puffs >= puffs0 + 3)
	# --- Sea crash: under the sea, same time ----------------------------------------------
	_main.toggle_plane()  # (she may be too far: put her back in)
	await _frames(5)
	if _main.state != _main.State.LANDED:
		_main._enter(_main.State.FLYING)
	_main._enter(_main.State.FLYING)
	_plane.teleport(Vector3(900, 30, -1900), 0.0)
	_plane.mode = Aircraft.Mode.FLYING
	await _frames(2)
	_plane.global_position.y = -1.0
	_plane._crash()
	await _frames(50)
	var diving: bool = _main.underwater.is_diving() and GameSettings.is_muffled()
	var n := 50
	while _plane.mode != Aircraft.Mode.PARKED and n < 400:
		await get_tree().physics_frame
		n += 1
	var took := n / float(Engine.physics_ticks_per_second)
	await _frames(40)
	print("  note: sea crash to runway %.2f s (hold %.2f + fade %.2f)" % [took, _main.CRASH_HOLD, _main.CRASH_FADE])
	_check("a sea crash: under the sea for a moment, muffled; then the runway in the usual time, not muffled",
			diving and not _main.underwater.is_diving() and not GameSettings.is_muffled()
			and absf(took - (_main.CRASH_HOLD + _main.CRASH_FADE)) < 0.4)
	# --- Volcano crash: lava glow ---------------------------------------------------------
	_main._enter(_main.State.FLYING)
	_plane.teleport(Vector3(IslandShape.VOLCANO.x + 120, 200, IslandShape.VOLCANO.y), 0.0)
	await _frames(2)
	_plane._crash()
	await _frames(12)
	var c: Color = _main._fade.color
	var glowing := c.r > 0.9 and c.g < 0.5 and c.a > 0.05
	await _until(func(): return _plane.mode == Aircraft.Mode.PARKED, 400)
	await _frames(40)
	_check("a volcano crash: a hot orange glow, then the usual white fade", glowing and _main._fade.color.g > 0.9 and _main._fade.color.a < 0.05)
	# --- Max volume ---------------------------------------------------------------------
	SaveManager.set_max_volume(0.5)
	var db := AudioServer.get_bus_volume_db(0)
	SaveManager.set_max_volume(0.0)
	var floor_ok := SaveManager.max_volume >= SaveManager.MAX_VOLUME_MIN - 0.001 and not AudioServer.is_bus_mute(0)
	SaveManager.set_max_volume(0.6)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("the loudest-it-gets cap turns everything down, never off, and is saved",
			absf(db - linear_to_db(0.5)) < 0.1 and floor_ok and absf(SaveManager.max_volume - 0.6) < 0.01)


func _first(cls) -> Node:
	for n in _main.find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null


func _last_of(kind: String) -> Dictionary:
	for i in range(WorldEvents.recent.size() - 1, -1, -1):
		if WorldEvents.recent[i].kind == kind:
			return WorldEvents.recent[i]
	return {}


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
