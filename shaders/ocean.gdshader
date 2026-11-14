shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
// Stylised-but-believable ocean for the Steam Deck:
//  * three Gerstner swells in the vertex shader (correct lighting normals)
//  * two scrolling noise normal maps for fine ripples and sun glints
//  * Fresnel sky reflection at grazing angles
//  * depth-based colour: clear turquoise shallows, deep blue offshore,
//    white foam where the water meets the shore
// No screen-space reflections or refraction, so it stays cheap.

uniform vec4 deep_color : source_color = vec4(0.05, 0.32, 0.62, 1.0);
uniform vec4 mid_color : source_color = vec4(0.07, 0.52, 0.78, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.86, 0.85, 1.0);
uniform vec4 sky_color : source_color = vec4(0.70, 0.86, 1.0, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform sampler2D ripples_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D ripples_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float swell = 1.0;

varying vec3 v_world;
varying float v_crest;

// Gerstner wave: x/y = direction, z = steepness, w = wavelength (m).
vec3 gerstner(vec4 w, vec3 p, inout vec3 tangent, inout vec3 binormal) {
	float k = 6.28318 / w.w;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p.xz) - c * TIME * 0.6);
	float a = w.z / k;
	tangent += vec3(-d.x * d.x * w.z * sin(f), d.x * w.z * cos(f), -d.x * d.y * w.z * sin(f));
	binormal += vec3(-d.x * d.y * w.z * sin(f), d.y * w.z * cos(f), -d.y * d.y * w.z * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 offset = vec3(0.0);
	offset += gerstner(vec4(1.0, 0.35, 0.05 * swell, 170.0), p, t, b);
	offset += gerstner(vec4(-0.4, 1.0, 0.04 * swell, 95.0), p, t, b);
	offset += gerstner(vec4(0.7, -0.8, 0.035 * swell, 61.0), p, t, b);
	VERTEX += offset;
	NORMAL = normalize(cross(b, t));
	v_world = p + offset;
	v_crest = offset.y;
}

void fragment() {
	vec2 uv = v_world.xz;
	vec3 n1 = texture(ripples_a, uv / 46.0 + vec2(TIME * 0.012, TIME * 0.007)).xyz;
	vec3 n2 = texture(ripples_b, uv / 27.0 - vec2(TIME * 0.009, -TIME * 0.013)).xyz;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.55;

	// Water depth under this pixel: scene depth behind the surface minus ours.
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = clamp(length(behind.xyz) - length(VERTEX), 0.0, 400.0);

	// Fully deep blue by ~24 m, matching where the sea floor mesh stops.
	float shallow = exp(-water_depth * 0.28);
	float mid = exp(-water_depth * 0.13);
	vec3 col = mix(deep_color.rgb, mid_color.rgb, mid);
	col = mix(col, shallow_color.rgb, shallow);

	// Fresnel: water looks like the sky when seen at a low angle.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_color.rgb, fresnel * 0.55);

	// Shoreline foam (breaking up with the ripple pattern) and crest foam.
	float ripple = n1.r * 0.5 + n2.g * 0.5;
	float shore = smoothstep(1.6, 0.0, water_depth + (ripple - 0.5) * 1.2);
	float crest = smoothstep(1.2, 1.8, v_crest) * 0.12;
	col = mix(col, foam_color.rgb, clamp(shore + crest, 0.0, 1.0));

	ALBEDO = col;
	ALPHA = clamp(0.6 + (1.0 - mid) * 0.4 + shore, 0.0, 1.0);
	ROUGHNESS = mix(0.06, 0.6, shore);
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
