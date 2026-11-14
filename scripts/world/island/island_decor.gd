class_name IslandDecor
extends RefCounted
## Scatter helpers for dressing islands with many copies of a model.

## Scatter `count` copies of a model as one MultiMesh under `parent` (which
## sits at the island centre, y = 0). Spots are picked between r_min and
## r_max from the centre and kept only where min_h <= ground <= max_h.
static func scatter(parent: Node3D, path: String, count: int, centre: Vector2, r_min: float, r_max: float,
		height_fn: Callable, scale_min: float, scale_max: float, min_h := 4.0, max_h := 1000.0, seed_value := 1,
		view_distance := 2200.0) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var data: Array = AssetLib.mesh_of(path)
	var xforms: Array[Transform3D] = []
	var spots: Array[Vector3] = []
	var tries := 0
	while xforms.size() < count and tries < count * 8:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range((r_min / r_max) ** 2, 1.0)) * r_max
		var p := centre + Vector2(cos(a), sin(a)) * r
		var h: float = height_fn.call(p.x, p.y)
		if h < min_h or h > max_h:
			continue
		var s := rng.randf_range(scale_min, scale_max)
		var local := Vector3(p.x - centre.x, h - 0.3, p.y - centre.y)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), local) * data[1])
		spots.append(local)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data[0]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = view_distance
	parent.add_child(mmi)
	return spots


## Ground height at a point given in the island's local coordinates.
static func ground(height_fn: Callable, centre: Vector2, local: Vector2) -> float:
	return height_fn.call(centre.x + local.x, centre.y + local.y)
