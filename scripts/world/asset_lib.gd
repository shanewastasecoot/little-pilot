class_name AssetLib
extends RefCounted
## Helpers for placing imported .glb models: instancing with scale and a
## looping animation, and pulling a single mesh out for MultiMesh use.

## Instance a model under `parent`. Plays its first (or named) animation
## on loop if it has one.
static func place(parent: Node3D, path: String, pos := Vector3.ZERO, scale := 1.0, yaw_deg := 0.0, anim := "") -> Node3D:
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.scale = Vector3.ONE * scale
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	play_loop(node, anim)
	return node


static func play_loop(node: Node, anim := "", speed := 1.0) -> void:
	var players := node.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var ap: AnimationPlayer = players[0]
	var name := anim if anim != "" and ap.has_animation(anim) else ap.get_animation_list()[0]
	ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	ap.play(name, -1, speed)
	ap.seek(randf() * ap.current_animation_length)  # herds don't move in sync


static var _mesh_cache: Dictionary = {}


## The first mesh in a .glb plus its transform relative to the model root,
## with transparent materials switched to cheap alpha scissor (no sorting,
## far less overdraw on the Steam Deck). Returns [Mesh, Transform3D].
static func mesh_of(path: String) -> Array:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var root: Node = load(path).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D.IDENTITY
	var cur: Node = mi
	while cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	var mesh: Mesh = mi.mesh.duplicate()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			m = m.duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(i, m)
	root.free()
	_mesh_cache[path] = [mesh, xf]
	return _mesh_cache[path]


static var _merged_cache: Dictionary = {}


## All meshes in a .glb merged into ONE surface with material colours baked
## into vertex colours: one draw call per copy instead of one per part.
## Optionally shifts one hue range (e.g. a mermaid's tail) to `to_color`.
## parts: only merge parts whose node name is in this list (empty = all);
## skip: leave these parts out. offset is added to every vertex (use it to
## put a pivot, e.g. a shoulder, at the mesh origin).
static func merged_mesh(path: String, from_hue := -1.0, hue_range := 0.06, to_color := Color.WHITE,
		parts: PackedStringArray = [], skip: PackedStringArray = [], offset := Vector3.ZERO) -> ArrayMesh:
	var key := "%s|%.2f|%s|%s|%s|%s" % [path, from_hue, to_color.to_html(), ",".join(parts), ",".join(skip), offset]
	if _merged_cache.has(key):
		return _merged_cache[key]
	var root: Node = load(path).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if (not parts.is_empty() and not parts.has(part)) or skip.has(part):
			continue
		var xf := Transform3D(Basis.IDENTITY, offset)
		var cur: Node = mi
		while cur != root:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var col := mat.albedo_color if mat else Color.WHITE
			if from_hue >= 0.0 and col.s > 0.35 and absf(wrapf(col.h - from_hue, -0.5, 0.5)) < hue_range:
				col = Color.from_hsv(to_color.h, to_color.s, clampf(to_color.v * col.v / 0.8, 0.0, 1.0))
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = indices if indices != null else PackedInt32Array(range(verts.size()))
			for idx in order:
				st.set_color(col)
				if normals != null:
					st.set_normal((xf.basis * normals[idx]).normalized())
				st.add_vertex(xf * verts[idx])
	root.free()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.7
	mesh.surface_set_material(0, m)
	_merged_cache[key] = mesh
	return mesh
