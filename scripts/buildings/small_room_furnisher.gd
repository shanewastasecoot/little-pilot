class_name SmallRoomFurnisher
extends RefCounted
## Furniture for the city's small houses (rooms 6-22 m across for 5 m
## townspeople). Everything is placed through `place_*`, which keeps it out
## of the clear space in front of every door, keeps tall things out from
## in front of windows, and doesn't stack things on each other: it tries
## a few spots along a wall (or across the floor) and skips a piece rather
## than block a door.
##   small_living   sofa (or an armchair) against a plain wall, a low table,
##                  a lamp, a rug, a picture; the owner stands in it
##   small_kitchen  fridge, counters and stove along a wall, a small table
##   small_bedroom  a bed, a shelf, a rug; the house's hidden star

var interior: Interior
var data: Dictionary
var room: Dictionary
var rect := Rect2()
var base := 0.0
var node: Node3D
var rng: RandomNumberGenerator
var f := 2.27
var t := 0.5
var _keep_clear: Array[Rect2] = []   # doors
var _windows: Array[Rect2] = []      # in front of windows (tall things only)
var _taken: Array[Rect2] = []        # placed things


func _init(p_interior: Interior, p_data: Dictionary, p_room: Dictionary, p_rect: Rect2, p_base: float, p_node: Node3D,
		p_rng: RandomNumberGenerator) -> void:
	interior = p_interior
	data = p_data
	room = p_room
	rect = p_rect
	base = p_base
	node = p_node
	rng = p_rng
	f = data.get("furniture_scale", 2.27)
	t = data.get("wall_thickness", 0.5)
	var door_w: float = data.get("door_width", 4.0)
	for d: Dictionary in room.get("doors", []):
		# The front door: also where she appears coming in (kept clear further).
		_keep_clear.append(_zone(str(d.side), float(d.at), door_w * 0.5 + 0.9, 7.2 if d.get("exit", false) else 3.4))
	for w: Dictionary in room.get("windows", []):
		_windows.append(_zone(str(w.side), float(w.at), BuildingGenerator.WINDOW_SIZE.x * 0.5 + 0.4, 2.6))


## A strip along wall `side` at fraction `at`: half-width `half`, `deep` into the room.
func _zone(side: String, at: float, half: float, deep: float) -> Rect2:
	match side:
		"N":
			var x := rect.position.x + at * rect.size.x
			return Rect2(x - half, rect.position.y, half * 2.0, deep)
		"S":
			var x := rect.position.x + at * rect.size.x
			return Rect2(x - half, rect.end.y - deep, half * 2.0, deep)
		"W":
			var z := rect.position.y + at * rect.size.y
			return Rect2(rect.position.x, z - half, deep, half * 2.0)
		_:
			var z := rect.position.y + at * rect.size.y
			return Rect2(rect.end.x - deep, z - half, deep, half * 2.0)


func _fits(r: Rect2, tall: bool) -> bool:
	if not rect.grow(-t).encloses(r):
		return false
	for z in _keep_clear + _taken:
		if z.intersects(r):
			return false
	if tall:
		for z in _windows:
			if z.intersects(r):
				return false
	return true


## Against wall `side`: `w` x `d` furniture units (along x into the room),
## facing into the room. Tries spots along the wall; null if none fit.
func place_on_wall(item: String, side: String, w: float, d: float, scale := 1.0, tall := false, solid := true,
		spots := [0.5, 0.35, 0.65, 0.2, 0.8]) -> Node3D:
	var ww := w * f * scale
	var dd := d * f * scale
	for along: float in spots:
		var r: Rect2
		var pos: Vector2
		var yaw := 0.0
		match side:
			"N":
				pos = Vector2(rect.position.x + along * rect.size.x, rect.position.y + t + dd * 0.5 + 0.2)
				r = Rect2(pos.x - ww * 0.5, pos.y - dd * 0.5, ww, dd)
			"S":
				pos = Vector2(rect.position.x + along * rect.size.x, rect.end.y - t - dd * 0.5 - 0.2)
				r = Rect2(pos.x - ww * 0.5, pos.y - dd * 0.5, ww, dd)
				yaw = 180.0
			"W":
				pos = Vector2(rect.position.x + t + dd * 0.5 + 0.2, rect.position.y + along * rect.size.y)
				r = Rect2(pos.x - dd * 0.5, pos.y - ww * 0.5, dd, ww)
				yaw = 90.0
			_:
				pos = Vector2(rect.end.x - t - dd * 0.5 - 0.2, rect.position.y + along * rect.size.y)
				r = Rect2(pos.x - dd * 0.5, pos.y - ww * 0.5, dd, ww)
				yaw = -90.0
		if _fits(r, tall):
			_taken.append(r)
			return BuildingGenerator._put(node, data, rect, base, item, (pos.x - rect.position.x) / rect.size.x,
					(pos.y - rect.position.y) / rect.size.y, yaw, scale, solid)
	return null


## Somewhere free on the floor (`w` x `d` metres), trying spots from the
## middle outwards; returns the centre or Vector2.INF.
func free_floor(w: float, d: float, tall := false) -> Vector2:
	var c := rect.get_center()
	for k in 49:
		var dx := (k % 7 - 3) * rect.size.x * 0.12
		var dz := (k / 7 - 3) * rect.size.y * 0.12
		var p := c + Vector2(dx, dz)
		var r := Rect2(p.x - w * 0.5, p.y - d * 0.5, w, d)
		if _fits(r, tall):
			_taken.append(r)
			return p
	return Vector2.INF


func _plain_walls(prefer: Array) -> Array:
	var out := []
	for side: String in prefer:
		var ok := true
		for dd: Dictionary in room.get("doors", []):
			if str(dd.side) == side:
				ok = false
		if ok:
			out.append(side)
	return out + prefer.filter(func(s): return not out.has(s))


func furnish() -> void:
	match str(room.type):
		"small_living": _living()
		"small_kitchen": _kitchen()
		"small_bedroom": _bedroom()


func _ab(name: String) -> String:
	return name + ("_A" if rng.randf() < 0.5 else "_B")


func _living() -> void:
	BuildingGenerator._put(node, data, rect, base, _ab("rug_rectangle"), 0.5, 0.5, 90.0 if rect.size.x < rect.size.y else 0.0, 1.3, false)
	var seat: Node3D = null
	for side: String in _plain_walls(["W", "N", "E", "S"]):
		seat = place_on_wall("couch_pillows", side, 3.0, 1.6, 1.0, false, false)
		if seat == null:
			seat = place_on_wall("armchair_pillows", side, 1.8, 1.6, 1.0, false, true)
		if seat:
			break
	if seat and String(seat.name) == "couch_pillows":
		BuildingGenerator._bouncy_seat(seat, f)
		interior.sofas.append(seat)
	var tp := free_floor(2.4 * f * 0.8, 1.5 * f * 0.8)
	if tp != Vector2.INF:
		BuildingGenerator._put(node, data, rect, base, "table_low", (tp.x - rect.position.x) / rect.size.x, (tp.y - rect.position.y) / rect.size.y, 0.0, 0.8)
	for side: String in ["E", "N", "W"]:
		if place_on_wall("lamp_standing", side, 1.0, 1.0, 1.0, true, true, [0.1, 0.9, 0.15, 0.85]):
			break
	var pic := BuildingGenerator._free_spot(data, room, "N", 3.0)
	if pic >= 0.0:
		BuildingGenerator._put(node, data, rect, base, _ab("pictureframe_small"), pic, (t + 0.3) / rect.size.y, 0.0, 1.4, false, 5.0)
	# The owner, somewhere free, facing the front door (if the living room's
	# too full, the bedroom has them instead).
	if not _place_owner():
		interior.set_meta("owner_pending", true)
	place_star()


## The house's hidden star (once per house): near a corner of whichever room
## has space first, else anywhere free; it floats low, under the windows.
## The house's owner (a townsperson who gives the sticker). True if placed.
func _place_owner() -> bool:
	var look: Array = data.get("owner", [])
	if look.is_empty():
		return true
	var op := Vector2.INF
	for size in [3.6, 2.6, 2.0]:
		op = free_floor(size, size, true)
		if op != Vector2.INF:
			break
	if op == Vector2.INF:
		return false
	var keeper := Shopkeeper.new()
	keeper.name = "Owner"
	keeper.sticker = str(data.get("sticker", ""))
	keeper.look = OutfitData.make("owner", look[0], look[1], look[2], look[3])
	keeper.head = look[4]
	keeper.position = Vector3(op.x, base, op.y)
	node.add_child(keeper)
	interior.shopkeepers.append(keeper)
	interior.remove_meta("owner_pending") if interior.has_meta("owner_pending") else null
	return true


func place_star() -> void:
	if interior.house_star != null:
		return
	var corners := [Vector2(rect.position.x + t + 1.8, rect.position.y + t + 1.8), Vector2(rect.end.x - t - 1.8, rect.position.y + t + 1.8),
		Vector2(rect.position.x + t + 1.8, rect.end.y - t - 1.8), Vector2(rect.end.x - t - 1.8, rect.end.y - t - 1.8)]
	var at := Vector2.INF
	for c: Vector2 in corners:
		var r := Rect2(c.x - 1.2, c.y - 1.2, 2.4, 2.4)
		if _fits(r, false):
			_taken.append(r)
			at = c
			break
	if at == Vector2.INF:
		at = free_floor(2.4, 2.4, false)
	if at != Vector2.INF:
		var star := HouseStar.new()
		star.name = "HiddenStar"
		star.height = 1.4  # under the windows
		star.position = Vector3(at.x, base, at.y)
		node.add_child(star)
		interior.house_star = star


func _kitchen() -> void:
	# (Counters with a backsplash reach up to the windows: kept clear of them too.)
	var items := [["r:fridge_A_decorated", 2.0, 1.6, true], ["r:kitchencounter_sink_backsplash", 2.0, 2.0, true],
		["r:stove_multi", 2.0, 2.0, false], ["r:kitchencounter_straight_A_backsplash", 2.0, 2.0, true]]
	for side: String in _plain_walls(["N", "W", "E"]):
		var placed := 0
		for it: Array in items:
			if place_on_wall(it[0], side, it[1], it[2], 1.0, it[3], true, [0.2, 0.4, 0.6, 0.8, 0.3, 0.7]):
				placed += 1
		if placed > 0:
			break
	var tp := free_floor(2.0 * f, 2.0 * f)
	if tp != Vector2.INF:
		BuildingGenerator._put(node, data, rect, base, "table_small", (tp.x - rect.position.x) / rect.size.x, (tp.y - rect.position.y) / rect.size.y)
	if interior.has_meta("owner_pending"):
		_place_owner()
	place_star()


func _bedroom() -> void:
	var bed: Node3D = null
	for side: String in _plain_walls(["N", "E", "W", "S"]):
		bed = place_on_wall(_ab("bed_single"), side, 1.6, 3.0, 1.0, false, false)
		if bed:
			break
	if bed:
		var seat := StaticBody3D.new()
		seat.collision_layer = GameSettings.LAYER_WORLD
		seat.add_to_group("bouncy")
		seat.add_to_group("bed")
		var cs := CollisionShape3D.new()
		cs.shape = BuildKit.box_shape(Vector3(1.6, 0.55, 2.9))
		cs.position = Vector3(0, 0.275, 0.05)
		seat.add_child(cs)
		bed.add_child(seat)
		interior.beds.append(bed)
	BuildingGenerator._put(node, data, rect, base, _ab("rug_oval"), 0.5, 0.6, 0.0, 1.0, false)
	if interior.has_meta("owner_pending"):
		_place_owner()
	for side in ["E", "W", "N"]:
		var sf := BuildingGenerator._free_spot(data, room, side, 3.2)
		if sf >= 0.0:
			var fx := (1.0 - (t + 0.6) / rect.size.x) if side == "E" else ((t + 0.6) / rect.size.x if side == "W" else sf)
			var fz := sf if side != "N" else (t + 0.6) / rect.size.y
			BuildingGenerator._put(node, data, rect, base, "shelf_A_small", fx, fz, {"E": -90.0, "W": 90.0, "N": 0.0}[side], 1.3, false, 4.5)
			break
	place_star()
