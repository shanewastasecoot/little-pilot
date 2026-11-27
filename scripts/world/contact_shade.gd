class_name ContactShade
extends RefCounted
## Graphics G3: baked contact shading. The Mobile renderer has no SSAO, so
## the soft darkening where things meet (under eaves, in inside corners,
## where walls meet the ground, in hollows of the land) is worked out ahead
## of time and stored in vertex colours. It costs nothing while playing.
##
##   models   tools/import/contact_shade_import.gd calls bake_scene() when
##            Godot imports a STATIC_WORLD .glb, so the shading is saved in
##            the imported model (.godot/imported) and loading is no slower
##   terrain  TerrainBuilder darkens hollows and valley floors with
##            terrain_cavity() from its height grid
##
## `strength` scales everything at runtime (1 = as baked, 0 = off) so the
## screenshot A/B (./dev.sh shots) can compare; the game always uses 1.

## (The parent picked this "Subtle" strength from the screenshot A/B, Nov 26.)
const BAKED_STRENGTH := 1.0  ## how much of the full occlusion is kept
const DARKEST := 0.3  ## the darkest a vertex gets (linear), before BAKED_STRENGTH
const RES := 48  ## voxels along the model's longest side
const RAYS := 16
const STEPS := 7

static var strength := 1.0  ## models
static var terrain_strength := 1.0  ## terrain hollows
static var ground_strength := 1.0  ## ground under forests, rocks and buildings, tree bases

static var _dirs: PackedVector3Array


## Bakes occlusion into every MeshInstance3D under `scene` (an imported
## model), measured against the whole model. `ground`: treat everything
## below the model's lowest point as solid ground (false for boats and
## icebergs, which sit in water). Returns the number of vertices shaded.
static func bake_scene(scene: Node, ground := true) -> int:
	var parts: Array = []  # [MeshInstance3D, Transform3D to scene root]
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not mi.mesh is ArrayMesh:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != scene and cur != null:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		parts.append([mi, xf])
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if parts.is_empty() or box.get_longest_axis_size() <= 0.0:
		return 0
	var grid := _Grid.new(box, ground)
	grid.dirs = _hemisphere()
	for p: Array in parts:
		var mesh: ArrayMesh = (p[0] as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var a := mesh.surface_get_arrays(s)
			grid.add_triangles(a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX], p[1])
	var shaded := 0
	var done := {}
	for p: Array in parts:
		var mesh: ArrayMesh = (p[0] as MeshInstance3D).mesh
		if done.has(mesh):  # (the same mesh used twice: shade it once)
			continue
		done[mesh] = true
		shaded += _shade_mesh(mesh, grid, p[1])
	return shaded


## Rescales the baked shading on `mesh` in place by `k` (0 removes it).
## Only the screenshot A/B uses this.
static func rescale(mesh: ArrayMesh, k: float) -> void:
	_rebuild(mesh, func(s: int, arrays: Array) -> void:
		var cols = arrays[Mesh.ARRAY_COLOR]
		if cols == null:
			return
		var c: PackedColorArray = cols
		for i in c.size():
			var v := clampf(1.0 - (1.0 - c[i].r) * k, 0.15, 1.0)
			c[i] = Color(v, v, v, c[i].a)
		arrays[Mesh.ARRAY_COLOR] = c)


## How hollow the land is at grid point (i, j) of a height grid `h` (m x m):
## positive in valleys, at the foot of slopes and in dips,
## negative on ridges. In metres; compared at two distances so both small
## dips and wide valleys count.
static func terrain_cavity(h: PackedFloat32Array, m: int, i: int, j: int) -> float:
	var c := h[j * m + i]
	var near := 0.0
	var far := 0.0
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		near += h[clampi(j + o.y, 0, m - 1) * m + clampi(i + o.x, 0, m - 1)]
		far += h[clampi(j + o.y * 3, 0, m - 1) * m + clampi(i + o.x * 3, 0, m - 1)]
	return (near * 0.25 - c) * 0.6 + (far * 0.25 - c) * 0.4


## The brightness (0-1) for a cavity of `cav` metres at grid spacing `step`.
static func terrain_shade(cav: float, step: float) -> float:
	if terrain_strength <= 0.0 or cav <= 0.0:
		return 1.0
	# A dip of ~a fifth of the spacing reads as fully hollow.
	var t := clampf(cav / (step * 0.2), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t) * 0.16 * terrain_strength


static func _shade_mesh(mesh: ArrayMesh, grid: _Grid, xf: Transform3D) -> int:
	var count := [0]  # (a lambda can't change a plain local)
	var nb := xf.basis.inverse().transposed()
	_rebuild(mesh, func(s: int, arrays: Array) -> void:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		var memo := {}
		for i in verts.size():
			var p := xf * verts[i]
			var n := Vector3.UP
			if normals != null:
				n = (nb * (normals[i] as Vector3)).normalized()
			var key := Vector3i((p / grid.cell * 8.0).round()) * 64 + Vector3i((n * 7.0).round())
			var v: float
			if memo.has(key):
				v = memo[key]
			else:
				v = 1.0 - (1.0 - grid.ambient(p, n)) * BAKED_STRENGTH
				memo[key] = v
			cols[i] = Color(v, v, v, 1.0)
		arrays[Mesh.ARRAY_COLOR] = cols
		count[0] += verts.size()
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat:
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = false)
	return count[0]


## Rebuilds every surface of `mesh` in place after `edit.call(surface,
## arrays)` changes its arrays, keeping names, materials and the importer's
## LODs (the mesh object stays the same, so every user sees the change).
static func _rebuild(mesh: ArrayMesh, edit: Callable) -> void:
	var saved := []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		edit.call(s, arrays)
		saved.append([mesh.surface_get_primitive_type(s), arrays, _lods(mesh, s),
			mesh.surface_get_material(s), mesh.surface_get_name(s)])
	var had_shadow := mesh.shadow_mesh != null
	mesh.clear_surfaces()
	mesh.shadow_mesh = null
	for d: Array in saved:
		mesh.add_surface_from_arrays(d[0], d[1], [], d[2])
		var s := mesh.get_surface_count() - 1
		mesh.surface_set_material(s, d[3])
		mesh.surface_set_name(s, d[4])
	# The importer's shadow-only copy no longer matches the new surfaces
	# (left in, the rocks cast a huge shadow over everything and the GPU time
	# doubled at Dragon Peak): make a matching one, positions only.
	if had_shadow:
		var shadow := ArrayMesh.new()
		for d: Array in saved:
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = d[1][Mesh.ARRAY_VERTEX]
			a[Mesh.ARRAY_INDEX] = d[1][Mesh.ARRAY_INDEX]
			shadow.add_surface_from_arrays(d[0], a, [], d[2])
		mesh.shadow_mesh = shadow


## The importer's LODs for surface `s`: {edge length: indices}.
static func _lods(mesh: ArrayMesh, s: int) -> Dictionary:
	var out := {}
	var surf := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
	var lods: Array = surf.get("lods", [])
	var count: int = surf.get("index_count", 0)
	var data: PackedByteArray = surf.get("index_data", PackedByteArray())
	if lods.is_empty() or count == 0 or data.is_empty():
		return out
	var wide := data.size() / count >= 4
	for l: Dictionary in lods:
		var bytes: PackedByteArray = l.get("index_data", PackedByteArray())
		var idx := PackedInt32Array()
		if wide:
			idx = bytes.to_int32_array()
		else:
			idx.resize(bytes.size() / 2)
			for k in idx.size():
				idx[k] = bytes.decode_u16(k * 2)
		out[float(l.get("edge_length", 0.0))] = idx
	return out


static func _hemisphere() -> PackedVector3Array:
	if _dirs.is_empty():
		# Cosine-weighted directions around +Y (a spiral), so more rays go
		# outwards than skim along the surface.
		for k in RAYS:
			var r := sqrt((k + 0.5) / RAYS)
			var a := k * 2.39996323
			_dirs.append(Vector3(cos(a) * r, sqrt(1.0 - r * r), sin(a) * r))
	return _dirs


## A coarse solid/empty grid of the model, to march rays through.
class _Grid:
	var origin: Vector3
	var cell: float
	var size: Vector3i
	var solid := PackedByteArray()
	var ground: bool
	var ground_y: float
	var dirs: PackedVector3Array

	func _init(box: AABB, has_ground: bool) -> void:
		cell = box.get_longest_axis_size() / RES
		var pad := Vector3.ONE * cell * 2.0
		origin = box.position - pad
		size = Vector3i(((box.size + pad * 2.0) / cell).ceil())
		solid.resize(size.x * size.y * size.z)
		ground = has_ground
		ground_y = box.position.y

	func add_triangles(verts: PackedVector3Array, indices, xf: Transform3D) -> void:
		var order: PackedInt32Array = indices if indices != null else PackedInt32Array(range(verts.size()))
		for t in range(0, order.size() - 2, 3):
			var a := xf * verts[order[t]]
			var b := xf * verts[order[t + 1]]
			var c := xf * verts[order[t + 2]]
			var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
			var n := maxi(1, ceili(longest / (cell * 0.5)))
			for i in n + 1:
				for j in n + 1 - i:
					_mark(a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n))

	func _mark(p: Vector3) -> void:
		var q := Vector3i(((p - origin) / cell).floor())
		if q.x >= 0 and q.y >= 0 and q.z >= 0 and q.x < size.x and q.y < size.y and q.z < size.z:
			solid[(q.y * size.z + q.z) * size.x + q.x] = 1

	func is_solid(p: Vector3) -> bool:
		if ground and p.y < ground_y:
			return true
		var q := Vector3i(((p - origin) / cell).floor())
		if q.x < 0 or q.y < 0 or q.z < 0 or q.x >= size.x or q.y >= size.y or q.z >= size.z:
			return false
		return solid[(q.y * size.z + q.z) * size.x + q.x] == 1

	## How open the sky is from point p with normal n (1 = open, down to DARKEST).
	func ambient(p: Vector3, n: Vector3) -> float:
		var t := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.FORWARD).normalized()
		var bt := n.cross(t)
		var start := p + n * cell * 1.05
		var blocked := 0.0
		for d in dirs:
			var dir := t * d.x + n * d.y + bt * d.z
			for k in STEPS:
				if is_solid(start + dir * cell * (0.6 + k)):
					blocked += 1.0 - float(k) / STEPS
					break
		var occ := blocked / dirs.size()
		return 1.0 - occ * (1.0 - DARKEST)
