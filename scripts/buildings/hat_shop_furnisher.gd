class_name HatShopFurnisher
extends RefCounted
## Furnishes the hat shop's one room (HatShopLayout): the counter at the
## back with the milliner behind it (the sticker on her first visit) and a
## shelf of hat boxes, hat stands down both side walls showing the hats,
## the try-on mirror (HatMirror: Y opens the hat chooser) and the hidden
## star behind the counter's end. Nothing goes in the doorway or in front
## of a window.

const STAND_GAP := 3.0
const BOX_COLOURS := ["ff9fc4", "9fd8ff", "fff08a", "b6f0a0", "d0b3ff", "ffc38a"]


static func furnish(interior: Interior, data: Dictionary, room: Dictionary, rect: Rect2, base: float, node: Node3D) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var t: float = data.get("wall_thickness", 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", 1))
	var door: Dictionary = room.doors[0]
	var door_x := rect.position.x + float(door.at) * rect.size.x
	var door_w: float = data.get("door_width", 6.0)
	# The counter, at the back on the side away from the door.
	var side := -1.0 if door_x >= rect.get_center().x else 1.0
	var counter_w := clampf(rect.size.x * 0.34, 6.0, 9.0)
	var cx := rect.get_center().x + side * (rect.size.x * 0.5 - t - 1.2 - counter_w * 0.5 - 2.6)
	var counter_z := rect.position.y + t + 3.6
	var counter := Node3D.new()
	counter.name = "Counter"
	node.add_child(counter)
	for part in [[Vector3(counter_w, 2.6, 1.8), Vector3(cx, base + 1.3, counter_z), "d9667a"],
			[Vector3(counter_w + 0.4, 0.3, 2.2), Vector3(cx, base + 2.75, counter_z), "ffffff"]]:
		BuildKit.add(counter, BuildKit.box(part[0]), part[2], part[1]).material_override = BuildingGenerator._mat(part[2])
	# Stripes down the counter's front, like a hatbox.
	for k in int(counter_w / 1.2):
		var x := cx - counter_w * 0.5 + 0.6 + k * 1.2
		BuildKit.add(counter, BuildKit.box(Vector3(0.45, 2.5, 0.1)), "fff4dc", Vector3(x, base + 1.3, counter_z + 0.92)).material_override = BuildingGenerator._mat("fff4dc")
	BuildKit.collider(counter, BuildKit.box_shape(Vector3(counter_w + 0.4, 3.0, 2.2)), Vector3(cx, base + 1.5, counter_z))
	# A hat on the counter, waiting to be wrapped, and a stack of boxes.
	var on_counter := _hat(Hats.prop_of(Hats.ids()[rng.randi() % Hats.ids().size()]), f * 0.8)
	on_counter.position = Vector3(cx + counter_w * 0.25, base + 2.9, counter_z) - _foot(on_counter)
	counter.add_child(on_counter)
	for k in 3:
		var col: String = BOX_COLOURS[(k + rng.randi()) % BOX_COLOURS.size()]
		BuildKit.add(counter, BuildKit.cyl(0.9 - k * 0.15, 0.7, -1.0, 16), col, Vector3(cx - counter_w * 0.3, base + 3.25 + k * 0.7, counter_z)).material_override = BuildingGenerator._mat(col)
	# The shelf of hat boxes on the back wall, behind the milliner.
	var shelf_z := rect.position.y + t + 0.6
	BuildKit.add(node, BuildKit.box(Vector3(counter_w, 0.3, 1.2)), "b98a5e", Vector3(cx, base + 4.6, shelf_z)).material_override = BuildingGenerator._mat("b98a5e")
	for k in int(counter_w / 1.6):
		var col: String = BOX_COLOURS[rng.randi() % BOX_COLOURS.size()]
		var bx := cx - counter_w * 0.5 + 0.8 + k * 1.6
		BuildKit.add(node, BuildKit.cyl(0.65, 1.0, -1.0, 16), col, Vector3(bx, base + 5.25, shelf_z)).material_override = BuildingGenerator._mat(col)
		BuildKit.add(node, BuildKit.cyl(0.7, 0.18, -1.0, 16), "ffffff", Vector3(bx, base + 5.8, shelf_z)).material_override = BuildingGenerator._mat("ffffff")
	# The milliner behind the counter, in a sun hat.
	var keeper := Shopkeeper.new()
	keeper.name = "Milliner"
	keeper.sticker = str(data.get("sticker", "hat_shop"))
	keeper.look = OutfitData.make("milliner", "Mage", {"r1c0": Color("e86aa6"), "r0c3": Color("ffe3f0"), "r0c4": Color("ffe3f0"),
		"r0c5": Color("ffd23f"), "r2c2": Color("ffd23f"), "r1c7": Color("ffe3f0"), "r2c7": Color("ffffff")},
		[["Sun_Hat", "head"]], [])
	keeper.head = ["Mage", {"r0c1": Color("3b2a20")}]
	keeper.position = Vector3(cx, base, counter_z - 2.0)
	node.add_child(keeper)
	interior.shopkeepers.append(keeper)
	# The try-on mirror: against the side wall on the door's side, facing
	# into the shop (she stands on its rug, the camera in front of her).
	var toward := -side  # from the counter towards the door's side
	var mirror_wall_x := rect.end.x - t if toward > 0.0 else rect.position.x + t
	var mirror := HatMirror.new()
	mirror.name = "HatMirror"
	var mz := clampf(rect.get_center().y + 0.8, counter_z + 3.0, rect.end.y - 4.0)
	mirror.position = Vector3(mirror_wall_x - toward * 0.8, base, mz)
	mirror.rotation.y = -toward * PI * 0.5
	node.add_child(mirror)
	interior.hat_mirrors.append(mirror)
	# Hat stands: down the side wall behind the counter, along the back wall
	# past the counter's far end, and on the mirror's wall nearer the back;
	# clear of the doorway, the windows and the mirror.
	var spots: Array[Vector3] = []
	var gap := 2.4
	var back_z := rect.position.y + t + 1.4
	var far_x := rect.position.x + t + 1.4 if side < 0.0 else rect.end.x - t - 1.4
	var near_x := rect.end.x - t - 1.4 if side < 0.0 else rect.position.x + t + 1.4
	var z := back_z
	while z <= rect.end.y - 3.4 + 0.01:
		spots.append(Vector3(far_x, base, z))
		z += gap
	var x := cx + toward * (counter_w * 0.5 + 3.4)
	while (x - near_x) * toward <= 0.01:
		spots.append(Vector3(x, base, back_z))
		x += toward * gap
	z = back_z + gap
	while z <= mz - 1.7 - 1.4 + 0.01:
		spots.append(Vector3(near_x, base, z))
		z += gap
	spots = spots.filter(func(p: Vector3) -> bool:
		return not _near_window(room, rect, "W" if p.x < rect.get_center().x else "E", p.z) \
				and not _in_front_of_window(room, rect, p) \
				and not (absf(p.x - door_x) < door_w * 0.5 + 2.0 and p.z > rect.end.y - 5.0))
	var ids := Hats.ids()
	var first := rng.randi() % ids.size()
	for k in mini(spots.size(), ids.size()):
		_stand(node, spots[k], Hats.prop_of(ids[(first + k) % ids.size()]), f, BOX_COLOURS[(first + k) % BOX_COLOURS.size()])
	# The hidden star: behind the counter, at its end nearer the door.
	var star := HouseStar.new()
	star.name = "HiddenStar"
	star.height = 1.4
	star.position = Vector3(cx + toward * (counter_w * 0.5 + 1.6), base, rect.position.y + t + 2.0)
	node.add_child(star)
	interior.house_star = star


## A hat stand: a white pedestal, a pale wooden head, the hat on it.
static func _stand(node: Node3D, at: Vector3, prop: String, f: float, col: String) -> void:
	var stand := Node3D.new()
	stand.name = "HatStand_" + prop
	stand.position = at
	node.add_child(stand)
	BuildKit.add(stand, BuildKit.cyl(0.9, 0.3, -1.0, 16), col, Vector3(0, 0.15, 0)).material_override = BuildingGenerator._mat(col)
	BuildKit.add(stand, BuildKit.cyl(0.22, 2.6, -1.0, 10), "ffffff", Vector3(0, 1.6, 0)).material_override = BuildingGenerator._mat("ffffff")
	BuildKit.add(stand, BuildKit.sphere(0.62, 14), "f1d7b8", Vector3(0, 3.35, 0)).material_override = BuildingGenerator._mat("f1d7b8")
	BuildKit.collider(stand, BuildKit.cyl_shape(0.9, 3.0), Vector3(0, 1.5, 0))
	var hat := _hat(prop, f * 0.85)
	hat.position = Vector3(0, 3.35, 0) - _seat(hat)
	stand.add_child(hat)


## A display copy of hat `prop` at scale `s` (no outline: it's furniture).
static func _hat(prop: String, s: float) -> MeshInstance3D:
	var mi := CharacterLook.prop(prop) as MeshInstance3D
	mi.scale = Vector3.ONE * s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Offset that puts the hat's middle on a point at the bottom of its crown
## (the props are modelled sitting on a KayKit head).
static func _seat(hat: MeshInstance3D) -> Vector3:
	var b := hat.get_aabb()
	var c := b.get_center()
	return Vector3(c.x, b.position.y + b.size.y * 0.3, c.z) * hat.scale


## Offset that stands the hat's bottom on a point.
static func _foot(hat: MeshInstance3D) -> Vector3:
	var b := hat.get_aabb()
	var c := b.get_center()
	return Vector3(c.x, b.position.y, c.z) * hat.scale


## Within reach of the front (S) windows: the 2.5 m strip inside them.
static func _in_front_of_window(room: Dictionary, rect: Rect2, p: Vector3) -> bool:
	for w: Dictionary in room.get("windows", []):
		if str(w.side) == "S" and p.z > rect.end.y - 4.4 \
				and absf(rect.position.x + float(w.at) * rect.size.x - p.x) < BuildingGenerator.WINDOW_SIZE.x * 0.5 + 1.2:
			return true
	return false


static func _near_window(room: Dictionary, rect: Rect2, wall: String, z: float) -> bool:
	for w: Dictionary in room.get("windows", []):
		if str(w.side) == wall and absf(rect.position.y + float(w.at) * rect.size.y - z) < BuildingGenerator.WINDOW_SIZE.x * 0.5 + 1.4:
			return true
	return false
