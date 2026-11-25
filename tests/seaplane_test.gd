extends Node
## Seaplane (Phase 14): a plane with floats lands on, taxis on and takes off
## from the open sea, reusing the flight controller and the waves.
##   catalog   the Seaplane is in the hangar, with floats; the others have none
##   landing   coming down onto open sea (crashes on) is a landing, not a
##             crash: it slows on the water and parks, bobbing on the waves
##   gentle    the same in can't-crash mode (slowing down low over the sea)
##   afloat    out at sea there's nowhere to stand: she stays in
##   takeoff   boost: it speeds across the water and lifts off ("water")
##   shore     taxiing at a beach it stops in the water, never runs aground
##   others    the prop plane still splashes into the sea (crash), as before
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_seaplane.cfg"
var _fails := 0
var _main: Node
var _plane: Aircraft
var _crashed := 0
var _sea := Vector3.ZERO


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_plane = _main.aircraft
	_plane.crashed.connect(func(_w, _water): _crashed += 1)
	# --- catalog ---------------------------------------------------------------------
	var sea_stats := AircraftCatalog.get_stats("seaplane")
	var model: Node = sea_stats.model_scene.instantiate()
	var has_floats := model.find_child("Floats", true, false) != null
	model.free()
	_check("the Seaplane is in the hangar, with floats; the others have none", AircraftCatalog.has("seaplane")
			and sea_stats.floats and has_floats and sea_stats.display_name == "Seaplane"
			and not AircraftCatalog.get_stats("prop").floats and not AircraftCatalog.get_stats("jet").floats)
	# Somewhere well out at sea.
	for c in [Vector2(1100, -1500), Vector2(-1300, 1900), Vector2(1600, 1500), Vector2(-2400, -400)]:
		var deep := true
		for dx in [-400, 0, 400]:
			for dz in [-400, 0, 400]:
				deep = deep and DeliveryManager.ground_at(c.x + dx, c.y + dz) < -12.0
		if deep:
			_sea = Vector3(c.x, 0, c.y)
			break
	print("  note: open sea at ", _sea)
	# --- landing (crashes on) ------------------------------------------------------------
	_main._enter(_main.State.FLYING)
	_plane.set_stats(sea_stats)
	_plane.crashes = true
	var landed := await _come_down()
	var parked_ok: bool = _plane.mode == Aircraft.Mode.PARKED and _plane.on_water()
	# Bobbing: stays on the surface as the waves move.
	var worst := 0.0
	var spot := _plane.global_position
	for i in 90:
		await get_tree().physics_frame
		var p := _plane.global_position
		worst = maxf(worst, absf(p.y - (Waves.height(p.x, p.z) + sea_stats.ground_offset * Aircraft.FLOAT_RIDE)))
	var stayed := Vector2(spot.x - _plane.global_position.x, spot.z - _plane.global_position.z).length() < 0.5
	print("  note: landed %s, parked on the water %s, crashes %d, off the surface by %.2f m" % [landed, parked_ok, _crashed, worst])
	_check("coming down onto open sea is a landing, not a crash: it parks, bobbing on the waves", landed and parked_ok
			and _crashed == 0 and worst < 0.3 and stayed)
	# --- afloat --------------------------------------------------------------------------
	var could_exit: bool = _main._can_exit_plane()
	var got_out: bool = _main.toggle_plane()
	_check("out at sea there's nowhere to stand: she stays in", not could_exit and not got_out and _main.state != _main.State.ON_FOOT)
	# --- takeoff -------------------------------------------------------------------------
	var surface := [""]
	WorldEvents.happened.connect(func(k, _w, info): if k == "takeoff": surface[0] = info.get("surface", ""))
	await _frames(2)
	_plane.input.override_enabled = true  # (parking switched to LANDED: take the controls again)
	_plane.input.override_throttle = 1.0
	var off := await _until(func(): return _plane.mode == Aircraft.Mode.FLYING, 600)
	await _frames(120)
	_plane.input.override_throttle = 0.0
	var height := _plane.global_position.y - Waves.height(_plane.global_position.x, _plane.global_position.z)
	print("  note: took off %s from '%s', now %.0f m up" % [off, surface[0], height])
	_check("boost: it speeds across the water and lifts off", off and surface[0] == "water" and height > 6.0 and _crashed == 0)
	# --- gentle (can't-crash mode) --------------------------------------------------------
	_plane.crashes = false
	SaveManager.crashes = false
	var gentle := await _come_down()
	_check("in can't-crash mode, slowing down low over the sea lands on it too", gentle and _plane.on_water())
	# --- shore ---------------------------------------------------------------------------
	# Skimming in at speed (just landed) towards Palm Island's beach.
	var dock: Dock = _main.docks[1]
	var out := -dock.global_basis.z
	var start := dock.global_position + out * 110.0 - dock.global_basis.x * 50.0
	_plane.teleport(Vector3(start.x, 3.0, start.z), atan2(out.x, out.z))
	_plane.set("_on_water", true)
	_plane.set("_landing", true)
	_plane.mode = Aircraft.Mode.ROLLING
	_plane.speed = 22.0
	var shallowest := -999.0
	for i in 600:
		await get_tree().physics_frame
		var p := _plane.global_position
		shallowest = maxf(shallowest, DeliveryManager.ground_at(p.x, p.z))
		if _plane.mode == Aircraft.Mode.PARKED:
			break
	print("  note: shore: shallowest under the plane %.1f m, parked %s" % [shallowest, _plane.mode == Aircraft.Mode.PARKED])
	_check("taxiing at a beach it stops in the water, never runs aground", shallowest < -1.0 and _plane.mode == Aircraft.Mode.PARKED and _plane.on_water())
	# --- others ----------------------------------------------------------------------------
	_plane.set_stats(AircraftCatalog.get_stats("prop"))
	_plane.crashes = true
	SaveManager.crashes = true
	_crashed = 0
	_plane.speed = _plane.stats.cruise_speed
	_plane.teleport(_sea + Vector3(0, 25, 0), 0.0)
	await _frames(2)
	_plane.teleport(_sea + Vector3(0, 25, 0), 0.0)
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2(0, -1)
	await _until(func(): return _crashed > 0, 600)
	_plane.input.override_stick = Vector2.ZERO
	_check("the prop plane still splashes into the sea, as before", _crashed > 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nSEAPLANE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


## Fly low over open sea, nose a little down and throttle back: true once
## it's parked on the water.
func _come_down() -> bool:
	_plane.speed = _plane.stats.cruise_speed
	_plane.teleport(_sea + Vector3(0, 22, 0), 0.0)
	await _frames(2)  # (the game goes back to FLYING, which resets the controls)
	_plane.teleport(_sea + Vector3(0, 22, 0), 0.0)
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2(0, -0.4)
	_plane.input.override_throttle = -1.0
	var ok := await _until(func(): return _plane.mode == Aircraft.Mode.PARKED and _plane.on_water(), 1500)
	_plane.input.override_stick = Vector2.ZERO
	_plane.input.override_throttle = 0.0
	await _frames(20)
	return ok


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
