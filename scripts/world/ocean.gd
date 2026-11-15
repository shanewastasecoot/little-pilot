class_name Ocean
extends Node3D
## The sea. A dense wave mesh that follows the camera (snapped to its grid
## so the waves never swim), a flat collider at sea level for the safety
## system, and procedurally generated ripple normal maps.

const SIZE := 9000.0
const SUBDIV := 400  # ~22 m quads: fine enough for the swells

var _mesh: MeshInstance3D


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = SUBDIV
	plane.subdivide_depth = SUBDIV
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("ripples_a", _ripple_texture(3, 0.012))
	mat.set_shader_parameter("ripples_b", _ripple_texture(8, 0.02))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = AABB(Vector3(-SIZE, -5, -SIZE), Vector3(SIZE * 2, 10, SIZE * 2))
	_mesh.top_level = true
	add_child(_mesh)
	BuildKit.collider(self, BuildKit.box_shape(Vector3(14000, 2, 14000)), Vector3(0, -1, 0))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var step := SIZE / SUBDIV * 2.0
	var p := cam.global_position
	_mesh.global_position = Vector3(snappedf(p.x, step), 0, snappedf(p.z, step))


static func _ripple_texture(seed: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex
