extends Node
## Landing anywhere:
##   soft     a gentle approach onto a meadow touches down, rolls out, parks
##            (LANDED state), and sits perfectly still
##   brakes   holding slow stops in a shorter distance
##   again    after parking, a held stick doesn't restart it; letting go and
##            boosting does, and it lifts off by itself (off the runway)
##   bumps    diving in, boosting in, steep ground, a rooftop and the sea are
##            still a crash, not a landing
##   islands  the plane can land, park and take off again on every island
##            and islet
##   jet      the lower, faster jet lands and takes off too
##   child    like a 4-year-old: nose down, boost held all the way, never
##            touching slow, onto the runway, a meadow and three islands, with
##            crashes on and off: it always lands and parks, never crashes
##   gentle   crashes off: holding slow lets it land; otherwise it still
##            refuses to touch the ground
## Exit code 0 = pass, 1 = fail.

## Landing sites: [name, x, z] (a point over landable ground).
const SITES := [
	["main island meadow", 1200.0, 40.0], ["runway", -100.0, 0.0], ["palm island", 2240.0, 440.0],
	["volcano beach", -1514.0, -1021.0], ["ice island", 620.0, -3280.0], ["dino meadow", 2650.0, 2080.0],
	["castle island", -440.0, 3520.0], ["town island", -3060.0, 580.0],
	# Where you land for deliveries (scripts/delivery/recipients.gd land_at).
	["city meadow", -160.0, 450.0], ["lighthouse meadow", 950.0, 560.0], ["farm meadow", -560.0, 380.0],
]

var _main: Node
var _plane: Aircraft
var _fails := 0
var _crashes := 0


func _ready() -> void:
	SaveManager.use_path("user://test_landing.cfg")
	SaveManager.crashes = true
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_plane.crashed.connect(func(_w, _s): _crashes += 1)
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_plane.input.override_enabled = true
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_landing.cfg"))
	print("\nLANDING TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	# --- soft landing on a meadow ------------------------------------------
	var site := Vector2(1200, 40)
	var roll_free: float = await _approach(site, 0.0, -1.0)
	_check("gentle approach lands and parks", _plane.mode == Aircraft.Mode.PARKED and _crashes == 0)
	_check("game is in the LANDED state", _main.state == _main.State.LANDED)
	var g := _ground(_plane.global_position)
	_check("wheels are on the ground", absf(_plane.global_position.y - g - _plane.stats.ground_offset) < 0.05)
	var before := _plane.global_position
	await _frames(180)
	_check("parked plane doesn't slide or jitter", _plane.global_position.distance_to(before) < 0.001)
	# --- release + boost takes off again -------------------------------------
	_plane.input.override_stick = Vector2.ZERO
	_plane.input.override_throttle = 0.0
	await _frames(30)
	_plane.input.override_throttle = 1.0
	var lifted := await _until(func(): return _plane.mode == Aircraft.Mode.FLYING, 600)
	_check("boost takes off again from the meadow", lifted and _crashes == 0)
	_check("game is back in the FLYING state", _main.state == _main.State.FLYING)
	await _frames(240)
	_check("climbs away without bumping", _crashes == 0 and _plane.mode == Aircraft.Mode.FLYING)
	# --- a stick still held from the approach doesn't restart it ----------------
	await _approach(site, 0.0, -1.0, true)
	await _frames(120)
	_check("stick still held from flying doesn't restart it", _plane.mode == Aircraft.Mode.PARKED and _crashes == 0)
	# --- brakes ----------------------------------------------------------------
	var roll_brake: float = await _approach(site, -1.0, -1.0)
	print("  note: roll-out %.0f m coasting (slow let go at touchdown), %.0f m braking" % [roll_free, roll_brake])
	_check("holding slow stops shorter", roll_brake < roll_free - 3.0 and roll_brake < 30.0)
	# --- things that are still a bump ----------------------------------------
	_check("diving in is a bump", await _bumps(Vector3(1200, 0, 40), Vector2(0, -1), 0.0, 40.0))
	_check("boosting in is a bump", await _bumps(Vector3(1200, 0, 40), Vector2(0, -0.35), 1.0, 18.0))
	_check("steep mountainside is a bump", await _bumps(Vector3(195, 0, -780), Vector2(0, -0.3), -1.0, 14.0))
	_check("a rooftop is a bump", await _bumps(Vector3(IslandShape.CITY.x - 80, 0, IslandShape.CITY.y - 160), Vector2(0, -0.3), -1.0, 14.0))
	_check("the sea is a splash", await _bumps(Vector3(1500, 0, 2000), Vector2(0, -0.3), -1.0, 14.0))
	# --- every island and islet --------------------------------------------
	var sites := SITES.duplicate()
	for i in Islets.LIST.size():
		var e: Array = Islets.LIST[i]
		var c: Vector2 = e[0]
		if e[3] == "lagoon":
			var pad := LandingPads.lagoon_pad(c, (-c).angle(), MermaidLagoon.RING_RADIUS)
			sites.append(["mermaid lagoon", pad[0].x, pad[0].y])
		elif e[3] == "mermaid":
			sites.append(["mermaid cove %d" % i, c.x + e[1] * 0.3, c.y + e[1] * 0.3])  # beside the big rocks
		else:
			sites.append(["islet %d (%s)" % [i, e[3]], c.x, c.y])
	var failed: Array[String] = []
	for s in sites:
		_crashes = 0
		await _approach(Vector2(s[1], s[2]), -1.0, -1.0)
		var ok_land: bool = _plane.mode == Aircraft.Mode.PARKED and _crashes == 0
		_plane.input.override_stick = Vector2.ZERO
		_plane.input.override_throttle = 0.0
		await _frames(20)
		# Take off back the way it came (a player steers clear of hills).
		_plane.heading = wrapf(_plane.heading + PI, -PI, PI)
		_plane.rotation.y = _plane.heading
		_plane.input.override_throttle = 1.0
		var up := await _until(func(): return _plane.mode == Aircraft.Mode.FLYING, 900)
		_plane.input.override_stick = Vector2(0, 0.5)
		await _frames(150)
		var ok_off: bool = up and _crashes == 0
		if not (ok_land and ok_off):
			failed.append("%s (%s)" % [s[0], "landing" if not ok_land else "take-off"])
	_check("lands and takes off again at all %d sites" % sites.size(), failed.is_empty())
	if not failed.is_empty():
		print("  failed: ", ", ".join(failed))
	# --- the jet (lower and faster) ----------------------------------------------
	_plane.set_stats(AircraftCatalog.get_stats("jet"))
	_crashes = 0
	await _approach(site, -1.0, -1.0)
	var jet_g := _ground(_plane.global_position)
	_check("the jet lands and parks too", _plane.mode == Aircraft.Mode.PARKED and _crashes == 0 and absf(_plane.global_position.y - jet_g - _plane.stats.ground_offset) < 0.05)
	_plane.input.override_stick = Vector2.ZERO
	_plane.input.override_throttle = 0.0
	await _frames(20)
	_plane.input.override_throttle = 1.0
	_check("the jet takes off again", await _until(func(): return _plane.mode == Aircraft.Mode.FLYING, 900) and _crashes == 0)
	_plane.set_stats(AircraftCatalog.get_stats(AircraftCatalog.DEFAULT_ID))
	# --- can't-crash mode ------------------------------------------------------
	SaveManager.set_crashes(false)
	_crashes = 0
	await _fly_at(Vector3(1200, 0, 40), 30.0, Vector2(0, -1), 0.0)
	var min_clear := INF
	for i in 360:
		_plane.input.override_enabled = true
		await get_tree().physics_frame
		min_clear = minf(min_clear, _plane.global_position.y - _ground(_plane.global_position))
	_check("crashes off: still won't touch the ground on its own", _plane.mode == Aircraft.Mode.FLYING and min_clear > _plane.stats.min_clearance - 0.6)
	await _approach(site, -1.0, -1.0)
	_check("crashes off: holding slow lets it land", _plane.mode == Aircraft.Mode.PARKED and _crashes == 0)
	# --- child-style approaches (both modes) -----------------------------------------
	var child_sites := [["runway", Vector2(-300, 0), -PI / 2.0], ["main island meadow", Vector2(1200, 40), 0.0],
		["dino meadow (from the sea)", Vector2(2650, 2080), -3.0 * PI / 4.0], ["town island", Vector2(-3060, 580), 0.0], ["ice island", Vector2(620, -3280), 0.0]]
	for crash_mode in [true, false]:
		var bad: Array[String] = []
		for s in child_sites:
			if not await _child_lands(s[1], s[2], crash_mode):
				bad.append(s[0])
		_check("child-style approach (nose down, boost held, no slow) lands with crashes %s" % ("on" if crash_mode else "off"),
				bad.is_empty())
		if not bad.is_empty():
			print("  didn't land: ", ", ".join(bad))
	SaveManager.set_crashes(true)


## Fly a gentle approach to `site` (holding slow, nose down a little), then
## hold `roll_throttle` after touchdown. Waits for it to park (or crash).
## Returns the roll-out distance (m).
func _approach(site: Vector2, roll_throttle: float, approach_throttle: float, hold_stick := false) -> float:
	# Start 60 m short, 12 m above the landing spot (islet tops are high).
	var from := Vector3(site.x, 0, site.y + 60.0)
	var height := _ground(Vector3(site.x, 0, site.y)) + 12.0 - maxf(_ground(from), 0.0)
	await _fly_at(from, height, Vector2(0, -0.4), approach_throttle)
	var start_crashes := _crashes
	await _until(func(): return _plane.mode != Aircraft.Mode.FLYING or _crashes > start_crashes, 900)
	var touch := _plane.global_position
	if not hold_stick:
		_plane.input.override_stick = Vector2.ZERO
	_plane.input.override_throttle = roll_throttle
	await _until(func(): return _plane.mode == Aircraft.Mode.PARKED or _crashes > start_crashes, 1500)
	return touch.distance_to(_plane.global_position)


## Come in like a 4-year-old towards `at` (x, z) heading `yaw`: from 90 m
## short and 35 m up, nose down and boost held the whole time (through the
## roll too), never slow. True if it touched down and parked with no crash.
func _child_lands(at: Vector2, yaw: float, crash_mode: bool) -> bool:
	SaveManager.set_crashes(crash_mode)
	var start := _crashes
	var touched := [false]
	var on_touch := func(): touched[0] = true
	_plane.touched_down.connect(on_touch)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var from := Vector3(at.x, 0.0, at.y) - fwd * 90.0
	var gy := _ground(Vector3(at.x, 0.0, at.y))
	_plane.speed = _plane.stats.cruise_speed * 1.3
	_plane.teleport(Vector3(from.x, gy + 35.0, from.z), yaw)
	_plane._grace = 0.0
	await _frames(2)
	_plane.input.override_stick = Vector2(0, -0.6)
	_plane.input.override_throttle = 1.0
	await _until(func(): return touched[0] or _crashes > start, 900)
	await _until(func(): return _plane.mode == Aircraft.Mode.PARKED or _crashes > start, 1500)
	var ok: bool = touched[0] and _crashes == start and _plane.mode == Aircraft.Mode.PARKED
	_plane.touched_down.disconnect(on_touch)
	_plane.input.override_stick = Vector2.ZERO
	_plane.input.override_throttle = 0.0
	if _crashes > start:
		await _until(func(): return _plane.mode == Aircraft.Mode.PARKED, 600)
	await _frames(20)
	return ok


## Put the plane `height` m above the ground at `at` (x, z), heading north.
func _fly_at(at: Vector3, height: float, stick: Vector2, throttle: float) -> void:
	_plane.input.override_stick = stick
	_plane.input.override_throttle = throttle
	_plane.speed = _plane.stats.cruise_speed * (0.65 if throttle < 0.0 else 1.0)
	_plane.teleport(Vector3(at.x, maxf(_ground(at), 0.0) + height, at.z), 0.0)
	_plane._grace = 0.0
	# Leaving LANDED resets the override inputs once: wait, then set ours.
	await _frames(2)
	_plane.input.override_stick = stick
	_plane.input.override_throttle = throttle


## Fly at the ground there with this input: true if it ends in a crash.
func _bumps(at: Vector3, stick: Vector2, throttle: float, height: float) -> bool:
	var start := _crashes
	await _fly_at(at + Vector3(0, 0, 40), height, stick, throttle)
	await _until(func(): return _crashes > start or _plane.mode == Aircraft.Mode.PARKED, 900)
	var bumped := _crashes > start
	# Let the game put it back on the runway before the next case.
	await _until(func(): return _plane.mode == Aircraft.Mode.PARKED, 600)
	await _frames(10)
	return bumped


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 800, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	q.exclude = [_plane.get_rid()]
	var hit := _plane.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -INF


## (State changes hand the controls back to the real gamepad: keep ours.)
func _frames(n: int) -> void:
	for i in n:
		_plane.input.override_enabled = true
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		_plane.input.override_enabled = true
		await get_tree().physics_frame
	return cond.call()


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
