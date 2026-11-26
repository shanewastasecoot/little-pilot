shader_type spatial;
// Trees in the wind (Phase 11, the FOLIAGE style profile): the tree's own
// colour (and texture, and vertex colours) like its original material, with
// a gentle sway: none at the foot, a little in the trunk, more up in the
// leaves; each tree out of step with its neighbours (phased by where it
// stands); fading out with distance. Colours are kept in the shared
// saturation / brightness range of the world's style.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
// The mesh's height (model space), so the sway can grow with height.
uniform float height = 1.0;
// 0 for a trunk surface, 1 for leaves.
uniform float leafiness : hint_range(0.0, 1.0) = 1.0;
uniform float sway = 0.06;          // fraction of the height at the top
uniform float sway_speed = 1.3;
uniform float fade_start = 120.0;
uniform float fade_end = 260.0;
uniform float max_saturation = 0.9;
uniform vec2 value_range = vec2(0.18, 0.95);
uniform bool alpha_scissor = false;
uniform float alpha_cut = 0.5;
// Graphics G3: a little darker at the foot, where the tree meets the ground.
uniform float base_shade : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;
varying float v_h;

vec3 to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / max(height, 0.001), 0.0, 1.0);
	v_h = h;
	float bend = h * h * mix(0.25, 1.0, leafiness);
	float dist = length(origin - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	float phase = origin.x * 0.11 + origin.z * 0.07;
	float t = TIME * sway_speed + phase;
	vec2 wind = vec2(sin(t) + 0.35 * sin(t * 2.3 + 1.1), 0.6 * cos(t * 0.8 + 0.4)) * sway * height * bend * fade;
	// Sway in world space (the same way for every tree), into model space.
	vec3 w = (inverse(mat3(MODEL_MATRIX)) * vec3(wind.x, 0.0, wind.y));
	VERTEX += w;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo_color;
	if (use_texture) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vertex_color) {
		c.rgb *= COLOR.rgb;
	}
	// The shared range is in everyday (sRGB) terms, like the rest of the
	// style profiles: clamp there, then back to linear for lighting.
	vec3 srgb = pow(max(c.rgb, vec3(0.0)), vec3(1.0 / 2.2));
	vec3 hsv = to_hsv(srgb);
	hsv.y = min(hsv.y, max_saturation);
	hsv.z = clamp(hsv.z, value_range.x, value_range.y);
	ALBEDO = pow(to_rgb(hsv), vec3(2.2)) * mix(1.0 - base_shade, 1.0, smoothstep(0.0, 0.22, v_h));
	ROUGHNESS = roughness;
	SPECULAR = specular;
	if (alpha_scissor) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
}
