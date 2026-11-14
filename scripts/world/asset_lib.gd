class_name AssetLib
extends RefCounted
## Helpers for placing imported .glb models: instancing with scale and a
## looping animation, and pulling a single mesh out for MultiMesh use.

## Instance a model under `parent`. Plays its first (or named) animation
## on loop if it has one.
static func place(parent: Node3D, path: String, pos := Vector3.ZERO, scale := 1.0, yaw_deg := 0.0, anim := "") -> Node3D:
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.scale = Vector3.ONE * scale
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	play_loop(node, anim)
	return node


static func play_loop(node: Node, anim := "", speed := 1.0) -> void:
	var players := node.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var ap: AnimationPlayer = players[0]
	var name := anim if anim != "" and ap.has_animation(anim) else ap.get_animation_list()[0]
	ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	ap.play(name, -1, speed)
	ap.seek(randf() * ap.current_animation_length)  # herds don't move in sync


static var _mesh_cache: Dictionary = {}


## The first mesh in a .glb plus its transform relative to the model root,
## with transparent materials switched to cheap alpha scissor (no sorting,
## far less overdraw on the Steam Deck). Returns [Mesh, Transform3D].
static func mesh_of(path: String) -> Array:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var root: Node = load(path).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D.IDENTITY
	var cur: Node = mi
	while cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	var mesh: Mesh = mi.mesh.duplicate()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			m = m.duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(i, m)
	root.free()
	_mesh_cache[path] = [mesh, xf]
	return _mesh_cache[path]
