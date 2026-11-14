shader_type spatial;
// Cheap stylised ocean: gentle vertex swell, two-tone colour, sun glints.
// No reflections or depth reads, so it's light on the Steam Deck GPU.

uniform vec4 deep_color : source_color = vec4(0.12, 0.52, 0.86, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.78, 0.95, 1.0);
uniform float wave_height = 0.6;
uniform float wave_scale = 0.02;

varying float v_wave;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 0.6;
	float h = sin(w.x * wave_scale + t) * 0.5 + sin(w.z * wave_scale * 1.3 + t * 1.2) * 0.5;
	VERTEX.y += h * wave_height;
	v_wave = h;
}

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(w.xz);
	// Lighter water near the island.
	float near = 1.0 - smoothstep(850.0, 1200.0, dist);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, near * 0.7 + v_wave * 0.08);
	// Sparkles
	float s = sin(w.x * 0.35 + TIME * 1.7) * sin(w.z * 0.31 - TIME * 1.3);
	col += vec3(smoothstep(0.96, 1.0, s)) * 0.35;
	ALBEDO = col;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
