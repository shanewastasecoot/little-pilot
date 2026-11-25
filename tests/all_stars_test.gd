extends Node
## All-stars reward (Phase 14): every floating star she's ever found is
## remembered; finding the last new one changes the world for good: the
## rainbow sparkles for ever and flying through it sets off fireworks.
##   remember  each star she picks up is saved (across sessions)
##   before    until then the rainbow is the usual rainbow (no show)
##   unlock    the last new star unlocks it once, saved; the rainbow sparkles
##   show      flying through the sparkling rainbow sets off fireworks
##   forever   next time she plays it's still sparkling
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_all_stars.cfg"
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	await _frames(15)
	main._enter(main.State.FLYING)
	var stars: Array = get_tree().get_nodes_in_group("stars")
	var rainbow: RainbowArch
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l is RainbowArch:
			rainbow = l
	print("  note: %d stars in the world" % stars.size())
	# --- remember ---------------------------------------------------------------------
	var first: Star = stars[0]
	main.aircraft.teleport(first.global_position, 0.0)
	await _until(func(): return first.is_collected, 120)
	var remembered := SaveManager.stars_found.has(first.key)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("each star she picks up is remembered, across sessions", first.is_collected and remembered
			and SaveManager.stars_found.has(first.key) and main.stars.found_count() == 1)
	# --- before ------------------------------------------------------------------------
	main.aircraft.teleport(rainbow.global_position + Vector3(-60, 70, 0), PI * 0.5)
	await _frames(2)
	rainbow._on_body_entered(main.aircraft)
	await _frames(5)
	_check("until then the rainbow is the usual rainbow (no sparkles, no show)", not rainbow.golden
			and rainbow.show_fireworks == null and not SaveManager.all_stars)
	# --- unlock --------------------------------------------------------------------------
	var unlocked := [0]
	main.stars.every_star_found.connect(func(): unlocked[0] += 1)
	# (All but the last already found, as if over many days.)
	var last: Star = stars[stars.size() - 1]
	for s in stars:
		if s != last:
			SaveManager.star_found(s.key)
	var before := SaveManager.all_stars
	main.aircraft.teleport(last.global_position, 0.0)
	await _until(func(): return last.is_collected, 120)
	await _frames(3)
	# A star found again (already known) doesn't unlock it twice.
	main.stars._on_star_collected(first)
	await _frames(2)
	var sparkles := rainbow.find_child("Sparkles", false, false) as CPUParticles3D
	_check("the last new star unlocks it (once, saved), and the rainbow sparkles", not before and SaveManager.all_stars
			and unlocked[0] == 1 and rainbow.golden and sparkles != null and sparkles.emitting and sparkles.amount == 220)
	# --- show ---------------------------------------------------------------------------
	rainbow._cooldown = 0.0
	main.aircraft.teleport(rainbow.global_position + Vector3(-60, 70, 0), PI * 0.5)
	await _frames(2)
	rainbow._on_body_entered(main.aircraft)
	await _frames(5)
	_check("flying through the sparkling rainbow sets off fireworks", rainbow.show_fireworks != null and rainbow.show_fireworks.running)
	# --- forever -------------------------------------------------------------------------
	SaveManager.save_now()
	main.queue_free()
	await _frames(5)
	SaveManager.use_path(PATH)
	var again: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(again)
	again.title.hide()
	await _frames(15)
	var rainbow2: RainbowArch
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l is RainbowArch and is_instance_valid(l) and not l.is_queued_for_deletion():
			rainbow2 = l
	_check("next time she plays it's still sparkling", SaveManager.all_stars and rainbow2 != null and rainbow2.golden
			and rainbow2.find_child("Sparkles", false, false) != null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nALL STARS TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


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
