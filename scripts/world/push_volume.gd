class_name PushVolume
extends Area3D
## A soft keep-away zone around a tall object (pillar, turbine, tower).
## The plane's FlightSafety steers away harder the closer it gets.

## Horizontal radius of the zone (m). Set to roughly 3x the object radius.
@export var radius: float = 18.0:
	set(value):
		radius = value
		_update_shape()
@export var height: float = 200.0:
	set(value):
		height = value
		_update_shape()

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = GameSettings.LAYER_PUSH_VOLUMES
	collision_mask = 0
	monitoring = false
	monitorable = true
	_update_shape()


## 0 at the edge, 1 at the centre (horizontal distance only).
func push_strength_at(pos: Vector3) -> float:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return clampf(1.0 - d / radius, 0.0, 1.0) ** 0.7


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	_shape.shape = cyl
	_shape.position.y = height * 0.5
