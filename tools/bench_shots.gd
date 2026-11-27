extends Node
## ./dev.sh shots [label] (Graphics G0): pictures from fixed camera spots, so
## every visual change can be compared side by side. Saves PNGs (1280x800)
## to user://bench/shots/<label>/ (label defaults to "now"). Same fully
## grown city as the bench, no HUD, no weather or visitors, the dragon away.

## name, camera position, looking at
const SPOTS := [
	["airport_apron", Vector3(30, 22, -10), Vector3(110, 8, -95)],
	["city_low", Vector3(300, 60, 980), Vector3(380, 25, 650)],
	["farmland", Vector3(-420, 40, 660), Vector3(-560, 8, 494)],
	["lagoon_shallows", Vector3(40, 26, -2150), Vector3(-120, 0, -2300)],
	["dragon_peak", Vector3(260, 270, -1260), Vector3(-180, 190, -1640)],
	# (Graphics G3) close up, where contact shading shows.
	["farm_close", Vector3(-522, 21, 534), Vector3(-560, 13, 494)],
	["city_street", Vector3(250, 22, 420), Vector3(320, 12, 500)],
	["forest_edge", Vector3(-610, 140, -20), Vector3(-610, 30, -340)],
]

var _main: Node
var _dir := ""
## (Graphics G2) --variants=a,b,c: every spot is shot once per variant
## (tools/look_variants.gd), as <spot>__<variant>.jpg; without it, one PNG
## per spot as before.
var _variants: Array = []
var _look := LookVariants.new()
var _env: Environment
var _sun: DirectionalLight3D
var _indoor: Environment


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var label := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.trim_prefix("--label=")
		elif a.begins_with("--variants="):
			_variants = Array(a.trim_prefix("--variants=").split(",", false))
			if _variants == ["all"]:
				_variants = LookVariants.VARIANTS.keys()
		elif a.begins_with("--contact="):
			# (Graphics G3) contact shading strengths: models,terrain,ground
			# (1 = as baked, 0 = off), e.g. --contact=0,0,0 for "before".
			var k := a.trim_prefix("--contact=").split(",")
			ContactShade.strength = float(k[0])
			ContactShade.terrain_strength = float(k[1]) if k.size() > 1 else ContactShade.strength
			ContactShade.ground_strength = float(k[2]) if k.size() > 2 else ContactShade.strength
	_dir = "user://bench/shots/%s/" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	SaveManager.use_path("user://bench_shots.cfg")
	SaveManager.dragon = false
	SaveManager.crashes = false
	SaveManager.city_seed = 12345
	SaveManager.playtime = 30.0 * 3600.0
	SaveManager.city_time = SaveManager.playtime
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	await _frames(30)
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_main.weather.countdown = 1e9  # (no rain, no visitors in the pictures)
	_main.leader.countdown = 1e9
	var plane: Aircraft = _main.aircraft
	plane.teleport(Vector3(0, 400, 3000), 0.0)  # out of the way
	var cam := Camera3D.new()
	add_child(cam)
	_hide_ui(true)
	var we: Array = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	_env = (we[0] as WorldEnvironment).environment if not we.is_empty() else null
	var suns: Array = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	_sun = suns[0] if not suns.is_empty() else null
	_indoor = load(_main.INDOOR_ENV)
	for s in SPOTS:
		cam.global_position = s[1]
		cam.look_at(s[2])
		cam.make_current()
		await _frames(45)
		await _shoot(s[0], false)
	if not _variants.is_empty():
		# For the glow: a star up close (not spinning, so every picture
		# matches), and a firework burst over the sea.
		Star._get_material().set_shader_parameter("spin_speed", 0.0)
		Star._get_material().set_shader_parameter("bob_height", 0.0)
		var best: Node3D = null
		for st: Node3D in get_tree().get_nodes_in_group("stars"):
			if best == null or st.global_position.distance_to(Vector3(0, 40, 0)) < best.global_position.distance_to(Vector3(0, 40, 0)):
				best = st
		if best:
			cam.global_position = best.global_position + Vector3(3.6, 1.2, 3.6)
			cam.look_at(best.global_position)
			await _frames(30)
			await _shoot("star_glow", false)
		cam.global_position = Vector3(0, 60, 2600)
		cam.look_at(Vector3(0, 80, 2520))
		await _frames(20)
		await _shoot("firework_glow", false, true)
	# The plane up close on the runway.
	plane.park(Vector3(-200, IslandShape.height(-200, 0), 0), PI * 0.5)
	await _frames(20)
	var p := plane.global_position
	cam.global_position = p + Vector3(-8, 2.8, 10)
	cam.look_at(p + Vector3(0, 0.4, 0))
	await _frames(20)
	await _shoot("plane_closeup", false)
	# Inside her house.
	_main._enter(_main.State.ON_FOOT)
	_main.enter_house()
	await _frames(150)
	_main.indoor_camera.snap_to(0.0)
	_hide_ui(true)
	await _frames(20)
	await _shoot("house_inside", true)
	_main.indoor_camera.snap_to(PI)
	await _frames(20)
	await _shoot("house_inside_back", true)
	print("Saved shots to %s" % ProjectSettings.globalize_path(_dir))
	_main.queue_free()
	await _frames(2)
	get_tree().quit()


func _hide_ui(hidden: bool) -> void:
	_main.hud.visible = not hidden
	for n in get_tree().get_nodes_in_group("hide_in_photos"):
		n.visible = not hidden


## One spot: a PNG, or (with --variants) a JPEG per variant. Outdoor
## variants skip the inside of the house and indoor ones the outside.
func _shoot(spot: String, indoors: bool, firework := false) -> void:
	if _variants.is_empty():
		_save(spot)
		return
	for v: String in _variants:
		var item: int = LookVariants.VARIANTS[v].item
		if v != "current" and (item == 6) != indoors:
			continue
		if _main.state == _main.State.PAUSED:
			_main._resume()
		var active: Environment = _env
		if indoors:
			var we2: Array = get_tree().root.find_children("*", "WorldEnvironment", true, false)
			active = (we2[0] as WorldEnvironment).environment if not we2.is_empty() else _indoor
		_look.apply(v, _env, _sun, active if indoors else _indoor, _main.interior if indoors else null)
		var burst: FireworkBurst = null
		if firework:
			seed(7)
			burst = FireworkBurst.new(Color("ff5fa2"), Color("ffd23f"))
			burst.process_mode = Node.PROCESS_MODE_ALWAYS  # (even if the window lost focus and paused)
			var cam3 := get_viewport().get_camera_3d()
			burst.position = cam3.global_position - cam3.global_basis.z * 230.0  # (before adding)
			add_child(burst)
			await _frames(50)
		else:
			await _frames(8)
		var path := _dir + "%s__%s.jpg" % [spot, v]
		get_viewport().get_texture().get_image().save_jpg(path, 0.88)
		print("  shot ", path.get_file())
		if burst:
			burst.queue_free()
		_look.restore()
		await _frames(2)


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir + name + ".png")
	print("  shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
