extends Node
## The player character (built in Blender):
##   model    the .glb has both bodies, 4 hairs, 4 outfits x 2 bodies, all
##            on ONE skeleton, and Idle / Walk / Run / Jump
##   combos   every body x hair x outfit (32) shows exactly its 3 parts,
##            stays within the triangle budget and stands ~5 m tall
##   anims    standing = Idle, walking = Walk, sprinting = Run, jumping =
##            Jump, back to Idle when landed; feet speed follows ground speed
##   save     the chosen looks survive a reload, bad values fall back, and
##            the walker wears them (and changes when they change)
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_character.cfg"
const TRI_BUDGET := 18000  # the one player character; townspeople are low-detail
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	_model_checks()
	await _anim_checks()
	_save_checks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nCHARACTER TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _model_checks() -> void:
	var scene: Node3D = (load(CharacterModel.SCENE) as PackedScene).instantiate()
	add_child(scene)
	var names := {}
	var skels := {}
	var tris := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		names[String(mi.name)] = true
		skels[mi.get_node(mi.skeleton)] = true
		var t := 0
		for s in mi.mesh.get_surface_count():
			var idx = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx != null else 0
		tris[String(mi.name)] = t
	var want := ["Body_M", "Body_F"]
	for i in range(1, 5):
		want.append("Hair_%d" % i)
		want.append("Outfit_%d_M" % i)
		want.append("Outfit_%d_F" % i)
	_check("all 14 parts are in the model", want.all(func(n): return names.has(n)) and names.size() == 14)
	_check("every part is skinned to the same one skeleton", skels.size() == 1)
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	_check("Idle, Walk, Run and Jump animations", ["Idle", "Walk", "Run", "Jump"].all(func(a): return ap.has_animation(a)))
	var worst := 0
	for b in ["M", "F"]:
		for h in range(1, 5):
			for o in range(1, 5):
				worst = maxi(worst, tris["Body_" + b] + tris["Hair_%d" % h] + tris["Outfit_%d_%s" % [o, b]])
	print("  note: heaviest combination %d triangles" % worst)
	_check("every combination within %d triangles" % TRI_BUDGET, worst <= TRI_BUDGET)
	scene.queue_free()
	# Every combination shows exactly its own three parts.
	var cm := CharacterModel.new()
	add_child(cm)
	var bad := []
	for b in ["M", "F"]:
		for h in range(1, 5):
			for o in range(1, 5):
				cm.apply(b, h, o)
				var shown := cm.visible_parts()
				shown.sort()
				var expect: Array[String] = ["Body_" + b, "Hair_%d" % h, "Outfit_%d_%s" % [o, b]]
				expect.sort()
				if shown != expect:
					bad.append("%s/%d/%d" % [b, h, o])
	_check("all 32 combinations show exactly body + hair + outfit", bad.is_empty())
	cm.apply("Z", 9, -3)
	_check("bad choices clamp to real ones", cm.body == "M" and cm.hair == 4 and cm.outfit == 1)
	# Height in the game: ~5 m like the townspeople.
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in cm.find_children("*", "MeshInstance3D", true, false):
		if mi.visible:
			var a: AABB = mi.global_transform * mi.get_aabb()
			box = a if first else box.merge(a)
			first = false
	print("  note: standing height %.2f m" % box.size.y)
	_check("about 5 m tall in the game (storybook size)", absf(box.size.y - Walker.HEIGHT) < 0.6)
	cm.queue_free()


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
	w.override_move = Vector2(0, 1)
	await _frames(60)
	var walk_scale: float = w.model._anim.speed_scale
	_check("walking plays Walk", w.model.anim == "Walk")
	w.override_move = Vector2(0, 0.5)
	await _frames(60)
	_check("slower walking plays the walk slower", w.model.anim == "Walk" and w.model._anim.speed_scale < walk_scale - 0.2)
	w.override_move = Vector2(0, 1)
	w.override_sprint = true
	await _frames(60)
	_check("sprinting plays Run", w.model.anim == "Run")
	w.override_jump = true
	await _frames(3)
	w.override_jump = false
	_check("jumping plays Jump", w.model.anim == "Jump")
	w.override_move = Vector2.ZERO
	w.override_sprint = false
	await _frames(120)
	_check("landed and stopped: back to Idle", w.model.anim == "Idle" and w.is_on_floor())
	main.queue_free()
	await get_tree().process_frame


func _save_checks() -> void:
	SaveManager.use_path(PATH)
	_check("a new save starts with the first character, not yet made", SaveManager.char_body == "M"
			and SaveManager.char_hair == 1 and SaveManager.char_outfit == 1 and not SaveManager.char_made)
	SaveManager.set_character("F", 3, 2)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("character survives reload", SaveManager.char_body == "F" and SaveManager.char_hair == 3
			and SaveManager.char_outfit == 2 and SaveManager.char_made)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('[character]\nbody="X"\nhair=7\noutfit="red"\nmade=1\n')
	f.close()
	SaveManager.use_path(PATH)
	_check("bad saved character falls back", SaveManager.char_body == "M" and SaveManager.char_hair == 1
			and SaveManager.char_outfit == 1 and not SaveManager.char_made)
	var w := Walker.new()
	add_child(w)
	SaveManager.set_character("F", 4, 3)
	_check("the walker wears the saved looks (and changes with them)", w.model.body == "F" and w.model.hair == 4 and w.model.outfit == 3)
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
