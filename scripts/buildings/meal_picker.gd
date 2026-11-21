class_name MealPicker
extends Node3D
## In front of the kitchen fridge: when the fridge opens, three meals pop up
## on little trays (pizza, chicken fingers, breakfast). Walk into one and
## you carry it (like a parcel); take it to the dining table and the table
## is set with it. No reading: the meals are the pictures. Origin on the
## floor at the row's centre; the row runs along local X.

const MEALS := ["Meal_Pizza", "Meal_Chicken", "Meal_Breakfast"]
const SPACING := 4.2
## Bright trays so the meals stand out on the white kitchen floor.
const TRAY_COLOURS := ["ff9ecb", "8fd3ff", "ffd166"]

var fridge: KitchenFridge
var furniture_scale := 2.27
var _spots: Array[Node3D] = []
var _shown := false
var _armed := {}


func _ready() -> void:
	for i in MEALS.size():
		var spot := Node3D.new()
		spot.position = Vector3((i - (MEALS.size() - 1) * 0.5) * SPACING, 0, 0)
		add_child(spot)
		var tray_col: String = TRAY_COLOURS[i]
		var tray := BuildKit.add(spot, BuildKit.cyl(1.6, 0.5, -1, 24), tray_col, Vector3(0, 0.25, 0))
		tray.material_override = BuildingGenerator._mat(tray_col)
		var meal := CharacterLook.prop(MEALS[i])
		meal.scale = Vector3.ONE * furniture_scale * 1.1
		meal.position = Vector3(0, 0.55, 0)
		spot.add_child(meal)
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = GameSettings.LAYER_PLAYER
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 1.2
		cs.shape = s
		cs.position = Vector3(0, 1.0, 0)
		area.add_child(cs)
		spot.add_child(area)
		_armed[i] = true
		area.body_entered.connect(func(b): if b is Walker and _armed[i] and _shown: _armed[i] = false; _pick(i, b))
		area.body_exited.connect(func(b): if b is Walker: _armed[i] = true)
		spot.visible = false
		_spots.append(spot)


## Shown when the fridge opens; they stay out while you're in the kitchen
## (so you can walk over to them) and go back when you leave it.
const HIDE_RADIUS := 20.0
var _player: Node3D


func _physics_process(_delta: float) -> void:
	if fridge == null:
		return
	if not _shown and fridge.is_open():
		_set_shown(true)
	elif _shown and not fridge.is_open():
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		if _player and _player.global_position.distance_to(global_position) > HIDE_RADIUS:
			_set_shown(false)


func reset() -> void:
	_set_shown(false)


func _set_shown(on: bool) -> void:
	_shown = on
	for i in _spots.size():
		var spot := _spots[i]
		if on:
			spot.visible = true
			spot.scale = Vector3.ONE * 0.05
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.1 + i * 0.12)
			tw.tween_property(spot, "scale", Vector3.ONE, 0.35)
		else:
			spot.visible = false


func is_shown() -> bool:
	return _shown


## Pick meal `i`: it goes into your arms (not while you're already
## carrying something: brushing past another tray never swaps it).
func _pick(i: int, walker: Walker) -> void:
	if walker.model.carrying:
		return
	walker.model.set_carrying(true, MEALS[i])
	var burst := PickupBurst.new(24, 7.0)
	burst.position = Vector3(0, 2.0, 0)
	_spots[i].add_child(burst)
	Sfx.play("chime", 1.2 + i * 0.15)
