class_name ModelRecolor
extends Node
## Recolours an imported model by swapping one hue range for another colour,
## on the GPU: every material under `target` is replaced by a small shader
## that does the swap per pixel (texture or flat colour), so changing colour
## is instant even with large textures. Used for plane paint jobs, house
## roofs and anything else that needs a colour variant without editing the
## original asset.

## A MeshInstance3D, or any node whose MeshInstance3D descendants to recolour.
@export var target: Node3D
## Hue (0..1) to replace and how far around it counts as a match.
@export var from_hue: float = 0.0
@export var hue_range: float = 0.06
## Colours less saturated than this are left alone (greys, whites). Lower
## it for pastel parts (e.g. Kenney's soft teal roofs).
@export var min_saturation: float = 0.28
@export var to_color: Color = Color("3f8cff")
## Instead of swapping a hue range: recolour exactly the surfaces whose
## material has one of these names (models with flat, named paint
## materials, like the vinish.dev planes: "Paint_White", "Paint_Yellow").
@export var materials: PackedStringArray = []

const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float from_hue = 0.0;
uniform float hue_range = 0.06;
uniform float min_sat = 0.28;
uniform vec3 to_hsv = vec3(0.6, 0.7, 1.0);
uniform float roughness = 0.6;
uniform float metallic = 0.0;
// (Graphics G3) baked contact shading in the vertex colours, if any.
uniform bool use_vertex_shade = false;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	vec3 hsv = rgb2hsv(to_srgb(c.rgb));
	float d = abs(fract(hsv.x - from_hue + 0.5) - 0.5);
	float k = (1.0 - smoothstep(hue_range * 0.75, hue_range, d)) * smoothstep(min_sat, min_sat + 0.12, hsv.y);
	// Keep the model's shading (value relative to its brightest), take the
	// paint's hue, saturation and brightness.
	float shade = clamp(hsv.z / 0.96, 0.4, 1.1);
	vec3 painted = to_linear(hsv2rgb(vec3(to_hsv.x, to_hsv.y, clamp(to_hsv.z * shade, 0.0, 1.0))));
	ALBEDO = mix(c.rgb, painted, k);
	if (use_vertex_shade) {
		ALBEDO *= COLOR.rgb;
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
"""

static var _shader: Shader
## Shared per (source material, from_hue, to_color) so many copies batch.
static var _cache: Dictionary = {}


func _ready() -> void:
	apply(to_color)


## Recolour to `color` (cached per colour, so switching is instant).
func apply(color: Color) -> void:
	to_color = color
	if target == null:
		return
	var meshes: Array = target.find_children("*", "MeshInstance3D", true, false)
	if target is MeshInstance3D:
		meshes.append(target)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if not materials.is_empty():
				if not materials.has(mat.resource_name):
					continue
				var nkey := "%d:named:%s" % [mat.get_instance_id(), to_color.to_html()]
				if not _cache.has(nkey):
					var painted := mat.duplicate() as BaseMaterial3D
					painted.albedo_color = to_color
					_cache[nkey] = painted
				mi.set_surface_override_material(i, _cache[nkey])
				continue
			var key := "%d:%.3f:%s:%.2f" % [mat.get_instance_id(), from_hue, to_color.to_html(), min_saturation]
			if not _cache.has(key):
				_cache[key] = _shader_material(mat)
			mi.set_surface_override_material(i, _cache[key])


func _shader_material(mat: BaseMaterial3D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", mat.albedo_color)
	m.set_shader_parameter("use_tex", mat.albedo_texture != null)
	if mat.albedo_texture:
		m.set_shader_parameter("albedo_tex", mat.albedo_texture)
	m.set_shader_parameter("from_hue", from_hue)
	m.set_shader_parameter("hue_range", hue_range)
	m.set_shader_parameter("min_sat", min_saturation)
	m.set_shader_parameter("to_hsv", Vector3(to_color.h, to_color.s, to_color.v))
	m.set_shader_parameter("roughness", mat.roughness)
	m.set_shader_parameter("metallic", mat.metallic)
	m.set_shader_parameter("use_vertex_shade", mat.vertex_color_use_as_albedo)
	return m
