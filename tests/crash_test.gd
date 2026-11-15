extends Node
## Crash mode and player take-off:
##   1. take-off   parked on the runway, boost + pull up -> flying and climbing
##   2. mountain   crashes on, fly into a peak -> crashed, then back parked
##                 on the runway
##   3. sea        dive into open water -> crashed, flagged as water
##   4. no crash   crashes off, same mountain run -> never crashes
## Exit code 0 = pass, 1 = fail.

var _main: Node
var _plane: Aircraft
var _step := 0
var _t := 0.0
var _crashes: Array = []
var _crash_t := -1.0
var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_path("user://test_crash.cfg")
	SaveManager.crashes = true
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_plane.crashed.connect(func(where: Vector3, water: bool): _crashes.append([where, water]))
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_plane.input.override_enabled = true


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures.append(name)


func _physics_process(delta: float) -> void:
	_t += delta
	var input := _plane.input
	match _step:
		0:  # Take-off: wait parked a moment, then boost and pull up.
			if _t < 1.0:
				input.override_throttle = 0.0
				input.override_stick = Vector2.ZERO
				return
			if not has_meta("checked_wait"):
				set_meta("checked_wait", true)
				_check("waits parked until the player goes", _plane.mode == Aircraft.Mode.PARKED)
			input.override_throttle = 1.0
			input.override_stick = Vector2(0, 0.7)
			if _t > 25.0:
				var runway_y: float = _main.map.runway_start().y
				_check("player take-off lifts off", _plane.mode == Aircraft.Mode.FLYING)
				_check("climbs away from the runway", _plane.global_position.y > runway_y + 15.0)
				_check("no crash during take-off", _crashes.is_empty())
				_next()
		1:  # Into a mountain with crashes on.
			if _t < delta * 1.5:
				_plane.teleport(Vector3(195, 90, -560), 0.0)
			# Let go of the controls once crashed (holding boost on the runway
			# would start the next take-off straight away).
			input.override_throttle = 1.0 if _crashes.is_empty() else 0.0
			input.override_stick = Vector2(0, -0.3) if _crashes.is_empty() else Vector2.ZERO
			if not _crashes.is_empty() and _crash_t < 0.0:
				_crash_t = _t
			if _crash_t >= 0.0 and _t > _crash_t + 3.0:  # after the fade and respawn
				_check("crashes into the mountain", true)
				_check("mountain is not water", not _crashes[0][1])
				_check("respawns parked on the runway", _plane.mode == Aircraft.Mode.PARKED
					and _plane.global_position.distance_to(_main.map.runway_start()) < 5.0)
				_next()
			elif _t > 40.0:
				_check("crashes into the mountain", false)
				_next()
		2:  # Dive into open sea.
			if _t < delta * 1.5:
				_crashes.clear()
				_plane.teleport(Vector3(900, 20, -1900), 0.0)
			input.override_throttle = 0.0
			input.override_stick = Vector2(0, -1)
			if not _crashes.is_empty():
				_check("crashes into the sea", true)
				_check("sea crash is a splash", _crashes[0][1])
				_next()
			elif _t > 20.0:
				_check("crashes into the sea", false)
				_next()
		3:  # Crashes off: the same mountain run never crashes.
			if _t < 3.0:
				return  # let the sea crash's respawn finish first
			if _t < 3.0 + delta * 1.5:
				_crashes.clear()
				SaveManager.set_crashes(false)
				_plane.teleport(Vector3(195, 90, -560), 0.0)
			input.override_throttle = 1.0
			input.override_stick = Vector2(0, -0.3)
			if _t > 43.0:
				_check("no crashes with crashes off", _crashes.is_empty())
				_finish()


func _next() -> void:
	_step += 1
	_t = 0.0


func _finish() -> void:
	set_physics_process(false)
	if _failures.is_empty():
		print("CRASH TEST PASSED")
		get_tree().quit(0)
	else:
		print("CRASH TEST FAILED: ", _failures)
		get_tree().quit(1)
