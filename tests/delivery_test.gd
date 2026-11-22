extends Node
## Deliveries (phase 1), in the real game, driven like a child would:
##   world    the airport post office with its postie and a waiting parcel;
##            every recipient stands on dry, walkable ground
##   pick up  walking into the parcel picks it up (no button): it's in your
##            arms, the bubble shows who it's for, a beacon shines over
##            them, the post office's parcel is gone, the save knows
##   carry    walking past someone else delivers nothing; the parcel stays
##            through getting in the plane, a crash, and a restart (saved)
##   deliver  walking up to them: they cheer, confetti, reward stars go to
##            the lifetime total (not the floating stars' count), the count
##            and "met" list save, a new parcel waits at the post office
##   order    the two lesson people first, then everyone, never the same
##            person twice in a row
##   reach    every recipient can be walked up to from where you'd land
##   islands  post offices at the airport, the city and Town Island, each
##            with a postie, each giving out parcels; the parcel rides on
##            the plane (biplane and jet) while you're in it; on Easy the
##            dragon leaves a plane carrying a parcel alone (not on Medium)
##   arrow    the parents' setting hides the arrow and survives a reload
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_delivery.cfg"

var _main: Node
var _plane: Aircraft
var _w: Walker
var _cam: WalkCamera
var _dm: DeliveryManager
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	await _boot()
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nDELIVERY TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _boot() -> void:
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_plane = _main.get_node("Aircraft")
	_w = _main.walker
	_cam = _main.walk_camera
	_dm = _main.delivery
	_main.title.hide()
	_main._enter(_main.State.FLYING)
	_w.override_enabled = true
	_cam.override_enabled = true
	await _frames(5)


func _run() -> void:
	# --- the world ------------------------------------------------------------------
	var po: PostOffice = _dm.post_offices[0]
	_check("the airport post office is there with a parcel waiting", po.available and _dm.job == "")
	_check("the postie is there (and gets no parcels)", _dm.recipients.has("postie")
			and not Recipients.get_recipient("postie").deliverable)
	var dry := true
	var at_sea := 0
	for r: RecipientData in Recipients.all():
		if r.kind == "mermaid":
			# Mermaids sit on their rock at sea level, out in the water.
			var m: Recipient = _dm.recipients[r.id]
			if absf(m.global_position.y) < 0.5 and IslandShape.height(m.global_position.x, m.global_position.z) < -5.0 and m.mermaid != null:
				at_sea += 1
			else:
				print("    mermaid not at sea: %s at %s, ground %.1f" % [r.id, str(m.global_position.round()), _ground(m.global_position)])
			continue
		var g := _ground(Vector3(r.spot.x, 0, r.spot.y))
		if g < Walker.SHORE_LEVEL + 0.5 or absf(_dm.recipients[r.id].global_position.y - g) > 1.0:
			dry = false
			print("    not on dry ground: ", r.id, " ground ", g)
	_check("everyone stands on dry ground", dry)
	_check("three mermaids sit on rocks out at sea", at_sea == 3)
	_check("nothing showing before a pick-up", not _main.hud.delivery_showing() and not _dm.beacon.visible)
	await _frames(10)
	_check("a red beacon shows the nearest post office with a parcel waiting", _dm.po_beacon.visible
			and _dm.po_beacon_target() == _dm.post_offices[0] and not _dm.po_beacon.show_parcel)
	# --- pick up ------------------------------------------------------------------
	await _get_out_near(po.pickup_point() + Vector3(-30, 0, 25))
	var lifetime0 := SaveManager.lifetime_stars
	var trail0: int = _main.stars.count
	await _walk_to(po.pickup_point(), 1.0, 900)
	await _frames(10)
	var first := _dm.job
	_check("walking into the parcel picks it up (a lesson person first)", first != ""
			and Recipients.get_recipient(first).tier == 0)
	_check("it's in your arms", _w.model.carrying and _w.model.parcel() != null)
	_check("the bubble shows who it's for", _main.hud.delivery_showing())
	_check("a beacon shines over them", _dm.beacon.visible
			and _flat_dist(_dm.beacon.global_position, _dm.target().global_position) < 0.5)
	_check("the post office's parcel is gone", not po.available)
	_check("while carrying, the post office beacon hides (the delivery beacon shows the way)", not _dm.po_beacon.visible)
	_check("the save knows", SaveManager.delivery_job == first)
	# --- walking past someone else -----------------------------------------------------
	var other: Recipient = _dm.recipients["postie"]
	await _walk_to(other.global_position, 4.0, 600)
	await _frames(10)
	_check("walking up to someone else delivers nothing", _dm.job == first and _w.model.carrying)
	# --- carry through the plane and a crash --------------------------------------------
	await _walk_to(_plane.global_position, 6.0, 900)
	await _frames(5)
	_check("Y gets back in the plane with the parcel", _main.toggle_plane() and _main.state == _main.State.LANDED)
	var crashes := [0]
	_plane.crashed.connect(func(_a, _b): crashes[0] += 1)
	_main._enter(_main.State.FLYING)
	_plane.explode()
	await _frames(240)
	_check("after a crash the parcel is still yours", crashes[0] > 0 and _dm.job == first and _w.model.carrying
			and _main.hud.delivery_showing())
	# --- restart mid-delivery -----------------------------------------------------------
	SaveManager.save_now()
	_main.queue_free()
	await _frames(3)
	SaveManager.use_path(PATH)
	await _boot()
	_check("after a restart the parcel is still yours", _dm.job == first and _w.model.carrying
			and _main.hud.delivery_showing() and _dm.beacon.visible and not _dm.post_offices[0].available)
	# --- deliver --------------------------------------------------------------------
	var who := _dm.target()
	await _get_out_near(who.global_position + _front(who) * 35.0)
	await _walk_to(who.global_position, 3.0, 1200)
	await _frames(10)
	_check("walking up to them delivers it", _dm.job == "" and not _w.model.carrying and who.is_celebrating())
	_check("they cheer", who.model.anim in ["Interact", "Cheer"])
	_check("bubble and beacon go away", not _main.hud.delivery_showing() and not _dm.beacon.visible)
	_check("reward stars go into the lifetime total", SaveManager.lifetime_stars == lifetime0 + DeliveryManager.REWARD_STARS)
	_check("but not the floating stars' count", _main.stars.count == trail0)
	_check("the count and who's had one are saved", SaveManager.deliveries == 1 and SaveManager.delivered_to == [first]
			and SaveManager.delivery_job == "")
	await _frames(int(DeliveryManager.REFILL_DELAY * 60) + 20)
	_check("a new parcel waits at the post office", _dm.post_offices[0].available)
	# --- order --------------------------------------------------------------------
	var second := _dm.next_recipient()
	_check("the other lesson person is next", second != first and Recipients.get_recipient(second).tier == 0)
	SaveManager.delivered_to.append(second)
	var seen := {}
	for i in 80:
		seen[_dm.next_recipient()] = true
	var tiers_ok := true
	for id in seen:
		tiers_ok = tiers_ok and Recipients.get_recipient(id).tier == 1
	_check("then the rest of the main island", not seen.has(first) and not seen.has(second) and seen.size() >= 2 and tiers_ok)
	for r in Recipients.deliverable():
		if r.tier < 2 and not SaveManager.delivered_to.has(r.id):
			SaveManager.delivered_to.append(r.id)
	seen = {}
	for i in 80:
		seen[_dm.next_recipient()] = true
	tiers_ok = true
	for id in seen:
		tiers_ok = tiers_ok and Recipients.get_recipient(id).tier == 2
	_check("then the other islands", seen.size() >= 3 and tiers_ok)
	for r in Recipients.deliverable():
		if not SaveManager.delivered_to.has(r.id):
			SaveManager.delivered_to.append(r.id)
	var repeat := false
	for i in 60:
		if _dm.next_recipient() == first:  # first was the last one delivered
			repeat = true
	_check("never the same person twice in a row", not repeat)
	# --- everyone can be reached --------------------------------------------------------
	var unreached := []
	for r: RecipientData in Recipients.deliverable():
		if r.kind == "mermaid":
			continue  # out at sea: mermaid mail is dropped from the plane (below)
		var rec: Recipient = _dm.recipients[r.id]
		var land := Vector3(r.land_at.x, 0, r.land_at.y)
		await _get_out_near(land)
		var frames := int(_flat_dist(land, rec.global_position) / Walker.SPRINT_SPEED * 60.0 * 1.6) + 300
		if not await _walk_to(rec.global_position, GiveRadius.REACH, frames):
			unreached.append("%s (stuck at %s)" % [r.id, str(_w.global_position.round())])
	_check("every recipient can be walked up to from where you'd land", unreached.is_empty())
	for u in unreached:
		print("    unreached: ", u)
	# --- post offices on other islands -------------------------------------------------
	_check("three post offices, each with its postie", _dm.post_offices.size() == 3
			and _dm.recipients.has("postie_city") and _dm.recipients.has("postie_town"))
	var gave := 0
	for i in _dm.post_offices.size():
		var po2: PostOffice = _dm.post_offices[i]
		if _dm.carrying():
			_dm._deliver()
			await _frames(int(DeliveryManager.REFILL_DELAY * 60) + 20)
		var front: Vector3 = po2.global_transform.basis.z
		await _get_out_near(po2.pickup_point() + front * 30.0)
		await _walk_to(po2.pickup_point(), 1.0, 900)
		await _frames(10)
		if _dm.carrying():
			gave += 1
	_check("every post office gives out parcels", gave == _dm.post_offices.size())
	# --- the parcel on the plane -------------------------------------------------------
	await _walk_to(_plane.global_position, 6.0, 900)
	_main.toggle_plane()
	await _frames(15)
	var parcel: Node3D = _plane.visuals.get_node_or_null("Parcel")
	_check("in the plane, the parcel rides on top", parcel != null and parcel.visible and _dm.carrying())
	_plane.set_stats(AircraftCatalog.get_stats("jet"))
	await _frames(15)
	parcel = _plane.visuals.get_node_or_null("Parcel")
	_check("and on the jet too", parcel != null and parcel.visible)
	_plane.set_stats(AircraftCatalog.get_stats("prop"))
	await _get_out_near(_plane.global_position + Vector3(0, 0, 0))
	await _frames(15)
	parcel = _plane.visuals.get_node_or_null("Parcel")
	_check("on foot it's back in your arms, not on the plane", (parcel == null or not parcel.visible) and _w.model.carrying)
	# --- the dragon's parcel truce -----------------------------------------------------------
	var dragon: Dragon = get_tree().get_first_node_in_group("dragon")
	SaveManager.dragon_level = 0
	await _frames(10)
	_check("on Easy the dragon leaves a parcel plane alone", dragon.parcel_truce)
	SaveManager.dragon_level = 1
	await _frames(10)
	_check("not on Medium", not dragon.parcel_truce)
	_dm._deliver()
	SaveManager.dragon_level = 0
	await _frames(10)
	_check("and no truce without a parcel", not dragon.parcel_truce)
	# --- mermaid mail ------------------------------------------------------------------------
	_dm._start("mermaid_cove", true)
	var mer: Recipient = _dm.target()
	var stars0 := SaveManager.lifetime_stars
	var mer_done := [false]
	_dm.delivered.connect(func(id, _f): if id == "mermaid_cove": mer_done[0] = true, CONNECT_ONE_SHOT)
	_plane.park(mer.global_position + Vector3(-300, 0, 0), 0.0)
	_main._enter(_main.State.FLYING)
	# A pass high over her: nothing drops.
	for i in 40:
		_plane.global_position = mer.global_position + Vector3(0, DeliveryManager.DROP_HEIGHT + 40.0, 0)
		await get_tree().physics_frame
	var high_kept: bool = _dm.carrying() and not mer_done[0]
	# Low over her: the parcel parachutes down and she leaps to catch it.
	var leapt := 0.0
	for i in 200:
		if i < 30:
			_plane.global_position = mer.global_position + Vector3(-10, 30.0, 0)
		await get_tree().physics_frame
		leapt = maxf(leapt, mer.mermaid.position.y - Recipient.ROCK_TOP)
	_check("mermaid mail: a high pass drops nothing; a low pass over her drops the parcel and she leaps up to catch it",
			high_kept and mer_done[0] and not _dm.carrying() and leapt > 3.0
			and SaveManager.lifetime_stars == stars0 + DeliveryManager.REWARD_STARS)
	print("  note: high pass kept it %s, delivered %s, leapt %.1f m" % [high_kept, mer_done[0], leapt])
	# --- arrow setting ---------------------------------------------------------------
	SaveManager.set_delivery_arrow(false)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("the arrow setting survives a reload", not SaveManager.delivery_arrow)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[delivery]\njob=5\ncount=-3\ndelivered_to=\"x\"\n")
	f.close()
	SaveManager.use_path(PATH)
	_check("bad saved delivery values fall back", SaveManager.delivery_job == "" and SaveManager.deliveries == 0
			and SaveManager.delivered_to.is_empty())


class GiveRadius:
	const REACH := 7.0


func _front(r: Recipient) -> Vector3:
	var y := r.model.rotation.y
	return Vector3(-sin(y), 0, -cos(y))


## Park the plane at `at` and get out there.
func _get_out_near(at: Vector3) -> void:
	if _w.is_active():
		_main._enter(_main.State.FLYING)
	_plane.park(Vector3(at.x, _ground(at), at.z), 0.0)
	_main._enter(_main.State.FLYING)
	_plane.input.stick = Vector2.ZERO
	_plane.input.throttle = 0.0
	await _frames(3)
	_main.toggle_plane()
	await _frames(10)


## Walk (sprinting) towards `p` until within `radius`; false if it never got there.
func _walk_to(p: Vector3, radius: float, max_frames: int) -> bool:
	for i in max_frames:
		var d := p - _w.global_position
		d.y = 0.0
		if d.length() < radius:
			_w.override_move = Vector2.ZERO
			_w.override_sprint = false
			return true
		_cam.snap_to(atan2(-d.x, -d.z))
		_w.override_move = Vector2(0, 1)
		_w.override_sprint = true
		await get_tree().physics_frame
	_w.override_move = Vector2.ZERO
	_w.override_sprint = false
	return false


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 800, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	var hit: Dictionary = _main.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -100.0


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
