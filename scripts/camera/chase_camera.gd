class_name ChaseCamera
extends Node3D
## Smooth chase camera: follows the plane, swings gently into turns, lets the
## right stick look around and drifts back when released. No shake, no cuts.
## Scene layout: ChaseCamera (this) > SpringArm3D > Camera3D.

## Distance multipliers for the camera button: Close, Far.
const PRESETS: Array[float] = [1.0, 1.7]
## How far the right stick can look (degrees).
const LOOK_YAW_DEG := 150.0
const LOOK_PITCH_DEG := 35.0
## Default downward tilt of the camera (degrees).
const BASE_PITCH_DEG := -10.0

@export var target: Aircraft
## Rotation follow speed (per second). Lower = lazier swing.
@export var follow_rate: float = 4.0
## How quickly look-around reaches the stick and recenters.
@export var look_rate: float = 5.0

var preset: int = 0
var _look: Vector2 = Vector2.ZERO  # x = yaw, y = pitch (radians)
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	arm.collision_mask = GameSettings.LAYER_WORLD
	if target:
		arm.add_excluded_object(target.get_rid())
		target.input.camera_pressed.connect(cycle_preset)
		snap_to_target()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var stats := target.stats

	var look_in := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	var look_goal := Vector2(-look_in.x * deg_to_rad(LOOK_YAW_DEG), look_in.y * deg_to_rad(LOOK_PITCH_DEG))
	_look = _look.lerp(look_goal, 1.0 - exp(-look_rate * delta))

	var t := 1.0 - exp(-follow_rate * delta)
	_yaw = lerp_angle(_yaw, target.heading, t)
	_pitch = lerpf(_pitch, target.pitch * 0.4, t)

	global_position = target.global_position + Vector3.UP * stats.camera_height
	rotation = Vector3(deg_to_rad(BASE_PITCH_DEG) + _pitch + _look.y, _yaw + _look.x, 0.0)

	var zt := 1.0 - exp(-3.0 * delta)
	arm.spring_length = lerpf(arm.spring_length, stats.camera_distance * PRESETS[preset], zt)
	cam.fov = lerpf(cam.fov, stats.camera_fov + stats.boost_fov_bonus * target.boost_amount, zt)


func cycle_preset() -> void:
	preset = (preset + 1) % PRESETS.size()


## Jump straight behind the target with no smoothing (spawn, respawn).
func snap_to_target() -> void:
	_yaw = target.heading
	_pitch = target.pitch * 0.4
	global_position = target.global_position + Vector3.UP * target.stats.camera_height
	rotation = Vector3(deg_to_rad(BASE_PITCH_DEG) + _pitch, _yaw, 0.0)
	arm.spring_length = target.stats.camera_distance * PRESETS[preset]
	cam.fov = target.stats.camera_fov
	reset_physics_interpolation()
