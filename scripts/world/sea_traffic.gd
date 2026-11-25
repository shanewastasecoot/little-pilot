class_name SeaTraffic
extends RefCounted
## Things out at sea that a boat (her sail boat, or a seaplane taxiing on the
## water) must steer round rather than sail through: the cruising sail boat,
## the pirate ship, the whale and the mermaids' rocks. They have no collision
## of their own (they move, or are just for looking at), so boats ask here.

## Class name -> how far from its middle counts as "in the way" (m).
const RADII := {"Boat": 13.0, "PirateShip": 34.0, "Whale": 22.0}
const ROCK_RADIUS := 11.0

## [Node3D to measure from, radius] — gathered once per scene tree.
static var _list: Array = []
static var _tree_id := 0
static var _gathered_at := -100000


static func obstacles(tree: SceneTree) -> Array:
	# (Gathered once per scene; again only if the scene changed under it.
	# An empty list is remembered too: no searching the scene every frame.)
	var now := Time.get_ticks_msec()
	if _tree_id != tree.get_instance_id() or (not _list.is_empty() and not is_instance_valid(_list[0][0])) \
			or (_list.is_empty() and now - _gathered_at > 5000):
		_tree_id = tree.get_instance_id()
		_gathered_at = now
		_list = []
		for l in tree.get_nodes_in_group("landmarks"):
			var cls := (l.get_script() as Script).get_global_name() if l.get_script() else &""
			if RADII.has(String(cls)):
				var at: Node3D = l.get("_body") if l.get("_body") is Node3D else (l.get("_hull") if l.get("_hull") is Node3D else l)
				_list.append([at, RADII[String(cls)]])
		for n in tree.root.find_children("*", "Node3D", true, false):
			if n is Recipient and (n as Recipient).is_mermaid():
				_list.append([n, ROCK_RADIUS])
	return _list


## Is `p` (world) inside something at sea, allowing `margin` (m) for the
## asker's own size?
static func blocked(tree: SceneTree, p: Vector3, margin := 0.0) -> bool:
	for o in obstacles(tree):
		var n: Node3D = o[0]
		if is_instance_valid(n) and n.is_inside_tree() and n.is_visible_in_tree() \
				and Vector2(p.x - n.global_position.x, p.z - n.global_position.z).length() < float(o[1]) + margin:
			return true
	return false


## Where something of radius `r` at `p` should be so nothing at sea overlaps
## it (pushed straight out from whatever it's inside); `p` if nothing.
static func push_out(tree: SceneTree, p: Vector3, r: float) -> Vector3:
	for o in obstacles(tree):
		var n: Node3D = o[0]
		if not is_instance_valid(n) or not n.is_inside_tree() or not n.is_visible_in_tree():
			continue
		var d := Vector2(p.x - n.global_position.x, p.z - n.global_position.z)
		var need := float(o[1]) + r
		if d.length() < need:
			var out := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
			p.x = n.global_position.x + out.x * need
			p.z = n.global_position.z + out.y * need
	return p
