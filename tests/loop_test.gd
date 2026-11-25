extends Node
## The loop trick (Phase 14): X while holding the stick to climb. Purely
## visual, like the barrel roll: the real flight path, pitch limits and
## safety are unchanged.
##   roll      X on its own is still a barrel roll
##   loop      X while climbing: the model goes up and over (upside down at
##             the top, travelling backwards there), always above the real
##             path, and ends back on it
##   limits    the plane itself never pitches past its limit during a loop
##   room      under a roof, or near the sky's ceiling, it's a barrel roll
##             instead
##   cancel    a respawn in the middle of a loop puts the model straight back
##   camera    the chase camera rises part way, keeping the loop in view
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_loop.cfg"
var _fails := 0
var _main: Node
var _plane: Aircraft
var _vis: AircraftVisuals
const SKY := Vector3(-1300, 60, 1900)


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_main._enter(_main.State.FLYING)
	_plane = _main.aircraft
	_vis = _plane.visuals
	await _fly_at(SKY)
	# --- roll --------------------------------------------------------------------------
	_plane.input.override_stick = Vector2.ZERO
	await _frames(10)
	_plane.trick()
	await _frames(25)  # half way round
	var rolled := not _vis.is_looping() and absf(_vis.rotation.z) > 1.0
	await _frames(50)
	_check("X on its own is still a barrel roll", rolled and not _vis.is_looping())
	# --- loop --------------------------------------------------------------------------
	_plane.input.override_stick = Vector2(0, 1)
	await _frames(10)
	_plane.trick()
	var started := _vis.is_looping()
	var lowest := INF
	var highest := -INF
	var max_angle := 0.0
	var max_pitch := 0.0
	var backwards := false
	var cam_lift := 0.0
	var last := _vis.global_position
	var frames := 0
	while _vis.is_looping() and frames < 400:
		await get_tree().physics_frame
		frames += 1
		lowest = minf(lowest, _vis.position.y)
		highest = maxf(highest, _vis.position.y)
		max_angle = maxf(max_angle, _vis.rotation.x)
		max_pitch = maxf(max_pitch, absf(rad_to_deg(_plane.pitch)))
		var fwd := Vector3(-sin(_plane.heading), 0, -cos(_plane.heading))
		var moved := _vis.global_position - last
		if _vis.position.y > AircraftVisuals.LOOP_RADIUS * 1.6 and moved.dot(fwd) < 0.0:
			backwards = true
		last = _vis.global_position
		cam_lift = maxf(cam_lift, _main.chase_camera.global_position.y - (_plane.global_position.y + _plane.stats.camera_height))
	await _frames(2)
	print("  note: loop took %.1f s, model %.1f..%.1f m above the path, turned %.0f deg, plane pitch max %.0f deg, camera rose %.1f m" % [frames / 60.0, lowest, highest, rad_to_deg(max_angle), max_pitch, cam_lift])
	_check("X while climbing: up and over (upside down at the top, backwards there), above the path, back on it", started
			and lowest > -0.01 and highest > AircraftVisuals.LOOP_RADIUS * 1.8 and max_angle > PI and backwards
			and _vis.position.length() < 0.05 and absf(_vis.rotation.x) < 0.01)
	_check("the plane itself never pitches past its limit during a loop", max_pitch <= _plane.stats.max_pitch_deg + 0.5)
	_check("the chase camera rises part way, keeping the loop in view", cam_lift > AircraftVisuals.LOOP_RADIUS)
	# --- room ----------------------------------------------------------------------------
	var roof := StaticBody3D.new()
	roof.collision_layer = GameSettings.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	cs.shape = box
	roof.add_child(cs)
	await _fly_at(SKY)  # level, then a roof just overhead
	# (Crashes on, as in normal play: can't-crash mode would lift the plane
	# on top of the roof, treating it as ground.)
	_plane.crashes = true
	_plane.safety.assist = false
	add_child(roof)
	roof.global_position = _plane.global_position + Vector3.UP * 12.0
	await _frames(3)
	_plane.input.override_stick = Vector2(0, 1)
	await _frames(1)
	_plane.trick()
	await _frames(2)
	var under_roof := not _vis.is_looping()
	roof.queue_free()
	_plane.crashes = false
	_plane.safety.assist = true
	await _frames(70)
	await _fly_at(Vector3(SKY.x, _plane.safety.ceiling_height - 10.0, SKY.z))
	_plane.input.override_stick = Vector2(0, 1)
	await _frames(5)
	_plane.trick()
	await _frames(2)
	var near_ceiling := not _vis.is_looping()
	await _frames(70)
	print("  note: under a roof: loop %s; near the ceiling: loop %s" % [not under_roof, not near_ceiling])
	_check("under a roof, or near the sky's ceiling, it's a barrel roll instead", under_roof and near_ceiling)
	# --- cancel --------------------------------------------------------------------------
	await _fly_at(SKY)
	_plane.input.override_stick = Vector2(0, 1)
	await _frames(5)
	_plane.trick()
	await _frames(70)
	var mid: bool = _vis.is_looping() and _vis.position.y > 3.0
	_plane.teleport(SKY, 0.0)
	await _frames(1)
	_check("a respawn in the middle of a loop puts the model straight back", mid and not _vis.is_looping() and _vis.position.length() < 0.05)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nLOOP TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _fly_at(p: Vector3) -> void:
	_plane.speed = _plane.stats.cruise_speed
	_plane.teleport(p, 0.0)
	await _frames(2)
	_plane.teleport(p, 0.0)
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2.ZERO
	_main.chase_camera.snap_to_target()
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
