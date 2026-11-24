class_name PilotSeat
extends Node3D
## Her, flying the plane: her own character (body, hair, outfit and hat from
## the save) sitting in an open cockpit, sized to fit it. Rebuilt if she
## changes how she looks. Used by the biplane (vinish.dev model).

## How tall she'd be standing, in this node's units (her sitting height
## follows from it).
@export var height := 0.55

var _model: CharacterModel
var _look := ""
var _t := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.5:
		_t = 0.0
		if _look_key() != _look:
			_build()


func _look_key() -> String:
	return "%s|%d|%d|%s" % [SaveManager.char_body, SaveManager.char_hair, SaveManager.char_outfit, SaveManager.hat]


func _build() -> void:
	_look = _look_key()
	if is_instance_valid(_model):
		_model.queue_free()
	_model = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	add_child(_model)
	_model.apply(SaveManager.char_body, SaveManager.char_hair, SaveManager.char_outfit, SaveManager.hat)
	# Sized from her standing height.
	var top := 0.0
	for gi: VisualInstance3D in _model.find_children("*", "VisualInstance3D", true, false):
		var b := gi.get_aabb()
		top = maxf(top, (_model.global_transform.affine_inverse() * gi.global_transform * b.end).y)
	if top > 0.01:
		_model.scale = Vector3.ONE * height / top
	for gi: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.play("Sit_Chair_Idle")
