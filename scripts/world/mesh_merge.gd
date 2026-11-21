class_name MeshMerge
extends RefCounted
## Join a node's plain MeshInstance3D children (boxes, spheres, prisms built
## in code) into one mesh per material: hundreds of little pieces (fence
## rails, flowers, window frames) become a handful of draw calls. Only
## direct children with a material_override and no children of their own;
## everything else (imported models, MultiMeshes, colliders) is left alone.

static func merge_children(parent: Node3D) -> int:
	var groups := {}  # material -> [MeshInstance3D]
	for child in parent.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.get_child_count() > 0 or mi.material_override == null or mi.mesh == null:
			continue
		if not groups.has(mi.material_override):
			groups[mi.material_override] = []
		groups[mi.material_override].append(mi)
	var merged := 0
	for mat: Material in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in list:
			for s in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, s, mi.transform)
		var out := MeshInstance3D.new()
		out.name = "Merged%d" % merged
		out.mesh = st.commit()
		out.material_override = mat
		out.cast_shadow = (list[0] as MeshInstance3D).cast_shadow
		parent.add_child(out)
		for mi: MeshInstance3D in list:
			parent.remove_child(mi)
			mi.queue_free()
		merged += 1
	return merged
