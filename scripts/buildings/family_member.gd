class_name FamilyMember
extends Node3D
## Someone in her family living in the house (Sim-style): they have needs
## that slowly run down (hungry, sleepy, bored, lonely) and pick something
## to do that helps (Family hands out the places to do it): walk there
## through the doorways and up the stairs, then cook, eat at the table,
## watch TV on the sofa, sleep in their bed, read on their rug, play in the
## playroom, bounce on their bed... When Sophia comes near they turn and
## cheer (hearts), then carry on. Moved by hand along a route (no physics),
## with a capsule you bump into. Origin on the floor.

signal finished(member: FamilyMember)

const WALK_SPEED := 6.5
const TURN_RATE := 8.0
const GREET_RADIUS := 9.0
const GREET_EVERY := 30.0

var id := ""
var look: OutfitData
var head: Array = []
var is_kid := false
var bedroom := ""
## Needs, 1 = all good, 0 = really wants it.
var needs := {"hunger": 0.9, "energy": 0.9, "fun": 0.6, "social": 0.7}
## What they're doing: {} when choosing; else the activity (see Family).
var activity: Dictionary = {}
var state := "idle"   # idle, walking, doing, greeting
var model: CharacterModel
var interior: Interior
var _path: Array = []
var _timer := 0.0
var _yaw := 0.0
var _beat := 0.0
var _greet_cool := 0.0
var _body: AnimatableBody3D
var _zzz: Label3D
var _player: Node3D
var _waited := 0.0


func _ready() -> void:
	model = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	model.look_override = look
	model.head_override = head
	add_child(model)
	if is_kid:
		model.scale = Vector3.ONE * 0.78
	_body = AnimatableBody3D.new()
	_body.collision_layer = GameSettings.LAYER_WORLD
	_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.1 if not is_kid else 0.9
	cap.height = 5.0 if not is_kid else 3.9
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	_zzz = Label3D.new()
	_zzz.text = "z z z"
	_zzz.font_size = 96
	_zzz.outline_size = 18
	_zzz.modulate = Color("9fd8ff")
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.visible = false
	_zzz.position = Vector3(0, 4.0, 0)
	add_child(_zzz)


## Walk to `act.pos` (world) through the house, then do it.
func start(act: Dictionary) -> void:
	_stand_up()
	activity = act
	var here: String = interior.room_at(global_position).get("id", "")
	var there: String = act.room
	_path = []
	if here != "" and there != "" and here != there:
		_path = interior.route(here, there)
	_path.append(act.pos)
	state = "walking"


func _physics_process(delta: float) -> void:
	for k in needs:
		needs[k] = clampf(needs[k] - delta * (0.006 if k != "energy" else 0.0025), 0.0, 1.0)
	_greet_cool -= delta
	_beat -= delta
	match state:
		"walking":
			_walk(delta)
		"doing":
			_do(delta)
		"greeting":
			_timer -= delta
			_face(_yaw, delta)
			if _timer <= 0.0:
				state = "doing" if not activity.is_empty() and _arrived() else "walking"
				_resume_anim()
	_check_greet()
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, 1.0 - exp(-TURN_RATE * delta))
	_body.global_transform = Transform3D(Basis.IDENTITY, global_position)


func _walk(delta: float) -> void:
	if _path.is_empty():
		_arrive()
		return
	var target: Vector3 = _path[0]
	var to := target - global_position
	var flat := Vector2(to.x, to.z)
	var step := WALK_SPEED * (1.1 if is_kid else 1.0) * delta
	if flat.length() <= step:
		global_position = target
		_path.pop_front()
		return
	var dir := flat.normalized()
	# Sophia right in front of them: wait for her to pass (a few seconds at
	# most, then carry on round her).
	if _player and is_instance_valid(_player):
		var to_her := _player.global_position - global_position
		var flat_her := Vector2(to_her.x, to_her.z)
		if absf(to_her.y) < 4.0 and flat_her.length() < 4.0 and flat_her.normalized().dot(dir) > 0.5 and _waited < 3.0:
			_waited += delta
			model.animate(0.0, true, false, false)
			return
	_waited = 0.0
	global_position += Vector3(dir.x, 0, dir.y) * step
	# Up or down the stairs: follow the slope between the points.
	global_position.y = lerpf(global_position.y, target.y, clampf(step / flat.length(), 0.0, 1.0))
	_yaw = atan2(-dir.x, -dir.y)
	model.animate(WALK_SPEED, true, false, false)


func _arrived() -> bool:
	return _path.is_empty()


func _arrive() -> void:
	state = "doing"
	_timer = float(activity.get("time", 20.0))
	_yaw = float(activity.get("yaw", _yaw))
	var pose: String = activity.get("pose", "stand")
	match pose:
		"sit":
			global_position = activity.get("sit_at", global_position)
			model.play("Sit_Chair_Down")
			get_tree().create_timer(0.9, false).timeout.connect(func(): if state == "doing": model.play("Sit_Chair_Idle"))
		"lie":
			global_position = activity.get("sit_at", global_position)
			model.play("Lie_Down")
			get_tree().create_timer(1.6, false).timeout.connect(func(): if state == "doing": model.play("Lie_Idle"))
			_zzz.visible = activity.get("kind", "") == "sleep"
		"onbed":
			global_position = activity.get("sit_at", global_position)
			model.play("Idle")
		"floor":
			model.play("Sit_Floor_Down")
			get_tree().create_timer(1.0, false).timeout.connect(func(): if state == "doing": model.play("Sit_Floor_Idle"))
		_:
			model.play("Idle")
	var cb: Callable = activity.get("on_arrive", Callable())
	if cb.is_valid():
		cb.call(self)


func _do(delta: float) -> void:
	_timer -= delta
	var kind: String = activity.get("kind", "")
	# A little action now and then while they're at it.
	if _beat <= 0.0:
		_beat = randf_range(1.6, 3.0)
		match kind:
			"cook", "tidy":
				model.play("Interact" if randf() < 0.5 else "Use_Item")
			"play":
				model.play(["Cheer", "Jump_Full_Short", "Interact", "PickUp"][randi() % 4])
			"bounce":
				model.play("Jump_Full_Short")
				var tw := create_tween()
				tw.tween_property(model, "position:y", 3.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				tw.tween_property(model, "position:y", 0.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				_beat = 0.8
			"wander":
				_yaw += randf_range(-1.2, 1.2)
	for need: String in activity.get("helps", {}):
		needs[need] = clampf(needs[need] + float(activity.helps[need]) * delta, 0.0, 1.0)
	if _timer <= 0.0:
		_finish()


func _finish() -> void:
	var cb: Callable = activity.get("on_done", Callable())
	if cb.is_valid():
		cb.call(self)
	_stand_up()
	activity = {}
	state = "idle"
	finished.emit(self)


## Get up from a chair, the floor or a bed (back on their feet).
func _stand_up() -> void:
	_zzz.visible = false
	model.position.y = 0.0
	if state == "doing" and not activity.is_empty():
		match str(activity.get("pose", "stand")):
			"sit", "lie", "onbed":
				global_position = activity.get("stand_at", global_position)
		model.play("Idle")


func _resume_anim() -> void:
	if state == "doing":
		match str(activity.get("pose", "stand")):
			"sit": model.play("Sit_Chair_Idle")
			"lie": model.play("Lie_Idle")
			"floor": model.play("Sit_Floor_Idle")
			_: model.play("Idle")


## Sophia close by: turn to her, a cheer and some hearts (not while asleep
## or sitting down: then just a turn of the head, i.e. nothing big).
func _check_greet() -> void:
	if _greet_cool > 0.0 or state == "greeting":
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	var to := _player.global_position - global_position
	if absf(to.y) > 4.0 or Vector2(to.x, to.z).length() > GREET_RADIUS:
		return
	var pose: String = activity.get("pose", "stand") if state == "doing" else "stand"
	if pose != "stand":
		return
	_greet_cool = GREET_EVERY
	state = "greeting"
	_timer = 2.2
	_yaw = atan2(-to.x, -to.z)
	model.play("Cheer")
	var hearts := PickupBurst.new(14, 6.0, [Color("ff5fa2"), Color("ff9ecb")])
	hearts.position = Vector3(0, 6.0 if not is_kid else 4.8, 0)
	add_child(hearts)
	greeted.emit(self)


signal greeted(member: FamilyMember)


func _face(yaw: float, _delta: float) -> void:
	_yaw = yaw

