shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
// Stylised-but-believable ocean for the Steam Deck:
//  * six Gerstner waves (three long swells, three choppy short waves) on a
//    grid that is dense under the camera and sparse at the horizon; the
//    same waves (scripts/world/waves.gd) move boats, the whale and spray
//  * per-pixel wave normals, so even far, coarse water has crisp swells
//  * three scrolling ripple normal maps (fine detail fades with distance
//    to avoid shimmering)
//  * Fresnel sky reflection, sun glints, light glowing through crests
//  * depth-based colour: clear turquoise shallows, deep blue offshore
//  * refraction of the sea floor and anything underwater
//  * textured foam: lapping shore foam, foam around anything touching the
//    surface (rocks, boats, the whale) and whitecaps on steep crests
// No screen-space reflections, so it stays cheap on the Deck.

uniform vec4 deep_color : source_color = vec4(0.03, 0.24, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(0.05, 0.45, 0.72, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.86, 0.83, 1.0);
uniform vec4 crest_color : source_color = vec4(0.20, 0.85, 0.78, 1.0);
uniform vec4 sky_color : source_color = vec4(0.70, 0.86, 1.0, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform sampler2D ripples_a : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ripples_b : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ripples_c : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// Wave table from Waves.gd: xy direction, z steepness, w wavelength (m);
// fades: distance from the camera where each wave flattens out.
uniform vec4 waves[6];
uniform vec2 fades[6];
uniform float wave_time = 0.0;
uniform float swell = 1.0;
// Grid warp: half size (m) and the linear share of the warp curve.
uniform float half_size = 4500.0;
uniform float warp_linear = 0.06;

uniform float refraction_strength = 0.02;
uniform float clarity = 0.75;
uniform float foam_width = 1.8;

varying vec3 v_world;
varying float v_crest;
varying float v_fold;

float fade(int i, float dist) {
	vec2 f = fades[i];
	return f.y <= 0.0 ? 1.0 : 1.0 - smoothstep(f.x, f.y, dist);
}

// Gerstner wave i at rest point p (xz). Adds tangent-space derivatives.
vec3 gerstner(int i, vec2 p, float dist, inout vec3 tangent, inout vec3 binormal, inout float fold) {
	vec4 w = waves[i];
	float k = 6.28318 / w.w;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p) - c * wave_time * 0.6);
	float q = w.z * swell * fade(i, dist);
	float a = q / k;
	float s = sin(f);
	float co = cos(f);
	tangent += vec3(-d.x * d.x * q * s, d.x * q * co, -d.x * d.y * q * s);
	binormal += vec3(-d.x * d.y * q * s, d.y * q * co, -d.y * d.y * q * s);
	fold += q * s;  // surface bunches up (Jacobian shrinks) where this is high
	return vec3(d.x * a * co, a * s, d.y * a * co);
}

void vertex() {
	// Warp the even grid: fine under the camera, coarse at the horizon.
	vec2 u = VERTEX.xz / half_size;
	VERTEX.xz = half_size * (warp_linear * u + (1.0 - warp_linear) * u * u * u);
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(p.xz - CAMERA_POSITION_WORLD.xz);
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	float fold = 0.0;
	vec3 offset = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		offset += gerstner(i, p.xz, dist, t, b, fold);
	}
	VERTEX += offset;
	NORMAL = normalize(cross(b, t));
	v_world = p + offset;
	v_crest = offset.y;
	v_fold = fold;
}

void fragment() {
	vec2 uv = v_world.xz;
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float far = smoothstep(150.0, 1500.0, dist);

	// Per-pixel wave normal (rest point approximated by the displaced one).
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	float fold = 0.0;
	for (int i = 0; i < 6; i++) {
		gerstner(i, uv, dist, t, b, fold);
	}
	vec3 wn = normalize(cross(b, t));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Ripples: two drifting layers plus a fine close-up layer.
	vec3 n1 = texture(ripples_a, uv / 52.0 + vec2(wave_time * 0.011, wave_time * 0.006)).xyz;
	vec3 n2 = texture(ripples_b, uv / 23.0 - vec2(wave_time * 0.008, -wave_time * 0.014)).xyz;
	vec3 n3 = texture(ripples_c, uv / 7.0 + vec2(-wave_time * 0.03, wave_time * 0.021)).xyz;
	vec3 nm = mix(n1, n2, 0.5);
	nm = mix(nm, n3, 0.35 * (1.0 - smoothstep(20.0, 160.0, dist)));
	NORMAL_MAP = normalize(nm);
	NORMAL_MAP_DEPTH = mix(0.65, 0.25, far);

	// Water depth under this pixel: scene depth behind the surface minus ours.
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = clamp(length(behind.xyz) - length(VERTEX), 0.0, 400.0);

	float shallow = exp(-water_depth * 0.28);
	float mid = exp(-water_depth * 0.12);
	vec3 col = mix(deep_color.rgb, mid_color.rgb, mid);
	col = mix(col, shallow_color.rgb, shallow);

	// Sunlight glowing through the thin tops of waves (seen side-on).
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float glow = smoothstep(0.2, 2.2, v_crest) * (1.0 - facing) * (1.0 - far);
	col = mix(col, crest_color.rgb, glow * 0.6);

	// Fresnel: water looks like the sky when seen at a low angle.
	float fresnel = pow(1.0 - facing, 4.0);
	col = mix(col, sky_color.rgb, fresnel * 0.6);

	// Foam pattern: two scrolling layers of bubbly cells.
	float fa = texture(foam_tex, uv / 9.0 + vec2(wave_time * 0.02, 0.0)).r;
	float fb = texture(foam_tex, uv / 5.3 - vec2(0.0, wave_time * 0.027)).r;
	float bubbles = fa * fb;
	// Shore foam laps in and out with a slow rhythm.
	float lap = 0.65 + 0.35 * sin(wave_time * 1.3 - water_depth * 1.6);
	float shore = smoothstep(foam_width * lap * 1.4, foam_width * lap * 0.3, water_depth);
	shore *= smoothstep(0.08, 0.35, bubbles + shore * 0.25);
	// Whitecaps where the waves bunch up into steep crests.
	float cap = smoothstep(0.12, 0.24, v_fold) * smoothstep(0.1, 0.3, bubbles) * (1.0 - far);
	float foam = clamp(shore + cap * 0.8, 0.0, 1.0);
	col = mix(col, foam_color.rgb, foam);

	// Refraction: look at what's under the surface through wobbling water,
	// tinted by the water colour; deep water is opaque.
	vec2 wobble = (NORMAL_MAP.xy - 0.5) * refraction_strength * (1.0 - shallow * 0.5);
	vec3 below = textureLod(screen_tex, SCREEN_UV + wobble, 1.5).rgb;
	float see_through = shallow * clarity * (1.0 - foam);
	col = mix(col, below * mix(vec3(1.0), shallow_color.rgb, 0.55), see_through);

	ALBEDO = col;
	ALPHA = 1.0;
	// Glassy up close (sharp sun glints), softer far away (no sparkle noise).
	ROUGHNESS = mix(mix(0.04, 0.16, far), 0.7, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.6, 0.2, foam);
}
