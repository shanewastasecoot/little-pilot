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
	for i in walls.size():
		var w: Dictionary = walls[i]
		var target := 0.0
		if w.floor > my_floor:
			target = 1.0
		elif w.floor == my_floor:
			# Between us (with a little margin), or facing the camera right
			# beside us in the same room.
			var a: Vector2 = w.a
			var b: Vector2 = w.b
			var dir := (b - a).normalized()
			if Geometry2D.segment_intersects_segment(m2, c2, a - dir * 2.0, b + dir * 2.0) != null:
				target = 1.0
		var cur: float = _fade.get(i, 0.0)
		cur = move_toward(cur, target, FADE_SPEED * delta)
		if cur != _fade.get(i, 0.0) or not _fade.has(i):
			_fade[i] = cur
			var hide_all: bool = w.floor > my_floor
			for gi: GeometryInstance3D in w.pieces:
				gi.visible = not (hide_all and cur >= 1.0)
				gi.transparency = cur * FADE
	for r in rooms:
		(r.node as Node3D).visible = r.floor <= my_floor
