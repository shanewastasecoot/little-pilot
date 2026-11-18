class_name Walker
extends CharacterBody3D
## The player on foot: gets out of the parked plane, walks about, gets back
## in. Storybook-sized like the townspeople (about 5 m tall). The left stick
## moves relative to the camera, and how far it's pushed sets the speed
## (analog walk); B sprints, A jumps. It walks on any ground up to
## MAX_SLOPE_DEG, bumps into buildings and the plane, and never goes into
## the sea: the shore is a soft invisible edge.
##
## Looks: the player's own character (CharacterModel, built in Blender),
## dressed from the save (body, hair, outfit). Origin is at the feet.

const HEIGHT := 5.0
const RADIUS := 0.9
const WALK_SPEED := 6.5        # m/s with the stick fully pushed (a brisk walk)
const SPRINT_SPEED := 14.0
const ACCEL := 45.0            # m/s^2 towards the wanted speed
const AIR_ACCEL := 14.0
const JUMP_SPEED := 11.0
const GRAVITY := 28.0
const MAX_SLOPE_DEG := 40.0
const TURN_RATE := 12.0        # how quickly it turns to face where it's going
## Keep this far above the waves, checked this far ahead of the feet.
const SHORE_HEIGHT := 0.9
const SHORE_REACH := 1.6

## The camera's yaw (set by WalkCamera): the stick moves relative to it.
var camera_yaw := 0.0
## Which way the character faces (radians round Y; -Z is forward).
var facing := 0.0
## Tests (and later cutscenes) drive it without a controller.
var override_enabled := false
var override_move := Vector2.ZERO   # x = right, y = forward, length 0..1
var override_sprint := false
var override_jump := false
## On the ground and moving / sprinting (for animations later).
var moving := false
var sprinting := false

var _visual: Node3D
var model: CharacterModel
var _active := false


func _ready() -> void:
	collision_layer = GameSettings.LAYER_PLAYER
	collision_mask = GameSettings.LAYER_WORLD | GameSettings.LAYER_AIRCRAFT
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEG)
	floor_snap_length = 1.2
	floor_stop_on_slope = true
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	model = CharacterModel.new()
	model.body = SaveManager.char_body
	model.hair = SaveManager.char_hair
	model.outfit = SaveManager.char_outfit
	_visual = model
	add_child(_visual)
	SaveManager.settings_changed.connect(_dress)
	set_active(false)


## Wear what's saved (the save changes when the player picks new looks).
func _dress() -> void:
	model.apply(SaveManager.char_body, SaveManager.char_hair, SaveManager.char_outfit)


## Switch the character on (visible, moving, solid) or away.
func set_active(on: bool) -> void:
	_active = on
	visible = on
	set_physics_process(on)
	collision_layer = GameSettings.LAYER_PLAYER if on else 0
	collision_mask = (GameSettings.LAYER_WORLD | GameSettings.LAYER_AIRCRAFT) if on else 0
	velocity = Vector3.ZERO
	moving = false
	sprinting = false
	if on:
		add_to_group("player_focus")
	elif is_in_group("player_focus"):
		remove_from_group("player_focus")


func is_active() -> bool:
	return _active


## Stand at `pos` (feet), facing `yaw`.
func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	facing = yaw
	_visual.rotation.y = yaw
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var move := override_move.limit_length(1.0) if override_enabled \
			else Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var sprint := override_sprint if override_enabled else Input.is_action_pressed("sprint")
	var jump := override_jump if override_enabled else Input.is_action_just_pressed("jump")
	var amount := move.length()
	var dir := Vector3.ZERO
	if amount > 0.01:
		var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
		var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
		dir = (forward * move.y + right * move.x).normalized()
	# Analog speed: half a push is half the speed.
	var want := dir * amount * (SPRINT_SPEED if sprint else WALK_SPEED)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.move_toward(want, (ACCEL if is_on_floor() else AIR_ACCEL) * delta)
	flat = _keep_ashore(flat)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = JUMP_SPEED if jump else 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if amount > 0.01:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), 1.0 - exp(-TURN_RATE * delta))
		_visual.rotation.y = facing
	moving = is_on_floor() and flat.length() > 0.3
	sprinting = moving and sprint
	model.animate(flat.length(), is_on_floor(), velocity.y > 0.5, sprinting)


## Don't walk into the sea: if the ground just ahead is under (or nearly
## under) the waves, keep only the part of the movement that stays ashore.
func _keep_ashore(flat: Vector3) -> Vector3:
	if flat.length() < 0.05:
		return flat
	if not _wet(global_position + flat.normalized() * SHORE_REACH):
		return flat
	var along_x := Vector3(flat.x, 0.0, 0.0)
	var along_z := Vector3(0.0, 0.0, flat.z)
	if absf(flat.x) > 0.05 and not _wet(global_position + along_x.normalized() * SHORE_REACH):
		return along_x
	if absf(flat.z) > 0.05 and not _wet(global_position + along_z.normalized() * SHORE_REACH):
		return along_z
	return Vector3.ZERO


## Is the ground at `p` sea (or nothing at all)?
func _wet(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12.0, p + Vector3.DOWN * 40.0, GameSettings.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return (hit.position as Vector3).y < Waves.height(p.x, p.z) + SHORE_HEIGHT
