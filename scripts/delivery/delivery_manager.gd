class_name DeliveryManager
extends Node
## The delivery game: post offices at the airport, in the city and on Town
## Island; people on the main island and the other islands.
##   pick up   walk into the glowing parcel on a post office's pad (no
##             button): it jumps into your arms, and the bubble shows who
##             it's for, with an arrow, and a beacon shines over them
##   carry     on foot it's in your arms; in the plane it rides on top; it
##             stays through crashes, pauses and quitting (it's saved). On
##             Easy the dragon leaves a plane carrying a parcel alone
##   deliver   walk up to them: they reach for it and cheer, confetti, a
##             fanfare, and reward stars fly into the jar
## One parcel at a time, no timers, nothing to lose: you can ignore it and
## just explore. Child of Main; builds the post office and the people.

signal picked_up(id: String)
signal delivered(id: String, first_time: bool)

const PICKUP_RADIUS := 6.5
const GIVE_RADIUS := 8.5
## People animate within this distance of the player.
const WAKE_RADIUS := 260.0
const REWARD_STARS := 5
const CHECK_EVERY := 0.1
## After a delivery, the next parcel appears at the post office after this.
const REFILL_DELAY := 2.0
## On foot this close, the beacon's column hides (just the parcel over them).
const BEACON_NEAR := 35.0
## Mermaid mail: fly within this far (flat) of her and this low over the sea
## and the parcel drops (a missed pass just means going round again).
const DROP_RADIUS := 40.0
const DROP_HEIGHT := 70.0
const DROP_TIME := 1.6
var _dropping := false

var job := ""
var recipients := {}           # id -> Recipient
var post_offices: Array[PostOffice] = []
var beacon: DeliveryBeacon
## Red, like the mailbox: over the nearest post office with a parcel
## waiting, whenever you're not carrying one (so it's easy to find).
var po_beacon: DeliveryBeacon
const PO_BEACON_COLOUR := Color("e63946")
var _main: Node
var _timer := 0.0
var _last := ""
var _rng := RandomNumberGenerator.new()
var _plane_parcel: Node3D
var _dragon: Node


## Build the post office and people into `world`, and pick up any parcel
## the save says is being carried.
func setup(main: Node, world: Node3D) -> void:
	_main = main
	_rng.randomize()
	for i in Recipients.POST_OFFICES.size():
		var spec: Array = Recipients.POST_OFFICES[i]
		var po := PostOffice.new()
		po.name = "PostOffice" if i == 0 else "PostOffice%d" % i
		po.rotation.y = deg_to_rad(-float(spec[1])) + PI  # front (+Z) faces the compass heading
		world.add_child(po)
		po.global_position = _ground3(spec[0])
		post_offices.append(po)
	for r in Recipients.all():
		var who := Recipient.new(r)
		world.add_child(who)
		who.global_position = Vector3(r.spot.x, 0.0, r.spot.y) if r.kind == "mermaid" else _ground3(r.spot)
		recipients[r.id] = who
	beacon = DeliveryBeacon.new()
	beacon.name = "DeliveryBeacon"
	world.add_child(beacon)
	beacon.hide()
	po_beacon = DeliveryBeacon.new()
	po_beacon.name = "PostOfficeBeacon"
	po_beacon.show_parcel = false  # the real parcel waits on the pad
	world.add_child(po_beacon)
	po_beacon.colour = PO_BEACON_COLOUR
	po_beacon.hide()
	_dragon = main.get_tree().get_first_node_in_group("dragon")
	_snap_to_ground.call_deferred()
	var saved := SaveManager.delivery_job
	if saved != "" and Recipients.get_recipient(saved) != null and Recipients.get_recipient(saved).deliverable:
		_start(saved, false)
	else:
		SaveManager.delivery_job = ""


func carrying() -> bool:
	return job != ""


func target() -> Recipient:
	return recipients.get(job) as Recipient


func _process(delta: float) -> void:
	if carrying() and _main._playing():
		var cam := get_viewport().get_camera_3d()
		if cam:
			var local := cam.global_basis.inverse() * (target().global_position - cam.global_position)
			_main.hud.set_delivery_angle(atan2(local.x, -local.z))
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	var walker: Walker = _main.walker
	var focus: Node3D = walker if walker.is_active() else _main.aircraft
	var p := focus.global_position
	# The camera decides how much detail people need; the player decides
	# who wakes up and turns to look.
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else p
	for who: Recipient in recipients.values():
		var d := who.global_position.distance_to(p)
		var near := d < WAKE_RADIUS
		if near != who.is_processing():
			who.set_awake(near)
		who.set_outlined(who.global_position.distance_to(eye) < Recipient.OUTLINE_DISTANCE)
		if near:
			who.notice(p if walker.is_active() else Vector3(1e9, 0, 0))
	if carrying():
		beacon.near = walker.is_active() and _flat_dist(p, target().global_position) < BEACON_NEAR
	_update_po_beacon(p, walker.is_active())
	_show_on_plane(carrying() and not walker.is_active() and not _dropping)
	if _dragon:
		_dragon.parcel_truce = carrying() and SaveManager.dragon_level == 0
	# Mermaid mail: a low pass over her drops the parcel.
	if carrying() and target().is_mermaid() and not _dropping and not walker.is_active() \
			and _main.state == _main.State.FLYING:
		var plane: Node3D = _main.aircraft
		if _flat_dist(plane.global_position, target().global_position) < DROP_RADIUS and plane.global_position.y < DROP_HEIGHT:
			_air_drop()
			return
	if not walker.is_active() or _main.state != _main.State.ON_FOOT:
		return
	if not carrying():
		for po in post_offices:
			if po.available and _flat_dist(walker.global_position, po.pickup_point()) < PICKUP_RADIUS:
				_pick_up(po)
				return
	elif not target().is_mermaid() and _flat_dist(walker.global_position, target().global_position) < GIVE_RADIUS \
			and not target().is_celebrating():
		_deliver()


## Who the next parcel is for: people who haven't had one yet, nearest
## tier first (a short walk from the airport, then the main island, then
## the other islands); after that anyone, never the same person twice in a
## row.
func next_recipient() -> String:
	var pool: Array[String] = []
	for tier in 3:
		for r in Recipients.deliverable():
			if r.tier == tier and not SaveManager.delivered_to.has(r.id):
				pool.append(r.id)
		if not pool.is_empty():
			break
	if pool.is_empty():
		for r in Recipients.deliverable():
			if r.id != _last:
				pool.append(r.id)
	if pool.is_empty():  # only one person to deliver to
		pool.append(Recipients.deliverable()[0].id)
	return pool[_rng.randi() % pool.size()]


func _pick_up(po: PostOffice) -> void:
	po.set_available(false)
	_start(next_recipient(), true)
	var burst := PickupBurst.new(30, 9.0)
	burst.position = _main.walker.global_position + Vector3.UP * 3.0
	_main.add_child(burst)
	Sfx.play("pop", 1.1)
	Sfx.play("chime", 1.5)
	picked_up.emit(job)


## Carry a parcel for `id` (the arms, the bubble, the beacon).
func _start(id: String, save: bool) -> void:
	job = id
	_main.walker.model.set_carrying(true)
	var who := target()
	beacon.colour = who.data.colour
	beacon.global_position = who.global_position
	beacon.show()
	_main.hud.show_delivery(who.data)
	for po in post_offices:
		po.set_available(false)
	if save:
		SaveManager.set_delivery_job(id)


func _deliver() -> void:
	var who := target()
	var id := job
	_last = id
	job = ""
	_main.walker.model.set_carrying(false)
	if not (who.is_mermaid() and who.is_celebrating()):  # a mermaid's already leapt for it
		who.receive()
	beacon.hide()
	_main.hud.show_delivery(null)
	var first := SaveManager.add_delivery(id)
	# Confetti over them, the big celebration and a fanfare, reward stars.
	var confetti := PickupBurst.new(90, 16.0, [Color("ff5a5f"), Color("ffd23f"), Color("4aa8ff"), Color("4cc06a"), Color("9b5de5"), Color.WHITE])
	confetti.gravity = Vector3(0, -9, 0)
	confetti.scale_amount_min = 0.8
	confetti.scale_amount_max = 1.6
	confetti.lifetime = 2.2
	confetti.position = who.global_position + Vector3.UP * 7.0
	_main.add_child(confetti)
	_main.hud.celebrate_delivery()
	Sfx.play("fanfare")
	_main.stars.add_bonus(REWARD_STARS)
	delivered.emit(id, first)
	get_tree().create_timer(REFILL_DELAY, false).timeout.connect(func():
		if not carrying():
			for po in post_offices:
				po.set_available(true))


## The parcel leaves the plane on a little parachute and floats down into
## the mermaid's hands; she leaps up to catch it; then the usual cheer.
func _air_drop() -> void:
	_dropping = true
	var who := target()
	_show_on_plane(false)
	var drop := Node3D.new()
	drop.name = "AirDrop"
	_main.add_child(drop)
	drop.global_position = _main.aircraft.global_position - Vector3.UP * 2.0
	var parcel := CharacterLook.prop("Package")
	parcel.scale = Vector3.ONE * 2.2
	drop.add_child(parcel)
	# The parachute: a bright dome on four strings.
	var chute := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 3.2
	dome.height = 3.2
	dome.is_hemisphere = true
	chute.mesh = dome
	chute.position = Vector3(0, 5.5, 0)
	chute.material_override = BuildKit.mat(who.data.colour.to_html(false))
	drop.add_child(chute)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var top := Vector3(cos(a) * 2.8, 5.5, sin(a) * 2.8)
		var line := BuildKit.add(drop, BuildKit.box(Vector3(0.08, top.length(), 0.08)), "ffffff", top * 0.5)
		line.look_at_from_position(top * 0.5, Vector3.ZERO, Vector3.UP if absf(top.normalized().y) < 0.99 else Vector3.FORWARD)
		line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	Sfx.play("whoosh", 1.3)
	var to := who.catch_point()
	var tw := create_tween()
	tw.tween_property(drop, "global_position", to, DROP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(drop, "rotation:y", TAU, DROP_TIME)
	get_tree().create_timer(DROP_TIME - 0.5, false).timeout.connect(func(): who.receive())
	tw.tween_callback(func():
		drop.queue_free()
		_dropping = false
		if carrying() and target() == who:
			_deliver())


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## The post office beacon: over the nearest post office with a parcel
## waiting, only while you're not carrying one.
func _update_po_beacon(p: Vector3, on_foot: bool) -> void:
	var best: PostOffice = null
	if not carrying():
		for po in post_offices:
			if po.available and (best == null or _flat_dist(p, po.global_position) < _flat_dist(p, best.global_position)):
				best = po
	po_beacon.visible = best != null
	if best:
		po_beacon.global_position = best.pickup_point()
		po_beacon.near = on_foot and _flat_dist(p, best.pickup_point()) < BEACON_NEAR


## The post office the red beacon is over (null when it's hidden).
func po_beacon_target() -> PostOffice:
	if not po_beacon.visible:
		return null
	for po in post_offices:
		if po.pickup_point().distance_to(po_beacon.global_position) < 0.5:
			return po
	return null


## The parcel riding on top of the plane (while you're in it).
func _show_on_plane(on: bool) -> void:
	var visuals: Node3D = _main.aircraft.visuals
	if on and (not is_instance_valid(_plane_parcel) or _plane_parcel.get_parent() != visuals):
		# New plane model (or the first time): sit it on the fuselage.
		_plane_parcel = CharacterLook.prop("Package")
		_plane_parcel.name = "Parcel"
		visuals.add_child(_plane_parcel)
		var spot := PlaneSpot.on_top(visuals)
		_plane_parcel.position = spot[0]
		_plane_parcel.scale = Vector3.ONE * spot[1]
	if is_instance_valid(_plane_parcel):
		_plane_parcel.visible = on


## Stand everyone and every post office exactly on the built ground (the
## height functions and the terrain mesh can differ a little on slopes).
func _snap_to_ground() -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
	var nodes: Array[Node3D] = []
	nodes.append_array(post_offices)
	for who: Recipient in recipients.values():
		if not who.is_mermaid():  # mermaids sit at sea level
			nodes.append(who)
	for n in nodes:
		var p := n.global_position
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 60.0, p.z), Vector3(p.x, p.y - 60.0, p.z), GameSettings.LAYER_WORLD)
		if n is PostOffice:
			q.exclude = [(n as PostOffice).body_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			n.global_position.y = (hit.position as Vector3).y
	if carrying():
		beacon.global_position = target().global_position


## Ground height anywhere on the map (the highest island there; the sea
## floor elsewhere).
static func ground_at(x: float, z: float) -> float:
	return maxf(IslandShape.height(x, z), maxf(maxf(IslandShape.palm_height(x, z), IslandShape.volcano_height(x, z)),
			maxf(maxf(OuterIslands.ice_height(x, z), OuterIslands.dino_height(x, z)),
				maxf(OuterIslands.castle_height(x, z), OuterIslands.town_height(x, z)))))


static func _ground3(at: Vector2) -> Vector3:
	return Vector3(at.x, ground_at(at.x, at.y), at.y)
