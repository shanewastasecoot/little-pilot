shader_type spatial;
// Townspeople crowd: plays baked walk/idle loops from a vertex animation
// texture (tools/bake_kaykit_people.gd), so every copy of a character is one
// MultiMesh draw. Per instance (INSTANCE_CUSTOM): r = time offset (s),
// g = 1 when standing (idle loop), else walking.
render_mode cull_back;

uniform sampler2D vat : filter_nearest, repeat_disable;
uniform int walk_frames = 20;
uniform int idle_frames = 25;
uniform float bake_fps = 12.0;

varying vec3 v_col;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	int column = int(UV2.x);
	int total = walk_frames + idle_frames;
	float t = (TIME + INSTANCE_CUSTOM.r) * bake_fps;
	int f = INSTANCE_CUSTOM.g > 0.5
		? walk_frames + int(mod(t, float(idle_frames)))
		: int(mod(t, float(walk_frames)));
	VERTEX = texelFetch(vat, ivec2(column, f), 0).xyz;
	NORMAL = normalize(texelFetch(vat, ivec2(column, f + total), 0).xyz);
	v_col = to_linear(COLOR.rgb);
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.8;
}
