extends Node
## The player character (KayKit Adventurers base + original outfits):
##   pack     the KayKit characters are there with their licence, share one
##            skeleton, and have Idle / Walking_A / Running_A / Jump / Cheer
##   combos   every hair x outfit (4 x 5 = 20) builds: one body, one head,
##            the outfit's own props on the right bones (and no others), a
##            smile, within the triangle budget, about 5 m tall
##   props    every prop in props.glb is one merged mesh with vertex colours
##   anims    standing = Idle, gentle push = walk, full stick = jog, jumping
##            = jump, back to Idle when landed; the screen's wave plays
##   save     the chosen looks survive a reload, bad values fall back, and
##            the walker wears them (and changes when they change)
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_character.cfg"
const TRI_BUDGET := 9000  # one player character (plus a same-size outline pass)
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	_pack_checks()
	await _combo_checks()
	_prop_checks()
	await _anim_checks()
	_save_checks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nCHARACTER TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _pack_checks() -> void:
	_check("KayKit licence file is kept with the pack", FileAccess.file_exists(CharacterModel.DIR + "LICENSE.txt"))
	var bone_lists := {}
	for who in ["Rogue", "Knight", "Mage"]:
		var scene: Node3D = (load(CharacterModel.DIR + who + ".glb") as PackedScene).instantiate()
		var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var names := []
		for b in skel.get_bone_count():
			names.append(skel.get_bone_name(b))
		bone_lists[str(names)] = true
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var ok := ["Idle", "Walking_A", "Running_A", "Jump_Start", "Jump_Idle", "Cheer"].all(func(a): return ap.has_animation(a))
		_check("%s has the animations we use" % who, ok)
		scene.free()
	_check("the base characters share one skeleton", bone_lists.size() == 1)


func _combo_checks() -> void:
	var worst := 0
	var bad := []
	var tallest := 0.0
	for o in range(1, Outfits.count() + 1):
		var look := Outfits.get_outfit(o)
		var want_props := look.props.map(func(p): return p[0])
		for h in range(1, CharacterModel.HAIRS + 1):
			var c: CharacterModel = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate()
			c.hair = h
			c.outfit = o
			add_child(c)
			await get_tree().process_frame
			var shown := c.visible_parts()
			var heads := shown.filter(func(n): return n.ends_with("_Head"))
			var bodies := shown.filter(func(n): return n.ends_with("_Body"))
			var all_props := CharacterLook.prop_names()
			var props := shown.filter(func(n): return n in all_props and n != "Face_Smile")
			var props_ok := props.size() == want_props.size() and want_props.all(func(p): return props.has(p))
			for p in look.props:  # hung on the bones the outfit says
				var mi: Node = c.find_child(p[0], true, false)
				if mi == null or not (mi.get_parent() is BoneAttachment3D) or (mi.get_parent() as BoneAttachment3D).bone_name != p[1]:
					props_ok = false
			if heads.size() != 1 or bodies.size() != 1 or not props_ok or not shown.has("Face_Smile"):
				bad.append("outfit %d hair %d: %s" % [o, h, shown])
			var tris := 0
			var box := AABB()
			var first := true
			for mi in c._parts:
				for s in mi.mesh.get_surface_count():
					var idx = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
					tris += (idx as PackedInt32Array).size() / 3 if idx != null else 0
				if mi.visible and mi.name != "Face_Smile":
					var a: AABB = mi.global_transform * mi.get_aabb()
					box = a if first else box.merge(a)
					first = false
			worst = maxi(worst, tris)
			tallest = maxf(tallest, box.size.y)
			c.queue_free()
	print("  note: heaviest look %d triangles, tallest %.2f m" % [worst, tallest])
	_check("all 20 looks: one body, one head, their own props on the right bones, a smile", bad.is_empty())
	for b in bad:
		print("    ", b)
	_check("every look within %d triangles" % TRI_BUDGET, worst <= TRI_BUDGET)
	_check("about 5 m tall (storybook size, hats included)", tallest > 4.5 and tallest < 7.0)


func _prop_checks() -> void:
	var scene: Node3D = (load(CharacterLook.PROPS) as PackedScene).instantiate()
	var ok := true
	var names := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
		var arr := mi.mesh.surface_get_arrays(0)
		if mi.mesh.get_surface_count() != 1 or arr[Mesh.ARRAY_COLOR] == null:
			ok = false
			print("    ", mi.name, " surfaces ", mi.mesh.get_surface_count())
	scene.free()
	var wanted := ["Pilot_Cap", "Pilot_Scarf", "Princess_Gown", "Princess_Tiara", "Astro_Helmet", "Astro_Pack",
		"Hero_Cape", "Hero_Emblem", "Dino_Hood", "Dino_Tail", "Face_Smile"]
	_check("all props are there", wanted.all(func(n): return names.has(n)))
	_check("each prop is one merged mesh with vertex colours", ok)


func _anim_checks() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	main.title.hide()
	var plane: Aircraft = main.get_node("Aircraft")
	var w: Walker = main.walker
	main._enter(main.State.FLYING)
	var at := Vector3(1200, 0, 40)
	plane.park(Vector3(at.x, _ground(main, at), at.z), 0.0)
	main._enter(main.State.FLYING)
	await get_tree().physics_frame
	main.toggle_plane()
	w.override_enabled = true
	main.walk_camera.override_enabled = true
	main.walk_camera.snap_to(PI)
	await _frames(30)
	_check("standing still plays Idle", w.model.anim == "Idle")
	w.override_move = Vector2(0, 0.25)
	await _frames(60)
	_check("a gentle push walks", w.model.anim == "Walking_A")
	w.override_move = Vector2(0, 1)
	await _frames(60)
	_check("full stick jogs", w.model.anim == "Running_A")
	w.override_jump = true
	await _frames(3)
	w.override_jump = false
	_check("jumping plays the jump", w.model.anim.begins_with("Jump"))
	w.override_move = Vector2.ZERO
	await _frames(120)
	_check("landed and stopped: back to Idle", w.model.anim == "Idle" and w.is_on_floor())
	main.queue_free()
	var preview: CharacterModel = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate()
	add_child(preview)
	await get_tree().process_frame
	preview.wave()
	await _frames(10)
	var waving: bool = preview.anim == "Cheer"
	await get_tree().create_timer(2.5).timeout
	_check("the screen's wave (cheer) plays, then back to Idle", waving and preview.anim == "Idle")
	preview.queue_free()
	await get_tree().process_frame


func _save_checks() -> void:
	SaveManager.use_path(PATH)
	_check("a new save starts with the first look, not yet made", SaveManager.char_hair == 1
			and SaveManager.char_outfit == 1 and not SaveManager.char_made)
	SaveManager.set_character("M", 3, 5)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("look survives reload (hair 3, dino)", SaveManager.char_hair == 3 and SaveManager.char_outfit == 5 and SaveManager.char_made)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[character]\nbody=\"X\"\nhair=7\noutfit=9\nmade=1\n")
	f.close()
	SaveManager.use_path(PATH)
	_check("bad saved look falls back", SaveManager.char_hair == 1 and SaveManager.char_outfit == 1 and not SaveManager.char_made)
	var w := Walker.new()
	add_child(w)
	SaveManager.set_character("M", 4, 3)
	_check("the walker wears the saved look (and changes with it)", w.model.hair == 4 and w.model.outfit == 3)
	w.queue_free()


func _ground(main: Node, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 800, p.z), Vector3(p.x, -60, p.z), GameSettings.LAYER_WORLD)
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else 0.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
