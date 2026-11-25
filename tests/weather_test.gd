extends Node
## Gentle weather (Phase 14): a rain cloud that washes the paint off, then a
## rainbow that brings it back. No thunder.
##   cloud    a soft rain cloud comes along while she plays: it drifts slowly,
##            rains (and hisses quietly), well above the ground
##   wash     flying under it washes the plane's paint off (plain white), but
##            her chosen colour is kept
##   rainbow  then a rainbow appears just ahead; flying through it brings the
##            colour back
##   fades    not flying through it: the colour comes back when it fades
##   walking  on foot under the rain nothing is washed
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_weather.cfg"
var _fails := 0
var _main: Node
var _plane: Aircraft
var _w: Weather


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	SaveManager.set_paint("prop", 1)  # blue
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_plane = _main.aircraft
	_w = _main.weather
	_main._enter(_main.State.FLYING)
	await _fly(Vector3(-200, 110, 300))
	# --- cloud ------------------------------------------------------------------------
	_w.countdown = 0.5
	await _until(func(): return _w.cloud != null, 120)
	await _frames(int(Weather.FADE * 60) + 10)
	var c0 := _w.cloud.global_position
	await _frames(60)
	var moved := _w.cloud.global_position.distance_to(c0)
	var above := c0.y - maxf(DeliveryManager.ground_at(c0.x, c0.z), 0.0)
	print("  note: cloud %.0f m above the ground, drifted %.1f m in 1 s" % [above, moved])
	_check("a soft rain cloud comes along: drifting slowly, raining (with a quiet hiss), well above the ground",
			_w.rain.emitting and moved > 2.0 and moved < 8.0 and above >= Weather.CLOUD_ABOVE - 1.0 and _w._sound.playing)
	# --- walking -------------------------------------------------------------------------
	var cpos := _w.cloud.global_position
	_main._enter(_main.State.ON_FOOT)
	_main.walker.place(Vector3(cpos.x, DeliveryManager.ground_at(cpos.x, cpos.z) + 0.2, cpos.z), 0.0)
	await _frames(30)
	_check("on foot under the rain nothing is washed", not _w.washed)
	_main._enter(_main.State.FLYING)
	# --- wash ------------------------------------------------------------------------------
	var saved_paint := SaveManager.get_paint("prop", 0)
	cpos = _w.cloud.global_position
	await _fly(Vector3(cpos.x, cpos.y - 50.0, cpos.z))
	await _until(func(): return _w.washed, 60)
	var colour: Color = _plane.visuals.recolor.to_color
	_check("flying under it washes the paint off (plain white); her colour is kept", _w.washed
			and colour.is_equal_approx(Weather.WASHED) and SaveManager.get_paint("prop", 0) == saved_paint)
	# --- rainbow -----------------------------------------------------------------------------
	var rb: Node3D = _w.rainbow
	var ahead := rb != null and (rb.global_position - _plane.global_position).dot(Vector3(-sin(_plane.heading), 0, -cos(_plane.heading))) > 100.0
	await _frames(130)  # (it grows in)
	# Fly straight through its middle.
	var through := rb.to_global(Vector3(0, _w.rainbow_radius * 0.5, 40))
	for i in 160:
		_plane.global_position = through + Vector3(-sin(rb.rotation.y), 0, -cos(rb.rotation.y)) * (i * 0.6)
		await get_tree().physics_frame
		if not _w.washed:
			break
	var back: Color = _plane.visuals.recolor.to_color
	print("  note: rainbow %.0f m across, ahead of her %s; colour after: %s" % [_w.rainbow_radius * 2.0, ahead, back.to_html(false)])
	_check("then a rainbow appears ahead; flying through it brings the colour back", ahead and not _w.washed
			and back.is_equal_approx(Paint.color(saved_paint)))
	# --- fades ------------------------------------------------------------------------------
	_w._washed_this_cloud = false
	cpos = _w.cloud.global_position
	await _fly(Vector3(cpos.x, cpos.y - 50.0, cpos.z))
	await _until(func(): return _w.washed, 60)
	_plane.global_position = _w.rainbow.global_position + Vector3(900, 120, 0)  # (nowhere near it)
	_w._rainbow_age = Weather.RAINBOW_TIME - 0.2
	await _frames(30)
	_check("not flying through it: the colour comes back when it fades", not _w.washed
			and (_plane.visuals.recolor.to_color as Color).is_equal_approx(Paint.color(saved_paint)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nWEATHER TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _fly(p: Vector3) -> void:
	_plane.speed = _plane.stats.cruise_speed
	_plane.teleport(p, 0.0)
	await _frames(2)
	_plane.teleport(p, 0.0)
	_plane.input.override_enabled = true
	_plane.input.override_stick = Vector2.ZERO


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
