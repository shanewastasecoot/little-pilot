class_name TerrainBuilder
extends RefCounted
## Turns IslandShape into a flat-shaded, vertex-coloured low-poly mesh plus
## matching trimesh collision. Triangles fully under the sea are skipped
## (the ocean covers them and the water collider handles safety).

const CELLS := 160  # per side -> 15 m cells over 2400 m


static func build(parent: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var n := CELLS + 1
	var step := IslandShape.SIZE / CELLS
	var half := IslandShape.SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = IslandShape.height(-half + i * step, -half + j * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in CELLS:
		for i in CELLS:
			var x0 := -half + i * step
			var z0 := -half + j * step
			var a := Vector3(x0, heights[j * n + i], z0)
			var b := Vector3(x0 + step, heights[j * n + i + 1], z0)
			var c := Vector3(x0, heights[(j + 1) * n + i], z0 + step)
			var d := Vector3(x0 + step, heights[(j + 1) * n + i + 1], z0 + step)
			# Alternate the diagonal for a less grid-like look.
			if (i + j) % 2 == 0:
				_tri(verts, normals, colors, a, b, c)
				_tri(verts, normals, colors, b, d, c)
			else:
				_tri(verts, normals, colors, a, b, d)
				_tri(verts, normals, colors, a, d, c)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = GameSettings.LAYER_WORLD
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	print_verbose("Terrain: %d triangles in %d ms" % [verts.size() / 3, Time.get_ticks_msec() - t0])


static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	if a.y < -4.0 and b.y < -4.0 and c.y < -4.0:
		return  # deep under the ocean: never seen
	var nrm := (c - a).cross(b - a).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	var centre := (a + b + c) / 3.0
	var col := IslandShape.color(centre.x, centre.z, centre.y, 1.0 - nrm.y)
	# Tiny per-face brightness jitter: reads as hand-made low-poly.
	var jitter := 1.0 + (fmod(absf(centre.x * 12.9898 + centre.z * 78.233), 1.0) - 0.5) * 0.06
	col = Color(col.r * jitter, col.g * jitter, col.b * jitter)
	# Order chosen so the upward face is the front face (verified visually).
	verts.append_array([a, b, c] if (c - a).cross(b - a).y > 0.0 else [a, c, b])
	normals.append_array([nrm, nrm, nrm])
	colors.append_array([col, col, col])
