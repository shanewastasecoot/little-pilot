extends Node
## ./dev.sh bench-render (Phase 8; Graphics G0): how fast the game draws, for
## the Steam Deck. Runs in a window at 1280x800 (Mobile renderer), vsync off.
##
## Goes through a fixed set of areas twice: the first lap is the COLD run
## (the first time anything is drawn: shaders compiling, things loading),
## the second the WARM run. Areas: flying over the airport, the fully grown
## city, open ocean and Dragon Peak; on foot in the city; inside her house;
## flying in the rain; flying towards the city's fireworks; the dragon
## breathing fire. In each it warms up for a few seconds, then measures
## every frame for MEASURE seconds:
##   median, 95th and 99th percentile frame time, the single worst frame,
##   the 1% low (frames-per-second of the slowest 1% of frames), draw calls,
##   game logic and physics time, render CPU time and GPU time (median and
##   95th percentile of each: CPU- or GPU-bound?)
## Hitch log (warm run): every frame slower than 11.1 ms (90 FPS), with what
## happened that frame (StallDetector notes, shader pipeline compiles) and
## its times; the most common causes are summarised at the end. Stalls over
## 250 ms are also logged by the StallDetector (user://bench/stalls.log).
## Results print as a table, compared with the previous run, and are saved
## to user://bench/render.json (hitches: user://bench/hitches.json).
##
## Bench toggles (`./dev.sh bench-render -- --bench-shadows=2048` etc.; see
## BenchToggles) change settings for this run only, never the defaults.
## `-- --bench-areas=city,rain` measures only those areas;
## `-- --bench-measure=10` changes MEASURE; `-- --bench-shots` saves what
## each area looks like (user://bench/area_<name>_<run>.jpg); `-- --contact=0,0,0` turns the
## G3 contact shading off (models,terrain,ground).

## name, kind, where, stick turn
const AREAS := [
	["airport", "fly", Vector3(-150, 60, 60), 0.25],
	["city", "fly", Vector3(380, 85, 760), 0.25],
	["ocean", "fly", Vector3(1300, 45, -1500), 0.6],
	["dragon_peak", "fly", Vector3(-170, 120, -1150), 0.25],
	["city_on_foot", "foot", Vector3(420, 0, 640), 0.0],
	["house", "house", Vector3.ZERO, 0.0],
	["rain", "rain", Vector3(-250, 110, 300), 0.3],
	["fireworks", "fireworks", Vector3(380, 130, 1450), 0.0],
	["dragon_fire", "dragon", Vector3(-120, 160, -1000), 0.0],
]
const WARM_UP := 3.0
const MEASURE := 30.0
const HITCH_MS := 1000.0 / 90.0
const OUT := "user://bench/render.json"
const HITCHES := "user://bench/hitches.json"

var _main: Node
var _shots := false  ## --bench-shots: a picture of each area, halfway through
var _plane: Aircraft
var _first_frame_ms := 0
var _measure := MEASURE
var _hitches: Array = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The Deck's screen size, whatever the desktop's window manager wanted.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	SaveManager.use_path("user://bench_render.cfg")
	SaveManager.dragon = false  # (the same route every time: no dragon chasing, except its own area)
	SaveManager.crashes = false
	SaveManager.city_seed = 12345
	SaveManager.playtime = 30.0 * 3600.0
	SaveManager.city_time = SaveManager.playtime
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-areas="):
			only = a.trim_prefix("--bench-areas=").split(",")
		elif a.begins_with("--bench-measure="):
			_measure = float(a.trim_prefix("--bench-measure="))
		elif a == "--bench-shots":
			_shots = true
		elif a.begins_with("--contact="):
			# (Graphics G3) contact shading strengths: models,terrain,ground.
			var k := a.trim_prefix("--contact=").split(",")
			ContactShade.strength = float(k[0])
			ContactShade.terrain_strength = float(k[1]) if k.size() > 1 else ContactShade.strength
			ContactShade.ground_strength = float(k[2]) if k.size() > 2 else ContactShade.strength
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
			if not only.is_empty() and not only.has(area[0]):
				continue
			var r := await _area(area, lap == 1)
			(cold if lap == 0 else warm)[area[0]] = r
	_report(cold, warm)
	await _quit()


func _area(area: Array, warm: bool) -> Dictionary:
	var name: String = area[0]
	var kind: String = area[1]
	var at: Vector3 = area[2]
	await _setup(kind, at, area[3])
	var t := 0.0
	while t < WARM_UP:
		await get_tree().process_frame
		_keep_going(kind, at)
		t += get_process_delta_time()
	var frames: Array[float] = []
	var draws: Array[float] = []
	var logic: Array[float] = []
	var physics: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var start := Time.get_ticks_usec()
	var sd := StallDetector.current
	var shot_taken := not _shots
	while Time.get_ticks_usec() - start < int(_measure * 1e6):
		await get_tree().process_frame
		_keep_going(kind, at)
		if not shot_taken and Time.get_ticks_usec() - start > int(_measure * 5e5):
			# (--bench-shots) what the camera sees halfway through.
			shot_taken = true
			get_viewport().get_texture().get_image().save_jpg("user://bench/area_%s_%s.jpg" % [name, "warm" if warm else "cold"], 0.85)
		var f: Dictionary = sd.last_frame if sd else {}
		if f.is_empty():
			continue
		frames.append(f.ms)
		logic.append(f.logic_ms)
		physics.append(f.physics_ms)
		cpu.append(f.cpu_ms)
		gpu.append(f.gpu_ms)
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		if warm and f.ms > HITCH_MS:
			_hitches.append({"area": name, "ms": f.ms, "logic_ms": f.logic_ms, "physics_ms": f.physics_ms,
				"cpu_ms": f.cpu_ms, "gpu_ms": f.gpu_ms, "compiles": f.compiles, "notes": Array(f.notes)})
	await _teardown(kind)
	var sorted := frames.duplicate()
	sorted.sort()
	var slow := sorted.slice(int(sorted.size() * 0.99))
	return {
		"median_ms": _pct(sorted, 0.5),
		"p95_ms": _pct(sorted, 0.95),
		"p99_ms": _pct(sorted, 0.99),
		"worst_ms": sorted[-1] if not sorted.is_empty() else 0.0,
		"low1_fps": 1000.0 / maxf(_avg(slow), 0.001),
		"draw_calls": _avg(draws),
		"logic_ms": _pct_of(logic, 0.5),
		"physics_ms": _pct_of(physics, 0.5),
		"cpu_ms": _pct_of(cpu, 0.5),
		"cpu_p95_ms": _pct_of(cpu, 0.95),
		"gpu_ms": _pct_of(gpu, 0.5),
		"gpu_p95_ms": _pct_of(gpu, 0.95),
		"frames": frames.size(),
	}


## Put her somewhere for the area: flying, on foot, indoors, in the rain...
func _setup(kind: String, at: Vector3, turn: float) -> void:
	match kind:
		"fly", "rain", "fireworks", "dragon":
			if _main.state != _main.State.FLYING:
				_main._enter(_main.State.FLYING)
				await get_tree().process_frame
			_plane.teleport(at, 0.0)
			_plane.mode = Aircraft.Mode.FLYING
			_plane.input.override_enabled = true
			_plane.input.override_stick = Vector2(turn, 0.0)
			_main.chase_camera.snap_to_target()
			if kind == "rain":
				_main.weather.spawn_cloud()
			elif kind == "fireworks" and _main._fireworks:
				_main._fireworks.start(WARM_UP + _measure + 2.0)
			elif kind == "dragon":
				SaveManager.dragon = true
				var d: Dragon = _main._dragon
				d._read_settings()
				# (Bench only: its fire doesn't blow the plane up mid-measure.)
				for c in d.plane_hit.get_connections():
					d.plane_hit.disconnect(c.callable)
				_place_dragon()
		"foot":
			_main._enter(_main.State.ON_FOOT)
			var g := DeliveryManager.ground_at(at.x, at.z)
			_main.walker.place(Vector3(at.x, g + 0.3, at.z), 0.0)
			_main.walker.override_enabled = true
			_main.walker.override_move = Vector2(0, 1)
			_main.walk_camera.snap_to(0.0)
		"house":
			_main._enter(_main.State.ON_FOOT)
			_main.enter_house()
			for i in 120:
				await get_tree().process_frame
				if _main.state == _main.State.INDOORS:
					break
			_main.walker.override_enabled = true
			_main.walker.override_move = Vector2(0, 0.7)


## Keep the scene doing its thing while it's measured.
var _yaw := 0.0
func _keep_going(kind: String, at: Vector3) -> void:
	# (The window losing focus pauses the game: a paused frame isn't a frame.)
	if _main.state == _main.State.PAUSED:
		_main._resume()
	match kind:
		"foot", "house":
			# Walking round in slow circles.
			_yaw += get_process_delta_time() * 0.5
			(_main.indoor_camera if kind == "house" else _main.walk_camera).snap_to(_yaw)
		"rain":
			var w: Weather = _main.weather
			if w.cloud:
				var p := _plane.global_position
				w.cloud.global_position = Vector3(p.x, w.cloud.global_position.y, p.z)
				w._age = Weather.FADE + 1.0
		"dragon":
			var d: Dragon = _main._dragon
			if d.state != Dragon.State.BREATHE:
				d._fire_cool = 0.0
				d._set_state(Dragon.State.BREATHE)
			if d.global_position.distance_to(_plane.global_position) > 220.0 or d.global_position.distance_to(_plane.global_position) < 25.0:
				_place_dragon()
		"fireworks":
			if _plane.global_position.distance_to(at) > 900.0:
				_plane.teleport(at, 0.0)


## The dragon a little ahead of the plane, facing it.
func _place_dragon() -> void:
	var d: Dragon = _main._dragon
	var fwd := Vector3(-sin(_plane.heading), 0, -cos(_plane.heading))
	d.global_position = _plane.global_position + fwd * 110.0 + Vector3(25, 8, 0)
	d.look_at(_plane.global_position, Vector3.UP)


func _teardown(kind: String) -> void:
	match kind:
		"foot", "house":
			_main.walker.override_move = Vector2.ZERO
			if _main.state == _main.State.INDOORS:
				_main.exit_house()
				for i in 120:
					await get_tree().process_frame
					if _main.state == _main.State.ON_FOOT:
						break
		"rain":
			var w: Weather = _main.weather
			if w.cloud:
				w.cloud.queue_free()
				w.cloud = null
		"dragon":
			SaveManager.dragon = false
			_main._dragon._read_settings()


func _report(cold: Dictionary, warm: Dictionary) -> void:
	var before := {}
	if FileAccess.file_exists(OUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if parsed is Dictionary:
			before = parsed
	var toggles := BenchToggles.active()
	print("\nBENCH RENDER at %s, %s renderer, %.0f s per area%s" % [str(get_viewport().get_visible_rect().size),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), _measure, (", toggles " + str(toggles)) if not toggles.is_empty() else ""])
	print("launch to first controllable frame: %d ms (before: %s)" % [_first_frame_ms, str(before.get("first_frame_ms", "-"))])
	for run in [["cold", cold], ["warm", warm]]:
		print("-- %s run" % run[0])
		print("%-13s %7s %7s %7s %8s %7s %6s | %6s %6s %6s %6s | %s" % ["area", "median", "p95", "p99", "worst", "1%low", "draws",
			"script", "phys", "rcpu", "gpu", "before (median / 1% low)"])
		for area in run[1]:
			var r: Dictionary = run[1][area]
			var b: Dictionary = before.get(run[0], {}).get(area, {})
			print("%-13s %6.2fms %6.2fms %6.2fms %7.1fms %5.0ffps %6.0f | %5.2fms %5.2fms %5.2fms %5.2fms | %s" % [area, r.median_ms, r.p95_ms,
				r.p99_ms, r.worst_ms, r.low1_fps, r.draw_calls, r.logic_ms, r.physics_ms, r.cpu_ms, r.gpu_ms,
				("%.2fms / %.0ffps" % [b.median_ms, b.low1_fps]) if not b.is_empty() else "-"])
	_report_hitches()
	var sd := StallDetector.current
	print("stalls over %d ms: %d%s" % [int(StallDetector.STALL_MS), sd.stalls if sd else 0,
		(" (see " + ProjectSettings.globalize_path(StallDetector.LOG) + ")") if sd and sd.stalls > 0 else ""])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bench"))
	if FileAccess.file_exists(OUT):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT), ProjectSettings.globalize_path("user://bench/render_previous.json"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"when": Time.get_datetime_string_from_system(), "godot": Engine.get_version_info().string,
		"resolution": str(get_viewport().get_visible_rect().size), "toggles": toggles, "measure_s": _measure,
		"first_frame_ms": _first_frame_ms, "cold": cold, "warm": warm}, " "))
	var h := FileAccess.open(HITCHES, FileAccess.WRITE)
	h.store_string(JSON.stringify(_hitches, " "))
	print("Saved %s (hitches: %s)" % [ProjectSettings.globalize_path(OUT), ProjectSettings.globalize_path(HITCHES)])


## The most common causes of the warm run's slow frames.
func _report_hitches() -> void:
	print("-- hitches (warm run, frames over %.1f ms): %d" % [HITCH_MS, _hitches.size()])
	if _hitches.is_empty():
		return
	var causes := {}  # cause -> [count, total ms]
	var per_area := {}
	for h: Dictionary in _hitches:
		per_area[h.area] = int(per_area.get(h.area, 0)) + 1
		var why: Array = []
		for n in h.notes:
			if not why.has(n):
				why.append(n)
		if int(h.compiles) > 0:
			why.append("shader compile")
		if why.is_empty():
			var cpu_side: float = h.logic_ms + h.physics_ms + h.cpu_ms
			why.append("no event: GPU-bound" if h.gpu_ms > cpu_side else "no event: CPU-bound (scripts %s)" % ("heavy" if h.logic_ms + h.physics_ms > 6.0 else "light"))
		for w in why:
			var c: Array = causes.get(w, [0, 0.0])
			c[0] += 1
			c[1] += h.ms
			causes[w] = c
	var keys := causes.keys()
	keys.sort_custom(func(a, b): return causes[a][0] > causes[b][0])
	for k in keys.slice(0, 10):
		print("  %-36s %4d frames, avg %.1f ms" % [k, causes[k][0], causes[k][1] / causes[k][0]])
	print("  by area: %s" % str(per_area))


static func _pct(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int((sorted.size() - 1) * q), 0, sorted.size() - 1)]


static func _pct_of(a: Array[float], q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return _pct(s, q)


static func _avg(a: Array) -> float:
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
