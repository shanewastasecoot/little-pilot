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
]

var _main: Node
var _dir := ""


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var label := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.trim_prefix("--label=")
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
	for s in SPOTS:
		cam.global_position = s[1]
		cam.look_at(s[2])
		cam.make_current()
		await _frames(45)
		_save(s[0])
	# The plane up close on the runway.
	plane.park(Vector3(-200, IslandShape.height(-200, 0), 0), PI * 0.5)
	await _frames(20)
	var p := plane.global_position
	cam.global_position = p + Vector3(-8, 2.8, 10)
	cam.look_at(p + Vector3(0, 0.4, 0))
	await _frames(20)
	_save("plane_closeup")
	# Inside her house.
	_main._enter(_main.State.ON_FOOT)
	_main.enter_house()
	await _frames(150)
	_main.indoor_camera.snap_to(0.0)
	_hide_ui(true)
	await _frames(20)
	_save("house_inside")
	print("Saved shots to %s" % ProjectSettings.globalize_path(_dir))
	_main.queue_free()
	await _frames(2)
	get_tree().quit()


func _hide_ui(hidden: bool) -> void:
	_main.hud.visible = not hidden
	for n in get_tree().get_nodes_in_group("hide_in_photos"):
		n.visible = not hidden


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir + name + ".png")
	print("  shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
