class_name WalkCamera
extends Node3D
## Third-person camera for walking. It orbits the character: the right
## stick swings it round and tilts it (speed and invert-Y come from the
## saved settings), and when the stick is left alone it drifts round behind
## the way the character is walking, so one stick is enough to get about.
## A SpringArm3D pulls the camera in when terrain or a building would be in
## the way, so it never clips through the ground.
## Layout (built here): WalkCamera > SpringArm3D > Camera3D.

const DISTANCE := 17.0
const PIVOT_HEIGHT := 5.2          # look at the head, not the feet
const YAW_RATE_DEG := 150.0
const PITCH_RATE_DEG := 90.0
const PITCH_MIN_DEG := -60.0       # looking down from above
const PITCH_MAX_DEG := 12.0        # looking up from near the ground
const DEFAULT_PITCH_DEG := -16.0
const FOLLOW_RATE := 0.8           # how fast it drifts behind the walker
const FOLLOW_DELAY := 1.0          # seconds after the right stick is let go
const SMOOTH := 14.0               # position follow (per second)

var target: Walker
var yaw := 0.0
var pitch := deg_to_rad(DEFAULT_PITCH_DEG)
var arm: SpringArm3D
var cam: Camera3D
## Tests drive the look without a controller.
var override_enabled := false
var override_look := Vector2.ZERO

var _since_look := 99.0


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = DISTANCE
	arm.collision_mask = GameSettings.LAYER_WORLD
	arm.margin = 0.6
	var probe := SphereShape3D.new()
	probe.radius = 0.5
	arm.shape = probe
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.far = 6000.0
	arm.add_child(cam)


## Start behind the character looking the way `view_yaw` looks, no easing.
func snap_to(view_yaw: float) -> void:
	yaw = view_yaw
	pitch = deg_to_rad(DEFAULT_PITCH_DEG)
	_since_look = 99.0
	if target:
		global_position = target.global_position + Vector3.UP * PIVOT_HEIGHT
		target.camera_yaw = yaw
	rotation = Vector3(pitch, yaw, 0.0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null or not target.is_active():
		return
	var look := override_look if override_enabled else Input.get_vector("look_left", "look_right", "look_down", "look_up")
	var sens := SaveManager.look_sensitivity
	if look.length() > 0.01:
		_since_look = 0.0
		yaw = wrapf(yaw - look.x * deg_to_rad(YAW_RATE_DEG) * sens * delta, -PI, PI)
		var tilt := look.y * (-1.0 if SaveManager.invert_y else 1.0)
		pitch = clampf(pitch + tilt * deg_to_rad(PITCH_RATE_DEG) * sens * delta, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	else:
		_since_look += delta
		if _since_look > FOLLOW_DELAY and target.moving:
			yaw = lerp_angle(yaw, target.facing, 1.0 - exp(-FOLLOW_RATE * delta))
	var pivot := target.global_position + Vector3.UP * PIVOT_HEIGHT
	global_position = global_position.lerp(pivot, 1.0 - exp(-SMOOTH * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	target.camera_yaw = yaw
