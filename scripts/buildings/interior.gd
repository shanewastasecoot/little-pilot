class_name Interior
extends Node3D
## The inside of a building (made by BuildingGenerator): its rooms, walls,
## exits and toys. While you're inside, the camera calls update_view(): any
## wall between the camera and you fades away (so you're never hidden), and
## the storey above yours is hidden, dollhouse style. Walking into an exit's
## doorway emits exit_reached.

signal exit_reached

const FADE := 0.82            # how see-through a faded wall is
const FADE_SPEED := 6.0

var data: Dictionary = {}
## {id, type, rect (Rect2), floor, base, node}
var rooms: Array = []
## {room, a, b (Vector2 ends on the plan), inward, floor, pieces}
var walls: Array = []
## {trigger (Area3D), spawn (Vector3 local), yaw}
var exits: Array = []
var toy_boxes: Array = []
var balls: Array = []
var fridges: Array = []
var pots: Array = []
var tvs: Array[TVSet] = []
## The people living here (Family), if any.
var family: Family
var mermaid_toys: Array[Node3D] = []
var stuffies: Array[Node3D] = []
var tables: Array = []
var sofas: Array = []
var beds: Array = []
var switches: Array = []
var trophy_shelf: TrophyShelf
var house_star: HouseStar
## Her bedroom's info (rooms entry): its wall materials, quilt and pickers.
var her_room: Dictionary = {}
## {from, to, bottom (local), top (local)}
var stairs: Array = []
var _room_fade: Dictionary = {}    # room id -> how visible 0..1
var _room_items: Dictionary = {}   # room id -> [GeometryInstance3D] (not its walls)
var _fade: Dictionary = {}    # wall index -> current fade 0..1


## A way out at `at` (local) and where you appear coming in through it.
func add_exit(at: Vector3, spawn: Vector3, yaw: float) -> void:
	var area := Area3D.new()
	area.name = "Exit%d" % exits.size()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	area.monitoring = false  # switched on a moment after you come in
	var shape := SphereShape3D.new()
	shape.radius = 2.6
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	area.position = at
	add_child(area)
	area.body_entered.connect(func(b): if b is Walker: exit_reached.emit())
	exits.append({"trigger": area, "spawn": spawn, "yaw": yaw})


## Where you appear coming in (world space) and which way you face.
func entry_point() -> Vector3:
	return to_global(exits[0].spawn) if not exits.is_empty() else global_position
func entry_yaw() -> float:
	return exits[0].yaw if not exits.is_empty() else 0.0


## Coming in: the exits wait until you've stepped away from them.
func arrive() -> void:
	for e in exits:
		e.trigger.monitoring = false
	await get_tree().create_timer(0.6, false).timeout
	for e in exits:
		if is_instance_valid(e.trigger):
			e.trigger.monitoring = true


## Going out: toys back in the box, the ball back where it was.
func reset() -> void:
	for tb in toy_boxes:
		tb.reset()
	for b in balls:
		b.reset()
	for f in fridges:
		f.reset()
	for t in tables:
		t.reset()
	for s in switches:
		s.reset()
	for tv in tvs:
		tv.reset()
	# A meal still in your arms stays in the house.
	var w := get_tree().get_first_node_in_group("player_focus") as Walker if is_inside_tree() else null
	if w and w.model.carrying and w.model.carry_item.begins_with("Meal_"):
		w.model.set_carrying(false)
	if house_star:
		house_star.reset()


## The middle of a doorway (world space, on the floor): the door on `side`
## of room `room_id` at fraction `at` along it.
func door_point(room_id: String, side: String, at: float) -> Vector3:
	for r in rooms:
		if r.id != room_id:
			continue
		var rect: Rect2 = r.rect
		var p := Vector2.ZERO
		match side:
			"N": p = Vector2(rect.position.x + at * rect.size.x, rect.position.y)
			"S": p = Vector2(rect.position.x + at * rect.size.x, rect.end.y)
			"W": p = Vector2(rect.position.x, rect.position.y + at * rect.size.y)
			_: p = Vector2(rect.end.x, rect.position.y + at * rect.size.y)
		return to_global(Vector3(p.x, r.base, p.y))
	return global_position


func find_room(room_id: String) -> Dictionary:
	for r in rooms:
		if r.id == room_id:
			return r
	return {}


## Her room's walls in colour `i` of PaintStation.COLOURS (saved if `save`).
## i = -1: back to the colour it was built with.
func paint_her_walls(i: int, save := false) -> void:
	if her_room.is_empty() or i < -1 or i >= PaintStation.COLOURS.size():
		return
	if i == -1:
		for m: StandardMaterial3D in her_room.mats:
			if m.has_meta("built"):
				m.albedo_color = m.get_meta("built")
		if her_room.has("wall_station"):
			(her_room.wall_station as PaintStation).show_colour(-1)
		return
	for s in switches:
		if s.get_parent() == her_room.node and not s.on:
			s.set_on(true)
	for m: StandardMaterial3D in her_room.mats:
		if m.get_meta("wall", false):
			if not m.has_meta("built"):
				m.set_meta("built", m.albedo_color)
			m.albedo_color = (PaintStation.COLOURS[i] as Color).lightened(0.35)
	if her_room.has("wall_station"):
		(her_room.wall_station as PaintStation).show_colour(i)
	if save:
		SaveManager.set_house_colours(i, SaveManager.house_bed)


## Her bed's quilt in colour `i` (saved if `save`).
func colour_her_quilt(i: int, save := false) -> void:
	if her_room.is_empty() or not her_room.has("quilt") or i < -1 or i >= PaintStation.COLOURS.size():
		return
	(her_room.quilt as StandardMaterial3D).albedo_color = Color.WHITE if i == -1 else PaintStation.COLOURS[i]
	if her_room.has("bed_station"):
		(her_room.bed_station as PaintStation).show_colour(i)
	if save:
		SaveManager.set_house_colours(SaveManager.house_wall, i)


## Doorways (and stairs) between rooms: [room a, room b, point on a's side,
## point on b's side] (world space; the same point for a doorway, the
## bottom and top of the stairs for a flight).
## A doorway is listed on both rooms' sides; these are the pairs that meet.
func doorways() -> Array:
	var ends := []
	var storey: float = data.get("storey_height", 11.0)
	for room: Dictionary in data.get("rooms", []):
		for d: Dictionary in room.get("doors", []):
			if not d.get("exit", false):
				ends.append([str(room.id), door_point(str(room.id), str(d.side), float(d.at))])
	var out := []
	for i in ends.size():
		for j in range(i + 1, ends.size()):
			if ends[i][0] != ends[j][0] and (ends[i][1] as Vector3).distance_to(ends[j][1]) < 1.5:
				out.append([ends[i][0], ends[j][0], ends[i][1], ends[i][1]])
	# Stairs: from a spot in front of the bottom step to one beyond the top
	# (so going up or down is a straight walk along the flight).
	for st in stairs:
		var along: Vector3 = ((st.top as Vector3) - (st.bottom as Vector3)) * Vector3(1, 0, 1)
		along = along.normalized()
		out.append([st.from, st.to, to_global((st.bottom as Vector3) - along * 3.0), to_global((st.top as Vector3) + along * 3.5)])
	return out


## The doorways to walk through from one room to another (shortest by
## number of rooms), as world points.
func route(from_room: String, to_room: String) -> Array:
	var prev := {from_room: ""}
	var via := {}
	var queue := [from_room]
	var links := doorways()
	while not queue.is_empty():
		var r: String = queue.pop_front()
		if r == to_room:
			break
		for l in links:
			for k in 2:
				var a: String = l[k]
				var b: String = l[1 - k]
				if a == r and not prev.has(b):
					prev[b] = r
					via[b] = [l[2 + k], l[3 - k]]  # from a's side to b's side
					queue.append(b)
	if not prev.has(to_room):
		return []
	var chain := [to_room]
	while chain[0] != from_room:
		chain.push_front(prev[chain[0]])
	var path := []
	for idx in range(1, chain.size()):
		var pts: Array = via[chain[idx]]
		var door_in: Vector3 = pts[0]
		# Two doorways in the same wall of the room between them: step out
		# into that room first (not along the wall from one to the other).
		if not path.is_empty():
			var last: Vector3 = path[-1]
			var same_z := absf(last.z - door_in.z) < 0.5
			if same_z or absf(last.x - door_in.x) < 0.5:
				var c := room_centre(chain[idx - 1])
				var step := Vector3(0, 0, signf(c.z - last.z) * 3.5) if same_z else Vector3(signf(c.x - last.x) * 3.5, 0, 0)
				path.append(last + step)
				path.append(door_in + step)
		if path.is_empty() or not (door_in as Vector3).is_equal_approx(pts[1]):
			path.append(door_in)
		path.append(pts[1])
	return _around_obstacles(path)


## Keep-out areas on each storey (local plan rects): the stairs on the
## storey they start from, and holes in the floor on theirs.
func _keep_out() -> Array:
	var out := []
	var storey: float = data.get("storey_height", 11.0)
	for st in stairs:
		var b: Vector3 = st.bottom
		var t: Vector3 = st.top
		var w := 6.0
		for s: Dictionary in data.get("stairs", []):
			w = float(s.get("width", 6.0))
		var r := Rect2(Vector2(minf(b.x, t.x), minf(b.z, t.z)), Vector2.ZERO).expand(Vector2(maxf(b.x, t.x), maxf(b.z, t.z)))
		r = r.grow_individual(0.0 if absf(t.z - b.z) > 0.1 else 0.0, w * 0.5, 0.0, w * 0.5) if absf(t.x - b.x) > absf(t.z - b.z) \
				else r.grow_individual(w * 0.5, 0.0, w * 0.5, 0.0)
		out.append([floori((b.y + 1.0) / storey), r.grow(1.2)])
	for room: Dictionary in data.get("rooms", []):
		for h: Array in room.get("holes", []):
			out.append([int(room.get("floor", 0)), Rect2(float(h[0]), float(h[1]), float(h[2]), float(h[3])).grow(1.2)])
	return out


## Walking straight between two points of a route on the same storey
## mustn't cross the stairs or a hole: go round by the side nearer the
## next point (two corners of the keep-out area).
func _around_obstacles(path: Array) -> Array:
	var storey: float = data.get("storey_height", 11.0)
	var areas := _keep_out()
	var out := []
	for i in path.size():
		var q: Vector3 = path[i]
		if i > 0:
			var p: Vector3 = out[out.size() - 1]
			var lp := to_local(p)
			var lq := to_local(q)
			if absf(lp.y - lq.y) < 1.0:
				var f := floori((lp.y + 1.0) / storey)
				for a in areas:
					if a[0] != f:
						continue
					var r: Rect2 = a[1]
					var p2 := Vector2(lp.x, lp.z)
					var q2 := Vector2(lq.x, lq.z)
					if not _segment_hits_rect(p2, q2, r):
						continue
					# Go round: the shortest way by one corner or two
					# neighbouring corners, staying inside this room.
					var room_rect := r
					var here := room_at(p)
					if not here.is_empty():
						room_rect = (here.rect as Rect2).grow(-1.3)
					var c: Array[Vector2] = []
					for k in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
						var off: Vector2 = ((k as Vector2) - r.get_center()).sign() * 1.5
						var cc: Vector2 = k + off
						cc.x = clampf(cc.x, room_rect.position.x, room_rect.end.x)
						cc.y = clampf(cc.y, room_rect.position.y, room_rect.end.y)
						c.append(cc)
					var best: Array = []
					var best_len := INF
					for k in 4:
						if not _segment_hits_rect(p2, c[k], r) and not _segment_hits_rect(c[k], q2, r):
							var l := p2.distance_to(c[k]) + c[k].distance_to(q2)
							if l < best_len:
								best_len = l
								best = [c[k]]
						for j in [(k + 1) % 4, (k + 3) % 4]:
							if not _segment_hits_rect(p2, c[k], r) and not _segment_hits_rect(c[k], c[j], r) \
									and not _segment_hits_rect(c[j], q2, r):
								var l2 := p2.distance_to(c[k]) + c[k].distance_to(c[j]) + c[j].distance_to(q2)
								if l2 < best_len:
									best_len = l2
									best = [c[k], c[j]]
					for cp: Vector2 in best:
						out.append(to_global(Vector3(cp.x, lp.y, cp.y)))
					break
		out.append(q)
	return out


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return false  # starting or ending at it (the stairs themselves)
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


## A clear spot to stand in a room, coming from `from_room`: a few metres
## in through the doorway (the middle may be under a table).
func inside_point(room_id: String, from_room: String) -> Vector3:
	var path := route(from_room, room_id)
	var centre := room_centre(room_id)
	if path.is_empty():
		return centre
	var door: Vector3 = path[path.size() - 1]
	var into := (centre - door) * Vector3(1, 0, 1)
	return door + into.normalized() * minf(7.0, into.length())


## The middle of a room's floor (world space).
func room_centre(room_id: String) -> Vector3:
	for r in rooms:
		if r.id == room_id:
			var c: Vector2 = (r.rect as Rect2).get_center()
			return to_global(Vector3(c.x, r.base, c.y))
	return global_position


## The room you're in at `p` (world space), or {}.
func room_at(p: Vector3) -> Dictionary:
	var lp := to_local(p)
	var storey: float = data.get("storey_height", 11.0)
	for r in rooms:
		if (r.rect as Rect2).grow(0.5).has_point(Vector2(lp.x, lp.z)) and absf(lp.y - r.base) < storey * 0.8:
			return r
	return {}


## Which storey you're on at `p` (world space).
func storey_at(p: Vector3) -> int:
	var storey: float = data.get("storey_height", 11.0)
	return maxi(0, floori((to_local(p).y + 1.0) / storey))


## Fade the walls between the camera and the player; hide storeys above
## the player's. Called every frame by IndoorCamera.
func update_view(camera_pos: Vector3, player_pos: Vector3, delta: float) -> void:
	var cam := to_local(camera_pos)
	var me := to_local(player_pos)
	var c2 := Vector2(cam.x, cam.z)
	var m2 := Vector2(me.x, me.z)
	var my_floor := storey_at(player_pos)
	var vis := {}
	for r in rooms:
		vis[r.id] = room_visibility(r, me.y)
	for i in walls.size():
		var w: Dictionary = walls[i]
		var v: float = vis.get(w.room, 1.0)
		var target := 1.0 - v
		if w.floor == my_floor and v > 0.99:
			# Between us (with a little margin): fade it so you're never hidden.
			var a: Vector2 = w.a
			var b: Vector2 = w.b
			var dir := (b - a).normalized()
			if Geometry2D.segment_intersects_segment(m2, c2, a - dir * 2.0, b + dir * 2.0) != null:
				target = FADE
		var cur: float = _fade.get(i, 0.0)
		cur = move_toward(cur, target, FADE_SPEED * delta)
		if cur != _fade.get(i, 0.0) or not _fade.has(i):
			_fade[i] = cur
			for gi: GeometryInstance3D in w.pieces:
				gi.visible = cur < 0.999
				gi.transparency = cur
	for r in rooms:
		var v: float = vis[r.id]
		if not is_equal_approx(_room_fade.get(r.id, -1.0), v):
			_room_fade[r.id] = v
			_set_room_visibility(r, v)


## How visible a room is with you at height `h` (local): dollhouse style,
## storeys above you are hidden, and so are rooms below once you're up
## (except the stairwell); on the stairs the two storeys cross-fade.
func room_visibility(r: Dictionary, h: float) -> float:
	var storey: float = data.get("storey_height", 11.0)
	var f: int = r.floor
	var up := 1.0 if f == 0 else clampf((h - float(f - 1) * storey - 4.0) / 5.0, 0.0, 1.0)
	var down := 1.0
	if str(r.type) != "stairwell":
		down = 1.0 - clampf((h - float(f) * storey - 4.0) / 5.0, 0.0, 1.0)
	return minf(up, down)


## Show room `r` (its floor and furniture; walls fade separately) at
## visibility `v` (0 hidden .. 1 solid).
func _set_room_visibility(r: Dictionary, v: float) -> void:
	if not _room_items.has(r.id):
		var wall_bits := {}
		for w in walls:
			for gi in w.pieces:
				wall_bits[gi] = true
		var items: Array = []
		for gi in (r.node as Node).find_children("*", "GeometryInstance3D", true, false):
			if not wall_bits.has(gi):
				items.append(gi)
		_room_items[r.id] = items
	(r.node as Node3D).visible = v > 0.02
	for gi: GeometryInstance3D in _room_items[r.id]:
		if is_instance_valid(gi):
			gi.transparency = 1.0 - v if v < 0.999 else 0.0


## The paint station you're standing at (her room), or null.
func station_near() -> PaintStation:
	for k in ["wall_station", "bed_station"]:
		var st := her_room.get(k) as PaintStation
		if st and st.is_player_near():
			return st
	return null


## What she can do with Y where she's standing: {"kind": "paint" | "food" |
## "sit", "target": the station, fridge or table, "seat": index}, or {}.
func interaction_at(walker: Walker) -> Dictionary:
	if walker.sitting or walker.lying:
		return {}
	var st := station_near()
	if st:
		return {"kind": "paint", "target": st}
	for f in fridges:
		if f.is_open() and not walker.model.carrying:
			return {"kind": "food", "target": f}
	for t in tables:
		var i: int = t.seat_near(walker.global_position, 4.5,
				func(k: int) -> bool: return family != null and family.is_taken("seat%d" % k))
		if i >= 0:
			return {"kind": "sit", "target": t, "seat": i}
	return {}
