extends Node
## The airport service loop (Phase 13):
##   start     parking on the hangar's yellow pad starts it: the doors open
##   locked    Y doesn't get her out halfway through
##   inside    the plane rolls inside, is washed and fuelled (the gauge fills)
##   out       it comes back out onto the pad facing the runway, parked and
##             hers again; the doors shut after she's gone
##   again     it works every time
## Exit code 0 = pass, 1 = fail.

var _main: Node
var _fails := 0


func _ready() -> void:
	SaveManager.use_path("user://test_service.cfg")
	SaveManager.dragon = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(10)
	var hangar: Hangar = _main.find_children("*", "Hangar", true, false)[0]
	var svc: HangarService = hangar.service
	var plane: Aircraft = _main.aircraft
	_check("the hangar's doors start shut", not hangar.doors_open() and hangar.door_amount() < 0.01)
	for visit in 2:
		plane.park(svc.to_global(HangarService.PAD), hangar.global_rotation.y)
		_main._enter(_main.State.LANDED)
		var started := await _until(func(): return svc.busy, 120)
		await _frames(60)
		var opening := hangar.doors_open() and hangar.door_amount() > 0.3
		_main.toggle_plane()
		await _frames(5)
		var still_in: bool = _main.state == _main.State.LANDED
		_check("visit %d: parking on the pad starts the service, the doors open, Y can't get her out halfway" % (visit + 1),
				started and opening and still_in)
		var was_inside := false
		var full := false
		while svc.busy:
			await get_tree().physics_frame
			var l := hangar.to_local(plane.global_position)
			was_inside = was_inside or (absf(l.x) < 6.0 and l.z < 8.0)
			full = full or svc.fuel > 0.99
		var l2 := hangar.to_local(plane.global_position)
		var facing_out := -plane.global_transform.basis.z
		var hangar_out := hangar.global_transform.basis.z
		_check("visit %d: rolls inside, is washed and fuelled, comes back out onto the pad facing the runway, parked" % (visit + 1),
				was_inside and full and Vector2(l2.x, l2.z - HangarService.PAD.z).length() < 1.0 and facing_out.dot(hangar_out) > 0.95
				and plane.mode == Aircraft.Mode.PARKED and not plane.input.override_enabled and svc.count == visit + 1)
		# Off she goes: the doors shut behind her.
		plane.park(_main.map.runway_start(), _main.map.spawn_heading())
		await _until(func(): return not hangar.doors_open(), 200)
		await _frames(120)
		_check("visit %d: the doors shut after she's gone" % (visit + 1), not hangar.doors_open() and hangar.door_amount() < 0.05)
		await _frames(400)  # (the pad rests a moment between visits)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_service.cfg"))
	print("\nSERVICE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
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
