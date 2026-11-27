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
##
## Graphics G3 (baked contact shading): hollows, valley floors and the foot
## of slopes are a little darker (ContactShade.terrain_cavity), and after the
## world is placed shade_ground() darkens the ground under forests, rocks
## and buildings. Both only change vertex colours: no runtime cost.

const DEEP := -24.0

static var _tint_noise: FastNoiseLite
## Every terrain built, for shade_ground(): [mesh, arrays, x0, z0, step, n].
static var _built: Array = []
static var _spots: Array = []  ## add_spot(): [centre xz, radius, darkness]
## Ground shade under things on the land (ContactShade.ground_strength 1).
const GROUND_SHADE := 0.2  ## darkest, right under a building or rock
const TREE_SHADE := 0.07  ## per tree (a forest adds up)
const GROUND_FLOOR := 0.72  ## never darker than this
const FALLOFF := 9.0  ## metres beyond the edge where the shade fades out


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
			# Soft, large-scale brightness patches (meadows look less flat),
			# darker in hollows (G3).
			var tint := 1.0 + _tint_noise.get_noise_2d(x, z) * 0.07
			tint *= ContactShade.terrain_shade(ContactShade.terrain_cavity(heights, m, i + 1, j + 1), step)
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
	_built.append([mesh, arrays, ox, oz, step, n])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = GameSettings.LAYER_WORLD
	body.add_to_group("terrain")  # the plane can land on it, people walk on it
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


## Graphics G3: darkens the ground under everything in the "contact_ground"
## group (STATIC_WORLD models, by their footprint) and at every add_spot(),
## on every terrain built so far. Call once, when the world is placed.
static func shade_ground(tree: SceneTree) -> void:
	var spots: Array = _spots  # [centre xz, radius, darkness]
	var built := _built
	_spots = []
	_built = []
	if ContactShade.ground_strength <= 0.0 or built.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	for node: Node in tree.get_nodes_in_group("contact_ground"):
		var n3 := node as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in n3.find_children("*", "MeshInstance3D", true, false):
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first or box.size.x > 400.0 or box.size.z > 400.0:
			continue
		var c := box.get_center()
		spots.append([Vector2(c.x, c.z), maxf(box.size.x, box.size.z) * 0.5, GROUND_SHADE])
	for b: Array in built:
		var arrays: Array = b[1]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var ox: float = b[2]
		var oz: float = b[3]
		var step: float = b[4]
		var n: int = b[5]
		var shade := PackedFloat32Array()
		shade.resize(n * n)
		shade.fill(1.0)
		var hit := false
		for s: Array in spots:
			var c: Vector2 = s[0]
			var reach: float = s[1] + FALLOFF
			var i0 := maxi(0, floori((c.x - reach - ox) / step))
			var i1 := mini(n - 1, ceili((c.x + reach - ox) / step))
			var j0 := maxi(0, floori((c.y - reach - oz) / step))
			var j1 := mini(n - 1, ceili((c.y + reach - oz) / step))
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var d := Vector2(ox + i * step, oz + j * step).distance_to(c)
					var t := clampf((d - s[1]) / FALLOFF, 0.0, 1.0)
					if d < reach:
						shade[j * n + i] *= 1.0 - (s[2] as float) * ContactShade.ground_strength * (1.0 - t * t * (3.0 - 2.0 * t))
						hit = true
		if not hit:
			continue
		for k in colors.size():
			var v := maxf(shade[k], GROUND_FLOOR)
			if v < 1.0:
				colors[k] = Color(colors[k].r * v, colors[k].g * v, colors[k].b * v)
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh: ArrayMesh = b[0]
		var mat := mesh.surface_get_material(0)
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
	print_verbose("Ground contact shade: %d spots in %d ms" % [spots.size(), Time.get_ticks_msec() - t0])


## Graphics G3: darken the ground around world point `at` (x, z) out to
## `radius` (+ FALLOFF) by `darkness` (GROUND_SHADE, TREE_SHADE) in shade_ground().
static func add_spot(at: Vector2, radius: float, darkness: float) -> void:
	_spots.append([at, radius, darkness])


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
