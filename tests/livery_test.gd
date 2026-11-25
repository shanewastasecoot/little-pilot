extends Node
## Liveries (Phase 13):
##   earned    decals are earned at 50, 100, 150 and 220 lifetime stars; one
##             not earned yet can't be worn; the stripe and "none" always can
##   trim      the trim colours are never locked and go round all eight
##   shown     the decal and trim show on the plane, in the trim colour
##   select    on the plane-select screen X changes the trim, RB / LB the
##             decal (skipping ones not earned yet)
##   saved     saved, and a bad saved value is ignored
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_livery.cfg"
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.lifetime_stars = 10
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	await _frames(10)
	# Earned at milestones.
	var early := SaveManager.set_decal("prop", "stripe") and not SaveManager.set_decal("prop", "checker")
	SaveManager.lifetime_stars = 50
	var at50 := SaveManager.set_decal("prop", "checker") and not SaveManager.set_decal("prop", "rescue")
	SaveManager.lifetime_stars = 220
	var all := Livery.DECALS.all(func(d): return Livery.unlocked(d))
	_check("decals are earned with stars (stripe always; checker at 50; all by 220)", early and at50 and all)
	# Trim: never locked, all eight.
	SaveManager.lifetime_stars = 0
	var seen := {}
	for i in Paint.COLORS.size():
		SaveManager.set_trim("jet", i)
		seen[SaveManager.get_trim("jet")] = true
	_check("the trim colours are never locked and go round all eight", seen.size() == Paint.COLORS.size())
	# Shown on the plane.
	SaveManager.lifetime_stars = 220
	SaveManager.set_decal("prop", "letters")
	SaveManager.set_trim("prop", 2)
	await _frames(3)
	var plane: Aircraft = main.aircraft
	var lv: Livery = plane.visuals.livery
	var label := lv.find_children("*", "Label3D", true, false)
	_check("the decal shows on the plane, in the trim colour", lv.pieces() > 0 and not label.is_empty()
			and (label[0] as Label3D).modulate.is_equal_approx(Paint.color(2)))
	# Plane select: X and RB.
	SaveManager.lifetime_stars = 60  # stripe, checker earned; rescue not
	SaveManager.set_decal("prop", "stripe")
	var ps: PlaneSelect = main.plane_select
	ps.open("prop", false)
	await _frames(5)
	var trim0 := SaveManager.get_trim("prop")
	_press("trick")
	await _frames(3)
	var trim_moved := SaveManager.get_trim("prop") == posmod(trim0 + 1, Paint.COLORS.size())
	_press("tab_next")
	await _frames(3)
	var first := SaveManager.get_decal("prop")
	_press("tab_next")
	await _frames(3)
	var second := SaveManager.get_decal("prop")
	_check("plane select: X changes the trim, RB the decal, skipping ones not earned (stripe -> checker -> none)",
			trim_moved and first == "checker" and second == "none")
	ps.hide()
	# Saved, and bad values ignored.
	SaveManager.set_decal("prop", "checker")
	SaveManager.save_now()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("livery", "decals", {"prop": "checker", "jet": "flames_of_doom"})
	cfg.set_value("livery", "trims", {"prop": 5, "jet": "red"})
	cfg.save(PATH)
	SaveManager.use_path(PATH)
	_check("saved; a bad saved value is ignored", SaveManager.get_decal("prop") == "checker" and SaveManager.get_decal("jet") == "none"
			and SaveManager.get_trim("prop") == 5 and SaveManager.get_trim("jet") == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nLIVERY TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
