extends Node
## Follow-the-leader (Phase 14): a friendly plane invites her to follow it on
## a loose loop. No timer, no penalty.
##   invite    only while flying freely (never on foot); it pulls up just
##             ahead of her and toots
##   follow    following it round the whole loop ends in a show and bonus
##             stars; it stays well above the ground all the way
##   wait      when she falls far behind it circles near its path and waits
##             (it doesn't fly on without her); nothing is taken away
##   ignore    left far behind for a while, it waggles goodbye and leaves,
##             and comes back another time
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_follow.cfg"
var _fails := 0
var _main: Node
var _plane: Aircraft
var _leader: FollowLeader


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_plane = _main.aircraft
	_leader = _main.leader
	# --- invite ------------------------------------------------------------------------
	_main._enter(_main.State.ON_FOOT)
	_leader.countdown = 0.5
	await _frames(120)
	var not_on_foot := _leader.state == FollowLeader.S.AWAY
	_main._enter(_main.State.FLYING)
	_plane.speed = _plane.stats.cruise_speed
	_plane.teleport(Vector3(-100, 120, 250), 0.0)
	await _frames(2)
	_plane.teleport(Vector3(-100, 120, 250), 0.0)
	_plane.input.override_enabled = true
	await _until(func(): return _leader.state != FollowLeader.S.AWAY, 120)
	var d := _leader.global_position.distance_to(_plane.global_position)
	var ahead := (_leader.global_position - _plane.global_position).dot(Vector3(-sin(_plane.heading), 0, -cos(_plane.heading))) > 50.0
	print("  note: invited on the %s loop (%.0f m long), %.0f m from her" % [_leader.route, _leader.length, d])
	_check("it only invites while she's flying freely, and pulls up just ahead of her", not_on_foot
			and _leader.state == FollowLeader.S.INVITE and _leader.visible and d < 200.0 and ahead)
	# --- follow ------------------------------------------------------------------------
	var stars0 := SaveManager.lifetime_stars
	var done := [false]
	_leader.finished.connect(func(_r): done[0] = true, CONNECT_ONE_SHOT)
	var lowest := INF
	var fastest := 0.0
	var frames := 0
	var before_end := [SaveManager.lifetime_stars]  # (an array: the lambda sees it change)
	var bonus := [0]
	_leader.finished.connect(func(_r): bonus[0] = SaveManager.lifetime_stars - before_end[0], CONNECT_ONE_SHOT)
	while not done[0] and frames < 60 * 600:
		before_end[0] = SaveManager.lifetime_stars  # (she picks up stars on the way too)
		await get_tree().physics_frame
		frames += 1
		# She flies along 60 m behind it.
		var back := Vector3(sin(_leader.rotation.y), 0, cos(_leader.rotation.y)) * 60.0
		_plane.global_position = _leader.global_position + back
		if _leader.state == FollowLeader.S.LEAD:
			var p := _leader.global_position
			lowest = minf(lowest, p.y - DeliveryManager.ground_at(p.x, p.z))
			fastest = maxf(fastest, _leader.speed)
	print("  note: followed the loop in %.0f s, lowest %.0f m above the ground, fastest %.0f m/s, stars %d -> %d (bonus %d)" % [frames / 60.0, lowest, fastest, stars0, SaveManager.lifetime_stars, bonus[0]])
	_check("following it round the whole loop: a show and bonus stars", done[0] and bonus[0] == FollowLeader.REWARD_STARS)
	_check("it stays well above the ground all the way, at a gentle pace", lowest > FollowLeader.CLEARANCE * 0.6 and fastest <= FollowLeader.FAST + 0.1)
	await _until(func(): return _leader.state == FollowLeader.S.AWAY, 900)
	# --- wait ----------------------------------------------------------------------------
	_leader.invite("farm")
	await _frames(int(FollowLeader.WAGGLE_TIME * 60) + 5)
	# Follow for a bit...
	for i in 300:
		_plane.global_position = _leader.global_position + Vector3(sin(_leader.rotation.y), 0, cos(_leader.rotation.y)) * 60.0
		await get_tree().physics_frame
	var p0 := _leader.progress
	# ...then fall far behind.
	var far_spot := _leader.global_position + Vector3(900, 0, 0)
	var stars1 := SaveManager.lifetime_stars
	var max_off := 0.0
	for i in 600:
		_plane.global_position = far_spot
		await get_tree().physics_frame
		max_off = maxf(max_off, _leader.global_position.distance_to(_leader._curve.sample_baked(_leader.progress, true)))
	var crept := _leader.progress - p0
	print("  note: while she was far behind it went on %.0f m along the loop, at most %.0f m off it; state %d" % [crept, max_off, _leader.state])
	_check("when she falls far behind it circles near its path and waits; nothing is taken away", crept < 80.0
			and max_off < FollowLeader.CIRCLE_RADIUS + 5.0 and _leader.state == FollowLeader.S.LEAD and SaveManager.lifetime_stars == stars1)
	_leader.leave()
	await _until(func(): return _leader.state == FollowLeader.S.AWAY, 900)
	# --- ignore --------------------------------------------------------------------------
	_leader.invite("valley")
	var gone := false
	for i in int((FollowLeader.GIVE_UP + FollowLeader.WAGGLE_TIME + 10.0) * 60):
		_plane.global_position = _leader.global_position + Vector3(2000, 0, 0)  # (she flies off elsewhere)
		await get_tree().physics_frame
		if _leader.state == FollowLeader.S.LEAVING:
			gone = true
			break
	await _until(func(): return _leader.state == FollowLeader.S.AWAY, 900)
	_check("left far behind for a while, it waggles goodbye and leaves, and comes back another time", gone
			and _leader.state == FollowLeader.S.AWAY and not _leader.visible and _leader.countdown > 0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nFOLLOW TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
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
