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


## Mermaids: the mermaid model on a rock (instead of `model`).
var mermaid: Node3D
const MERMAID_SCALE := 9.0
const ROCK_TOP := 2.2


func is_mermaid() -> bool:
	return data.kind == "mermaid"


func _ready() -> void:
	if is_mermaid():
		_build_mermaid()
		return
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


## A mermaid sitting on a rock just out of the water, waving now and then.
func _build_mermaid() -> void:
	var rock := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 6.0
	rm.height = 6.0
	rm.radial_segments = 14
	rm.rings = 7
	rock.mesh = rm
	rock.scale = Vector3(1.3, 0.75, 1.0)
	rock.position = Vector3(0, -0.4, 0)
	rock.material_override = BuildKit.mat("8a8f99")
	add_child(rock)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var pebble := BuildKit.add(self, BuildKit.sphere(1.8, 8), "9aa0aa", Vector3(cos(a) * 6.5, -0.6, sin(a) * 5.0))
		pebble.scale = Vector3(1.0, 0.6, 1.0)
	mermaid = (load("res://scenes/characters/mermaid.tscn") as PackedScene).instantiate()
	mermaid.set("tail_color", data.tail_colour)
	mermaid.scale = Vector3.ONE * MERMAID_SCALE
	mermaid.position = Vector3(0, ROCK_TOP, 0)
	_home_yaw = deg_to_rad(-data.face_deg)
	_want_yaw = _home_yaw
	mermaid.rotation.y = _home_yaw
	add_child(mermaid)
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.visibility_range_end = DRAW_DISTANCE * 3.0  # seen from the air, far out


## Where a dropped parcel should land: in her hands.
func catch_point() -> Vector3:
	return global_position + Vector3(0, ROCK_TOP + 4.5, 0)


## Animate (near) or freeze (far away).
func set_awake(on: bool) -> void:
	if is_mermaid():
		mermaid.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		set_process(on)
		return
	if model and model._anim:
		model._anim.active = on
	set_process(on)


func set_outlined(on: bool) -> void:
	if is_mermaid():
		return
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


## Take the parcel: reach out for it, then a big cheer. A mermaid leaps up
## out of the water to catch it and splashes back down, waving.
func receive() -> void:
	if is_mermaid():
		_celebrating = 4.6
		var tw := create_tween()
		tw.tween_property(mermaid, "position:y", ROCK_TOP + 7.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mermaid, "rotation:x", -0.5, 0.45)
		tw.tween_property(mermaid, "position:y", ROCK_TOP, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mermaid, "rotation:x", 0.0, 0.4)
		tw.tween_callback(func():
			Sfx.play("splash", 1.2)
			if mermaid.has_method("set_waving"):
				mermaid.set_waving(true))
		return
	model.play("Interact")
	_celebrating = 4.6
	var t := get_tree().create_timer(1.0, false)
	t.timeout.connect(func(): model.play("Cheer"))


func is_celebrating() -> bool:
	return _celebrating > 0.0


func _process(delta: float) -> void:
	var body: Node3D = mermaid if is_mermaid() else model
	body.rotation.y = lerp_angle(body.rotation.y, _want_yaw, 1.0 - exp(-TURN_RATE * delta))
	if _celebrating > 0.0:
		_celebrating -= delta
		if _celebrating <= 0.0:
			if is_mermaid():
				if mermaid.has_method("set_waving"):
					mermaid.set_waving(false)
			else:
				model.play("Idle")
