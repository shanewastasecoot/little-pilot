class_name TerrainBuilder
extends RefCounted
## Turns an island shape into a smooth-shaded, vertex-coloured terrain mesh
## plus matching trimesh collision. Vertices are shared (indexed mesh) with
## normals from the height field, so hills and mountains look rounded and
## colours blend smoothly. Cells entirely deep under the sea are skipped
## (the ocean is opaque there and the water collider handles safety).
##
## height_fn(x, z) -> float and color_fn(x, z, h, slope) -> Color describe the
## island; centre/size/cells choose the square area and resolution.

const DEEP := -24.0

static var _tint_noise: FastNoiseLite


static func build(parent: Node3D, height_fn: Callable, color_fn: Callable, centre: Vector2, size: float, cells: int, node_name := "Terrain") -> void:
	var t0 := Time.get_ticks_msec()
	if _tint_noise == null:
		_tint_noise = FastNoiseLite.new()
		_tint_noise.seed = 3
		_tint_noise.frequency = 0.01
	var n := cells + 1
	var step := size / cells
	var ox := centre.x - size * 0.5
	var oz := centre.y - size * 0.5
	# Sample one ring wider than the mesh so edge normals are correct.
	var m := n + 2
	var heights := PackedFloat32Array()
	heights.resize(m * m)
	for j in m:
		for i in m:
			heights[j * m + i] = height_fn.call(ox + (i - 1) * step, oz + (j - 1) * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for j in n:
		for i in n:
			var hc := heights[(j + 1) * m + (i + 1)]
			var hl := heights[(j + 1) * m + i]
			var hr := heights[(j + 1) * m + i + 2]
			var hu := heights[j * m + (i + 1)]
			var hd := heights[(j + 2) * m + (i + 1)]
			var nrm := Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
			var x := ox + i * step
			var z := oz + j * step
			var col: Color = color_fn.call(x, z, hc, 1.0 - nrm.y)
			# Soft, large-scale brightness patches (meadows look less flat).
			var tint := 1.0 + _tint_noise.get_noise_2d(x, z) * 0.07
			var k := j * n + i
			verts[k] = Vector3(x, hc, z)
			normals[k] = nrm
			colors[k] = Color(col.r * tint, col.g * tint, col.b * tint)

	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for j in cells:
		for i in cells:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			if verts[a].y < DEEP and verts[b].y < DEEP and verts[c].y < DEEP and verts[d].y < DEEP:
				continue
			if (i + j) % 2 == 0:
				_tri(indices, faces, verts, a, b, c)
				_tri(indices, faces, verts, b, d, c)
			else:
				_tri(indices, faces, verts, a, b, d)
				_tri(indices, faces, verts, a, d, c)
	if indices.is_empty():
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = GameSettings.LAYER_WORLD
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	print_verbose("%s: %d triangles in %d ms" % [node_name, indices.size() / 3, Time.get_ticks_msec() - t0])


## Adds triangle a-b-c with the upward side as the front face.
static func _tri(indices: PackedInt32Array, faces: PackedVector3Array, verts: PackedVector3Array, a: int, b: int, c: int) -> void:
	var pa := verts[a]
	var pb := verts[b]
	var pc := verts[c]
	if (pc - pa).cross(pb - pa).y > 0.0:
		indices.append_array([a, b, c])
		faces.append_array([pa, pb, pc])
	else:
		indices.append_array([a, c, b])
		faces.append_array([pa, pc, pb])
