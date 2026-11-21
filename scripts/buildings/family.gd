class_name Family
extends Node3D
## Her family living in the house, Sim-style: Mum, Dad, a big brother and a
## little sister (KayKit characters). Each has needs (FamilyMember) and
## picks what to do next by what they need most, what they like (Mum likes
## cooking, the kids like playing) and a bit of chance:
##   cook    Mum or Dad at the stove
##   eat     sit at a free dining chair and eat the food at that place; only
##           Sophia puts food on the table (from the fridge), and when she
##           does they all come to eat it with her
##   tv      sit on the sofa in front of the TV
##   sleep   lie in their own bed (z z z)
##   read    sit on the rug in their own room
##   play    (kids) in the playroom: the toy box opens, the ball gets kicked
##   bounce  (kids) jump on their bed
##   wander  have a look round another room
## Places are shared out so no two sit in the same chair. Being near the
## others keeps them from getting lonely. They show only on the storey you
## can see (dollhouse), and freeze with the house when you go outside.

const MEMBERS := ["mum", "dad", "brother", "sister"]

var interior: Interior
var members: Array[FamilyMember] = []
var _taken := {}   # spot key -> member id
var _keys := {}    # member id -> spot key
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.seed = 41
	for id in MEMBERS:
		var m := FamilyMember.new()
		m.id = id
		m.name = "Family_" + id
		m.interior = interior
		match id:
			"mum":
				m.look = OutfitData.make("mum", "Mage", {"r1c0": Color("ff8fab"), "r0c3": Color("ffffff"), "r0c4": Color("ff8fab")})
				m.head = ["Mage", {"r0c1": Color("7a4a2a")}]
				m.bedroom = "bedroom_ne"
			"dad":
				m.look = OutfitData.make("dad", "Knight", {"r0c3": Color("4a6fa5"), "r0c7": Color("2c3e66"), "r0c6": Color("6b4226"),
						"r0c4": Color("8a8f99"), "r1c0": Color("2ec4b6"), "r1c2": Color("ffd23f"), "r1c7": Color("2c3e66")})
				m.head = ["Rogue", {"r0c1": Color("3b2a20")}]
				m.bedroom = "bedroom_ne"
			"brother":
				m.look = OutfitData.make("brother", "Rogue", {"r1c0": Color("4cc06a"), "r0c5": Color("3a7bd5"), "r0c6": Color("ffd23f"),
						"r2c5": Color("ffd23f")}, [["Beanie", "head"]], ["Rogue_Cape"])
				m.head = ["Knight", {}]
				m.is_kid = true
				m.bedroom = "bedroom_sw"
			_:
				m.look = OutfitData.make("sister", "Mage", {"r1c0": Color("ffd23f"), "r0c3": Color("ffffff"), "r0c4": Color("b388ff")})
				m.head = ["Mage", {"r0c1": Color("d9a066")}]
				m.is_kid = true
				m.bedroom = "bedroom_se"
		# Start in different rooms, a bit peckish and ready to do something.
		var start_room: String = {"mum": "kitchen", "dad": "living", "brother": "playroom", "sister": "dining"}[id]
		add_child(m)
		m.global_position = interior.inside_point(start_room, "")
		m.needs.hunger = _rng.randf_range(0.5, 0.9)
		m.needs.fun = _rng.randf_range(0.3, 0.7)
		m.finished.connect(_on_finished)
	# They choose what to do on the first frame (the house is moved into
	# place after it's built, and their routes are in world space).
	members_list()


func members_list() -> Array[FamilyMember]:
	members.clear()
	for c in get_children():
		if c is FamilyMember:
			members.append(c)
	return members


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	for m in members:
		# Only on the storey you can see.
		var room: String = interior.room_at(m.global_position).get("id", "")
		m.visible = float(interior._room_fade.get(room, 1.0)) > 0.5
		# Company keeps them happy.
		for o in members:
			if o != m and o.global_position.distance_to(m.global_position) < 14.0:
				m.needs.social = minf(1.0, m.needs.social + 0.01)
		if m.state == "idle":
			_choose(m)


func _on_finished(m: FamilyMember) -> void:
	_release(m)
	_choose(m)


## Is this spot (e.g. "seat2") taken by someone (Sophia included)?
func is_taken(key: String) -> bool:
	return _taken.has(key)


## Sophia sits in a seat: nobody else takes it until she gets up.
func hold(key: String, on: bool) -> void:
	if on:
		_taken[key] = "sophia"
	elif _taken.get(key, "") == "sophia":
		_taken.erase(key)


func _release(m: FamilyMember) -> void:
	if _keys.has(m.id):
		_taken.erase(_keys[m.id])
		_keys.erase(m.id)


## Pick the best thing to do now and set off.
func _choose(m: FamilyMember) -> void:
	_release(m)
	var best: Dictionary = {}
	var best_score := -INF
	for act in _options(m):
		if _taken.has(act.key):
			continue
		var s: float = act.score + _rng.randf_range(0.0, 0.6)
		if s > best_score:
			best_score = s
			best = act
	if best.is_empty():
		return
	_taken[best.key] = m.id
	_keys[m.id] = best.key
	m.start(best)


## Everything this member could do right now, with how much they'd like it.
func _options(m: FamilyMember) -> Array:
	var out := []
	var f: float = interior.data.get("furniture_scale", 2.27)
	var hungry: float = 1.0 - m.needs.hunger
	var tired: float = 1.0 - m.needs.energy
	var bored: float = 1.0 - m.needs.fun
	var table: SettableTable = interior.tables[0] if not interior.tables.is_empty() else null
	# Cook (grown-ups).
	if not m.is_kid and not interior.pots.is_empty():
		var pot: Node3D = interior.pots[0]
		var at := _on_floor(pot.global_position + Vector3(0, 0, 4.5), "kitchen")
		out.append({"key": "cook", "kind": "cook", "room": "kitchen", "pos": at, "yaw": 0.0, "time": 16.0,
			"helps": {"fun": 0.01}, "score": (1.0 if m.id == "mum" else 0.5)})
	# Eat at the table.
	if table:
		for i in table.seats.size():
			out.append({"key": "seat%d" % i, "kind": "eat", "room": "dining", "pos": table.stand_point(i), "pose": "sit",
				"sit_at": table.seat_point(i), "stand_at": table.stand_point(i), "yaw": table.seat_yaw(i), "time": 12.0,
				"helps": {"hunger": 0.08, "social": 0.01},
				"score": hungry * 1.6 + (2.0 if table.has_food_at(i) else -0.8),
				"on_arrive": func(_who): table.eat_at(i)})
	# Watch TV on the sofa.
	if not interior.sofas.is_empty():
		var sofa: Node3D = interior.sofas[0]
		var fwd := sofa.global_transform.basis.z * Vector3(1, 0, 1)
		fwd = fwd.normalized()
		var side := Vector3(-fwd.z, 0, fwd.x)
		for k in 2:
			var seat := sofa.global_position + fwd * 0.7 + side * (1.6 if k == 0 else -1.6)
			out.append({"key": "sofa%d" % k, "kind": "tv", "room": "living", "pos": seat + fwd * 3.5, "pose": "sit",
				"sit_at": seat, "stand_at": seat + fwd * 3.5, "yaw": atan2(-fwd.x, -fwd.z), "time": 24.0,
				"helps": {"fun": 0.035, "energy": 0.004}, "score": bored * 1.3 + (0.4 if m.id == "dad" else 0.2)})
	# Their own bed: sleep (and the kids bounce on it).
	var beds := _beds_in(m.bedroom)
	for bi in beds.size():
		var bed: Node3D = beds[bi]
		var head_out := bed.global_transform.basis.z.normalized()
		var top := bed.global_position + Vector3.UP * 0.55 * f
		var foot := bed.global_position + head_out * (1.5 * f + 2.5)
		foot.y = bed.global_position.y
		var spots := [Vector3.ZERO] if m.is_kid else [bed.global_transform.basis.x.normalized() * 0.8, -bed.global_transform.basis.x.normalized() * 0.8]
		for si in spots.size():
			var lie_at: Vector3 = top + head_out * 0.6 + spots[si]
			out.append({"key": "bed_%s_%d_%d" % [m.bedroom, bi, si], "kind": "sleep", "room": m.bedroom, "pos": foot, "pose": "lie",
				"sit_at": lie_at, "stand_at": foot, "yaw": bed.global_rotation.y + PI, "time": 30.0,
				"helps": {"energy": 0.05}, "score": tired * 2.6 - 0.2})
		if m.is_kid:
			out.append({"key": "bounce_%s" % m.bedroom, "kind": "bounce", "room": m.bedroom, "pos": foot, "pose": "onbed",
				"sit_at": top, "stand_at": foot, "yaw": bed.global_rotation.y, "time": 9.0,
				"helps": {"fun": 0.06}, "score": bored * 1.2 + 0.2 - tired})
	# Read on the rug in their room.
	if m.bedroom != "":
		out.append({"key": "rug_%s" % m.bedroom, "kind": "read", "room": m.bedroom,
			"pos": interior.room_centre(m.bedroom) + Vector3(0, 0, 2.0), "pose": "floor", "yaw": _rng.randf() * TAU, "time": 18.0,
			"helps": {"fun": 0.02, "energy": 0.01}, "score": bored * 0.8 + (0.3 if m.id == "mum" else 0.1)})
	# Play (kids): the toy box, the ball.
	if m.is_kid and not interior.toy_boxes.is_empty():
		var tb: ToyBox = interior.toy_boxes[0]
		out.append({"key": "toybox", "kind": "play", "room": "playroom", "pos": _on_floor(tb.global_position + tb.global_transform.basis.z * 6.5, "playroom"),
			"yaw": atan2(tb.global_transform.basis.z.x, tb.global_transform.basis.z.z), "time": 18.0,
			"helps": {"fun": 0.06, "social": 0.01}, "score": bored * 1.6 + 0.4,
			"on_arrive": func(_who): tb.open()})
	if m.is_kid and not interior.balls.is_empty():
		var ball: BouncyBall = interior.balls[0]
		out.append({"key": "ball", "kind": "play", "room": "playroom", "pos": _on_floor(ball.global_position + Vector3(3, 0, 0), "playroom"),
			"yaw": PI * 0.5, "time": 12.0, "helps": {"fun": 0.05}, "score": bored * 1.4 + 0.3,
			"on_arrive": func(_who):
				ball.apply_central_impulse(Vector3(_rng.randf_range(-1, 1), 0.6, _rng.randf_range(-1, 1)).normalized() * 40.0)})
	# Have a wander into another room.
	var rooms := ["hall", "living", "kitchen", "dining", "playroom", "landing"]
	var r: String = rooms[_rng.randi() % rooms.size()]
	out.append({"key": "wander_%s_%s" % [m.id, r], "kind": "wander", "room": r, "pos": interior.inside_point(r, ""), "time": 6.0,
		"helps": {"social": 0.02}, "score": 0.35 + (1.0 - m.needs.social) * 0.6})
	return out


func _beds_in(room_id: String) -> Array:
	var out := []
	for b in interior.beds:
		if interior.room_at(b.global_position).get("id", "") == room_id:
			out.append(b)
	return out


## `p` put down on the floor of `room_id`.
func _on_floor(p: Vector3, room_id: String) -> Vector3:
	var info := interior.find_room(room_id)
	return Vector3(p.x, interior.global_position.y + float(info.get("base", 0.0)), p.z)
