class_name LookVariants
extends RefCounted
## Graphics G2: the lighting and environment options, as settings applied on
## top of the current look for a screenshot A/B (./dev.sh shots -- --variants=...).
## Nothing here changes the game. The parent's picks (Nov 26: AgX,
## softer glow, horizon fog + haze, golden sun with ambient 0.6, no extra
## grade, warm indoors) are now the defaults in world_environment.tres,
## island_map.gd, environment/indoor.tres and building_generator.gd, so
## these variants now apply on top of that new look.
##
## Each variant: "item" (the plan's G2 item number), "label" (plain words),
## "env" (outdoor Environment properties), "sun" (DirectionalLight3D
## properties), "indoor" (indoor Environment properties), "lut" (a colour
## grade made here), "lamps" (glowing bulbs in lamp shades, indoors),
## "terrain" / "runway" (G4 shader parameters), "aa" (G5: an --bench-aa
## value, BenchToggles.aa_settings), "shadow_size" (G5: the sun's shadow map), "shadow_filter" (G5: soft
## shadow filter quality 0-5; more = smoother shadow edges, no dots).

## The sky's horizon colour (shaders/sky.gdshader, world_environment.tres).
const HORIZON := Color(0.7490196, 0.9019608, 1.0)

const VARIANTS := {
	"current": {"item": 0, "label": "Now (no change)"},
	# 1. Tonemapper, saturation re-balanced so colours stay bright.
	"agx": {"item": 1, "label": "AgX tonemapper (saturation 1.45, contrast 1.14)",
		"env": {"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 1.0, "adjustment_saturation": 1.45, "adjustment_contrast": 1.14}},
	"filmic": {"item": 1, "label": "Filmic tonemapper (saturation 1.25, contrast 1.14)",
		"env": {"tonemap_mode": Environment.TONE_MAPPER_FILMIC, "tonemap_exposure": 1.0, "adjustment_saturation": 1.25, "adjustment_contrast": 1.14}},
	# 2. Glow.
	"glow_soft": {"item": 2, "label": "Glow 0.75, threshold 1.0",
		"env": {"glow_intensity": 0.75, "glow_hdr_threshold": 1.0}},
	"glow_more": {"item": 2, "label": "Glow 0.85, threshold 0.9",
		"env": {"glow_intensity": 0.85, "glow_hdr_threshold": 0.9}},
	# 3. Fog.
	"fog_match": {"item": 3, "label": "Fog colour = the sky's horizon exactly",
		"env": {"fog_light_color": HORIZON}},
	"fog_haze": {"item": 3, "label": "Horizon-coloured fog, a bit thicker, more distance haze",
		"env": {"fog_light_color": HORIZON, "fog_density": 0.00036, "fog_aerial_perspective": 0.6}},
	# 4. Sun and ambient.
	"sun_gold_06": {"item": 4, "label": "Golden sun, ambient 0.6",
		"sun": {"light_color": Color(1.0, 0.92, 0.78)}, "env": {"ambient_light_energy": 0.6}},
	"sun_gold_07": {"item": 4, "label": "Golden sun, ambient 0.7 (softest shadows)",
		"sun": {"light_color": Color(1.0, 0.92, 0.78)}, "env": {"ambient_light_energy": 0.7}},
	# 5. Grade: plain contrast/saturation versus a warm storybook LUT.
	"grade_plain": {"item": 5, "label": "Plain: contrast 1.12, saturation 1.15",
		"env": {"adjustment_contrast": 1.12, "adjustment_saturation": 1.15}},
	"grade_lut": {"item": 5, "label": "Warm storybook colour grade (LUT)", "lut": true},
	# Graphics G4: close-up terrain detail (and the runway's asphalt), by strength.
	"g4_off": {"item": 40, "label": "Off (plain colours, as before)", "terrain": {"strength": 0.0}, "runway": {"strength": 0.0}},
	"g4_subtle": {"item": 40, "label": "Subtle", "terrain": {"strength": 0.6}, "runway": {"strength": 0.6}},
	"g4_medium": {"item": 40, "label": "Medium", "terrain": {"strength": 1.0}, "runway": {"strength": 1.0}},
	"g4_strong": {"item": 40, "label": "Strong", "terrain": {"strength": 1.6}, "runway": {"strength": 1.6}},
	# Graphics G5: smoothing jagged edges (item 50) and shadow detail (51).
	# The parent's pick (Nov 27): 4x MSAA with the high filter, 4096 map:
	# now the defaults in project.godot, so "aa_msaa4_sf3" is the current look.
	# Filter 3 (high) removes the dotty pattern at shadow edges that the
	# low filter leaves (FXAA's blur was half hiding it).
	"aa_now": {"item": 50, "label": "Before G5 (2x MSAA + FXAA, low shadow filter)", "aa": "msaa2+fxaa", "shadow_filter": 1},
	"aa_fxaa_sf3": {"item": 50, "label": "Smooth shadow edges (2x MSAA + FXAA)", "aa": "msaa2+fxaa", "shadow_filter": 3},
	"aa_smaa_sf3": {"item": 50, "label": "Smooth shadow edges + sharper SMAA", "aa": "msaa2+smaa", "shadow_filter": 3},
	"aa_msaa4_sf3": {"item": 50, "label": "Smooth shadow edges + 4x MSAA", "aa": "msaa4", "shadow_filter": 3},
	"sh_4096": {"item": 51, "label": "Shadow map 4096 (as now)", "shadow_size": 4096, "shadow_filter": 3},
	"sh_2048": {"item": 51, "label": "Shadow map 2048", "shadow_size": 2048, "shadow_filter": 3},
	# 6. Indoors.
	"indoor_warm": {"item": 6, "label": "Warmer, softer light indoors, glowing lamps",
		"indoor": {"ambient_light_color": Color(1.0, 0.86, 0.68), "ambient_light_energy": 0.55,
			"glow_enabled": true, "glow_intensity": 0.6, "glow_hdr_threshold": 1.0},
		"room_lights": {"light_color": Color("ffd49a"), "light_energy": 0.42}, "lamps": true},
}

var _saved := []  # [object, property, old value]
var _added: Array[Node] = []
var _shadow_changed := false


## Applies variant `name` (undo with restore()). `lamps_in`: the interior to
## put glowing bulbs in, if the variant asks for them.
func apply(name: String, env: Environment, sun: DirectionalLight3D, indoor: Environment, lamps_in: Node = null) -> void:
	var v: Dictionary = VARIANTS[name]
	_set_all(env, v.get("env", {}))
	_set_all(sun, v.get("sun", {}))
	_set_all(indoor, v.get("indoor", {}))
	for k in v.get("terrain", {}):
		_set_all(TerrainBuilder.material(), {"shader_parameter/" + k: v.terrain[k]})
	for k in v.get("runway", {}):
		_set_all(Airport.runway_material(), {"shader_parameter/" + k: v.runway[k]})
	var vp := (Engine.get_main_loop() as SceneTree).root
	if v.has("aa"):
		var aa := BenchToggles.aa_settings(v.aa)
		_set_all(vp, {"msaa_3d": aa[0], "screen_space_aa": aa[1]})
	if v.has("shadow_size"):
		RenderingServer.directional_shadow_atlas_set_size(v.shadow_size, true)
		_shadow_changed = true
	if v.has("shadow_filter"):
		RenderingServer.directional_soft_shadow_filter_set_quality(v.shadow_filter)
		_shadow_changed = true
	if v.get("lut", false) and env:
		_set_all(env, {"adjustment_color_correction": warm_lut()})
	if lamps_in and v.has("room_lights"):
		for r: Dictionary in lamps_in.get("rooms"):
			if r.get("light") is OmniLight3D:
				_set_all(r.light, v.room_lights)
	if v.get("lamps", false) and lamps_in:
		for n in lamps_in.find_children("lamp_standing*", "Node3D", true, false) + lamps_in.find_children("lamp_table*", "Node3D", true, false):
			_add_bulb(n as Node3D)


func restore() -> void:
	for i in range(_saved.size() - 1, -1, -1):
		var s: Array = _saved[i]
		if is_instance_valid(s[0]):
			s[0].set(s[1], s[2])
	_saved.clear()
	for n in _added:
		if is_instance_valid(n):
			n.queue_free()
	_added.clear()
	if _shadow_changed:
		RenderingServer.directional_shadow_atlas_set_size(
			ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))
		_shadow_changed = false


func _set_all(target: Object, props: Dictionary) -> void:
	if target == null:
		return
	for k in props:
		_saved.append([target, k, target.get(k)])
		target.set(k, props[k])


## A soft glowing bulb inside a standing lamp's shade (an emissive surface,
## not a light).
func _add_bulb(lamp: Node3D) -> void:
	var top := 0.0
	for mi: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
		var box := mi.get_aabb()
		top = maxf(top, (mi.transform * box).end.y)
	if top <= 0.0:
		return
	var bulb := MeshInstance3D.new()
	var s := CylinderMesh.new()  # a glowing disc where the shade opens at the top
	s.top_radius = top * 0.1
	s.bottom_radius = top * 0.1
	s.height = top * 0.04
	bulb.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.86, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 2.5
	bulb.material_override = m
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(bulb)
	bulb.position = Vector3(0, top * 1.003, 0)  # at the top of the shade (seen from above)
	_added.append(bulb)


## A gentle warm grade: shadows lifted a little towards amber, blues kept
## clear, whites untouched (a 17x17x17 colour cube).
static func warm_lut() -> ImageTexture3D:
	const N := 17
	var images: Array[Image] = []
	for b in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for g in N:
			for r in N:
				var c := Color(r / float(N - 1), g / float(N - 1), b / float(N - 1))
				var lift := (1.0 - c.get_luminance()) * 0.035
				var o := Color(
					clampf(pow(c.r, 0.96) * 1.02 + lift, 0.0, 1.0),
					clampf(pow(c.g, 0.98) + lift * 0.6, 0.0, 1.0),
					clampf(c.b * 0.95 + 0.012, 0.0, 1.0))
				img.set_pixel(r, g, o)
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, images)
	return tex
