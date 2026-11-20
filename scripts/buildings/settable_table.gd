class_name SettableTable
extends Node3D
## The dining table: walk up to it and it sets itself, one place after
## another (a plate, a bowl and a little dinner pop on, with rising
## chimes). Going out of the house clears it again. Origin on the floor at
## the table's centre; `places` are spots on the table top (local).

const FOOD := "res://assets/furniture/kaykit_restaurant_bits/"
const SET_RADIUS := 13.0

var places: Array[Vector3] = []
var furniture_scale := 2.27
var _set := false
var _items: Array[Node3D] = []
var _player: Node3D
var _t := 0.0


func is_set() -> bool:
	return _set


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	if not _set and _player.global_position.distance_to(global_position) < SET_RADIUS:
		set_table()


## Put a plate, a bowl and some dinner at every place.
func set_table() -> void:
	if _set:
		return
	_set = true
	for i in places.size():
		var at := places[i]
		var pitch := pow(2.0, [0, 2, 4, 5, 7, 9, 11, 12][i % 8] / 12.0)
		var delay := 0.18 * i
		get_tree().create_timer(delay, false).timeout.connect(func():
			if not _set:
				return
			for k in 3:
				var item: Node3D = (load(FOOD + ["plate", "bowl", "food_dinner"][k] + ".gltf") as PackedScene).instantiate()
				item.position = at + Vector3(0, k * 0.08 * furniture_scale, 0)
				item.scale = Vector3.ONE * 0.01
				add_child(item)
				_items.append(item)
				var full := furniture_scale * (0.8 if k == 2 else 1.0)
				create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(item, "scale", Vector3.ONE * full, 0.3)
			Sfx.play("chime", pitch, -6.0))


func reset() -> void:
	_set = false
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
