class_name PostOfficeThings
extends Node3D
## The fun things in the post office's sorting room (built by
## BuildingGenerator for a "post_office" room), all walk-into, no buttons:
##   conveyor  parcels ride a belt along the wall, round and round
##   scales    stand on the big scales: the needle swings round and dings
##   letters   walk into the pile of letters to take one; walk it to the red
##             post box and in it goes (whoosh, sparkle, the postie cheers);
##             as many as she likes
## Origin = the room's plan origin on the floor; `rect` is the room on the plan.

signal posted

var rect := Rect2()
var furniture_scale := 2.27
var shopkeeper: Shopkeeper
var _belt_parcels: Array[Node3D] = []
var _belt_a := Vector3.ZERO
var _belt_b := Vector3.ZERO
var _needle: Node3D
var _scale_at := Vector3.ZERO
var _on_scale := false
var _pile_at := Vector3.ZERO
var _box_at := Vector3.ZERO
var _player: Walker
var _t := 0.0
var letters_posted := 0


func _ready() -> void:
	var f := furniture_scale
	var t := 0.5
	# --- The conveyor belt: along the west wall.
	_belt_a = Vector3(rect.position.x + t + 2.0, 0, rect.position.y + 3.5)
	_belt_b = Vector3(rect.position.x + t + 2.0, 0, rect.end.y - 4.5)
	var mid := (_belt_a + _belt_b) * 0.5
	var length := _belt_a.distance_to(_belt_b)
	_box(mid + Vector3(0, 1.1, 0), Vector3(3.0, 0.4, length), "2b2d42")
	_box(mid + Vector3(0, 1.32, 0), Vector3(2.6, 0.08, length - 0.4), "3a3d55")
	for s in [-1.0, 1.0]:
		_box(mid + Vector3(s * 1.6, 1.35, 0), Vector3(0.25, 0.5, length), "ffd23f")
	for k in int(length / 3.0):
		_box(Vector3(mid.x, 0.45, _belt_a.z + 1.5 + k * 3.0), Vector3(2.4, 0.9, 0.35), "8a8f99")
	BuildKit.collider(self, BuildKit.box_shape(Vector3(3.4, 1.6, length)), mid + Vector3(0, 0.8, 0))
	for k in 5:
		var p := CharacterLook.prop("Package")
		p.scale = Vector3.ONE * 1.6
		add_child(p)
		_belt_parcels.append(p)
	# --- The scales: a big platform with a round dial on a post.
	_scale_at = Vector3(rect.end.x - t - 4.0, 0, rect.end.y - 5.0)
	_box(_scale_at + Vector3(0, 0.2, 0), Vector3(4.0, 0.4, 4.0), "c9d3dd")
	_box(_scale_at + Vector3(0, 0.42, 0), Vector3(3.6, 0.05, 3.6), "8a8f99")
	_box(_scale_at + Vector3(0, 2.6, -2.2), Vector3(0.4, 5.0, 0.4), "c9d3dd")
	var dial := BuildKit.add(self, BuildKit.cyl(1.4, 0.3, -1, 24), "ffffff", _scale_at + Vector3(0, 5.2, -2.0), Vector3(90, 0, 0))
	dial.material_override = BuildingGenerator._mat("ffffff")
	var rim := TorusMesh.new()
	rim.inner_radius = 1.35
	rim.outer_radius = 1.55
	var rim_mi := BuildKit.add(self, rim, "e63946", _scale_at + Vector3(0, 5.2, -1.85), Vector3(90, 0, 0))
	rim_mi.material_override = BuildingGenerator._mat("e63946")
	_needle = Node3D.new()
	_needle.position = _scale_at + Vector3(0, 5.2, -1.8)
	add_child(_needle)
	BuildKit.add(_needle, BuildKit.box(Vector3(0.15, 1.1, 0.08)), "e63946", Vector3(0, 0.5, 0)).material_override = BuildingGenerator._mat("e63946")
	# --- The letters (a pile on a little table by the door) and the post box.
	_pile_at = Vector3(rect.position.x + rect.size.x * 0.74, 0, rect.get_center().y + 0.8)
	_box(_pile_at + Vector3(0, 1.4, 0), Vector3(3.0, 0.3, 2.2), "b98a5e")
	for s in [-1.0, 1.0]:
		for r in [-1.0, 1.0]:
			_box(_pile_at + Vector3(s * 1.3, 0.7, r * 0.9), Vector3(0.25, 1.4, 0.25), "8b5a2b")
	for k in 6:
		var l := CharacterLook.prop("Letter")
		l.scale = Vector3.ONE * f * 1.6
		l.position = _pile_at + Vector3(randf_range(-0.6, 0.6), 1.6 + k * 0.1, randf_range(-0.4, 0.4))
		l.rotation.y = randf() * TAU
		add_child(l)
	_box_at = Vector3(rect.position.x + rect.size.x * 0.3, 0, rect.position.y + 7.0)
	BuildKit.add(self, BuildKit.cyl(1.4, 4.0, -1, 16), "e63946", _box_at + Vector3(0, 2.0, 0)).material_override = BuildingGenerator._mat("e63946")
	BuildKit.add(self, BuildKit.sphere(1.4, 16), "e63946", _box_at + Vector3(0, 4.0, 0)).material_override = BuildingGenerator._mat("e63946")
	_box(_box_at + Vector3(0, 3.4, 1.35), Vector3(1.6, 0.3, 0.2), "1b1b2f")
	BuildKit.collider(self, BuildKit.cyl_shape(1.5, 5.2), _box_at + Vector3(0, 2.6, 0))


func _box(at: Vector3, size: Vector3, hex: String) -> void:
	BuildKit.add(self, BuildKit.box(size), hex, at).material_override = BuildingGenerator._mat(hex)


func _process(delta: float) -> void:
	# Parcels along the belt, round and round.
	var length := _belt_a.distance_to(_belt_b)
	for i in _belt_parcels.size():
		var u := fposmod(Time.get_ticks_msec() * 0.0015 + float(i) / _belt_parcels.size() * length, length)
		_belt_parcels[i].position = _belt_a.lerp(_belt_b, u / length) + Vector3(0, 1.4, 0)
	# The needle: swings round when she's on the scales, back when she's off.
	var want := 2.4 if _on_scale else 0.0
	_needle.rotation.z = lerpf(_needle.rotation.z, -want, 1.0 - exp(-4.0 * delta))
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Walker
		return
	var p := to_local(_player.global_position)
	var on := absf(p.x - _scale_at.x) < 2.2 and absf(p.z - _scale_at.z) < 2.2
	if on and not _on_scale:
		get_tree().create_timer(0.8, false).timeout.connect(func(): if _on_scale: Sfx.play("ding", 1.1))
	_on_scale = on
	var m := _player.model
	# Take a letter from the pile.
	if not m.carrying and Vector2(p.x - _pile_at.x, p.z - _pile_at.z).length() < 3.6:
		m.set_carrying(true, "Letter")
		Sfx.play("pop", 1.4)
	# Post it.
	elif m.carrying and m.carry_item == "Letter" and Vector2(p.x - _box_at.x, p.z - _box_at.z).length() < 3.8:
		m.set_carrying(false)
		letters_posted += 1
		Sfx.play("whoosh", 1.6)
		var burst := PickupBurst.new(24, 7.0, [Color.WHITE, Color("e63946"), Color("ffd23f")])
		burst.position = _box_at + Vector3(0, 4.5, 0)
		add_child(burst)
		if shopkeeper:
			shopkeeper.model.play("Cheer")
			get_tree().create_timer(2.0, false).timeout.connect(func(): shopkeeper.model.play("Idle"))
		posted.emit()


## Is she on the scales?
func on_scale() -> bool:
	return _on_scale


func needle_angle() -> float:
	return -_needle.rotation.z


func scale_point() -> Vector3:
	return to_global(_scale_at)


func pile_point() -> Vector3:
	return to_global(_pile_at)


func box_point() -> Vector3:
	return to_global(_box_at)


## Going out: a letter in her arms stays here.
func reset() -> void:
	_on_scale = false
	if _player and is_instance_valid(_player) and _player.model.carry_item == "Letter":
		_player.model.set_carrying(false)
