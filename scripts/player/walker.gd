class_name Walker
extends CharacterBody3D
## The player on foot: gets out of the parked plane, walks about, gets back
## in. Storybook-sized like the townspeople (about 5 m tall). The left stick
## moves relative to the camera, and how far it's pushed sets the speed
## (analog walk); holding the stick all the way for AUTO_RUN_AFTER seconds
## breaks into a run by itself (B runs straight away), A jumps. It walks on any ground up to
## MAX_SLOPE_DEG, bumps into buildings and the plane, and never goes into
## the sea: the shore is a soft invisible edge at SHORE_LEVEL (a fixed
## height, not the moving waves: big swells may lap at your feet, but the
## edge doesn't jump about with every wave).
##
## Looks: the player's own character (player_character.tscn: KayKit parts
## and outfits), dressed from the save (hair, outfit). Origin at the feet.

const HEIGHT := 5.0
const RADIUS := 0.9
const WALK_SPEED := 8.0        # m/s with the stick fully pushed
const SPRINT_SPEED := 15.0     # running (B, or the stick held all the way)
## Stick pushed all the way for this long: run without needing B.
const AUTO_RUN_AFTER := 1.5
## How far is "all the way" (the stick's length, 0..1).
const FULL_PUSH := 0.92
const ACCEL := 45.0            # m/s^2 towards the wanted speed
const AIR_ACCEL := 14.0
const JUMP_SPEED := 11.0
const GRAVITY := 28.0
const MAX_SLOPE_DEG := 40.0
const TURN_RATE := 12.0        # how quickly it turns to face where it's going
## Ground lower than this (m above mean sea level) counts as sea. Checked
## this far ahead of the feet.
const SHORE_LEVEL := 1.5
const SHORE_REACH := 1.6
## How hard walking into a ball or a toy pushes it (per m/s, per second of contact).
const PUSH := 9.0
const PUSH_LIFT := 6.0
## Landing on something bouncy (a sofa, a bed) springs you up this fast.
const BOUNCE_SPEED := 19.0

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
## The last spot it stood on dry ground: if it ever ends up over the sea
## (sliding down a steep bank), it goes back there.
var _last_dry := Vector3.ZERO
## Her feet's height the last time she stood on something (jumps and
## bounces don't change it; the stairs do, step by step).
var floor_y := 0.0
var _active := false
## Seconds the stick has been pushed all the way (auto-run).
var _full_push := 0.0
## Landed on something bouncy and sprang up.
signal bounced
var _bounce := false
## Lying in a bed (stand still on one for LIE_AFTER seconds).
signal lay_down
var lying := false
## Sitting on a chair (sit()).
var sitting := false
signal stood_up
var _stand_at := Vector3.ZERO
var _getting_up := false
var _still_on_bed := 0.0
var _bounce_speed := BOUNCE_SPEED
var _bed_bounces := 0
const LIE_AFTER := 1.2


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
	model = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
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
	_full_push = 0.0
	lying = false
	sitting = false
	_getting_up = false
	if on:
		add_to_group("player_focus")
	elif is_in_group("player_focus"):
		remove_from_group("player_focus")


func is_active() -> bool:
	return _active


## Stand at `pos` (feet), facing `yaw`.
func place(pos: Vector3, yaw: float) -> void:
	floor_y = pos.y
	lying = false
	sitting = false
	_getting_up = false
	global_position = pos
	_last_dry = pos
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
	# Lying in bed or sitting on a chair: stay put until the stick or A
	# gets you up again.
	if lying or sitting:
		velocity = Vector3.ZERO
		if (amount > 0.3 or jump) and not _getting_up:
			_get_up()
		return
	# Held all the way for a moment: break into a run by itself.
	_full_push = _full_push + delta if amount >= FULL_PUSH else 0.0
	sprint = sprint or _full_push >= AUTO_RUN_AFTER
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
		velocity.y = _bounce_speed if _bounce else (JUMP_SPEED if jump else 0.0)
		if jump and not _bounce:
			_bed_bounces = 0  # a fresh jump onto a bed bounces high again
		_bounce = false
	else:
		velocity.y -= GRAVITY * delta
	var was_falling := not is_on_floor() and velocity.y < -2.0
	move_and_slide()
	_push_things()
	if is_on_floor() and was_falling and _on_bouncy():
		# Beds: each bounce a little lower, so you settle (and can lie down).
		var on_bed := _bed_under() != null
		_bounce_speed = BOUNCE_SPEED if not on_bed or _bed_bounces == 0 else _bounce_speed * 0.6
		_bed_bounces = _bed_bounces + 1 if on_bed else 0
		if _bounce_speed > 7.0:
			_bounce = true  # springs up on the next step
			Sfx.play("whoosh", 1.8, -4.0)
			bounced.emit()
	elif is_on_floor() and not _bounce and _bed_under() == null:
		_bed_bounces = 0
	if _wet(global_position):
		global_position = _last_dry
		velocity = Vector3.ZERO
	elif is_on_floor():
		_last_dry = global_position
	if is_on_floor():
		floor_y = global_position.y
	if amount > 0.01:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), 1.0 - exp(-TURN_RATE * delta))
		_visual.rotation.y = facing
	moving = is_on_floor() and flat.length() > 0.3
	sprinting = moving and sprint
	# Standing still on a bed for a moment: lie down.
	var bed := _bed_under() if is_on_floor() and amount < 0.05 else null
	_still_on_bed = _still_on_bed + delta if bed else 0.0
	if bed and _still_on_bed > LIE_AFTER:
		_lie_down(bed)
		return
	model.animate(flat.length(), is_on_floor(), velocity.y > 0.5, sprinting)


## The bed you're standing on (group "bed"), or null.
func _bed_under() -> Node3D:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as Node
		if c.get_normal().y > 0.7 and body and body.is_in_group("bed"):
			return body.get_parent() as Node3D
	return null


## Lie down on `bed`, along it with your head on the pillow.
func _lie_down(bed: Node3D) -> void:
	lying = true
	_still_on_bed = 0.0
	var top := global_position.y
	global_position = Vector3(bed.global_position.x, top, bed.global_position.z) + bed.global_transform.basis.z.normalized() * 0.6
	# The bed's head is at its -Z end: lie with the feet towards +Z.
	facing = bed.global_rotation.y + PI
	_visual.rotation.y = facing
	model.play("Lie_Down")
	model._anim.speed_scale = 1.6
	get_tree().create_timer(1.8, false).timeout.connect(func():
		if lying and not _getting_up:
			model.play("Lie_Idle")
			model._anim.speed_scale = 1.0)
	lay_down.emit()


func _get_up() -> void:
	_getting_up = true
	model.play("Sit_Chair_StandUp" if sitting else "Lie_StandUp")
	model._anim.speed_scale = 2.2
	get_tree().create_timer(0.8 if sitting else 1.0, false).timeout.connect(func():
		if sitting:
			global_position = _stand_at
		lying = false
		sitting = false
		_getting_up = false
		stood_up.emit()
		model.play("Idle"))


## Sit on a chair at `seat` (world, on the floor), looking along `yaw`;
## getting up steps back out to `stand_at`.
func sit(seat: Vector3, yaw: float, stand_at: Vector3) -> void:
	sitting = true
	_getting_up = false
	_stand_at = stand_at
	velocity = Vector3.ZERO
	global_position = seat
	facing = yaw
	_visual.rotation.y = yaw
	model.play("Sit_Chair_Down")
	model._anim.speed_scale = 1.6
	get_tree().create_timer(1.0, false).timeout.connect(func():
		if sitting and not _getting_up:
			model.play("Sit_Chair_Idle")
			model._anim.speed_scale = 1.0)


## Standing on something bouncy (group "bouncy")?
func _on_bouncy() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7 and (c.get_collider() as Node).is_in_group("bouncy"):
			return true
	return false


## Kick: anything loose you walk into (a ball, toys) gets a push.
func _push_things() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null:
			continue
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var push := (-c.get_normal() * Vector3(1, 0, 1)).normalized() * maxf(flat.length(), 2.0) * PUSH
		body.apply_central_impulse((push + Vector3.UP * PUSH_LIFT) * body.mass * get_physics_process_delta_time())


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
	return (hit.position as Vector3).y < SHORE_LEVEL
