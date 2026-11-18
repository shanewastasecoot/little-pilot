class_name DeliveryManager
extends Node
## The delivery game (phase 1: walk-only on the main island).
##   pick up   walk into the glowing parcel on a post office's pad (no
##             button): it jumps into your arms, and the bubble shows who
##             it's for, with an arrow, and a beacon shines over them
##   carry     on foot it's in your arms; it stays with you in the plane,
##             through crashes, pauses and quitting (it's saved)
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

var job := ""
var recipients := {}           # id -> Recipient
var post_offices: Array[PostOffice] = []
var beacon: DeliveryBeacon
var _main: Node
var _timer := 0.0
var _last := ""
var _rng := RandomNumberGenerator.new()


## Build the post office and people into `world`, and pick up any parcel
## the save says is being carried.
func setup(main: Node, world: Node3D) -> void:
	_main = main
	_rng.randomize()
	var po := PostOffice.new()
	po.name = "PostOffice"
	po.rotation.y = deg_to_rad(-Recipients.POST_OFFICE_FACE) + PI  # front (+Z) faces the compass heading
	world.add_child(po)
	po.global_position = _ground3(Recipients.POST_OFFICE)
	post_offices.append(po)
	for r in Recipients.all():
		var who := Recipient.new(r)
		world.add_child(who)
		who.global_position = _ground3(r.spot)
		recipients[r.id] = who
	beacon = DeliveryBeacon.new()
	beacon.name = "DeliveryBeacon"
	world.add_child(beacon)
	beacon.hide()
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
	for who: Recipient in recipients.values():
		var near := who.global_position.distance_to(p) < WAKE_RADIUS
		if near != who.is_processing():
			who.set_awake(near)
		if near:
			who.notice(p if walker.is_active() else Vector3(1e9, 0, 0))
	if carrying():
		beacon.near = walker.is_active() and _flat_dist(p, target().global_position) < BEACON_NEAR
	if not walker.is_active() or _main.state != _main.State.ON_FOOT:
		return
	if not carrying():
		for po in post_offices:
			if po.available and _flat_dist(walker.global_position, po.pickup_point()) < PICKUP_RADIUS:
				_pick_up(po)
				return
	elif _flat_dist(walker.global_position, target().global_position) < GIVE_RADIUS and not target().is_celebrating():
		_deliver()


## Who the next parcel is for: the lesson people first, then anyone who
## hasn't had one yet, never the same person twice in a row.
func next_recipient() -> String:
	var pool: Array[String] = []
	for r in Recipients.deliverable():
		if r.lesson and not SaveManager.delivered_to.has(r.id):
			pool.append(r.id)
	if pool.is_empty():
		for r in Recipients.deliverable():
			if not SaveManager.delivered_to.has(r.id):
				pool.append(r.id)
	if pool.is_empty():
		for r in Recipients.deliverable():
			if r.id != _last:
				pool.append(r.id)
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


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


static func _ground3(at: Vector2) -> Vector3:
	return Vector3(at.x, IslandShape.height(at.x, at.y), at.y)
