class_name SettableTable
extends Node3D
## The dining table: empty until you bring a meal from the kitchen (picked
## at the fridge, carried in your arms). Walk up to the table with it and
## it's served at every place, one after another with rising chimes, and
## your arms are free again. Bring a different meal and it's swapped.
## Going out of the house clears it. Origin on the floor at the table's
## centre; `places` are spots on the table top (local).

const SERVE_RADIUS := 13.0

var places: Array[Vector3] = []
var furniture_scale := 2.27
## The meal on the table ("" = none yet).
var meal := ""
var _items: Array[Node3D] = []
var _player: Node3D
var _t := 0.0


func is_set() -> bool:
	return meal != ""


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	var w := _player as Walker
	if w and w.model.carrying and w.model.carry_item.begins_with("Meal_") \
			and _player.global_position.distance_to(global_position) < SERVE_RADIUS:
		var dish := w.model.carry_item
		w.model.set_carrying(false)
		serve(dish)


## Put `dish` (a meal prop) at every place.
func serve(dish: String) -> void:
	clear()
	meal = dish
	for i in places.size():
		var at := places[i]
		var pitch := pow(2.0, [0, 2, 4, 5, 7, 9, 11, 12][i % 8] / 12.0)
		get_tree().create_timer(0.18 * i, false).timeout.connect(func():
			if meal != dish:
				return
			var item := CharacterLook.prop(dish)
			item.position = at
			item.scale = Vector3.ONE * 0.01
			add_child(item)
			_items.append(item)
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(item, "scale", Vector3.ONE * furniture_scale * 0.85, 0.3)
			Sfx.play("chime", pitch, -6.0))


func clear() -> void:
	meal = ""
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()


func reset() -> void:
	clear()
