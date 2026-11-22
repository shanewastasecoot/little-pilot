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
## The chairs: {"at": local floor point, "yaw": walker yaw facing the
## table, "place": index into places (her plate)}.
var seats: Array = []
signal ate(seat: int)
var _by_place := {}  # place index -> meal node on the table
var _eating := {}  # place index -> being eaten
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
			_by_place[i] = item
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(item, "scale", Vector3.ONE * furniture_scale * 0.85, 0.3)
			Sfx.play("chime", pitch, -6.0))


func clear() -> void:
	meal = ""
	_by_place.clear()
	_eating.clear()
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()


func reset() -> void:
	clear()


## The seat nearest `p` (world) within `radius`, or -1 (seats someone's
## in, per `taken`, are skipped).
func seat_near(p: Vector3, radius := 4.5, taken := Callable()) -> int:
	var best := -1
	var best_d := radius
	for i in seats.size():
		if taken.is_valid() and taken.call(i):
			continue
		var sp := seat_point(i)
		var d := Vector2(p.x, p.z).distance_to(Vector2(sp.x, sp.z))
		if d < best_d and absf(p.y - sp.y) < 3.0:  # on this storey
			best_d = d
			best = i
	return best


## Seat `i` in world space (on the floor, where she sits).
func seat_point(i: int) -> Vector3:
	return to_global(seats[i].at)


func seat_yaw(i: int) -> float:
	return wrapf(float(seats[i].yaw) + global_rotation.y, -PI, PI)


## Where she stands after getting up from seat `i` (out behind the chair).
func stand_point(i: int) -> Vector3:
	var at: Vector3 = seats[i].at
	var out := Vector3(0, 0, signf(at.z)) if absf(at.z) > absf(at.x) else Vector3(signf(at.x), 0, 0)
	return to_global(at + out * 4.0)


## Is there food at seat `i`'s place?
func has_food_at(i: int) -> bool:
	var item: Node3D = _by_place.get(int(seats[i].place))
	return item != null and is_instance_valid(item)


## Eat the meal at seat `i`'s place: three bites (munch, smaller each time),
## then it's gone with a little burst of hearts and a happy chime.
func eat_at(i: int) -> bool:
	var place := int(seats[i].place)
	if _eating.has(place) or not has_food_at(i):
		return false
	_eating[place] = true
	var item: Node3D = _by_place[place]
	var full := item.scale
	var tw := create_tween()
	for bite in 3:
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			if is_instance_valid(item):
				Sfx.play("pop", 0.55 + bite * 0.08, -2.0)
				var crumbs := PickupBurst.new(10, 3.0, [Color("ffd166"), Color.WHITE])
				crumbs.position = item.position + Vector3.UP * 0.6
				add_child(crumbs))
		tw.tween_property(item, "scale", full * (0.72 - bite * 0.22), 0.25)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(item):
			var hearts := PickupBurst.new(16, 6.0, [Color("ff5fa2"), Color("ff9ecb")])
			hearts.position = item.position + Vector3.UP * 1.5
			add_child(hearts)
			_items.erase(item)
			item.queue_free()
		_by_place.erase(place)
		_eating.erase(place)
		Sfx.play("chime", 1.6)
		ate.emit(i))
	return true
