extends Node
## Autopilot flies the prop plane to every star (nearest first) and checks:
## every star is reachable, the counter reaches the total, the 10-star
## milestone and "all collected" fire, stars respawn, and the lifetime total
## is saved. Run:
##   flatpak run org.godotengine.Godot --headless --path . --fixed-fps 60 res://tests/star_run_test.tscn

const TIME_LIMIT := 5000.0  # simulated seconds

var _main: Node
var _plane: Aircraft
var _stars: StarManager
var _time := 0.0
var _milestones: Array[int] = []
var _all_fired := false
var _respawned := false
var _done := false


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_stars.cfg"))
	SaveManager.use_path("user://test_stars.cfg")
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_stars = _main.get_node("StarManager")
	_stars.milestone_reached.connect(func(n): _milestones.append(n))
	_stars.all_collected.connect(func(): _all_fired = true)
	_stars.star_collected.connect(_on_collected)
	_main.title.hide()  # skip menus; the flow keeps autopilot override on


func _on_collected(count: int, _total: int) -> void:
	if _all_fired and count == 0:
		_respawned = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_plane.input.override_enabled = true
	_plane.input.override_throttle = 0.0
	var target := _nearest_star()
	if target:
		_steer_to(target.global_position)
	if _respawned or _time > TIME_LIMIT:
		_finish()


func _nearest_star() -> Star:
	var best: Star = null
	var best_d := INF
	for s: Star in get_tree().get_nodes_in_group("stars"):
		if s.is_collected:
			continue
		var d := s.global_position.distance_squared_to(_plane.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _steer_to(target: Vector3) -> void:
	var to := target - _plane.global_position
	var flat := Vector2(to.x, to.z)
	var want_heading := atan2(-to.x, -to.z)
	var err := wrapf(want_heading - _plane.heading, -PI, PI)
	# Too close to turn onto it? Fly straight for a bit to open the circle.
	var radius := _plane.speed / deg_to_rad(_plane.stats.turn_rate_deg)
	var stick_x := clampf(-err * 2.5, -1.0, 1.0)
	if flat.length() < radius * 1.6 and absf(err) > 1.2:
		stick_x = 0.0
	var want_pitch := atan2(to.y, flat.length())
	var stick_y := clampf(want_pitch / deg_to_rad(_plane.stats.max_pitch_deg) * 1.5, -1.0, 1.0)
	_plane.input.override_stick = Vector2(stick_x, stick_y)


func _finish() -> void:
	_done = true
	var fails := 0
	var collected_all := _all_fired
	print("Stars: %d total, collected %d in %.0f s simulated" % [_stars.total, _stars.total if _all_fired else _stars.count, _time])
	for check in [
		["at least 140 stars on the map", _stars.total >= 140],
		["every star reached", collected_all],
		["10-star milestone fired", 10 in _milestones],
		["all-collected celebration fired", _all_fired],
		["stars respawned", _respawned and _stars.count == 0],
		["lifetime total counted", SaveManager.lifetime_stars == _stars.total],
	]:
		print(("PASS  " if check[1] else "FAIL  ") + check[0])
		if not check[1]:
			fails += 1
	if not collected_all:
		for s: Star in get_tree().get_nodes_in_group("stars"):
			if not s.is_collected:
				print("      unreached star at ", s.global_position.round())
	SaveManager.save_now()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_stars.cfg"))
	print("\nSTAR TEST %s" % ("PASSED" if fails == 0 else "FAILED"))
	get_tree().quit(1 if fails else 0)
