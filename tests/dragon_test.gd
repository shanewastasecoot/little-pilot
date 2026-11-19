extends Node
## The dragon:
##   1. wakes   asleep in the cave; wakes, flies out and starts patrolling
##   2. hunts   a plane in plain sight nearby -> it notices and hunts
##   3. rams    flies into the plane -> the plane explodes, respawns parked
##              on the runway, and the dragon leaves it alone for a while
##   4. fire    plane in front of its fire breath -> explodes (by fire)
##   5. gentle  crashes off: ram again -> nothing happens
##   6. airport heading for the runway -> never enters the airport
##   7. off     dragon setting off -> hidden and idle
## Throughout: it never goes into the ground.
## Exit code 0 = pass, 1 = fail.

var _main: Node
var _plane: Aircraft
var _dragon: Dragon
var _step := 0
var _t := 0.0
var _hits: Array = []
var _min_clear := 9999.0
var _airport_min := 9999.0
var _failures: Array[String] = []
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	SaveManager.use_path("user://test_dragon.cfg")
	SaveManager.crashes = true
	SaveManager.dragon = true
	SaveManager.dragon_level = 1
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_dragon = get_tree().get_first_node_in_group("dragon")
	_dragon.plane_hit.connect(func(where: Vector3, fire: bool): _hits.append([where, fire]))
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_plane.input.override_enabled = true
	_ray.collision_mask = GameSettings.LAYER_WORLD


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures.append(name)


func _next() -> void:
	_step += 1
	_t = 0.0


## Park the plane somewhere harmless and keep it flying straight.
func _plane_away() -> void:
	_plane.teleport(Vector3(2600, 120, 2600), 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_plane.input.override_throttle = 0.0
	_plane.input.override_stick = Vector2.ZERO
	if not _dragon.state in [Dragon.State.SLEEP, Dragon.State.WAKE, Dragon.State.ENTER, Dragon.State.EMERGE]:
		_track_clearance()
	match _step:
		0:  # Asleep at home, then wakes and comes out.
			if _t < delta * 1.5:
				_check("starts asleep in the cave", _dragon.state == Dragon.State.SLEEP)
				_plane_away()
				_dragon.wake()
			if _plane.global_position.distance_to(Vector3(2600, 120, 2600)) > 1500.0:
				_plane_away()
			if _dragon.state == Dragon.State.PATROL:
				var out := _dragon.global_position.distance_to(_dragon.lair.global_position)
				_check("flies out of the cave to patrol", out > 120.0)
				_next()
			elif _t > 30.0:
				_check("flies out of the cave to patrol (state %d)" % _dragon.state, false)
				_next()
		1:  # Patrol for a while: should be flying over the map, not stuck.
			if _plane.global_position.distance_to(Vector3(2600, 120, 2600)) > 1500.0:
				_plane_away()
			if _t < delta * 1.5:
				set_meta("patrol_start", _dragon.global_position)
			if _t > 25.0:
				# 25 s at patrol speed covers ~400 m: it should have got somewhere.
				var moved := _dragon.global_position.distance_to(get_meta("patrol_start"))
				var away := _dragon.global_position.distance_to(_dragon.lair.global_position)
				_check("patrols out over the map (moved %.0f m, %.0f m from cave)" % [moved, away], moved > 150.0 and away > 200.0)
				_next()
		2:  # A plane in plain sight, close in front: it should hunt.
			if _t < delta * 1.5:
				var d := _dragon
				var fwd := d._forward()
				fwd.y = 0.0
				# Its patrol route is random: pick a spot ahead that it can
				# really see (not behind a hill, not over the safe airport).
				var p := d.global_position + fwd.normalized() * 180.0 + Vector3.UP * 5.0
				for turn in [0.0, 0.3, -0.3, 0.6, -0.6]:
					var dir := fwd.normalized().rotated(Vector3.UP, turn)
					var q := d.global_position + dir * 180.0 + Vector3.UP * 5.0
					if d._clear_line(d.global_position, q) and not d._in_sanctuary(q):
						p = q
						fwd = dir
						break
				# Flying away from the dragon, so it has to chase.
				_plane.teleport(p, atan2(-fwd.x, -fwd.z))
			if _dragon.state == Dragon.State.HUNT or _dragon.state == Dragon.State.BREATHE:
				_check("notices the plane and hunts it", true)
				_next()
			elif _t > 10.0:
				_check("notices the plane and hunts it (alert %.2f)" % _dragon.alert, false)
				_next()
		3:  # Ram: plane flies straight at the dragon.
			if _t < delta * 1.5:
				_hits.clear()
				_ram()
			if _hits.is_empty() and _t < 12.0:
				_steer_at_dragon()
				return
			if not has_meta("hit_t"):
				set_meta("hit_t", _t)
				_check("ramming the dragon blows the plane up", not _hits.is_empty() and _plane.exploded)
			if _t > float(get_meta("hit_t")) + 3.5:
				_check("respawns parked on the runway", _plane.mode == Aircraft.Mode.PARKED)
				_check("leaves the plane alone after a respawn", _dragon._ignore > 0.0 and _dragon.state != Dragon.State.HUNT)
				remove_meta("hit_t")
				_next()
		4:  # Fire: plane just in front of the flames.
			if _t < delta * 1.5:
				_hits.clear()
				_dragon._ignore = 0.0
				_dragon._set_state(Dragon.State.BREATHE)
				_dragon._t_state = _dragon.cfg("windup") + 0.05
				var m := _dragon.mouth_position()
				var dir := _dragon._fire_dir()
				_plane.teleport(m + dir * 30.0, atan2(-dir.x, -dir.z))
				# It has just seen the plane right there.
				_dragon._last_seen = _plane.global_position
				_dragon._last_vel = Vector3.ZERO
				_dragon._seen_ago = 0.0
			if not _hits.is_empty():
				_check("fire breath blows the plane up (%s)" % ("fire" if _hits[0][1] else "body"), _hits[0][1])
				_next()
			elif _t > 1.5:
				_check("fire breath blows the plane up", false)
				_next()
		5:  # Crashes off: harmless.
			if _t < delta * 1.5:
				SaveManager.set_crashes(false)
				_hits.clear()
			if _t > 4.0 and _t < 4.0 + delta * 1.5:
				_ram()
			if _t > 4.0:
				_steer_at_dragon()
			if _t > 12.0:
				_check("with crashes off the dragon can't hurt the plane", _hits.is_empty() and _plane.mode != Aircraft.Mode.CRASHED)
				SaveManager.set_crashes(true)
				_next()
		6:  # Head for the airport: it must turn away.
			if _t < delta * 1.5:
				_plane_away()
				_dragon._set_state(Dragon.State.PATROL)
				_dragon.global_position = Vector3(0, 80, -Dragon.AIRPORT_RADIUS - 150.0)
				_dragon.velocity = Vector3(0, 0, 1) * 20.0
				_dragon.speed = 20.0
				_dragon._route = [Vector3(0, 60, 0)]  # tempt it with the runway
			_airport_min = minf(_airport_min, Vector2(_dragon.global_position.x, _dragon.global_position.z).length())
			if _t > 15.0:
				_check("never enters the airport (closest %.0f m)" % _airport_min, _airport_min > Dragon.AIRPORT_RADIUS - 40.0)
				_next()
		7:  # Switched off.
			if _t < delta * 1.5:
				SaveManager.set_dragon(false)
			if _t > 0.5:
				_check("dragon setting off hides it", not _dragon.visible and _dragon.process_mode == Node.PROCESS_MODE_DISABLED)
				_check("never flew into the ground (min clearance %.1f m)" % _min_clear, _min_clear > 2.0)
				_finish()


## Plane placed 120 m in front of the dragon, flying straight at it.
func _ram() -> void:
	var fwd := _dragon._forward()
	var p := _dragon.global_position + Vector3.UP * 12.0 + fwd * 120.0
	var to := _dragon.global_position + Vector3.UP * 12.0 - p
	_plane.teleport(p, atan2(-to.x, -to.z))
	_dragon._ignore = 0.0


func _steer_at_dragon() -> void:
	# Keep the plane pointed at the dragon's chest (simple homing).
	var target := _dragon.global_position + Vector3.UP * 12.0
	var to := target - _plane.global_position
	var want := atan2(-to.x, -to.z)
	_plane.heading = want
	_plane.pitch = clampf(asin(to.normalized().y), -0.5, 0.5)


func _track_clearance() -> void:
	var p := _dragon.global_position
	_ray.from = p + Vector3.UP * 200.0
	_ray.to = p + Vector3.DOWN * 600.0
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		if p.y - hit.position.y < _min_clear and p.y - hit.position.y < 2.0:
			print("  low: step %d state %d at %s clear %.1f hit %s" % [_step, _dragon.state, p, p.y - hit.position.y, hit.collider.get_parent().name])
		_min_clear = minf(_min_clear, p.y - hit.position.y)


func _finish() -> void:
	set_physics_process(false)
	print("\nDRAGON TEST %s" % ("PASSED" if _failures.is_empty() else "FAILED: " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
