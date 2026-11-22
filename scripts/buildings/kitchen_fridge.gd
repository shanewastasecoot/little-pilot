class_name KitchenFridge
extends Node3D
## The kitchen fridge (KayKit Restaurant Bits, CC0): walk up and both doors
## swing open with a cool glow inside and a ding; walk away and they close.
## Origin on the floor; the front faces +Z.

const MODEL := "res://assets/furniture/kaykit_restaurant_bits/fridge_A_decorated.gltf"
const OPEN_RADIUS := 9.0
const CLOSE_RADIUS := 12.0
const OPEN_ANGLE := 1.9

var furniture_scale := 2.27
var _doors: Array[Node3D] = []
var _glow: MeshInstance3D
var _open := false
var _player: Node3D
var _t := 0.0


func _ready() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE * furniture_scale
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*door*", "MeshInstance3D", true, false):
		_doors.append(mi)
	# Cool light inside (seen when the doors are open).
	_glow = BuildKit.add(self, BuildKit.box(Vector3(1.6, 2.1, 0.2) * furniture_scale), "dff6ff",
			Vector3(-0.1, 1.25, 0.42) * furniture_scale)
	_glow.material_override = BuildingGenerator._glow_mat(Color("e6f8ff"))
	_glow.visible = false
	BuildKit.collider(self, BuildKit.box_shape(Vector3(2.0, 2.5, 1.5) * furniture_scale), Vector3(0, 1.25, -0.25) * furniture_scale)


func is_open() -> bool:
	return _open


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	var d := _player.global_position.distance_to(global_position)
	if not _open and d < OPEN_RADIUS:
		_set_open(true)
	elif _open and d > CLOSE_RADIUS:
		_set_open(false)


func _set_open(on: bool) -> void:
	_open = on
	_glow.visible = on
	for door in _doors:
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(door, "rotation:y", OPEN_ANGLE if on else 0.0, 0.5)
	Sfx.play("ding" if on else "pop", 1.2 if on else 0.8, -4.0)


func reset() -> void:
	_open = false
	_glow.visible = false
	for door in _doors:
		door.rotation.y = 0.0
