extends Node
## The dragon's treasure (Phase 4.3):
##   a piece waits in front of the hoard only while the dragon is on
##   walking into it on foot takes it: one more on her shelf (saved), the
##   piece is gone until it refills, and only once she's left the cave
##   the dragon, asleep at home, wakes grumpy (roars, stomps, smoke) and
##   never hurts her on foot; when her plane takes off it comes out and
##   hunts it
##   her trophy shelf at home shows the pieces she's taken
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_treasure.cfg"

var _main: Node
var _w: Walker
var _plane: Aircraft
var _dragon: Dragon
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = true
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_w = _main.walker
	_plane = _main.get_node("Aircraft")
	_dragon = get_tree().get_first_node_in_group("dragon")
	_main.title.hide()
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nTREASURE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var tr: DragonTreasure = _dragon.lair.treasure
	var out := _dragon.lair.global_basis.z
	var hits := [0]
	_dragon.plane_hit.connect(func(_w2, _f): hits[0] += 1)
	# The plane parked outside the cave; on foot, a little way in front of the piece.
	_plane.park(tr.global_position + out * 260.0, 0.0)
	_main._enter(_main.State.FLYING)
	await _frames(3)
	_main.toggle_plane()
	await _frames(5)
	_w.place(tr.global_position + out * 20.0 + Vector3(0, 1, 0), 0.0)
	await _frames(40)
	_check("a piece of treasure waits in front of the sleeping dragon's hoard", tr.is_available() and _dragon.state == Dragon.State.SLEEP)
	SaveManager.dragon = false
	await _frames(40)
	var hidden_off := not tr.is_available()
	SaveManager.dragon = true
	await _frames(40)
	_check("only while the dragon is on", hidden_off and tr.is_available())
	# Walk into it.
	var before := SaveManager.treasures
	_w.place(tr.global_position + Vector3(0, 1, 0), 0.0)
	await _frames(30)
	_check("walking into it takes it: one more for her shelf, and the piece is gone",
			SaveManager.treasures == before + 1 and not tr.is_available())
	_check("the dragon wakes up grumpy (and angry with her plane)", _dragon.state == Dragon.State.GRUMPY and _dragon.angry)
	# It roars and stomps but never hurts her on foot.
	await _frames(60 * 5)
	_check("it roars and stomps but never hurts her on foot", _main.state == _main.State.ON_FOOT and hits[0] == 0
			and _dragon.state == Dragon.State.GRUMPY)
	# Saved.
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("the treasure is saved", SaveManager.treasures == before + 1)
	# One per visit: no new piece while she's still in the cave, even when it's due.
	SaveManager.treasure_ready_at = 0.0
	await _frames(60)
	var none_while_here := not tr.is_available()
	_w.place(tr.global_position + out * (DragonTreasure.AWAY + 60.0) + Vector3(0, 30, 0), 0.0)
	await _frames(60)
	_check("one piece per visit: a new one only once she's left the cave", none_while_here and tr.is_available())
	# Take off: it comes out and hunts the plane.
	_plane.teleport(_dragon.lair.global_position + out * 500.0 + Vector3(0, 120, 0), atan2(-out.x, -out.z))
	_main._enter(_main.State.FLYING)
	var hunted := false
	for i in 60 * 30:
		_plane.input.override_throttle = 0.0
		await get_tree().physics_frame
		if _dragon.state in [Dragon.State.HUNT, Dragon.State.BREATHE]:
			hunted = true
			break
	_check("when her plane takes off, the dragon comes out and hunts it", hunted)
	# Her shelf at home.
	SaveManager.treasures = 3
	_w.place(_main.house.doorstep() + Vector3(0, 0.5, 0), 0.0)
	if _main.state != _main.State.ON_FOOT:
		_main._enter(_main.State.ON_FOOT)
	await _frames(5)
	_main.enter_house()
	await _until(func(): return _main.state == _main.State.INDOORS, 240)
	await _frames(30)
	_check("her trophy shelf shows the treasure she's taken", _main.interior.trophy_shelf.shown() == 3)


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
