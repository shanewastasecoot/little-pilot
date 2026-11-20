class_name BubblingPot
extends Node3D
## A pot of stew on the stove (KayKit Restaurant Bits, CC0): bubbles rise
## and pop out of it all the time, with a soft blub-blub when you're near.
## Origin where the pot sits (on the stove top).

const MODEL := "res://assets/furniture/kaykit_restaurant_bits/pot_A_stew.gltf"
const HEAR_RADIUS := 12.0

var furniture_scale := 2.27
var bubbles: GPUParticles3D
var _player: Node3D
var _t := 0.0


func _ready() -> void:
	var pot: Node3D = (load(MODEL) as PackedScene).instantiate()
	pot.scale = Vector3.ONE * furniture_scale
	add_child(pot)
	bubbles = GPUParticles3D.new()
	bubbles.amount = 14
	bubbles.lifetime = 1.2
	bubbles.position = Vector3(0, 0.5 * furniture_scale, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35 * furniture_scale
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	bubbles.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.85, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	bubbles.draw_pass_1 = mesh
	bubbles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	add_child(bubbles)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(0.35, 0.8)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	if _player.global_position.distance_to(global_position) < HEAR_RADIUS:
		Sfx.play("pop", randf_range(0.5, 0.7), -18.0)
