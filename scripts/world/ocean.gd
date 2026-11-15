class_name Ocean
extends Node3D
## The sea. A wave mesh that follows the camera (the shader warps its even
## grid so it's ~1.7 m quads underneath and ~60 m at the horizon), a flat
## collider at sea level for the safety system, generated ripple normal maps
## and foam. Drives the shared wave clock in Waves.

const SIZE := 9000.0
const SUBDIV := 320
const WARP_LINEAR := 0.06
## Grid spacing right under the camera (the warp's slope at the centre).
const STEP := SIZE / (SUBDIV + 1) * WARP_LINEAR

var _mesh: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = SUBDIV
	plane.subdivide_depth = SUBDIV
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	# Reading the screen puts the sea in the transparent pass; draw it first
	# so spray, splashes and clouds always show on top of it.
	mat.render_priority = -100
	mat.set_shader_parameter("ripples_a", _ripple_texture(3, 0.012, 512, 6.0))
	mat.set_shader_parameter("ripples_b", _ripple_texture(8, 0.02, 512, 5.0))
	mat.set_shader_parameter("ripples_c", _ripple_texture(21, 0.035, 256, 3.0))
	mat.set_shader_parameter("foam_tex", _foam_texture())
	mat.set_shader_parameter("waves", Waves.shader_dirs())
	mat.set_shader_parameter("fades", Waves.shader_fades())
	mat.set_shader_parameter("half_size", SIZE * 0.5)
	mat.set_shader_parameter("warp_linear", WARP_LINEAR)
	_mat = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = AABB(Vector3(-SIZE, -5, -SIZE), Vector3(SIZE * 2, 10, SIZE * 2))
	_mesh.top_level = true
	add_child(_mesh)
	var body := BuildKit.collider(self, BuildKit.box_shape(Vector3(14000, 2, 14000)), Vector3(0, -1, 0))
	body.add_to_group("water")


func _process(delta: float) -> void:
	Waves.time += delta
	_mat.set_shader_parameter("wave_time", Waves.time)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	Waves.camera = p
	# Snap to the finest grid step so the waves under the camera never swim.
	_mesh.global_position = Vector3(snappedf(p.x, STEP), 0, snappedf(p.z, STEP))


static func _ripple_texture(seed: int, frequency: float, size: int, bump: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency * 256.0 / size
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.45
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = bump
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex


## Bubbly foam cells (bright rims, dark middles) for whitecaps and shores.
static func _foam_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = 5
	noise.frequency = 0.03
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.normalize = true
	tex.noise = noise
	return tex
