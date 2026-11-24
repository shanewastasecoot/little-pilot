class_name Dock
extends Node3D
## A wooden pier on a major island (Phase 14, sailing): from the beach out
## into deep water, a wide platform at the end and a berth beside it where
## her sail boat moors. Walk out to the end and press Y to sail (or to call
## the boat, if it's moored at another island); sail up to any dock and
## press Y to step off onto the pier.
##
## Local space: origin on the beach at deck height, -Z out to sea.

## [island id, beach point (x, z), heading out to sea (deg, Vector2.from_angle),
## pier length (m)]: found by scanning each coast for a gentle beach with deep
## water a short way out (facing home where it could).
const SPOTS := [
	["main", Vector2(-777, 946), 123.0, 34.0],
	["palm", Vector2(1841, 336), 192.0, 38.0],
	["volcano", Vector2(-1463, -970), 36.0, 38.0],
	["ice", Vector2(300, -3006), 90.0, 38.0],
	["dino", Vector2(2504, 2148), 201.0, 38.0],
	["castle", Vector2(-625, 3046), 282.0, 38.0],
	["town", Vector2(-3016, 460), 354.0, 38.0],
]
const WIDTH := 4.0
const END_WIDTH := 11.0
const END_LENGTH := 7.0
## The boat moors this far out to the side of the pier's middle.
const BERTH_SIDE := 8.5
## Walk this close to the berth (flat metres) to board or call the boat.
const BOARD_REACH := 10.0
## Sail this close to the berth to step off.
const ARRIVE_REACH := 45.0
const DRAW := 900.0

var index := 0
var island := ""
var length := 38.0
var flag_colour := Color("ff5a5f")


static func make(i: int) -> Dock:
	var d := Dock.new()
	var s: Array = SPOTS[i]
	d.index = i
	d.island = s[0]
	d.name = "Dock_" + d.island
	d.length = s[3]
	var beach: Vector2 = s[1]
	var out := Vector2.from_angle(deg_to_rad(s[2]))
	d.position = Vector3(beach.x, maxf(DeliveryManager.ground_at(beach.x, beach.y), 2.8) + 0.2, beach.y)
	d.rotation.y = atan2(-out.x, -out.y)
	d.flag_colour = [Color("ff5a5f"), Color("ffd23f"), Color("ff8c42"), Color("4cc9f0"), Color("4cc06a"), Color("9b5de5"), Color("ff7eb9")][i % 7]
	return d


func _ready() -> void:
	add_to_group("docks")
	var wood := "a0703c"
	var dark := "6b4a2b"
	# The walkway (from a little way up the beach) and the platform at the end.
	_deck(Vector3(0, -0.25, (6.0 - length) * 0.5), Vector3(WIDTH, 0.5, length + 6.0), wood)
	_deck(Vector3(0, -0.25, -length - END_LENGTH * 0.5 + 1.0), Vector3(END_WIDTH, 0.5, END_LENGTH), wood)
	# Planks: darker stripes across the walkway.
	var z := 4.0
	while z > -length:
		_box(Vector3(0, 0.02, z), Vector3(WIDTH + 0.1, 0.06, 0.25), dark)
		z -= 2.0
	# Posts down into the sea, and bollards to tie the boat to.
	z = 0.0
	while z > -length - END_LENGTH:
		var half := (END_WIDTH if z < -length + 1.0 else WIDTH) * 0.5 - 0.2
		for sx in [-half, half]:
			_box(Vector3(sx, -6.0, z), Vector3(0.5, 12.0, 0.5), dark)
		z -= 6.0
	for bz in [-length + 0.5, -length - END_LENGTH + 1.5]:
		_box(Vector3(END_WIDTH * 0.5 - 0.6, 0.45, bz), Vector3(0.6, 0.9, 0.6), "3a3a44")
	# A flag in the island's colour, seen from far out at sea.
	_box(Vector3(-END_WIDTH * 0.5 + 0.6, 4.0, -length - END_LENGTH + 1.5), Vector3(0.25, 8.0, 0.25), "f4f4f4")
	var flag := _box(Vector3(-END_WIDTH * 0.5 + 1.9, 7.2, -length - END_LENGTH + 1.5), Vector3(2.4, 1.4, 0.1), flag_colour.to_html(false))
	flag.rotation.y = 0.0
	# Lanterns at the end.
	for sx in [-END_WIDTH * 0.5 + 0.4, END_WIDTH * 0.5 - 0.4]:
		_box(Vector3(sx, 1.1, -length + 1.2), Vector3(0.2, 2.2, 0.2), "3a3a44")
		var lamp := BuildKit.add(self, BuildKit.sphere(0.35, 8), "ffd23f", Vector3(sx, 2.4, -length + 1.2))
		lamp.visibility_range_end = DRAW


func _deck(pos: Vector3, size: Vector3, colour: String) -> void:
	_box(pos, size, colour)
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	add_child(body)


func _box(pos: Vector3, size: Vector3, colour: String) -> MeshInstance3D:
	var mi := BuildKit.add(self, BuildKit.box(size), colour, pos)
	mi.visibility_range_end = DRAW
	return mi


## Where the boat moors (and which way it faces: out to sea).
func berth() -> Transform3D:
	return Transform3D(global_basis, global_transform * Vector3(BERTH_SIDE, -position.y, -length - 1.0))


## Out at sea in front of the dock: where a called boat sails in from.
func approach() -> Transform3D:
	return Transform3D(global_basis, global_transform * Vector3(BERTH_SIDE, -position.y, -length - 80.0))


## Where she steps off onto the platform, and which way she faces (inland).
func step_off() -> Vector3:
	return global_transform * Vector3(END_WIDTH * 0.5 - 1.6, 0.05, -length - 1.0)


func step_off_yaw() -> float:
	return rotation.y + PI


## The point at the end of the pier where she stands to board.
func board_point() -> Vector3:
	return global_transform * Vector3(END_WIDTH * 0.5 - 1.5, 0.0, -length - 1.0)


## Is `p` (world) inside the pier, where a boat mustn't go?
func blocks(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) < END_WIDTH * 0.5 + 2.0 and l.z < 10.0 and l.z > -length - END_LENGTH - 2.5


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
