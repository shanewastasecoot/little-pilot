extends SceneTree
## Bake townspeople for the city crowd (vertex animation textures).
##
## Usage (from the project root):
##   flatpak run org.godotengine.Godot --headless --path . -s tools/bake_people.gd
## Reads assets/characters/people/<name>.glb, writes <name>_crowd.res (a
## low-poly ArrayMesh) and <name>_vat.res (an Image) next to it.
##
## Each character's parts are merged into one surface with its material
## colours baked into vertex colours, each part simplified to about a
## quarter of its triangles (meshoptimizer LODs), then its Walk and Idle loops are skinned
## on the CPU at BAKE_FPS and stored as rows of an RGBAH image: for frame f,
## row f holds every vertex's position and row f + FRAMES holds its normal.
## UV2.x of each vertex is its column. The crowd shader (people_vat.gdshader)
## reads them back, so hundreds of walkers draw in one call per character.

const IN_DIR := "res://assets/characters/people/"
const NAMES := ["worker", "suit", "hoodie", "beach", "woman_a", "woman_b"]
const ANIMS := ["CharacterArmature|Walk", "CharacterArmature|Idle"]
const BAKE_FPS := 12.0
const KEEP := 0.22

var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var dir := IN_DIR
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
	for n in NAMES:
		_bake(dir, n)
	return true


func _bake(dir: String, char_name: String) -> void:
	var path := dir + char_name + ".glb"
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("can't load " + path)
		return
	var scene: Node3D = doc.generate_scene(state)
	root.add_child(scene)
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var to_root := scene.global_transform.affine_inverse() * skel.global_transform
	# 1. Merge every part into one indexed surface.
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()     # 4 skeleton bone indices per vertex
	var weights := PackedFloat32Array()  # 4 weights per vertex
	var bind := []                       # per vertex: its part's skin (bind poses)
	var idx := PackedInt32Array()
	var parts := []                      # [from, to) ranges of idx, one per part
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = mi.skin
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var c := mat.albedo_color if mat else Color.WHITE
			var base := pos.size()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bb = arr[Mesh.ARRAY_BONES]
			var ww = arr[Mesh.ARRAY_WEIGHTS]
			var per := (bb as PackedInt32Array).size() / v.size()
			for i in v.size():
				pos.append(v[i])
				nrm.append(nn[i])
				col.append(c)
				for k in 4:
					var b: int = bb[i * per + k] if k < per else 0
					var w: float = ww[i * per + k] if k < per else 0.0
					# With a skin, bone ids index its binds; map to skeleton bones.
					var sb := b
					if skin:
						sb = skin.get_bind_bone(b)
						if sb < 0:
							sb = skel.find_bone(skin.get_bind_name(b))
					bones.append(sb)
					weights.append(w)
				bind.append([skin, bb, i * per, per])
			var ii = arr[Mesh.ARRAY_INDEX]
			parts.append([idx.size(), idx.size() + ((ii as PackedInt32Array).size() if ii != null else v.size())])
			if ii == null:
				for i in v.size():
					idx.append(base + i)
			else:
				for i in (ii as PackedInt32Array):
					idx.append(base + i)
	# 2. Simplify each part on its own with meshoptimizer (ImporterMesh
	#    LODs): the coarsest LOD that keeps about KEEP of its triangles and
	#    its full size (so no head or feet go missing).
	var best := PackedInt32Array()
	for part in parts:
		best.append_array(_simplify(pos, nrm, col, idx, part[0], part[1]))
	# Compact to the vertices the simplified mesh still uses.
	var remap := {}
	var used: Array[int] = []
	var new_idx := PackedInt32Array()
	for i in best:
		if not remap.has(i):
			remap[i] = used.size()
			used.append(i)
		new_idx.append(remap[i])
	var count := used.size()
	# 3. Skin every used vertex for each frame of each animation.
	var frames_per: Array[int] = []
	for a in ANIMS:
		frames_per.append(maxi(int(round(ap.get_animation(a).length * BAKE_FPS)), 1))
	var total := 0
	for f in frames_per:
		total += f
	var img := Image.create(count, total * 2, false, Image.FORMAT_RGBAH)
	var row := 0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for ai in ANIMS.size():
		var anim: String = ANIMS[ai]
		ap.play(anim)
		var length := ap.get_animation(anim).length
		for f in frames_per[ai]:
			ap.seek(length * f / frames_per[ai], true)
			var pose := []
			pose.resize(skel.get_bone_count())
			for b in skel.get_bone_count():
				pose[b] = skel.get_bone_global_pose(b)
			for j in count:
				var vi := used[j]
				var info: Array = bind[vi]
				var skin: Skin = info[0]
				var m := Transform3D()
				m.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
				var wsum := 0.0
				for k in 4:
					var w: float = weights[vi * 4 + k]
					if w <= 0.0:
						continue
					var sb: int = bones[vi * 4 + k]
					var bind_pose := Transform3D()
					if skin:
						bind_pose = skin.get_bind_pose(info[1][info[2] + k])
					var t: Transform3D = pose[sb] * bind_pose
					m.basis.x += t.basis.x * w
					m.basis.y += t.basis.y * w
					m.basis.z += t.basis.z * w
					m.origin += t.origin * w
					wsum += w
				if wsum <= 0.0:
					m = Transform3D()
				var p := to_root * (m * pos[vi])
				var n := (to_root.basis * (m.basis * nrm[vi])).normalized()
				img.set_pixel(j, row, Color(p.x, p.y, p.z, 1.0))
				img.set_pixel(j, row + total, Color(n.x, n.y, n.z, 0.0))
				lo = lo.min(p)
				hi = hi.max(p)
			row += 1
	# 4. The mesh: rest-pose vertices (first walk frame), colours, column in UV2.
	var out_pos := PackedVector3Array()
	var out_nrm := PackedVector3Array()
	var out_col := PackedColorArray()
	var out_uv2 := PackedVector2Array()
	for j in count:
		var c0 := img.get_pixel(j, 0)
		var n0 := img.get_pixel(j, total)
		out_pos.append(Vector3(c0.r, c0.g, c0.b))
		out_nrm.append(Vector3(n0.r, n0.g, n0.b))
		out_col.append(col[used[j]])
		out_uv2.append(Vector2(j + 0.5, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_pos
	arrays[Mesh.ARRAY_NORMAL] = out_nrm
	arrays[Mesh.ARRAY_COLOR] = out_col
	arrays[Mesh.ARRAY_TEX_UV2] = out_uv2
	arrays[Mesh.ARRAY_INDEX] = new_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(lo, hi - lo).grow(0.1)
	mesh.set_meta("frames", frames_per)
	mesh.set_meta("bake_fps", BAKE_FPS)
	var out := dir + char_name
	ResourceSaver.save(mesh, out + "_crowd.res")
	ResourceSaver.save(img, out + "_vat.res")
	print("%-8s %d verts, %d tris (from %d), frames %s, height %.2f" % [char_name, count, new_idx.size() / 3, idx.size() / 3, frames_per, hi.y - lo.y])
	scene.free()


## One part's simplified triangles (indices into the merged arrays).
func _simplify(pos: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array, from: int, to: int) -> PackedInt32Array:
	var local := {}
	var lp := PackedVector3Array()
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	var back := PackedInt32Array()
	var li := PackedInt32Array()
	for k in range(from, to):
		var g := idx[k]
		if not local.has(g):
			local[g] = lp.size()
			lp.append(pos[g])
			ln.append(nrm[g])
			lc.append(col[g])
			back.append(g)
		li.append(local[g])
	var full := _box(lp, li)
	var im := ImporterMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = lp
	arr[Mesh.ARRAY_NORMAL] = ln
	arr[Mesh.ARRAY_COLOR] = lc
	arr[Mesh.ARRAY_INDEX] = li
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	var pick := li
	for l in im.get_surface_lod_count(0):
		var cand := im.get_surface_lod_indices(0, l)
		var size := _box(lp, cand)
		var whole := size.x >= full.x * 0.95 and size.y >= full.y * 0.95 and size.z >= full.z * 0.95
		if whole and cand.size() >= li.size() * KEEP and cand.size() < pick.size():
			pick = cand
	var out := PackedInt32Array()
	for i in pick:
		out.append(back[i])
	return out


func _box(p: PackedVector3Array, ii: PackedInt32Array) -> Vector3:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in ii:
		lo = lo.min(p[i])
		hi = hi.max(p[i])
	return hi - lo
