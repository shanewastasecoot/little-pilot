class_name StyleProfiles
extends RefCounted
## Visual consistency (Phase 11): each asset belongs to a style profile, by
## file or folder, and only two profiles are changed when it's loaded:
##   STATIC_WORLD  buildings, rocks, props: consistent roughness, no stray
##                 shine (low specular), colours brought into a shared
##                 saturation and brightness range
##   FOLIAGE       trees: the same, plus a gentle sway in the wind
##                 (shaders/foliage.gdshader)
## Left exactly as they are: GLASS (glass towers), AIRCRAFT, ANIMATED_CHARACTER
## (people, animals, the dragon, the whale), EMISSIVE, WATER, UNTREATED.
## Changed materials are cached by the original, so identical assets still
## share one material (and still batch). AssetLib applies this when it
## places or merges a model (set `enabled` false to compare).

enum Profile { STATIC_WORLD, FOLIAGE, GLASS, AIRCRAFT, ANIMATED_CHARACTER, EMISSIVE, WATER, UNTREATED }

static var enabled := true
const FOLIAGE_SHADER := "res://shaders/foliage.gdshader"
const MAX_SATURATION := 0.9
const VALUE_RANGE := Vector2(0.18, 0.95)
const ROUGHNESS := 0.85
const SPECULAR := 0.3

## By file name (in assets/environment/) or folder. Anything not listed
## under assets/environment is UNTREATED.
const BY_FILE := {
	"pine": Profile.FOLIAGE, "tree_round": Profile.FOLIAGE, "palm": Profile.FOLIAGE, "snow_pine": Profile.FOLIAGE,
	"sky_glass": Profile.GLASS, "sky_glass_b": Profile.GLASS, "sky_glass_c": Profile.GLASS,
	"sheep": Profile.ANIMATED_CHARACTER, "cow": Profile.ANIMATED_CHARACTER, "dragon": Profile.ANIMATED_CHARACTER,
	"whale": Profile.ANIMATED_CHARACTER, "dolphin": Profile.ANIMATED_CHARACTER, "seal": Profile.ANIMATED_CHARACTER,
	"crab": Profile.ANIMATED_CHARACTER, "penguin": Profile.ANIMATED_CHARACTER, "mermaid_hd": Profile.ANIMATED_CHARACTER,
	"trex": Profile.ANIMATED_CHARACTER, "triceratops": Profile.ANIMATED_CHARACTER, "stegosaurus": Profile.ANIMATED_CHARACTER,
	"apatosaurus": Profile.ANIMATED_CHARACTER,
	"cloud_a": Profile.UNTREATED, "cloud_b": Profile.UNTREATED, "balloons": Profile.UNTREATED,
}

static var _cache := {}


static func profile_of(path: String) -> Profile:
	if path.begins_with("res://assets/aircraft/"):
		return Profile.AIRCRAFT
	if path.begins_with("res://assets/characters/"):
		return Profile.ANIMATED_CHARACTER
	if path.begins_with("res://assets/environment/"):
		return BY_FILE.get(path.get_file().get_basename(), Profile.STATIC_WORLD)
	return Profile.UNTREATED


## Apply `path`'s profile to every mesh under `node` (a placed model).
static func apply(node: Node, path: String) -> void:
	var p := profile_of(path)
	if not enabled or not p in [Profile.STATIC_WORLD, Profile.FOLIAGE]:
		return
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.material_override != null:
			continue
		var h := maxf(mi.mesh.get_aabb().end.y, 0.01)
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var out := material_for(src, p, h)
			if out != src:
				mi.set_surface_override_material(s, out)


## Apply `path`'s profile to a mesh's own surface materials (meshes drawn
## through a MultiMesh or merged batches). Returns the mesh (changed in place).
static func apply_mesh(mesh: Mesh, path: String) -> Mesh:
	var p := profile_of(path)
	if not enabled or mesh == null or not p in [Profile.STATIC_WORLD, Profile.FOLIAGE]:
		return mesh
	var h := maxf(mesh.get_aabb().end.y, 0.01)
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s)
		var out := material_for(src, p, h)
		if out != src:
			mesh.surface_set_material(s, out)
	return mesh


## The profile's version of material `src` (cached; ShaderMaterials and
## unknown kinds come back unchanged).
static func material_for(src: Material, p: Profile, height := 1.0) -> Material:
	var std := src as BaseMaterial3D
	if std == null:
		return src
	# Glowing bits (lit windows, lamps) are EMISSIVE: left alone.
	if is_glowing(std) or std.metallic > 0.5:
		return src
	var key := "%d/%d/%.2f" % [src.get_instance_id(), p, height if p == Profile.FOLIAGE else 0.0]
	if _cache.has(key):
		return _cache[key]
	var out: Material
	if p == Profile.FOLIAGE:
		var sm := ShaderMaterial.new()
		sm.shader = load(FOLIAGE_SHADER)
		sm.set_shader_parameter("albedo_color", std.albedo_color)
		sm.set_shader_parameter("use_texture", std.albedo_texture != null)
		if std.albedo_texture:
			sm.set_shader_parameter("albedo_tex", std.albedo_texture)
		sm.set_shader_parameter("use_vertex_color", std.vertex_color_use_as_albedo)
		sm.set_shader_parameter("roughness", maxf(std.roughness, ROUGHNESS))
		sm.set_shader_parameter("specular", SPECULAR)
		sm.set_shader_parameter("height", height)
		sm.set_shader_parameter("leafiness", 0.0 if _is_trunk(std.albedo_color) else 1.0)
		sm.set_shader_parameter("max_saturation", MAX_SATURATION)
		sm.set_shader_parameter("value_range", VALUE_RANGE)
		var scissor := std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		sm.set_shader_parameter("alpha_scissor", scissor)
		sm.set_shader_parameter("alpha_cut", std.alpha_scissor_threshold)
		out = sm
	else:
		var m := std.duplicate() as BaseMaterial3D
		m.roughness = maxf(m.roughness, ROUGHNESS)
		m.metallic_specular = SPECULAR
		if m.albedo_texture == null:
			var c := m.albedo_color
			m.albedo_color = Color.from_hsv(c.h, minf(c.s, MAX_SATURATION), clampf(c.v, VALUE_RANGE.x, VALUE_RANGE.y), c.a)
		out = m
	_cache[key] = out
	return out


## A colour baked into a merged mesh's vertices, in `path`'s profile's range.
static func vertex_colour(c: Color, path: String) -> Color:
	if not enabled or not profile_of(path) in [Profile.STATIC_WORLD, Profile.FOLIAGE]:
		return c
	return Color.from_hsv(c.h, minf(c.s, MAX_SATURATION), clampf(c.v, VALUE_RANGE.x, VALUE_RANGE.y), c.a)


## Really glowing (emission on AND a visible emission colour: some imported
## models switch emission on with black, which glows nothing).
static func is_glowing(m: BaseMaterial3D) -> bool:
	return m.emission_enabled and m.emission.get_luminance() * m.emission_energy_multiplier > 0.02


## A trunk is brown: warm, not very bright, not very saturated.
static func _is_trunk(c: Color) -> bool:
	return c.h > 0.03 and c.h < 0.14 and c.v < 0.6 and c.s > 0.25
