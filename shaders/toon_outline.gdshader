shader_type spatial;
// Soft outline for the toon look (next pass of toon.gdshader): the mesh
// pushed out along its normals and drawn back-faces only, in a darkened
// version of the part's own colour (so it reads as a soft edge, not a
// black line).
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
// Outline width in the mesh's own units.
uniform float width = 0.014;
uniform float darkness = 0.35;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	VERTEX += normalize(NORMAL) * width;
}

void fragment() {
	vec3 base = use_texture ? texture(albedo_tex, UV).rgb : srgb_to_linear(COLOR.rgb);
	ALBEDO = base * darkness;
}
