class_name Ocean
extends Node3D
## The sea. A wave mesh that follows the camera (the shader warps its even
## grid so it's ~1.7 m quads underneath and ~60 m at the horizon), a flat
## collider at sea level for the safety system, a baked wind-wave normal map
## and generated foam. Drives the shared wave clock in Waves.

const SIZE := 9000.0
const SUBDIV := 320
const WARP_LINEAR := 0.06
## Seamless wind-wave normal map baked from an ocean spectrum (~570 waves).
const RIPPLES := "res://assets/environment/water/ocean_normal.png"
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
	if BenchToggles.value("refraction") == "off":
		mat.shader = _without_refraction(mat.shader)
	# Reading the screen puts the sea in the transparent pass; draw it first
	# so spray, splashes and clouds always show on top of it.
	mat.render_priority = -100
	mat.set_shader_parameter("ripples", load(RIPPLES))
	mat.set_shader_parameter("foam_tex", _foam_texture())
	mat.set_shader_parameter("waves", Waves.shader_dirs())
	var fades := Waves.shader_fades()
	if BenchToggles.value("far-waves") == "simple":
		# (Bench toggle) far waves fade out at half the distance.
		for i in fades.size():
			fades[i] *= 0.5
	mat.set_shader_parameter("fades", fades)
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


## (Bench toggle) the ocean shader without its see-through refraction: no
## screen read, so no screen copy for the sea. Made from the real shader's
## code, so the two never drift apart.
static func _without_refraction(src: Shader) -> Shader:
	var code := src.code
	code = code.replace("uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;", "")
	code = code.replace("vec3 below = textureLod(screen_tex, SCREEN_UV + wobble, 1.5).rgb;", "vec3 below = col;")
	var sh := Shader.new()
	sh.code = code
	return sh


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
