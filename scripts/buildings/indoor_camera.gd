class_name IndoorCamera
extends Node3D
## The camera inside buildings: closer than the walk camera, looking down
## over the walls from behind the character (rooms have no ceilings to the
## camera, dollhouse style). The right stick swings it round (camera speed
## and invert-Y from the settings, like the walk camera); left alone it
## drifts back behind where you're walking. It's always above the walls,
## so it never clips through one, and the Interior fades any wall between
## it and you. Layout: IndoorCamera > Camera3D.

const DISTANCE := 27.0
const PITCH_DEG := -52.0
const PIVOT_HEIGHT := 3.0
const YAW_RATE_DEG := 120.0
const FOLLOW_RATE := 0.9
const FOLLOW_DELAY := 1.2
const SMOOTH := 10.0

var target: Walker
var interior: Interior
var yaw := 0.0
var cam: Camera3D
var override_enabled := false
var override_look := Vector2.ZERO
var _since_look := 99.0
## Close up, low and level at her head (the hat shop's try-on), eased in
## and out.
var close_up := false
var _close := 0.0
const CLOSE_DISTANCE := 11.0
const CLOSE_PITCH_DEG := -12.0
const CLOSE_PIVOT := 3.2


func _ready() -> void:
	top_level = true
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 800.0
	add_child(cam)
	_place_camera()


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Start behind the character, facing `view_yaw`, no easing.
func snap_to(view_yaw: float) -> void:
	yaw = view_yaw
	_since_look = 99.0
	if target:
		global_position = target.global_position + Vector3.UP * PIVOT_HEIGHT
		target.camera_yaw = yaw
	_place_camera()


func _physics_process(delta: float) -> void:
	if target == null or not cam.current:
		return
	var look := override_look if override_enabled else Input.get_vector("look_left", "look_right", "look_down", "look_up")
	if look.length() > 0.15:
		yaw = wrapf(yaw - look.x * deg_to_rad(YAW_RATE_DEG) * SaveManager.look_sensitivity * delta, -PI, PI)
		_since_look = 0.0
	else:
		_since_look += delta
		if _since_look > FOLLOW_DELAY and target.moving:
			yaw = lerp_angle(yaw, target.facing, 1.0 - exp(-FOLLOW_RATE * delta))
	target.camera_yaw = yaw
	_close = move_toward(_close, 1.0 if close_up else 0.0, delta * 2.5)
	var want := target.global_position + Vector3.UP * lerpf(PIVOT_HEIGHT, CLOSE_PIVOT, _ease(_close))
	global_position = global_position.lerp(want, 1.0 - exp(-SMOOTH * delta))
	_place_camera()
	if interior:
		# Which storeys show follows where she's standing (a big bounce on
		# a bed mustn't fade the room she's in away).
		var feet := target.global_position
		if target is Walker and not (target as Walker).is_on_floor():
			feet.y = minf(feet.y, (target as Walker).floor_y)
		interior.update_view(cam.global_position, feet + Vector3.UP * 2.5, delta)


func _place_camera() -> void:
	var k := _ease(_close)
	var p := deg_to_rad(lerpf(PITCH_DEG, CLOSE_PITCH_DEG, k))
	var dist := lerpf(DISTANCE, CLOSE_DISTANCE, k)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))  # behind: opposite of facing -Z at yaw
	cam.position = back * dist * cos(p) + Vector3.UP * (-sin(p)) * dist
	cam.look_at(global_position, Vector3.UP)
