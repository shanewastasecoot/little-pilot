extends Node
## Graphics G3, baked contact shading (ContactShade):
##   models   every STATIC_WORLD model is shaded when imported: vertex
##            colours darker in corners and at the foot of walls, never
##            black, mostly light; its materials use them; its shadow-only
##            mesh matches it (a stale one shadowed the whole mountain)
##   others   trees, animals, glass towers and aircraft aren't touched
##   terrain  hollows count as hollow and come out darker; ridges don't
##   ground   the ground under a building is darker than open meadow
##   trees    trees are a little darker at their foot
## Exit code 0 = pass, 1 = fail.

const ENV := "res://assets/environment/"
var _fails := 0


func _ready() -> void:
	_model_checks()
	_terrain_checks()
	await _ground_checks()
	print("\nCONTACT SHADE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _model_checks() -> void:
	var unshaded := []
	var too_dark := []
	var no_vcol := []
	var bad_shadow := []
	var count := 0
	for f in DirAccess.get_files_at(ENV):
		if not f.ends_with(".glb") or StyleProfiles.profile_of(ENV + f) != StyleProfiles.Profile.STATIC_WORLD:
			continue
		count += 1
		var root: Node = load(ENV + f).instantiate()
		var lo := 1.0
		var sum := 0.0
		var n := 0
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := mi.mesh as ArrayMesh
			for s in mesh.get_surface_count():
				var cols = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
				if cols == null:
					continue
				for c: Color in cols:
					lo = minf(lo, c.r)
					sum += c.r
					n += 1
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat and not mat.vertex_color_use_as_albedo and f not in no_vcol:
					no_vcol.append(f)
			var sh := mesh.shadow_mesh
			if sh and (sh.get_surface_count() != mesh.get_surface_count()
					or sh.surface_get_array_len(0) != mesh.surface_get_array_len(0)) and f not in bad_shadow:
				bad_shadow.append(f)
		if n == 0 or lo > 0.95:
			unshaded.append(f)
		elif lo < ContactShade.DARKEST - 0.01 or sum / n < 0.5:
			too_dark.append(f)
		root.free()
	_check("all %d STATIC_WORLD models are shaded %s" % [count, unshaded], count >= 30 and unshaded.is_empty())
	_check("never darker than %.2f, mostly light %s" % [ContactShade.DARKEST, too_dark], too_dark.is_empty())
	_check("their materials use the shading %s" % [no_vcol], no_vcol.is_empty())
	_check("shadow-only meshes match the shaded ones %s" % [bad_shadow], bad_shadow.is_empty())
	# Not shaded: trees, animals, glass towers, aircraft.
	var touched := []
	for path in [ENV + "pine.glb", ENV + "sheep.glb", ENV + "sky_glass.glb", "res://assets/aircraft/jet_trainer.glb"]:
		var root: Node = load(path).instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if mat and mat.vertex_color_use_as_albedo and mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] != null:
					var cols: PackedColorArray = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
					if cols.size() > 0 and cols[0].r == cols[0].g and cols[0].g == cols[0].b and cols[0].r < 0.99 and path not in touched:
						touched.append(path.get_file())
		root.free()
	_check("trees, animals, glass towers and aircraft are left alone %s" % [touched], touched.is_empty())


func _terrain_checks() -> void:
	# A 9x9 grid: a bowl in the middle, a ridge along one row.
	var m := 9
	var bowl := PackedFloat32Array()
	var ridge := PackedFloat32Array()
	for j in m:
		for i in m:
			var d := Vector2(i - 4, j - 4).length()
			bowl.append(d * 2.0)
			ridge.append(10.0 - absf(j - 4) * 2.0)
	var hollow := ContactShade.terrain_cavity(bowl, m, 4, 4)
	var top := ContactShade.terrain_cavity(ridge, m, 4, 4)
	_check("a hollow counts as hollow (%.2f m)" % hollow, hollow > 0.5)
	_check("a ridge doesn't (%.2f m)" % top, top <= 0.0)
	_check("hollows come out darker, ridges not", ContactShade.terrain_shade(hollow, 12.0) < 0.97 and ContactShade.terrain_shade(top, 12.0) == 1.0)
	_check("flat ground isn't darkened", ContactShade.terrain_shade(0.0, 12.0) == 1.0)


func _ground_checks() -> void:
	# The real island: the farm's barn sits on terrain; open meadow nearby.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_contact.cfg"))
	SaveManager.use_path("user://test_contact.cfg")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var terrain: MeshInstance3D = null
	for b: Node in get_tree().get_nodes_in_group("terrain"):
		if b.name == "Terrain":
			terrain = b.get_child(0) as MeshInstance3D
	var cols: PackedColorArray = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var near := _nearest(verts, IslandShape.FARM)
	var raw_near: Color = IslandShape.color(verts[near].x, verts[near].z, verts[near].y, 0.0)
	var ratio := cols[near].g / maxf(raw_near.g, 0.001)
	_check("the ground under the barn is darker (%.2f of its colour)" % ratio, ratio < 0.95 and ratio >= TerrainBuilder.GROUND_FLOOR - 0.1)
	# Trees: the foliage material darkens their foot.
	var data: Array = AssetLib.mesh_of(ENV + "tree_round.glb")
	var shaded := false
	for s in (data[0] as Mesh).get_surface_count():
		var sm := (data[0] as Mesh).surface_get_material(s) as ShaderMaterial
		if sm and float(sm.get_shader_parameter("base_shade")) > 0.1:
			shaded = true
	_check("trees are darker at their foot", shaded)
	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_contact.cfg"))


func _nearest(verts: PackedVector3Array, at: Vector2) -> int:
	var best := 0
	var bd := INF
	for k in verts.size():
		var d := Vector2(verts[k].x, verts[k].z).distance_squared_to(at)
		if d < bd:
			bd = d
			best = k
	return best


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
