extends Node
## ./dev.sh bench-render (Phase 8): how fast the game draws, for the Steam
## Deck. Runs in a window at 1280x800 (Mobile renderer), vsync off.
##
## Flies a fixed route through four areas (the airport, the fully grown
## city, open ocean, Dragon Peak) twice: the first lap is the COLD run (the
## first time anything is drawn: shaders compiling, things loading), the
## second the WARM run. In each area it warms up for a few seconds, then
## measures every frame:
##   median frame time (ms), 95th-percentile frame time (ms),
##   1% low (the frames-per-second of the slowest 1% of frames), draw calls
## and how long from launching the game to the first frame where it takes
## input (the title screen ready). Results print as a table, compared with
## the previous run, and are saved to user://bench/render.json.
##
## Bench toggles (`./dev.sh bench-render -- --bench-shadows=2048` etc.; see
## BenchToggles) change settings for this run only, never the defaults.

const AREAS := [
	["airport", Vector3(-150, 60, 60), 0.0],
	["city", Vector3(380, 85, 760), 0.0],
	["ocean", Vector3(1300, 45, -1500), 0.6],
	["dragon_peak", Vector3(-170, 120, -1150), 0.0],
]
const WARM_UP := 3.0
const MEASURE := 6.0
const OUT := "user://bench/render.json"

var _main: Node
var _plane: Aircraft
var _first_frame_ms := 0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The Deck's screen size, whatever the desktop's window manager wanted.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	SaveManager.use_path("user://bench_render.cfg")
	SaveManager.dragon = false  # (the same route every time: no dragon chasing)
	SaveManager.crashes = false
	SaveManager.city_seed = 12345
	SaveManager.playtime = 30.0 * 3600.0
	SaveManager.city_time = SaveManager.playtime
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	# Launch to the title screen taking input: the engine's clock started
	# when the game was launched.
	_first_frame_ms = Time.get_ticks_msec()
	_main.title.hide()
	_plane = _main.aircraft
	await get_tree().process_frame
	_main._enter(_main.State.FLYING)
	var cold := {}
	var warm := {}
	for lap in 2:
		for area in AREAS:
			var r := await _area(area[1], area[2])
			(cold if lap == 0 else warm)[area[0]] = r
	_report(cold, warm)
	await _quit()


func _area(at: Vector3, turn: float) -> Dictionary:
	_plane.teleport(at, 0.0)
	_plane.mode = Aircraft.Mode.FLYING
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2(turn if turn > 0.0 else 0.25, 0.0)
	_main.chase_camera.snap_to_target()
	var t := 0.0
	while t < WARM_UP:
		await get_tree().process_frame
		t += get_process_delta_time()
	var frames: Array[float] = []
	var draws: Array[float] = []
	var last := Time.get_ticks_usec()
	var start := last
	while Time.get_ticks_usec() - start < int(MEASURE * 1e6):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var sorted := frames.duplicate()
	sorted.sort()
	var worst := sorted.slice(int(sorted.size() * 0.99))
	var worst_ms := 0.0
	for w in worst:
		worst_ms += w
	worst_ms /= maxf(worst.size(), 1)
	return {
		"median_ms": sorted[sorted.size() / 2],
		"p95_ms": sorted[int((sorted.size() - 1) * 0.95)],
		"low1_fps": 1000.0 / maxf(worst_ms, 0.001),
		"draw_calls": _avg(draws),
		"frames": frames.size(),
	}


func _report(cold: Dictionary, warm: Dictionary) -> void:
	var before := {}
	if FileAccess.file_exists(OUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if parsed is Dictionary:
			before = parsed
	var toggles := BenchToggles.active()
	print("\nBENCH RENDER at %s, %s renderer%s" % [str(get_viewport().get_visible_rect().size),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), (", toggles " + str(toggles)) if not toggles.is_empty() else ""])
	print("launch to first controllable frame: %d ms (before: %s)" % [_first_frame_ms, str(before.get("first_frame_ms", "-"))])
	for run in [["cold", cold], ["warm", warm]]:
		print("-- %s run" % run[0])
		print("%-12s %9s %9s %9s %8s   %s" % ["area", "median", "p95", "1% low", "draws", "before (median / 1% low)"])
		for area in run[1]:
			var r: Dictionary = run[1][area]
			var b: Dictionary = before.get(run[0], {}).get(area, {})
			print("%-12s %7.2fms %7.2fms %6.0ffps %8.0f   %s" % [area, r.median_ms, r.p95_ms, r.low1_fps, r.draw_calls,
				("%.2fms / %.0ffps" % [b.median_ms, b.low1_fps]) if not b.is_empty() else "-"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bench"))
	if FileAccess.file_exists(OUT):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT), ProjectSettings.globalize_path("user://bench/render_previous.json"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"when": Time.get_datetime_string_from_system(), "godot": Engine.get_version_info().string,
		"resolution": str(get_viewport().get_visible_rect().size), "toggles": toggles,
		"first_frame_ms": _first_frame_ms, "cold": cold, "warm": warm}, " "))
	print("Saved %s" % ProjectSettings.globalize_path(OUT))


static func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


## Free the game first, then quit (quitting mid-frame can leave the clouds
## updating a freed batch).
func _quit() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
