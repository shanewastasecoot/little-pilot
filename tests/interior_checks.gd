class_name InteriorChecks
extends RefCounted
## Layout checks any building's inside should pass (used by the building
## tests): nothing standing in a doorway, nothing over a window.


## Doorways with something standing in them: every piece of furniture or
## decoration (not walls, floors or flat rugs) overlapping the clear space
## through a doorway (a little narrower than the door, 2.5 m either side,
## up to the top of the door).
static func blocked_doorways(interior: Interior) -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = interior.data
	var door_w: float = data.get("door_width", 7.0)
	var door_h: float = data.get("door_height", 8.0)
	var wall_bits := _wall_bits(interior)
	for room: Dictionary in data.rooms:
		var rect := _rect(room)
		var info: Dictionary = interior.find_room(str(room.id))
		for d: Dictionary in room.get("doors", []):
			var c := _side_point(rect, str(d.side), float(d.at))
			var along_x := str(d.side) in ["N", "S"]
			var half := Vector2((door_w - 1.0) * 0.5, 2.5) if along_x else Vector2(2.5, (door_w - 1.0) * 0.5)
			var clear := AABB(Vector3(c.x - half.x, float(info.base) + 0.3, c.y - half.y), Vector3(half.x * 2.0, door_h - 0.6, half.y * 2.0))
			for other in interior.rooms:
				if other.floor != info.floor:
					continue
				for gi: GeometryInstance3D in (other.node as Node).find_children("*", "GeometryInstance3D", true, false):
					if wall_bits.has(gi) or not gi.is_visible_in_tree():
						continue  # (invisible parts block nothing)
					var box: AABB = interior.global_transform.affine_inverse() * gi.global_transform * gi.get_aabb()
					if box.size.y < 0.5 or box.size.x > 30.0 or box.size.z > 30.0:
						continue
					if box.intersects(clear):
						out.append("%s door %s: %s" % [room.id, d.side, gi.get_parent().name])
	return out


## Windows with something in front of them (from the wall to 2 m into the room).
static func covered_windows(interior: Interior) -> Array[String]:
	var out: Array[String] = []
	var ws := BuildingGenerator.WINDOW_SIZE
	var wall_bits := _wall_bits(interior)
	for room: Dictionary in interior.data.rooms:
		var rect := _rect(room)
		var info: Dictionary = interior.find_room(str(room.id))
		var y := float(info.base) + BuildingGenerator.WINDOW_Y
		for w: Dictionary in room.get("windows", []):
			var at := float(w.at)
			var box: AABB
			match str(w.side):
				"N": box = AABB(Vector3(rect.position.x + at * rect.size.x - ws.x * 0.5, y - ws.y * 0.5, rect.position.y + 0.3), Vector3(ws.x, ws.y, 2.0))
				"S": box = AABB(Vector3(rect.position.x + at * rect.size.x - ws.x * 0.5, y - ws.y * 0.5, rect.end.y - 2.3), Vector3(ws.x, ws.y, 2.0))
				"W": box = AABB(Vector3(rect.position.x + 0.3, y - ws.y * 0.5, rect.position.y + at * rect.size.y - ws.x * 0.5), Vector3(2.0, ws.y, ws.x))
				_: box = AABB(Vector3(rect.end.x - 2.3, y - ws.y * 0.5, rect.position.y + at * rect.size.y - ws.x * 0.5), Vector3(2.0, ws.y, ws.x))
			for gi: GeometryInstance3D in (info.node as Node).find_children("*", "GeometryInstance3D", true, false):
				if wall_bits.has(gi) or gi.get_parent() is LightSwitch or not gi.is_visible_in_tree():
					continue
				var b: AABB = interior.global_transform.affine_inverse() * gi.global_transform * gi.get_aabb()
				if b.size.y < 0.5 or b.size.x > 30.0 or b.size.z > 30.0:
					continue
				if (str(w.side) in ["N", "S"] and b.size.z < 0.6) or (str(w.side) in ["E", "W"] and b.size.x < 0.6):
					continue
				if b.intersects(box):
					out.append("%s window %s %.2f: %s" % [room.id, w.side, at, gi.get_parent().name])
	return out


static func _wall_bits(interior: Interior) -> Dictionary:
	var bits := {}
	for w in interior.walls:
		for gi in w.pieces:
			bits[gi] = true
	return bits


static func _rect(room: Dictionary) -> Rect2:
	var r: Array = room.rect
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func _side_point(rect: Rect2, side: String, at: float) -> Vector2:
	match side:
		"N": return Vector2(rect.position.x + at * rect.size.x, rect.position.y)
		"S": return Vector2(rect.position.x + at * rect.size.x, rect.end.y)
		"W": return Vector2(rect.position.x, rect.position.y + at * rect.size.y)
		_: return Vector2(rect.end.x, rect.position.y + at * rect.size.y)
