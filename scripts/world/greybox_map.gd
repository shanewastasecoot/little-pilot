class_name GreyboxMap
extends Node3D
## Builds the Phase 1 test map from Godot primitives: an island, water,
## hills, tall pillars and a sky. Replaced by the real island in Phase 3.

@export var seed_value: int = 7
@export var island_radius: float = 380.0
@export var hill_count: int = 14
@export var pillar_count: int = 10
@export var spawn_position: Vector3 = Vector3(0, 30, 200)
## Degrees; 0 faces -Z (towards the island centre from the default spawn).
@export var spawn_heading_deg: float = 0.0

const ISLAND_TOP := 2.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	_build_environment()
	_build_water()
	_build_island()
	_build_hills()
	_build_valley()
	_build_pillars()


func spawn_heading() -> float:
	return deg_to_rad(spawn_heading_deg)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4aa8ff")
	sky_mat.sky_horizon_color = Color("bfe6ff")
	sky_mat.ground_horizon_color = Color("bfe6ff")
	sky_mat.ground_bottom_color = Color("3d7fbf")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color("cfeaff")
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var bounds := WorldBounds.new()
	bounds.radius = 520.0
	bounds.ceiling = 130.0
	add_child(bounds)


func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(3000, 3000)
	var body := _static_box(Vector3(3000, 2, 3000), Vector3(0, -1, 0))
	_add_mesh(body, mesh, _mat("2f9be0", 0.15), Vector3(0, 1, 0))


func _build_island() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = island_radius
	mesh.bottom_radius = island_radius + 30.0
	mesh.height = ISLAND_TOP + 4.0
	mesh.radial_segments = 48
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.position.y = ISLAND_TOP - mesh.height * 0.5
	add_child(body)
	_add_mesh(body, mesh, _mat("7ccf5a"))
	_add_shape(body, mesh.create_convex_shape())
	# Sandy beach ring.
	var sand := CylinderMesh.new()
	sand.top_radius = island_radius + 12.0
	sand.bottom_radius = island_radius + 40.0
	sand.height = 3.0
	sand.radial_segments = 48
	var beach := MeshInstance3D.new()
	beach.mesh = sand
	beach.material_override = _mat("f4dc8a")
	beach.position.y = 0.2
	add_child(beach)


func _build_hills() -> void:
	for i in hill_count:
		var r := _rng.randf_range(35.0, 80.0)
		var h := _rng.randf_range(25.0, 70.0)
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(60.0, island_radius - r)
		_hill(Vector3(cos(angle) * dist, ISLAND_TOP, sin(angle) * dist), r, h, "5fb84a")


func _build_valley() -> void:
	# Two big mountains with a gap to fly through.
	_hill(Vector3(-150, ISLAND_TOP, -230), 110.0, 105.0, "8f8f9a")
	_hill(Vector3(40, ISLAND_TOP, -260), 110.0, 110.0, "8f8f9a")


func _build_pillars() -> void:
	var colors := ["ff5a5f", "ffd23f", "9b5de5", "ff8c42"]
	for i in pillar_count:
		var angle := TAU * i / pillar_count + _rng.randf_range(-0.2, 0.2)
		var dist := _rng.randf_range(120.0, island_radius - 30.0)
		var pos := Vector3(cos(angle) * dist, ISLAND_TOP, sin(angle) * dist)
		var h := _rng.randf_range(60.0, 115.0)
		var radius := 5.0
		var body := StaticBody3D.new()
		body.collision_layer = GameSettings.LAYER_WORLD
		body.position = pos + Vector3.UP * h * 0.5
		add_child(body)
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = h
		_add_mesh(body, mesh, _mat(colors[i % colors.size()]))
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = h
		_add_shape(body, shape)
		var push := PushVolume.new()
		push.radius = radius * 4.0
		push.height = h + 40.0
		push.position = pos
		add_child(push)


func _hill(base: Vector3, radius: float, height: float, color: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.12
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.position = base + Vector3.UP * height * 0.5
	add_child(body)
	_add_mesh(body, mesh, _mat(color))
	_add_shape(body, mesh.create_convex_shape())


# --- Small helpers -----------------------------------------------------------

func _static_box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.position = pos
	add_child(body)
	var box := BoxShape3D.new()
	box.size = size
	_add_shape(body, box)
	return body


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, offset := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)


func _add_shape(parent: Node3D, shape: Shape3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	parent.add_child(cs)


func _mat(hex: String, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = roughness
	return m
