shader_type spatial;
// Graphics G4: the terrain. The base is exactly the old look (the island's
// vertex colours, sRGB, rough), plus a soft, stylised detail pattern that
// shows up close and fades out with distance:
//   grass  clumps and tufts, and big meadow patches a little yellower/deeper
//   sand   fine grain and gentle wind ripples
//   rock   cracks and horizontal ledge bands (steep or grey ground)
//   snow   a faint, cool unevenness
// Which one comes from the vertex colour itself (green, sandy, grey, white)
// and the slope, so no extra data is needed. assets/terrain/detail.png
// (tools/make_terrain_detail.gd) holds four channels of soft noise.

uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float strength : hint_range(0.0, 2.0) = 1.0;  // 0 = exactly the old look
uniform float scale = 1.0;          // >1 = finer pattern
uniform float fade_start = 35.0;    // m: full detail nearer than this
uniform float fade_end = 170.0;     // m: none beyond this
uniform float patch_strength = 1.0; // the big meadow patches (seen further away)
uniform float roughness = 0.95;

varying vec3 v_world;
varying float v_up;  // world normal's y: 1 flat, 0 a cliff

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_up = normalize(mat3(MODEL_MATRIX) * NORMAL).y;
}

void fragment() {
	vec3 c = COLOR.rgb;  // sRGB
	vec3 base = srgb_to_linear(c);
	if (strength <= 0.0) {
		ALBEDO = base;
		ROUGHNESS = roughness;
	} else {
		float dist = length(v_world - CAMERA_POSITION_WORLD);
		float near = 1.0 - smoothstep(fade_start, fade_end, dist);
		float far = 1.0 - smoothstep(fade_end, fade_end * 4.0, dist);
		vec2 p = v_world.xz * scale;
		vec4 d1 = texture(detail_tex, p / 9.0);         // ~9 m tile
		vec4 d2 = texture(detail_tex, p / 2.3 + 0.37);  // ~2 m tile
		vec4 d3 = texture(detail_tex, p / 0.8 + 0.71);  // ~0.8 m: tufts, grain
		float big = texture(detail_tex, p / 140.0 + 0.61).a;  // meadow patches

		// What kind of ground, from the colour (sRGB) and the slope.
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float sat = (mx - mn) / max(mx, 0.001);
		float snow = smoothstep(0.86, 0.94, mn);
		float sand = smoothstep(0.05, 0.12, c.r - c.g) * smoothstep(0.15, 0.3, c.g - c.b) * (1.0 - snow);
		float grass = smoothstep(0.02, 0.1, c.g - max(c.r, c.b)) * (1.0 - snow);
		float rock = clamp(1.0 - snow - sand - grass, 0.0, 1.0);
		rock = max(rock, smoothstep(0.55, 0.4, v_up) * (1.0 - snow));  // (only real cliffs; the colour already greys steep ground)
		grass *= 1.0 - rock;

		// Each kind's pattern, as a brightness change around 1. Flecks are
		// small hard-edged specks (stylised tufts / grains), not photo noise.
		float fleck = smoothstep(0.58, 0.66, d3.r) - smoothstep(0.34, 0.26, d3.r);
		float g = (d1.r - 0.5) * 0.26 + (d2.r - 0.5) * 0.16 + fleck * 0.07;    // clumps, tufts
		float s = (d3.g - 0.5) * 0.1 + (d2.g - 0.5) * 0.06
			+ sin(v_world.x * 1.9 * scale + v_world.z * 0.6 * scale + d1.a * 6.0) * 0.035;  // grain, ripples
		float ledge = smoothstep(0.55, 0.95, sin(v_world.y * 0.9 + d1.a * 5.0));  // ledge bands
		float r = (d1.b - 0.6) * 0.32 + (d2.b - 0.6) * 0.16 + (d3.g - 0.5) * 0.08 - ledge * 0.13;  // cracks, gravel, ledges
		float w = (d1.a - 0.5) * 0.06 + (d3.g - 0.5) * 0.03;
		float k = grass * g + sand * s + rock * r + snow * w;
		vec3 col = base * (1.0 + k * strength * near);
		// Meadow patches: a touch yellower or deeper green, out to a few
		// hundred metres (they break up big flat greens from the air).
		vec3 warm = base * vec3(1.1, 1.06, 0.82);
		vec3 deep = base * vec3(0.86, 0.95, 0.88);
		float pt = (big - 0.5) * 2.0;
		col = mix(col, pt > 0.0 ? warm : deep, abs(pt) * 0.35 * grass * patch_strength * strength * far);
		ALBEDO = col;
		ROUGHNESS = roughness;
	}
}
