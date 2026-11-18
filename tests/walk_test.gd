extends Node
## Walking:
##   out      Y in the parked plane puts the walker on the ground beside it
##            (ON_FOOT), with the walk camera live and the "get in" prompt
##   plane    the parked plane ignores the controls while you walk
##   speed    full stick walks at walk speed, half stick at half (analog),
##            B sprints; A jumps and lands again
##   prompt   walking away hides the prompt and Y does nothing there
##   sea      sprinting at the sea stops at the shore, never in the water
##   slopes   it won't climb ground steeper than the limit, and the camera
##            stays above the ground
##   camera   invert-Y flips up/down, camera speed scales turning, and the
##            parents' settings buttons change both
##   pause    pausing on foot resumes on foot
##   back     walking back to the plane and pressing Y gets in (LANDED); a
##            held stick doesn't set it rolling; then it takes off
##   islands  getting out, walking and getting back in works at every site
## Exit code 0 = pass, 1 = fail.

const SITES := [
	["main island meadow", 1200.0, 40.0], ["runway", -100.0, 0.0], ["palm island", 2240.0, 440.0],
	["volcano beach", -1514.0, -1021.0], ["ice island", 620.0, -3280.0], ["dino meadow", 2650.0, 2080.0],
	["castle island", -440.0, 3520.0], ["town island", -3060.0, 580.0],
]

var _main: Node
var _plane: Aircraft
var _w: Walker
var _cam: WalkCamera
var _fails := 0


func _ready() -> void:
	SaveManager.use_path("user://test_walk.cfg")
	SaveManager.crashes = true
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_w = _main.walker
	_cam = _main.walk_camera
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_w.override_enabled = true
	_cam.override_enabled = true
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_walk.cfg"))
	print("\nWALK TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var site := Vector3(1200, 0, 40)
	_park(site)
	await _frames(3)
	_check("the Y prompt offers to get out when parked", _main.hud.prompt_kind() == "exit")
	_check("Y gets out of the parked plane", _main.toggle_plane() and _main.state == _main.State.ON_FOOT)
	await _frames(20)
	var feet := _w.global_position
	_check("walker stands on the ground beside the plane", _w.is_active() and _w.is_on_floor()
			and absf(feet.y - _ground(feet)) < 0.3 and _flat_dist(feet, _plane.global_position) < 8.0)
	_check("walk camera is live", _cam.cam.current and not _main.chase_camera.cam.current)
	_check("prompt offers to get back in", _main.hud.prompt_kind() == "enter")
	_check("A / B button hints show after getting out", _main.hud.foot_hints_showing())
	# --- speeds ---------------------------------------------------------------
	_cam.yaw = PI  # look (and walk) south, away from the plane's nose
	var v_full: float = await _walk(Vector2(0, 1), false, 150)
	var v_half: float = await _walk(Vector2(0, 0.5), false, 150)
	var v_run: float = await _walk(Vector2(0, 1), true, 150)
	print("  note: walk %.1f m/s, half stick %.1f m/s, sprint %.1f m/s" % [v_full, v_half, v_run])
	_check("full stick walks at walk speed", absf(v_full - Walker.WALK_SPEED) < 1.2)
	_check("half stick is about half speed (analog)", absf(v_half - Walker.WALK_SPEED * 0.5) < 0.9)
	_check("B sprints", v_run > v_full + 3.0)
	_check("the parked plane ignores the controls", _plane.mode == Aircraft.Mode.PARKED and _plane.speed == 0.0)
	# --- jump -------------------------------------------------------------------
	_w.override_move = Vector2.ZERO
	await _frames(30)
	var y0 := _w.global_position.y
	_w.override_jump = true
	await _frames(1)
	_w.override_jump = false
	var top := y0
	for i in 40:
		await get_tree().physics_frame
		top = maxf(top, _w.global_position.y)
	await _frames(90)
	_check("A jumps and lands again", top > y0 + 1.5 and _w.is_on_floor() and absf(_w.global_position.y - _ground(_w.global_position)) < 0.3)
	# --- prompt goes away -------------------------------------------------------
	_check("walked away: no prompt, Y does nothing", _flat_dist(_w.global_position, _plane.global_position) > 20.0
			and _main.hud.prompt_kind() == "" and not _main.toggle_plane() and _main.state == _main.State.ON_FOOT)
	# --- camera settings: speed and invert-Y -------------------------------------
	var pitch0: float = _cam.pitch
	_cam.override_look = Vector2(0, 1)  # right stick up
	await _frames(10)
	var up_normal: float = _cam.pitch - pitch0
	_cam.pitch = pitch0
	SaveManager.set_invert_y(true)
	await _frames(10)
	var up_inverted: float = _cam.pitch - pitch0
	SaveManager.set_invert_y(false)
	_cam.pitch = pitch0
	_check("invert-Y flips the camera's up/down", signf(up_normal) == -signf(up_inverted) and absf(up_normal) > 0.05)
	var yaw0: float = _cam.yaw
	_cam.override_look = Vector2(1, 0)
	await _frames(10)
	var turn_normal := absf(wrapf(_cam.yaw - yaw0, -PI, PI))
	_cam.yaw = yaw0
	SaveManager.set_look_sensitivity(1.6)
	await _frames(10)
	var turn_fast := absf(wrapf(_cam.yaw - yaw0, -PI, PI))
	SaveManager.set_look_sensitivity(1.0)
	_cam.override_look = Vector2.ZERO
	_cam.yaw = yaw0
	_check("faster camera speed turns faster", turn_fast > turn_normal * 1.4)
	# The parents' settings buttons change them.
	var panel: SettingsPanel = _main._settings
	panel._on_cam_speed()
	var s1 := SaveManager.look_sensitivity
	panel._on_cam_speed()
	var s2 := SaveManager.look_sensitivity
	panel._on_cam_speed()
	_check("camera speed button steps fast -> slow -> normal", is_equal_approx(s1, 1.6) and is_equal_approx(s2, 0.6)
			and is_equal_approx(SaveManager.look_sensitivity, 1.0))
	panel._invert.toggled.emit(true)
	var inv_on := SaveManager.invert_y
	panel._invert.toggled.emit(false)
	_check("invert button toggles invert-Y", inv_on and not SaveManager.invert_y)
	# --- pause on foot ------------------------------------------------------------
	_main._show_pause()
	var paused_ok: bool = _main.state == _main.State.PAUSED and _w.is_active()
	_main._resume()
	_check("pause on foot resumes on foot", paused_ok and _main.state == _main.State.ON_FOOT and _cam.cam.current)
	# --- the sea ------------------------------------------------------------------
	_cam.yaw = -PI * 0.5  # east, to the coast
	var wettest := INF
	_w.override_move = Vector2(0, 1)
	_w.override_sprint = true
	for i in 3000:
		await get_tree().physics_frame
		var p := _w.global_position
		wettest = minf(wettest, _ground(p))
	_w.override_sprint = false
	var at_shore := _w.global_position
	print("  note: ran east to %s, lowest ground %.2f m above sea level" % [at_shore.round(), wettest])
	_check("sprinting at the sea stops at the shore (never in the water)", wettest > Walker.SHORE_LEVEL - 0.3 and at_shore.x > 1250.0)
	# --- slopes and camera --------------------------------------------------------
	var foot := Vector3(195, 0, -640)
	_w.place(Vector3(foot.x, _ground(foot) + 0.2, foot.z), 0.0)
	_cam.snap_to(0.0)  # north, straight at the big peak
	var steepest := 0.0
	var cam_low := INF
	_w.override_sprint = true
	for i in 2400:
		await get_tree().physics_frame
		if _w.is_on_floor():
			steepest = maxf(steepest, rad_to_deg(_w.get_floor_angle()))
		var c := _cam.cam.global_position
		cam_low = minf(cam_low, c.y - _ground(c))
	_w.override_sprint = false
	_w.override_move = Vector2.ZERO
	print("  note: up the mountain to %.0f m, steepest footing %.0f deg, camera at least %.1f m above ground" % [_w.global_position.y, steepest, cam_low])
	_check("won't stand on ground steeper than the limit", steepest <= Walker.MAX_SLOPE_DEG + 1.0)
	_check("camera stays above the ground", cam_low > 0.2)
	# --- back to the plane ----------------------------------------------------------
	var pp := _plane.global_position
	var from := pp + Vector3(0, 0, 30)
	_w.place(Vector3(from.x, _ground(from) + 0.2, from.z), 0.0)
	_cam.snap_to(0.0)  # the plane is north of us
	_w.override_move = Vector2(0, 1)
	var reached := await _until(func(): return _main.hud.prompt_kind() == "enter", 600)
	_check("walking up to the plane shows the get-in prompt", reached)
	_check("Y gets back in", _main.toggle_plane() and _main.state == _main.State.LANDED and not _w.is_active()
			and _main.chase_camera.cam.current)
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2(0, 0.8)  # still pushing from walking
	await _frames(60, true)
	_check("a stick still held from walking doesn't set it rolling", _plane.mode == Aircraft.Mode.PARKED)
	_plane.input.override_stick = Vector2.ZERO
	await _frames(20, true)
	_plane.input.override_throttle = 1.0
	var up := await _until(func(): return _plane.mode == Aircraft.Mode.FLYING, 900, true)
	_check("and then it takes off again", up and _main.state == _main.State.FLYING)
	# --- every island and islet -------------------------------------------------------
	var sites := SITES.duplicate()
	for i in Islets.LIST.size():
		var e: Array = Islets.LIST[i]
		var c: Vector2 = e[0]
		if e[3] == "lagoon":
			var pad := LandingPads.lagoon_pad(c, (-c).angle(), MermaidLagoon.RING_RADIUS)
			sites.append(["mermaid lagoon", pad[0].x, pad[0].y])
		elif e[3] == "mermaid":
			sites.append(["mermaid cove %d" % i, c.x + e[1] * 0.3, c.y + e[1] * 0.3])
		else:
			sites.append(["islet %d (%s)" % [i, e[3]], c.x, c.y])
	var failed: Array[String] = []
	for s in sites:
		_park(Vector3(s[1], 0, s[2]))
		await _frames(3)
		var out: bool = _main.toggle_plane()
		_cam.yaw = PI
		_w.override_move = Vector2(0.4, 1)
		await _frames(150)
		_w.override_move = Vector2.ZERO
		var p := _w.global_position
		var dry := _ground(p) > Walker.SHORE_LEVEL - 0.3
		var moved := _flat_dist(p, _plane.global_position) > 10.0
		# Walk back: face the plane and go.
		var to := _plane.global_position - p
		_cam.yaw = atan2(-to.x, -to.z)
		_w.override_move = Vector2(0, 1)
		var back := await _until(func(): return _main.hud.prompt_kind() == "enter", 900)
		_w.override_move = Vector2.ZERO
		var in_again: bool = back and _main.toggle_plane() and _main.state == _main.State.LANDED
		if not (out and dry and moved and in_again):
			failed.append("%s (%s)" % [s[0], "out" if not out else ("wet" if not dry else ("stuck" if not moved else "back in"))])
			if _main.state == _main.State.ON_FOOT:
				_main._enter(_main.State.LANDED)
	_check("out, a walk, and back in at all %d sites" % sites.size(), failed.is_empty())
	if not failed.is_empty():
		print("  failed: ", ", ".join(failed))


## Park the plane on the ground at `at` (x, z), heading north.
func _park(at: Vector3) -> void:
	_plane.park(Vector3(at.x, _ground(at), at.z), 0.0)
	_main._enter(_main.State.FLYING)  # also hands the plane back its (idle) controls
	_plane.input.stick = Vector2.ZERO    # and forget boost held in the last check
	_plane.input.throttle = 0.0


## Hold the stick for `frames`; returns the average ground speed over the
## last two thirds (m/s).
func _walk(stick: Vector2, sprint: bool, frames: int) -> float:
	_w.override_move = stick
	_w.override_sprint = sprint
	await _frames(frames / 3)
	var a := _w.global_position
	var n := frames - frames / 3
	await _frames(n)
	_w.override_sprint = false
	return _flat_dist(a, _w.global_position) / (n / 60.0)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 800, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	var hit := _plane.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -INF


## (keep_plane: state changes hand the plane's controls back; keep ours.)
func _frames(n: int, keep_plane := false) -> void:
	for i in n:
		if keep_plane:
			_plane.input.override_enabled = true
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int, keep_plane := false) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		if keep_plane:
			_plane.input.override_enabled = true
		await get_tree().physics_frame
	return cond.call()


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
