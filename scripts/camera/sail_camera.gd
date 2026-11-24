class_name SailCamera
extends Node3D
## Follows her sail boat from behind and a little above (Phase 14). The
## right stick looks around, like the plane's camera; let go and it swings
## back behind the boat.

const BACK := 30.0
const UP := 11.0
const LOOK_YAW_DEG := 150.0
const FOLLOW := 3.5

var target: SailBoat
var cam: Camera3D
var _look := 0.0


func _ready() -> void:
	top_level = true
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 9000.0
	add_child(cam)


## Jump straight behind the boat (boarding).
func snap() -> void:
	_look = 0.0
	if target:
		cam.global_position = _wanted()
		cam.look_at(target.global_position + Vector3.UP * 4.0)
		cam.reset_physics_interpolation()


func _wanted() -> Vector3:
	var yaw := target.yaw + _look
	return target.global_position + Vector3(sin(yaw) * BACK, UP, cos(yaw) * BACK)


func _process(delta: float) -> void:
	if target == null or not cam.current:
		return
	var want_look := deg_to_rad(LOOK_YAW_DEG) * Input.get_axis("look_right", "look_left")
	_look = lerpf(_look, want_look, 1.0 - exp(-5.0 * delta))
	cam.global_position = cam.global_position.lerp(_wanted(), 1.0 - exp(-FOLLOW * delta))
	cam.look_at(target.global_position + Vector3.UP * 4.0)
