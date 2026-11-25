class_name SailBoat
extends Node3D
## Her own sail boat (Phase 14): the same little CC0 sail boat as the one
## cruising off the south coast, moored at a dock. Walk to the end of the pier
## and press Y to sail it:
##   left stick   left / right steers; up sails faster, back slows (and backs
##                up a little)
##   RT (boost)   a gust of wind: faster still
##   honk         the boat's horn (whales, dolphins and boats answer)
##   Y            near a dock: glide into the berth and step off
## It always sails gently forward on its own (like the plane flies), stops
## softly before shallow water and piers (never runs aground), heels over in
## the turns and leaves a white wake. She stands at the helm, in her own
## clothes and hat.

signal berthed(dock: Dock)

const CRUISE := 7.0
const FAST := 13.0
const GUST := 20.0
const BACK := -3.0
const ACCEL := 3.0
const TURN_RATE := 0.75       # rad/s at speed
const SHALLOW := -1.5         # ground higher than this is too shallow
const LOOK_AHEAD := 11.0
const FAR := 6000.0           # the edge of the map
const HELM := Vector3(0, 1.3, 2.5)

var speed := 0.0
var yaw := 0.0
## Being sailed by her (not moored, not gliding in).
var driving := false
## Gliding into a berth (or sailing in when called).
var berthing := false
## The dock it's moored at (null while out at sea).
var dock: Dock
## Tests: a fixed stick (x steer, y forward) instead of the controller.
var override_stick := Vector2.INF
var override_gust := false
var docks: Array = []
var hull: Node3D
var _tilt: Node3D
var _skipper: CharacterModel
var _wake: CPUParticles3D
var _steer := 0.0
var _bumped := 0.0


func _ready() -> void:
	name = "SailBoat"
	hull = Node3D.new()
	add_child(hull)
	_tilt = Node3D.new()
	hull.add_child(_tilt)
	# Model faces -Z, the way it sails.
	AssetLib.place(_tilt, "res://assets/environment/sail_boat.glb", Vector3.ZERO, 22.0, 0.0)
	_wake = CPUParticles3D.new()
	_wake.amount = 40
	_wake.lifetime = 2.6
	_wake.local_coords = false
	_wake.emitting = false
	_wake.position = Vector3(0, 0.3, 8.5)
	_wake.direction = Vector3(0, 0.2, 1)
	_wake.spread = 25.0
	_wake.initial_velocity_min = 1.0
	_wake.initial_velocity_max = 2.5
	_wake.gravity = Vector3.ZERO
	_wake.scale_amount_min = 0.9
	_wake.scale_amount_max = 1.8
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	# A soft round puff, not a square.
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 32
	puff.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = g
	m.albedo_texture = puff
	q.material = m
	_wake.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_wake.color_ramp = fade
	add_child(_wake)


## Moor at `d` (no fuss: where it's kept when the game starts).
func moor(d: Dock) -> void:
	dock = d
	var t := d.berth()
	global_position = Vector3(t.origin.x, 0.0, t.origin.z)
	yaw = d.rotation.y
	rotation.y = yaw
	speed = 0.0
	berthing = false


## She climbs aboard: her own clothes at the helm, and off we go.
func board() -> void:
	if is_instance_valid(_skipper):
		_skipper.queue_free()
	_skipper = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	_tilt.add_child(_skipper)
	_skipper.position = HELM
	_skipper.rotation.y = PI
	_skipper.set_hat(SaveManager.hat)
	dock = null
	driving = true
	speed = maxf(speed, 1.0)
	Sfx.play("splash", 1.4, -8.0)


## Glide into `d`'s berth; `berthed` when it's tied up (she steps off).
func berth(d: Dock) -> void:
	driving = false
	berthing = true
	var t := d.berth()
	var to := Vector3(t.origin.x, 0.0, t.origin.z)
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(func(a: float): yaw = a; rotation.y = a, yaw, yaw + wrapf(d.rotation.y - yaw, -PI, PI), 1.6)
	tw.tween_callback(func():
		speed = 0.0
		berthing = false
		dock = d
		if is_instance_valid(_skipper):
			_skipper.queue_free()
		Sfx.play("toot", 1.1, -4.0)
		berthed.emit(d))


## Called from another island's dock: it sails in from out at sea, tooting.
func come_to(d: Dock) -> void:
	driving = false
	var a := d.approach()
	global_position = Vector3(a.origin.x, 0.0, a.origin.z)
	yaw = d.rotation.y + PI  # sailing in, towards the beach
	rotation.y = yaw
	Sfx.play_at("toot", global_position, 1.0)
	berth(d)


## Is there a dock close enough to step off at?
func dock_near() -> Dock:
	for d: Dock in docks:
		if Dock.flat_dist(global_position, d.berth().origin) < Dock.ARRIVE_REACH:
			return d
	return null


func toot() -> void:
	Sfx.play("toot", 1.0, 0.0, EchoZone.honk_bus())
	WorldEvents.send("honk", global_position)


func _physics_process(delta: float) -> void:
	_bumped = maxf(_bumped - delta, 0.0)
	if driving:
		var stick := override_stick
		if stick == Vector2.INF:
			stick = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
		var gust := override_gust or Input.is_action_pressed("boost")
		var want := CRUISE
		if gust:
			want = GUST
		elif stick.y > 0.3:
			want = lerpf(CRUISE, FAST, (stick.y - 0.3) / 0.7)
		elif stick.y < -0.3:
			want = lerpf(CRUISE * 0.3, BACK, (-stick.y - 0.3) / 0.7)
		speed = move_toward(speed, want, ACCEL * delta * (2.0 if want < speed else 1.0))
		_steer = lerpf(_steer, stick.x, 1.0 - exp(-4.0 * delta))
		var grip := clampf(absf(speed) / 5.0, 0.25, 1.0) * signf(speed if absf(speed) > 0.1 else 1.0)
		yaw -= _steer * TURN_RATE * grip * delta
		rotation.y = yaw
		var fwd := -global_basis.z
		var nose := global_position + fwd * signf(speed) * (LOOK_AHEAD + absf(speed) * 0.6)
		if _blocked(nose) or global_position.length() > FAR and fwd.dot(global_position) * speed > 0.0:
			if absf(speed) > 2.0 and _bumped <= 0.0:
				Sfx.play("pop", 0.6, -6.0)
				_bumped = 1.5
			speed = move_toward(speed, 0.0, 30.0 * delta)
		global_position += fwd * speed * delta
		global_position.y = 0.0
	elif not berthing:
		speed = 0.0
	_tilt.rotation.z = lerpf(_tilt.rotation.z, _steer * 0.16 * clampf(speed / FAST, 0.0, 1.0) if driving else 0.0, 1.0 - exp(-3.0 * delta))
	Waves.ride(hull, 16.0, 9.0, 0.0, delta)
	_wake.emitting = absf(speed) > 2.5 or berthing


func _blocked(p: Vector3) -> bool:
	if DeliveryManager.ground_at(p.x, p.z) > SHALLOW:
		return true
	for d: Dock in docks:
		if d.blocks(p):
			return true
	return false
