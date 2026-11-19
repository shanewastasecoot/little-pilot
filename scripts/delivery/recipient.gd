class_name Recipient
extends Node3D
## A person you deliver to, standing at their spot: idles, turns to face
## you when you walk up, and when handed a parcel reaches out for it
## (Interact), then cheers. Cheap at a distance: their meshes stop drawing
## beyond DRAW_DISTANCE and their animation sleeps when nobody is near
## (DeliveryManager wakes them).

const DRAW_DISTANCE := 400.0
## Outlines only this close (further, they'd be under a pixel wide).
const OUTLINE_DISTANCE := 90.0
## Turn to face the player within this distance.
const NOTICE := 28.0
const TURN_RATE := 4.0

var data: RecipientData
var model: CharacterModel
var _home_yaw := 0.0
var _want_yaw := 0.0
var _celebrating := 0.0
var _outlined := true


func _init(p_data: RecipientData) -> void:
	data = p_data
	name = "Recipient_" + data.id


func _ready() -> void:
	model = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	model.look_override = data.look
	model.head_override = data.head
	add_child(model)
	_home_yaw = deg_to_rad(-data.face_deg)
	_want_yaw = _home_yaw
	model.rotation.y = _home_yaw
	for gi: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
		gi.visibility_range_end = DRAW_DISTANCE
	set_outlined(false)  # the manager turns them on when you come close


## Animate (near) or freeze (far away).
func set_awake(on: bool) -> void:
	if model and model._anim:
		model._anim.active = on
	set_process(on)


func set_outlined(on: bool) -> void:
	if on != _outlined:
		_outlined = on
		model.set_outline(on)


## The player is at `p`: face them if close, else turn back home.
func notice(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() < NOTICE and to.length() > 0.5:
		_want_yaw = atan2(-to.x, -to.z)
	else:
		_want_yaw = _home_yaw


## Take the parcel: reach out for it, then a big cheer.
func receive() -> void:
	model.play("Interact")
	_celebrating = 4.6
	var t := get_tree().create_timer(1.0, false)
	t.timeout.connect(func(): model.play("Cheer"))


func is_celebrating() -> bool:
	return _celebrating > 0.0


func _process(delta: float) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, _want_yaw, 1.0 - exp(-TURN_RATE * delta))
	if _celebrating > 0.0:
		_celebrating -= delta
		if _celebrating <= 0.0:
			model.play("Idle")
