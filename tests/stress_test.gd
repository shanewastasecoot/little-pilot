extends Node
## Automated version of the roadmap's stress test: holds each stick direction
## (with and without boost/slow) for 60 simulated seconds and checks the plane
## never goes below the hard floor, above the ceiling or past the world edge.
##
## Run headless (fast, no window):
##   flatpak run org.godotengine.Godot --headless --path . --fixed-fps 60 res://tests/stress_test.tscn
## Runs every case for every aircraft in AircraftCatalog.
## Exit code 0 = pass, 1 = fail.

const SECONDS_PER_CASE := 60.0
const CASES := [
	["no input", Vector2(0, 0), 0.0],
	["dive", Vector2(0, -1), 0.0],
	["dive + boost", Vector2(0, -1), 1.0],
	["climb", Vector2(0, 1), 0.0],
	["climb + boost", Vector2(0, 1), 1.0],
	["turn left", Vector2(-1, 0), 0.0],
	["turn right + slow", Vector2(1, 0), -1.0],
	["dive left + boost", Vector2(-0.7, -0.7), 1.0],
	["dive right", Vector2(0.7, -0.7), 0.0],
	["climb right + boost", Vector2(0.7, 0.7), 1.0],
	["straight + boost", Vector2(0, 0), 1.0],
	["straight + slow", Vector2(0, 0), -1.0],
	# Targeted runs at the island's hardest spots: [name, stick, throttle, start, heading°]
	["dive into peak", Vector2(0, -1), 1.0, Vector3(150, 140, -380), 0.0],
	["straight into peak", Vector2(0, 0), 1.0, Vector3(150, 90, -420), 0.0],
	["circle lighthouse", Vector2(-1, 0), 0.0, Vector3(700, 45, 520), -90.0],
	["across turbines", Vector2(0, -0.3), 1.0, Vector3(470, 60, -40), 0.0],
	["valley weave", Vector2(0.6, -0.5), 1.0, Vector3(-70, 80, -400), 0.0],
	["dive into volcano", Vector2(0, -1), 1.0, Vector3(-1200, 160, -800), 50.0],
	["through the rainbow", Vector2(0, -0.2), 1.0, Vector3(950, 45, 300), -90.0],
	["circle palm island", Vector2(0.8, 0), 0.0, Vector3(1680, 40, 120), -90.0],
]

var _main: Node
var _plane: Aircraft
var _aircraft_ids: Array = AircraftCatalog.ids()
var _aircraft_index := 0
var _case := -1
var _frames := 0
var _frames_per_case := 0
var _stats := {}
var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_path("user://test_save.cfg")  # never touch the real save
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_plane.input.override_enabled = true
	_frames_per_case = int(SECONDS_PER_CASE * Engine.physics_ticks_per_second)
	_start_aircraft()
	_next_case()


func _start_aircraft() -> void:
	var id: String = _aircraft_ids[_aircraft_index]
	_plane.set_stats(AircraftCatalog.get_stats(id))
	print("--- %s ---" % _plane.stats.display_name)


func _physics_process(_delta: float) -> void:
	if _case < 0 or _aircraft_index >= _aircraft_ids.size():
		return
	var s := _plane.safety
	var pos := _plane.global_position
	var flat := Vector2(pos.x - s.boundary_center.x, pos.z - s.boundary_center.z).length()
	_stats.min_clear = minf(_stats.min_clear, s.clearance)
	_stats.max_alt = maxf(_stats.max_alt, pos.y)
	_stats.max_dist = maxf(_stats.max_dist, flat)
	for i in _plane.get_slide_collision_count():
		_stats.contacts += 1
		if _stats.first_contact == "":
			var col := _plane.get_slide_collision(i)
			_stats.first_contact = "%s at %s (plane alt %.1f, clearance %.1f)" % [
				col.get_collider().get_class(), col.get_position().round(), pos.y, s.clearance]
	if not pos.is_finite():
		_stats.nan = true
	_frames += 1
	if _frames >= _frames_per_case:
		_finish_case()
		_next_case()


func _next_case() -> void:
	_case += 1
	if _case >= CASES.size():
		_aircraft_index += 1
		if _aircraft_index >= _aircraft_ids.size():
			_report()
			return
		_case = 0
		_start_aircraft()
	var c: Array = CASES[_case]
	_plane.input.override_stick = c[1]
	_plane.input.override_throttle = c[2]
	_plane.speed = _plane.stats.cruise_speed
	var map: GameMap = _main.get_node("Map")
	if c.size() > 3:
		_plane.teleport(c[3], deg_to_rad(c[4]))
	else:
		_plane.teleport(map.spawn_position, map.spawn_heading())
	_frames = 0
	_stats = {min_clear = INF, max_alt = -INF, max_dist = 0.0, contacts = 0, nan = false, first_contact = ""}


func _finish_case() -> void:
	var c: Array = CASES[_case]
	var s := _plane.safety
	var problems: Array[String] = []
	# The body sphere is 1.4 m; staying above min_clearance - 0.5 means no touching.
	if _stats.min_clear < _plane.stats.min_clearance - 0.5:
		problems.append("too low (%.2f m)" % _stats.min_clear)
	if _stats.max_alt > s.ceiling_height + 0.1:
		problems.append("above ceiling (%.1f)" % _stats.max_alt)
	if _stats.max_dist > s.boundary_radius + 0.5:
		problems.append("left the world (%.1f)" % _stats.max_dist)
	if _stats.nan:
		problems.append("NaN position")
	var line := "%-22s min clearance %6.2f  max alt %6.1f  max dist %6.1f  contacts %d" % [
		c[0], _stats.min_clear, _stats.max_alt, _stats.max_dist, _stats.contacts]
	if problems.is_empty():
		print("PASS  ", line)
	else:
		print("FAIL  ", line, "  <- ", ", ".join(problems))
		_failures.append("%s: %s" % [_plane.stats.id, c[0]])
	if _stats.contacts > 0:
		print("      note: touched an obstacle collider %d frames, first: %s" % [_stats.contacts, _stats.first_contact])


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("ALL %d STRESS CASES PASSED" % (CASES.size() * _aircraft_ids.size()))
		get_tree().quit(0)
	else:
		print("%d FAILED: %s" % [_failures.size(), ", ".join(_failures)])
		get_tree().quit(1)
