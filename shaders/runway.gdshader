shader_type spatial;
// Graphics G4: the runway's asphalt. The same grey as before, plus a fine
// grain, a few darker repair patches, and rubber tyre marks in the two
// touchdown zones (where landing wheels first hit), fading along the runway.
// Object space: the runway box is centred, long side along x.

uniform vec4 asphalt : source_color = vec4(0.333, 0.345, 0.373, 1.0);  // 55585f
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 half_size = vec2(450.0, 28.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;  // 0 = plain grey
uniform float roughness = 0.8;  // (as BuildKit.mat)

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 col = asphalt.rgb;
	if (strength > 0.0) {
		vec2 p = v_local.xz;
		vec4 d1 = texture(detail_tex, p / 7.0);
		vec4 d2 = texture(detail_tex, p / 1.7 + 0.21);
		float grain = (d2.g - 0.5) * 0.3 + (d1.r - 0.5) * 0.14;
		float patches = smoothstep(0.62, 0.7, texture(detail_tex, p / 60.0 + 0.4).a) * 0.18;
		// Tyre marks: two main-gear tracks either side of the centre line,
		// strongest just past each threshold, fading 250 m along.
		float from_end = half_size.x - abs(p.x);
		float zone = smoothstep(30.0, 70.0, from_end) * (1.0 - smoothstep(110.0, 300.0, from_end));
		float track = 0.0;
		for (int k = 0; k < 2; k++) {
			float lane = k == 0 ? -3.2 : 3.2;
			float wobble = (d1.a - 0.5) * 2.0;
			track += 1.0 - smoothstep(0.6, 1.9, abs(p.y - lane - wobble));
		}
		float streaks = smoothstep(0.35, 0.75, texture(detail_tex, vec2(p.x / 40.0, p.y / 3.0)).r);
		float rubber = clamp(track, 0.0, 1.0) * zone * (0.45 + 0.55 * streaks) * 0.6;
		col *= 1.0 + (grain - patches) * strength;
		col = mix(col, vec3(0.012, 0.012, 0.014), clamp(rubber * strength, 0.0, 0.9));  // (linear: nearly black rubber)
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
}
