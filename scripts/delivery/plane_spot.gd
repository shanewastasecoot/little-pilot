class_name PlaneSpot
extends RefCounted
## Where a parcel sits on top of a plane model: on the fuselage's spine just
## behind the middle (behind the pilot), found from the model's own
## vertices so it works for any plane. Cached per model scene.

static var _cache: Dictionary = {}


## [position in the visuals node's space, parcel scale].
static func on_top(visuals: Node3D) -> Array:
	var key := visuals.scene_file_path
	if _cache.has(key):
		return _cache[key]
	var box := AABB()
	var pts := PackedVector3Array()
	var first := true
	var to_vis := visuals.global_transform.affine_inverse()
	for mi: MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var xf := to_vis * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := xf * v
				pts.append(p)
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	var c := box.get_center()
	# Behind the middle (+Z is the tail end: planes fly towards -Z).
	var z := c.z + box.size.z * 0.12
	var half_w := box.size.x * 0.05
	var half_l := box.size.z * 0.06
	# The highest point of the fuselage there, ignoring anything well above
	# the body (an upper wing): take the top of the lowest-topped column.
	var top := -INF
	var ys: Array[float] = []
	for p in pts:
		if absf(p.x - c.x) < half_w and absf(p.z - z) < half_l:
			ys.append(p.y)
	if ys.is_empty():
		top = box.end.y
	else:
		ys.sort()
		# Usually the top of the column. But if there's a big gap of air
		# (a biplane's upper wing above the body), the body's top is the
		# point just below the biggest gap.
		top = ys[ys.size() - 1]
		var best_gap := 0.0
		for i in range(1, ys.size()):
			var g: float = ys[i] - ys[i - 1]
			if g > best_gap:
				best_gap = g
				if g > box.size.y * 0.25:
					top = ys[i - 1]
	var size := box.size.x * 0.15 / 0.62  # the parcel is 0.62 wide
	var out := [Vector3(c.x, top + 0.23 * size, z), size]
	_cache[key] = out
	return out
