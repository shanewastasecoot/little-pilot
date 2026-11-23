extends Node
## Visual consistency (Phase 11):
##   untouched  glass towers, the sea, characters (people, animals) and the
##              aircraft keep exactly their own materials
##   world      buildings and props (STATIC_WORLD): rough, little shine,
##              colours inside the shared saturation / brightness range
##   foliage    trees get the swaying foliage shader with their own colours
##   batching   two copies of the same asset share the same materials
##   sky        the sky is the custom sky shader; the environment comes
##              from resources/world_environment.tres
##   tonemap    the debug overlay flips Linear <-> AgX, Linear by default
## Exit code 0 = pass, 1 = fail.

const ENV := "res://assets/environment/"
var _fails := 0


func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	# Untouched profiles: same material objects as a plain instance.
	var same := true
	for path in [ENV + "sky_glass.glb", ENV + "sheep.glb", ENV + "dragon.glb", "res://assets/aircraft/jet_trainer.glb",
			"res://assets/characters/kaykit_adventurers/Rogue.glb"]:
		var raw: Node = load(path).instantiate()
		var placed := AssetLib.place(root, path)
		var a := _materials(raw)
		var b := _materials(placed)
		if a != b:
			same = false
			print("    changed: ", path)
		raw.free()
	_check("glass, characters, animals and aircraft keep their own materials", same)
	# The sea (and any other shader material) is never changed.
	var sea := ShaderMaterial.new()
	sea.shader = load("res://shaders/ocean.gdshader")
	_check("the sea (a shader material) is left exactly as it is",
			StyleProfiles.material_for(sea, StyleProfiles.Profile.STATIC_WORLD) == sea
			and StyleProfiles.material_for(sea, StyleProfiles.Profile.FOLIAGE) == sea)
	# Static world: rough, little shine, colours in range.
	var barn := AssetLib.place(root, ENV + "barn.glb")
	var ok := true
	var checked := 0
	for mi: MeshInstance3D in barn.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m == null or StyleProfiles.is_glowing(m):
				continue
			checked += 1
			var c := m.albedo_color
			if m.roughness < StyleProfiles.ROUGHNESS - 0.001 or absf(m.metallic_specular - StyleProfiles.SPECULAR) > 0.001 \
					or (m.albedo_texture == null and (c.s > StyleProfiles.MAX_SATURATION + 0.01 or c.v > StyleProfiles.VALUE_RANGE.y + 0.01)):
				ok = false
	_check("buildings and props: rough, little shine, colours in the shared range (%d materials)" % checked, ok and checked > 0)
	# Batching: two barns share materials.
	var barn2 := AssetLib.place(root, ENV + "barn.glb")
	_check("two copies of the same asset share the same materials", _materials(barn) == _materials(barn2))
	# Foliage: the sway shader, with the tree's own colour.
	var pine: Array = AssetLib.mesh_of(ENV + "pine.glb")
	var mesh: Mesh = pine[0]
	var foliage := true
	for s in mesh.get_surface_count():
		var sm := mesh.surface_get_material(s) as ShaderMaterial
		if sm == null or sm.shader.resource_path != StyleProfiles.FOLIAGE_SHADER:
			foliage = false
	_check("trees sway: the foliage shader on every surface", foliage and mesh.get_surface_count() > 0)
	# Sky and environment.
	var env: Environment = load("res://resources/world_environment.tres")
	var sky_ok := env != null and env.sky and env.sky.sky_material is ShaderMaterial \
			and (env.sky.sky_material as ShaderMaterial).shader.resource_path == "res://shaders/sky.gdshader"
	_check("the environment comes from world_environment.tres, with the custom sky shader", sky_ok)
	# Tonemap toggle (on a copy of the environment).
	var we := WorldEnvironment.new()
	we.environment = env.duplicate()
	add_child(we)
	var hud: DebugHud = load("res://scenes/ui/debug_hud.tscn").instantiate() if ResourceLoader.exists("res://scenes/ui/debug_hud.tscn") else null
	var linear_default := we.environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR
	var flipped := -2
	if hud:
		add_child(hud)
		flipped = hud.toggle_tonemap()
	_check("Linear by default; the debug overlay flips it to AgX to compare", linear_default and flipped == Environment.TONE_MAPPER_AGX)
	print("\nSTYLE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _materials(n: Node) -> Array:
	var out := []
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			out.append(mi.get_active_material(s))
	return out


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
