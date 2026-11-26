extends Node
## ./dev.sh bench-sim (Phase 8): how much CPU the game's simulation costs,
## headless, along a fixed route. It runs in CI.
##
## Headless means nothing is drawn, so this NEVER measures frames per
## second: it measures the time the simulation takes (physics and game
## logic), which is the part that's the same with or without a screen.
##
## For each area (the airport, the fully grown city, open ocean, Dragon Peak
## with the dragon awake) the plane flies a gentle circle for a few seconds
## (after settling for a few seconds) while it records Godot's own timers per
## frame (physics process and process, ms: the median and the 95th
## percentile), then times each system on its own, many times over:
##   flight safety   one look-ahead (FlightSafety.evaluate), µs
##   crowd           one update of the townspeople (CityCrowd), µs
##   city            one tick of the growing city (CityGrowth), µs
##   dragon          one think-and-move of the dragon AI, µs
## Results print as a table and go to user://bench/sim.json; the previous
## run's numbers are shown alongside for comparison.

const AREAS := [
	["airport", Vector3(-150, 70, 60)],
	["city", Vector3(380, 90, 600)],
	["ocean", Vector3(1300, 60, -1500)],
	["dragon_peak", Vector3(-170, 140, -1250)],
]
const FLY_FRAMES := 300
const REPEATS := 300
const OUT := "user://bench/sim.json"

var _main: Node
var _plane: Aircraft


func _ready() -> void:
	SaveManager.use_path("user://bench_sim.cfg")
	SaveManager.dragon = true
	SaveManager.crashes = false  # (the plane must keep flying the route)
	SaveManager.city_seed = 12345
	SaveManager.playtime = 30.0 * 3600.0  # the city fully grown
	SaveManager.city_time = SaveManager.playtime
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	_plane = _main.aircraft
	for i in 10:
		await get_tree().physics_frame
	_main._enter(_main.State.FLYING)
	var results := {}
	# The route first (whole frames), then each system on its own at each
	# place (calling a system many times in a row can leave work for the
	# frames after it, so it never runs while the route is measured).
	for area in AREAS:
		results[area[0]] = await _area(area[0], area[1])
	for area in AREAS:
		results[area[0]].merge(await _systems(area[0], area[1]))
	_report(results)
	await _quit()


func _area(area: String, at: Vector3) -> Dictionary:
	_plane.teleport(at, 0.0)
	_plane.mode = Aircraft.Mode.FLYING
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2(0.3, 0.0)  # a gentle circle
	var dragon: Node = get_tree().get_first_node_in_group("dragon")
	if area == "dragon_peak" and dragon:
		dragon.wake()
	# Settle first (arriving somewhere new sets up its physics and loads
	# what's nearby: a burst that isn't what flying there costs).
	for i in 150:
		await get_tree().physics_frame
	var phys: Array[float] = []
	var proc: Array[float] = []
	for i in FLY_FRAMES:
		await get_tree().physics_frame
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_plane.input.override_stick = Vector2.ZERO
	return {
		"physics_ms_median": _pct(phys, 0.5), "physics_ms_p95": _pct(phys, 0.95),
		"process_ms_median": _pct(proc, 0.5), "process_ms_p95": _pct(proc, 0.95),
	}


## Each system on its own, many times over, at `at`.
func _systems(area: String, at: Vector3) -> Dictionary:
	_plane.teleport(at, 0.0)
	_plane.mode = Aircraft.Mode.FLYING
	for i in 60:
		await get_tree().physics_frame
	var dragon: Node = get_tree().get_first_node_in_group("dragon")
	var r := {}
	var safety: FlightSafety = _plane.safety
	r["safety_us"] = _time(func(): safety.evaluate(_plane.global_position, _plane.velocity, 0.0))
	var city: CityDistrict = _first(CityDistrict)
	if city and area == "city":
		r["crowd_us"] = _time(func(): city.crowd._process(1.0 / 60.0))
		r["crowd_people"] = city.crowd.population()
		r["city_us"] = _time(func(): city.growth._process(1.0 / 60.0))
	if dragon and area == "dragon_peak":
		r["dragon_us"] = _time(func(): dragon._physics_process(1.0 / 60.0))
	return r


## Average µs per call of `f`, over REPEATS calls.
func _time(f: Callable) -> float:
	StallDetector.note("bench-sim timing loop")  # (its own long frame, not a game stall)
	f.call()  # (warm up)
	var t0 := Time.get_ticks_usec()
	for i in REPEATS:
		f.call()
	return float(Time.get_ticks_usec() - t0) / REPEATS


func _report(results: Dictionary) -> void:
	var before := {}
	if FileAccess.file_exists(OUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if parsed is Dictionary:
			before = parsed.get("areas", {})
	print("\nBENCH SIM (headless: simulation time only, not frames per second)")
	print("%-12s %-16s %10s %10s" % ["area", "measure", "now", "before"])
	for area in results:
		for k in results[area]:
			var now: float = results[area][k]
			var was = before.get(area, {}).get(k, null)
			print("%-12s %-16s %10.3f %10s" % [area, k, now, "%.3f" % float(was) if was != null else "-"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bench"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"when": Time.get_datetime_string_from_system(), "godot": Engine.get_version_info().string,
		"areas": results}, " "))
	print("Saved %s" % ProjectSettings.globalize_path(OUT))


func _first(cls) -> Node:
	for n in _main.find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null


static func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


static func _pct(a: Array[float], p: float) -> float:
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(p * (b.size() - 1)), 0, b.size() - 1)] if not b.is_empty() else 0.0


## Free the game first, then quit (quitting mid-frame can leave the clouds
## updating a freed batch).
func _quit() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
