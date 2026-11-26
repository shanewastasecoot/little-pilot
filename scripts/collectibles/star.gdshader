shader_type spatial;
// A star: the same look as the old StandardMaterial3D (gold, glowing), but
// the spin and bob are done here on the graphics card, so the 224 stars
// cost the processor nothing each frame (Graphics G1; they used to move
// their own mesh in _process). `phase` keeps them from bobbing in step.

uniform vec4 albedo : source_color = vec4(1.0, 0.8235, 0.2471, 1.0);
uniform vec4 emission_color : source_color = vec4(1.0, 0.7216, 0.0, 1.0);
uniform float emission_energy = 1.6;
uniform float roughness = 0.3;
uniform float spin_speed = 1.6;
uniform float bob_height = 0.6;
instance uniform float phase = 0.0;

void vertex() {
	float t = TIME + phase;
	float a = t * spin_speed;
	float c = cos(a);
	float s = sin(a);
	// Turn about the star's own up axis (as rotation.y did), then bob.
	mat3 r = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	VERTEX.y += sin(t * 2.0) * bob_height;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * emission_energy;
}
