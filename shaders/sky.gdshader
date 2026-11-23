shader_type sky;
// The sky (Phase 11): a soft gradient from the horizon up (the colours the
// procedural sky used), a sun disc with a warm glow round it, and a faint
// layer of high, wispy cloud. No TIME: the sky (and the light it gives the
// world) is drawn once, not every frame.

uniform vec4 top_color : source_color = vec4(0.184, 0.549, 0.961, 1.0);      // 2f8cf5
uniform vec4 horizon_color : source_color = vec4(0.749, 0.902, 1.0, 1.0);    // bfe6ff
uniform vec4 ground_horizon_color : source_color = vec4(0.749, 0.902, 1.0, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.184, 0.498, 0.753, 1.0); // 2f7fc0
uniform float curve : hint_range(0.01, 1.0) = 0.12;
uniform float sun_size : hint_range(0.0, 0.2) = 0.035;      // radians
uniform float sun_glow : hint_range(0.0, 1.0) = 0.35;
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y >= 0.0) {
		// Like the procedural sky: the horizon colour rising into the top.
		float t = pow(clamp(d.y, 0.0, 1.0), curve);
		col = mix(horizon_color.rgb, top_color.rgb, t);
		// High wispy cloud, stretched along the sky, thinning to the zenith
		// and gone at the horizon (so far islands stay clear).
		if (cloud_amount > 0.0 && d.y > 0.03 && d.y < 0.95) {
			vec2 uv = d.xz / max(d.y + 0.25, 0.05) * 1.6;
			float c = fbm(uv * vec2(1.0, 2.6));
			c = smoothstep(0.55, 0.85, c) * cloud_amount;
			c *= smoothstep(0.03, 0.25, d.y) * (1.0 - smoothstep(0.6, 1.0, d.y));
			col = mix(col, cloud_color.rgb, c * 0.55);
		}
	} else {
		float t = pow(clamp(-d.y, 0.0, 1.0), curve);
		col = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, t);
	}
	// The sun: a disc and a soft glow round it.
	if (LIGHT0_ENABLED) {
		float a = acos(clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0));
		float disc = 1.0 - smoothstep(sun_size * 0.8, sun_size, a);
		float glow = exp(-a * 9.0) * sun_glow;
		col += sun_color.rgb * (disc * 4.0 + glow) * LIGHT0_ENERGY * 0.5;
	}
	COLOR = col;
}
