class_name PropSplitter
extends Node3D
## For models whose propeller is baked into the body mesh: at load time,
## moves every triangle in front of `cut` (along `forward`, in the source
## mesh's own space) into a child mesh of this node, so the propeller can
## spin on its own. Put this node at the propeller hub, with its Z axis
## along the spin axis (AircraftVisuals spins it with rotate_z).

@export var source: MeshInstance3D
## Forward direction and cut distance in the source mesh's local space.
@export var forward := Vector3(0, -1, 0)
@export var cut := 49.0
## Below 1 picks lighter LODs sooner (the body is very dense for its size).
@export var lod_bias := 0.35

static var _cache: Dictionary = {}


func _ready() -> void:
	if source == null or source.mesh == null:
		return
	var key := "%s|%s|%.2f" % [source.mesh.resource_path, forward, cut]
	if not _cache.has(key):
		_cache[key] = _split(source.mesh)
	var parts: Array = _cache[key]
	source.mesh = parts[0]
	source.lod_bias = lod_bias
	var prop := MeshInstance3D.new()
	prop.name = "Blades"
	prop.mesh = parts[1]
	add_child(prop)
	# Keep the blades exactly where they were in the model.
	prop.global_transform = source.global_transform


func _split(mesh: Mesh) -> Array:
	# ImporterMesh so the rebuilt meshes get automatic LODs again (the
	# original import had them; a hand-built ArrayMesh would not).
	var body := ImporterMesh.new()
	var blades := ImporterMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var keep := PackedInt32Array()
		var move := PackedInt32Array()
		for t in idx.size() / 3:
			var front := true
			for j in 3:
				if v[idx[t * 3 + j]].dot(forward) < cut:
					front = false
					break
			# (Packed arrays copy on assignment, so append to each directly.)
			if front:
				move.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
			else:
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		for pair in [[body, keep], [blades, move]]:
			if pair[1].is_empty():
				continue
			var b := a.duplicate()
			b[Mesh.ARRAY_INDEX] = pair[1]
			for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				b[c] = null  # would need format flags; unused
			pair[0].add_surface(Mesh.PRIMITIVE_TRIANGLES, b, [], {}, mesh.surface_get_material(s))
	for im: ImporterMesh in [body, blades]:
		im.generate_lods(25.0, 60.0, [])
	return [body.get_mesh(), blades.get_mesh()]
