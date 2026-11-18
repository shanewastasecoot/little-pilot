shader_type spatial;
// Toon look for the player character and its props (one style for both):
// two soft cel bands, a gentle rim light, no shiny highlights. Parts are
// coloured by a palette texture (KayKit) or by vertex colours (props).
// The outline is a second pass: toon_outline.gdshader.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
// How dark the shaded side is (fraction of the lit colour).
uniform float shade = 0.62;
// Width of the soft step between lit and shaded.
uniform float softness = 0.08;
uniform float rim_strength = 0.28;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	ALBEDO = use_texture ? texture(albedo_tex, UV).rgb : srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	// Soft-edged cel step, and shadows stepped the same way.
	float lit = smoothstep(-softness, softness, nl) * smoothstep(0.25, 0.6, ATTENUATION);
	float band = mix(shade, 1.0, lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	// A light rim on the edges facing away from the camera.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * rim_strength * (0.4 + 0.6 * lit) / PI;
}
