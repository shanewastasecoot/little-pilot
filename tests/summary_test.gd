extends Node
## Parent summary (Phase 14): today's stars, deliveries, crashes, time and
## islands are counted; a new day starts afresh; saved; the page opens from
## the pause menu and closes with B.
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_summary.cfg"
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	await _frames(10)
	SaveManager.add_lifetime_star()
	SaveManager.add_lifetime_star()
	SaveManager.add_delivery("farmer")
	WorldEvents.send("crash", Vector3.ZERO, {"water": false})
	SaveManager.add_playtime(0.5)
	main._enter(main.State.FLYING)
	main.aircraft.teleport(Vector3(IslandShape.PALM_ISLAND.x, 60, IslandShape.PALM_ISLAND.y), 0.0)
	await _frames(200)
	var t := SaveManager.today()
	print("  note: ", t)
	_check("today counts stars, deliveries, crashes, time and islands", int(t.stars) == 2 and int(t.deliveries) == 1
			and int(t.crashes) == 1 and float(t.seconds) > 0.4 and (t.islands as Array).has("palm"))
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("saved", int(SaveManager.today().stars) == 2)
	SaveManager.today_date = "2000-01-01"
	_check("a new day starts afresh", int(SaveManager.today().stars) == 0 and (SaveManager.today().islands as Array).is_empty())
	main.pause_menu.today_requested.emit()
	await _frames(3)
	var opened: bool = main.summary.visible
	main.summary.close()
	_check("the page opens from the pause menu and closes", opened and not main.summary.visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nSUMMARY TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
