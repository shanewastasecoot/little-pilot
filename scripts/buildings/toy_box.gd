class_name ToyBox
extends Node3D
## A big toy box in the playroom. Walk up to it and the lid flips open and
## toys pop out, bouncing and squeaking (you can push them about). Going out
## of the house puts them all back. Origin on the floor at the box's centre;
## its front faces +Z.

const SIZE := Vector3(7.0, 4.0, 4.4)
const OPEN_RADIUS := 8.5
const TOYS := 5

var _lid: Node3D
var _open := false
var _toys: Array[RigidBody3D] = []
var _player: Node3D
var _t := 0.0


func _ready() -> void:
	var body := BuildKit.add(self, BuildKit.box(SIZE), "e63946", Vector3(0, SIZE.y * 0.5, 0))
	body.material_override = BuildingGenerator._mat("e63946")
	for k in 3:  # yellow stripes and big dots on the front
		var dot := BuildKit.add(self, BuildKit.cyl(0.7, 0.2, -1, 16), "ffd23f", Vector3(-2.2 + k * 2.2, SIZE.y * 0.5, SIZE.z * 0.5 + 0.05), Vector3(90, 0, 0))
		dot.material_override = BuildingGenerator._mat(["ffd23f", "4aa8ff", "4cc06a"][k])
	BuildKit.collider(self, BuildKit.box_shape(SIZE), Vector3(0, SIZE.y * 0.5, 0))
	_lid = Node3D.new()
	_lid.position = Vector3(0, SIZE.y, -SIZE.z * 0.5)  # hinge at the back
	add_child(_lid)
	var lid_mesh := BuildKit.add(_lid, BuildKit.box(Vector3(SIZE.x + 0.4, 0.5, SIZE.z + 0.3)), "ffd23f", Vector3(0, 0.25, SIZE.z * 0.5))
	lid_mesh.material_override = BuildingGenerator._mat("ffd23f")


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	if not _open and _player.global_position.distance_to(global_position) < OPEN_RADIUS:
		open()


func is_open() -> bool:
	return _open


## Flip the lid and pop the toys out.
func open() -> void:
	if _open:
		return
	_open = true
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_lid, "rotation:x", deg_to_rad(-110), 0.45)
	Sfx.play("pop", 1.3)
	for i in TOYS:
		var toy := _make_toy(i)
		add_child(toy)
		toy.global_position = global_position + Vector3(randf_range(-2.0, 2.0), SIZE.y + 1.5, randf_range(-0.8, 0.8))
		toy.apply_central_impulse(Vector3(randf_range(-4.0, 4.0), randf_range(9.0, 13.0), randf_range(3.0, 7.0)) * toy.mass)
		toy.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 3.0 * toy.mass)
		_toys.append(toy)
		var pitch := 1.6 + i * 0.12
		get_tree().create_timer(0.15 * i, false).timeout.connect(func(): Sfx.play("honk", pitch, -8.0))


## Close the lid, toys gone (back in the box).
func reset() -> void:
	for t in _toys:
		if is_instance_valid(t):
			t.queue_free()
	_toys.clear()
	_open = false
	if _lid:
		_lid.rotation.x = 0.0


func _make_toy(i: int) -> RigidBody3D:
	var toy := RigidBody3D.new()
	toy.collision_layer = GameSettings.LAYER_WORLD
	toy.collision_mask = GameSettings.LAYER_WORLD | GameSettings.LAYER_PLAYER
	toy.mass = 2.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.6
	toy.physics_material_override = pm
	var colours := ["4aa8ff", "4cc06a", "ffd23f", "9b5de5", "ff8c42"]
	var cs := CollisionShape3D.new()
	if i % 2 == 0:  # building blocks
		var s := 1.6
		cs.shape = BuildKit.box_shape(Vector3(s, s, s))
		BuildKit.add(toy, BuildKit.box(Vector3(s, s, s)), colours[i % 5]).material_override = BuildingGenerator._mat(colours[i % 5])
	else:  # little balls
		var sphere := SphereShape3D.new()
		sphere.radius = 0.9
		cs.shape = sphere
		BuildKit.add(toy, BuildKit.sphere(0.9, 14), colours[i % 5]).material_override = BuildingGenerator._mat(colours[i % 5])
	toy.add_child(cs)
	toy.contact_monitor = true
	toy.max_contacts_reported = 1
	toy.body_entered.connect(func(_b):
		if toy.linear_velocity.length() > 4.0:
			Sfx.play("pop", 1.8 + randf() * 0.4, -10.0))
	return toy
