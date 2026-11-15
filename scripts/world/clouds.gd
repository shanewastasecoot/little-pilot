class_name Clouds
extends Node3D
## Puffy low-poly clouds (Quaternius CC0) drifting with the wind high above
## the island. No collision: flying through them is part of the fun.
## Two MultiMeshes (one per cloud shape), moved every frame.

@export var count: int = 110
@export var radius: float = 4500.0
@export var min_height: float = 170.0
@export var max_height: float = 330.0
@export var wind: Vector3 = Vector3(3.0, 0, 1.2)  # m/s

const SHAPES := ["res://assets/environment/cloud_a.glb", "res://assets/environment/cloud_b.glb"]

var _positions: Array[Vector3] = []
var _basis: Array[Basis] = []
var _multis: Array[MultiMesh] = []
var _locals: Array[Transform3D] = []  # each shape's own transform inside its .glb


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for shape in SHAPES:
		var data: Array = AssetLib.mesh_of(shape)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data[0]
		_locals.append(data[1])
		mm.instance_count = count / SHAPES.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.material_override = _cloud_material()
		mmi.custom_aabb = AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2, max_height + 50, radius * 2))
		add_child(mmi)
		_multis.append(mm)
	for i in count:
		var r := sqrt(rng.randf()) * radius
		var a := rng.randf() * TAU
		_positions.append(Vector3(cos(a) * r, rng.randf_range(min_height, max_height), sin(a) * r))
		var s := rng.randf_range(28.0, 60.0)
		_basis.append(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)))
	_update(0.0)


func _process(delta: float) -> void:
	_update(minf(delta, 0.1))


func _update(delta: float) -> void:
	for i in count:
		var p := _positions[i] + wind * delta
		# Wrap clouds that drift off one side back in on the other.
		var flat := Vector2(p.x, p.z)
		if flat.length() > radius:
			flat = -flat.normalized() * (radius - 1.0)
			p = Vector3(flat.x, p.y, flat.y)
		_positions[i] = p
		var k := i % _multis.size()
		_multis[k].set_instance_transform(i / _multis.size(), Transform3D(_basis[i], p) * _locals[k])


## Soft bright white: a little self-glow keeps the shaded side from going
## grey, so they read as fluffy clouds rather than floating rocks.
static func _cloud_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.85, 0.9, 1.0)
	m.emission_energy_multiplier = 0.45
	return m
