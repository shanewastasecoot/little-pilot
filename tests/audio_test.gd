extends Node
## Audio (Phase 12):
##   honks     each aircraft has its own horn, a little higher or lower each
##             time
##   fallback  every sound still has its made-in-code version (a real file in
##             assets/audio/ would replace it under the same name)
##   ambient   quiet sounds of places: birds at the farm, the city's murmur,
##             wind in the forest, the volcano's rumble, drips and snoring in
##             the cave, waves at the shore; heard only nearby, looping
## Exit code 0 = pass, 1 = fail.

var _fails := 0


func _ready() -> void:
	SaveManager.use_path("user://test_audio.cfg")
	SaveManager.dragon = false
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	await _frames(10)
	main._enter(main.State.FLYING)
	var plane: Aircraft = main.aircraft
	# Honks.
	var prop := AircraftCatalog.get_stats("prop")
	var jet := AircraftCatalog.get_stats("jet")
	_check("each aircraft has its own horn", prop.honk_sound != jet.honk_sound and Sfx._streams.has(prop.honk_sound) and Sfx._streams.has(jet.honk_sound))
	var pitches: Array[float] = []
	for i in 6:
		plane.input.honk_pressed.emit()
		await _frames(2)
		pitches.append(_last_pitch())
	var differ := false
	for p in pitches:
		differ = differ or absf(p - pitches[0]) > 0.001
	var in_range := pitches.all(func(p): return p > prop.honk_pitch * 0.95 and p < prop.honk_pitch * 1.05)
	_check("a little higher or lower each time (within 5 percent)", differ and in_range)
	# Fallback.
	var names := ["chime", "honk", "pop", "whoosh", "splash", "moo", "chirp", "toot", "rawr", "roar", "honk_prop", "honk_jet"]
	_check("every sound has its made-in-code version (files would replace them by name)",
			names.all(func(n): return Sfx._streams.has(n)) and Sfx._file_for("res://assets/audio/no_such_sound") == null)
	# Ambient zones.
	var zones := main.find_children("Ambient_*", "", true, false)
	var kinds := {}
	var ok := true
	for z in zones:
		var a := z as AmbientZone
		kinds[String(a.name).trim_prefix("Ambient_").split("@")[0]] = true
		var wav := a.stream as AudioStreamWAV
		if a.volume_db > -8.0 or a.max_distance > 800.0 or not a.autoplay or (wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED):
			ok = false
	print("  note: %d zones: %s" % [zones.size(), kinds.keys()])
	_check("quiet, nearby, looping sounds of places: birds, city, wind, volcano, cave, waves", ok
			and kinds.has("birds") and kinds.has("city") and kinds.has("wind") and kinds.has("rumble") and kinds.has("cave") and kinds.has("waves"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_audio.cfg"))
	print("\nAUDIO TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


## The pitch of the voice Sfx used last.
func _last_pitch() -> float:
	var i := posmod(Sfx._next - 1, Sfx.VOICES)
	return (Sfx._players[i] as AudioStreamPlayer).pitch_scale


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
