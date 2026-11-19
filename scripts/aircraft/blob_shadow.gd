class_name BlobShadow
extends MeshInstance3D
## A soft round shadow on the ground (or the sea) right under the plane,
## darker the lower it flies and gone above FADE_HEIGHT, so a child can
## judge how high they are when coming in to land. One small unshaded quad.

const FADE_HEIGHT := 70.0
const MAX_ALPHA := 0.42
## Shadow radius as a multiple of the plane's size (grows a little with height).
const SIZE := 5.5

var _plane: Aircraft
var _mat: ShaderMaterial

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float alpha = 0.4;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.05, 0.07, 0.12);
	ALPHA = alpha * (1.0 - smoothstep(0.35, 1.0, d));
}
"""


func _ready() -> void:
	_plane = get_parent() as Aircraft
	top_level = true  # placed in world space, not riding along with the plane's tilt
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material_override = _mat
	visible = false


func _physics_process(_delta: float) -> void:
	# Parked or crashed: the real shadow is enough.
	if _plane == null or _plane.mode == Aircraft.Mode.PARKED or _plane.mode == Aircraft.Mode.CRASHED:
		visible = false
		return
	var p := _plane.global_position
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * (FADE_HEIGHT + 10.0), GameSettings.LAYER_WORLD)
	q.exclude = [_plane.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var sea := Waves.height(p.x, p.z) + 0.3
	var ground := sea
	var normal := Vector3.UP
	if not hit.is_empty() and (hit.position as Vector3).y > sea:
		ground = (hit.position as Vector3).y
		normal = hit.normal
	var height := p.y - ground
	if height > FADE_HEIGHT:
		visible = false
		return
	visible = true
	var t := clampf(height / FADE_HEIGHT, 0.0, 1.0)
	_mat.set_shader_parameter("alpha", MAX_ALPHA * (1.0 - t) * (1.0 - t))
	var s := SIZE * _plane.stats.model_scale * (1.0 + t * 0.6)
	var b := Basis(Quaternion(Vector3.UP, normal))
	global_transform = Transform3D(b.scaled(Vector3(s, 1.0, s)), Vector3(p.x, ground + 0.25, p.z))
