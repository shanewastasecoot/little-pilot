extends Node
## Sticker book and postcard camera (Phase 14):
##   pictures  a place near and on screen gets its picture by itself
##   postcard  LB takes a postcard (the HUD hidden for it); only the newest
##             48 are kept
##   book      every place, animal and friend has a card (a "?" until seen);
##             the book opens from the pause menu; LB / RB change tab
##   saved     which pictures she has is saved
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_book.cfg"
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
	var sp: Spotter = main.spotter
	var kinds := {}
	for t in sp.targets:
		kinds[t[1]] = int(kinds.get(t[1], 0)) + 1
	print("  note: targets ", kinds)
	_check("the book has places, animals and friends to find", int(kinds.get("place", 0)) >= 15
			and int(kinds.get("animal", 0)) >= 5 and int(kinds.get("friend", 0)) >= 5)
	# A picture by itself: fly at the farm.
	main._enter(main.State.FLYING)
	var plane: Aircraft = main.aircraft
	plane.input.override_enabled = true
	plane.teleport(Vector3(IslandShape.FARM.x, 60, IslandShape.FARM.y + 160), 0.0)
	main.chase_camera.snap_to_target()
	await _until(func(): return SaveManager.book_has("place:Farm"), 300)
	_check("flying at the farm puts its picture in the book", SaveManager.book_has("place:Farm"))
	# Postcards: LB, and only the newest 48 kept.
	var before := SaveManager.postcards.size()
	_press("tab_prev")
	await _until(func(): return SaveManager.postcards.size() > before, 120)
	var took := SaveManager.postcards.size() == before + 1
	for i in 50:
		SaveManager.add_postcard(SaveManager.next_postcard(), Spotter.MAX_POSTCARDS)
	_check("LB takes a postcard; only the newest 48 are kept", took and SaveManager.postcards.size() == Spotter.MAX_POSTCARDS)
	# The book.
	main.pause_menu.book_requested.emit()
	await _frames(5)
	var book: StickerBook = main.book
	var c := book.counts()
	var opened := book.visible and book.tab == 0 and c.x >= 15 and c.y >= 1
	_press("tab_next")
	await _frames(3)
	var tab_moved := book.tab == 1
	book.close()
	_check("the book opens from the pause menu: a card for every place (seen ones filled in); RB changes tab", opened and tab_moved)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("which pictures she has is saved", SaveManager.book_has("place:Farm") and SaveManager.postcards.size() == Spotter.MAX_POSTCARDS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nSTICKER BOOK TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
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
