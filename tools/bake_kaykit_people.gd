extends Node
## Bake the city's townspeople from KayKit Adventurers characters, in the
## same style as her own character (vertex animation textures, like
## tools/bake_people.gd, for the crowd shader people_vat.gdshader).
##
## Usage (from the project root):
##   flatpak run org.godotengine.Godot --headless --path . res://tools/bake_kaykit_people.tscn
## Writes assets/characters/people/kk_<name>_crowd.res (low-poly ArrayMesh)
## and kk_<name>_vat.res (Image).
##
## Each look is built exactly as the game builds her character
## (CharacterModel with an OutfitData and a head): its visible parts' colours
## come from their repainted palette texture (sampled at each vertex's UV),
## props on bones (hats, bags) ride their bone rigidly. Parts are merged,
## simplified to about KEEP of their triangles, then Walking_A (played faster
## so the feet match the crowd's walking speed) and Idle are skinned on the
## CPU at BAKE_FPS into rows of an RGBAH image (positions, then normals).

const OUT_DIR := "res://assets/characters/people/"
const BAKE_FPS := 12.0
const KEEP := 0.28
## The crowd walks at CityCrowd.WALK_SPEED; KayKit's walk loop matches this
## ground speed (CharacterModel.WALK_NATURAL): the walk is baked this much faster.
const CROWD_WALK := 3.4



## [name, OutfitData, head]: everyday townspeople, varied outfits and colours.
static func looks() -> Array:
	return [
		["kk_baker", OutfitData.make("kk_baker", "Rogue", {"r1c0": Color("ffffff"), "r0c5": Color("8a8f99"), "r0c6": Color("5a3a22"),
			"r2c5": Color("5a3a22")}, [["Chef_Hat", "head"]], ["Rogue_Cape"]), ["Knight", {"r0c1": Color("a0522d")}]],
		["kk_jogger", OutfitData.make("kk_jogger", "Rogue", {"r1c0": Color("ff5a5f"), "r0c5": Color("2b2d42"), "r0c6": Color("ffffff"),
			"r2c5": Color("ffffff")}, [["Beanie", "head"]], ["Rogue_Cape"]), ["Rogue", {"r0c1": Color("3b2a20")}]],
		["kk_gardener", OutfitData.make("kk_gardener", "Rogue", {"r1c0": Color("4cc06a"), "r0c5": Color("6b4226"), "r0c6": Color("6b4226"),
			"r2c5": Color("6b4226")}, [["Straw_Hat", "head"]], ["Rogue_Cape"]), ["Barbarian", {}]],
		["kk_artist", OutfitData.make("kk_artist", "Mage", {"r1c0": Color("9b5de5"), "r0c3": Color("ffffff"), "r0c4": Color("ffd23f")},
			[["Beret", "head"]]), ["Mage", {"r0c1": Color("2a2522")}]],
		["kk_grandad", OutfitData.make("kk_grandad", "Knight", {"r0c3": Color("6b7a8f"), "r0c7": Color("3a4250"), "r0c6": Color("6b4226"),
			"r0c4": Color("8a8f99"), "r1c0": Color("e9c46a"), "r1c2": Color("6b4226"), "r1c7": Color("3a4250")},
			[["Flat_Cap", "head"]]), ["Rogue", {"r0c1": Color("d9d9e0")}]],
		["kk_lady", OutfitData.make("kk_lady", "Mage", {"r1c0": Color("4aa8ff"), "r0c3": Color("fff0f5"), "r0c4": Color("4aa8ff")},
			[["Sun_Hat", "head"]]), ["Mage", {"r0c1": Color("7a4a2a")}]],
	]


func _ready() -> void:
	for l in looks():
		await _bake(l[0], l[1], l[2])
	get_tree().quit()


func _bake(char_name: String, look: OutfitData, head: Array) -> void:
	var model := (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	model.look_override = look
	model.head_override = head
	add_child(model)
	await get_tree().process_frame
	await get_tree().process_frame
	var skel: Skeleton3D = model._skel
	var ap: AnimationPlayer = model._anim
	ap.stop()
	# Model space turned to face +Z (the crowd walks along +Z).
	var to_crowd := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * model.global_transform.affine_inverse()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var vinfo := []     # per vertex: ["skin", skin, bone ids, weights] or ["rigid", bone, rel transform]
	var idx := PackedInt32Array()
	var parts := []
	# 1a. Skinned parts (body, arms, legs, head) with their palette colours.
	for mi: MeshInstance3D in model._parts:
		if mi.get_parent() is BoneAttachment3D or mi.skin == null and mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] == null:
			continue  # a prop on a bone: below
		var img: Image = _texture_of(mi)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			if arr[Mesh.ARRAY_BONES] == null:
				continue
			var base := pos.size()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var bb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ww: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bb.size() / v.size()
			for i in v.size():
				pos.append(v[i])
				nrm.append(nn[i])
				col.append(_sample(img, uv[i]) if img and uv.size() > i else Color.WHITE)
				var ids := []
				var ws := []
				for k in mini(per, 4):
					var b := bb[i * per + k]
					var sb := b
					if mi.skin:
						sb = mi.skin.get_bind_bone(b)
						if sb < 0:
							sb = skel.find_bone(mi.skin.get_bind_name(b))
					ids.append([sb, mi.skin.get_bind_pose(b) if mi.skin else Transform3D()])
					ws.append(ww[i * per + k])
				vinfo.append(["skin", ids, ws, mi.global_transform])
			var ii = arr[Mesh.ARRAY_INDEX]
			parts.append([idx.size(), idx.size() + ((ii as PackedInt32Array).size() if ii != null else v.size())])
			if ii == null:
				for i in v.size():
					idx.append(base + i)
			else:
				for i in (ii as PackedInt32Array):
					idx.append(base + i)
	# 1b. Props on bones (hats...): rigid, coloured by their vertex colours.
	for att: BoneAttachment3D in skel.find_children("*", "BoneAttachment3D", true, false):
		var bone := skel.find_bone(att.bone_name)
		for mi: MeshInstance3D in att.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree():
				continue
			var rel := att.global_transform.affine_inverse() * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var base := pos.size()
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var cc = arr[Mesh.ARRAY_COLOR]
				var mat := mi.get_active_material(s) as BaseMaterial3D
				for i in v.size():
					pos.append(v[i])
					nrm.append(nn[i])
					col.append((cc as PackedColorArray)[i] if cc != null else (mat.albedo_color if mat else Color.WHITE))
					vinfo.append(["rigid", bone, rel])
				var ii = arr[Mesh.ARRAY_INDEX]
				parts.append([idx.size(), idx.size() + ((ii as PackedInt32Array).size() if ii != null else v.size())])
				if ii == null:
					for i in v.size():
						idx.append(base + i)
				else:
					for i in (ii as PackedInt32Array):
						idx.append(base + i)
	# 2. Simplify each part.
	var best := PackedInt32Array()
	for part in parts:
		best.append_array(_simplify(pos, nrm, col, idx, part[0], part[1]))
	var remap := {}
	var used: Array[int] = []
	var new_idx := PackedInt32Array()
	for i in best:
		if not remap.has(i):
			remap[i] = used.size()
			used.append(i)
		new_idx.append(remap[i])
	var count := used.size()
	# 3. Skin every used vertex for each frame (the walk sped up to the crowd's pace).
	var speedup := CROWD_WALK / CharacterModel.WALK_NATURAL
	var anims := [["Walking_A", speedup], ["Idle", 1.0]]
	var frames_per: Array[int] = []
	for a in anims:
		frames_per.append(maxi(int(round(ap.get_animation(a[0]).length / a[1] * BAKE_FPS)), 1))
	var total := 0
	for f in frames_per:
		total += f
	var img := Image.create(count, total * 2, false, Image.FORMAT_RGBAH)
	var row := 0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var skel_gt := skel.global_transform
	for ai in anims.size():
		var anim: String = anims[ai][0]
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
				var info: Array = vinfo[vi]
				var world: Vector3
				var wn: Vector3
				if info[0] == "skin":
					var m := Transform3D()
					m.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
					var wsum := 0.0
					for k in (info[1] as Array).size():
						var w: float = info[2][k]
						if w <= 0.0:
							continue
						var t: Transform3D = pose[info[1][k][0]] * (info[1][k][1] as Transform3D)
						m.basis.x += t.basis.x * w
						m.basis.y += t.basis.y * w
						m.basis.z += t.basis.z * w
						m.origin += t.origin * w
						wsum += w
					if wsum <= 0.0:
						m = Transform3D()
					world = skel_gt * (m * pos[vi])
					wn = (skel_gt.basis * (m.basis * nrm[vi]))
				else:
					var t: Transform3D = skel_gt * pose[info[1]] * (info[2] as Transform3D)
					world = t * pos[vi]
					wn = t.basis * nrm[vi]
				var p := to_crowd * world
				var n := (to_crowd.basis * wn).normalized()
				img.set_pixel(j, row, Color(p.x, p.y, p.z, 1.0))
				img.set_pixel(j, row + total, Color(n.x, n.y, n.z, 0.0))
				lo = lo.min(p)
				hi = hi.max(p)
			row += 1
	# 4. The mesh.
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
	mesh.set_meta("scale", 1.0)  # already her size (~5 m)
	ResourceSaver.save(mesh, OUT_DIR + char_name + "_crowd.res")
	ResourceSaver.save(img, OUT_DIR + char_name + "_vat.res")
	print("%-12s %d verts, %d tris (from %d), frames %s, height %.2f" % [char_name, count, new_idx.size() / 3, idx.size() / 3,
		frames_per, hi.y - lo.y])
	model.queue_free()
	await get_tree().process_frame


## The palette image a part is painted with (its material's albedo texture).
func _texture_of(mi: MeshInstance3D) -> Image:
	var mat := mi.get_active_material(0)
	var tex: Texture2D = null
	if mat is BaseMaterial3D:
		tex = (mat as BaseMaterial3D).albedo_texture
	elif mat is ShaderMaterial:
		for p in ["albedo_tex", "albedo_texture", "texture_albedo"]:
			var v = (mat as ShaderMaterial).get_shader_parameter(p)
			if v is Texture2D:
				tex = v
				break
	if tex == null:
		push_warning("no palette texture on " + mi.name)
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


static func _sample(img: Image, uv: Vector2) -> Color:
	var x := clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


## One part's simplified triangles (as tools/bake_people.gd).
func _simplify(pos: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array, from: int, to: int) -> PackedInt32Array:
	return _simplify_part(pos, nrm, col, idx, from, to)


func _simplify_part(pos: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array, from: int, to: int) -> PackedInt32Array:
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
