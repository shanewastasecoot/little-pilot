extends Node
## Sky-writing (Phase 14):
##   RB        holding RB while flying leaves puffs of smoke in the plane's
##             paint colour; letting go stops it; not on the ground
##   lingers   the smoke stays about a minute, then it's gone
##   cheap     all of it is one draw (a MultiMesh), however long the trail
## Exit code 0 = pass, 1 = fail.

var _fails := 0


func _ready() -> void:
	SaveManager.use_path("user://test_skywriting.cfg")
	SaveManager.dragon = false
	SaveManager.crashes = false
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	await _frames(10)
	var sw: SkyWriter = main.sky_writer
	var plane: Aircraft = main.aircraft
	# On the ground: nothing.
	Input.action_press("tab_next")
	await _frames(30)
	var ground_none := sw.puffs() == 0
	Input.action_release("tab_next")
	# Flying, RB held.
	main._enter(main.State.FLYING)
	plane.teleport(Vector3(0, 120, 300), 0.0)
	await _frames(5)
	Input.action_press("tab_next")
	await _frames(120)
	Input.action_release("tab_next")
	var made := sw.puffs()
	await _frames(60)
	var after := sw.puffs()
	var c: Color = sw._colour[0]
	var paint := Paint.color(SaveManager.get_paint(plane.stats.id, plane.stats.default_paint)).lightened(0.25)
	_check("holding RB while flying writes smoke in the paint colour (%d puffs); letting go stops; not on the ground" % made,
			ground_none and made > 20 and after == made and c.is_equal_approx(paint))
	sw.age(30.0)
	var half := sw.puffs()
	sw.age(31.0)
	_check("the smoke lingers about a minute, then it's gone", half == made and sw.puffs() == 0)
	_check("all of it is one MultiMesh", sw.find_children("*", "MultiMeshInstance3D", true, false).size() == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_skywriting.cfg"))
	print("\nSKYWRITING TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
