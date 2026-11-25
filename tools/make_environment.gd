extends Node
## Writes resources/world_environment.tres (Phase 11): the island's sky, fog,
## glow and tonemap, which used to be built in code in island_map.gd. Run it
## to (re)make the file from these starting values; after that, tune the look
## live in the Godot editor by opening the .tres (running this again would
## put these values back). Step 1 wrote exactly what the code used; step 2
## changed the sky to shaders/sky.gdshader and softened the fog.

const OUT := "res://resources/world_environment.tres"


func _ready() -> void:
	# The sky: shaders/sky.gdshader (a soft gradient in the old sky's colours,
	# a sun disc with a glow, faint high cloud).
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", Color("2f8cf5"))
	sky_mat.set_shader_parameter("horizon_color", Color("bfe6ff"))
	sky_mat.set_shader_parameter("ground_horizon_color", Color("bfe6ff"))
	sky_mat.set_shader_parameter("ground_bottom_color", Color("2f7fc0"))
	sky_mat.set_shader_parameter("curve", 0.12)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color("cfeaff")
	# Far islands read as hazy and "over there", not gone: a little less
	# fog, and the fog takes the sky's colour in the direction you look.
	env.fog_density = 0.00026
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.1
	var err := ResourceSaver.save(env, OUT)
	print("Wrote %s (%s)" % [OUT, error_string(err)])
	get_tree().quit()
