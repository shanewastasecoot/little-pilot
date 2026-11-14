class_name TownIsland
extends Landmark
## A little town far to the west: colourful houses along two streets round a
## square with a clock tower, and hot-air balloons drifting overhead.
## The balloons twirl and the bells ring when discovered.

const C := OuterIslands.TOWN
const ROOFS := ["ff5a5f", "4aa8ff", "ffd23f", "9b5de5", "4cc06a", "ff8c42"]
const BALLOONS := ["ff5a5f", "ffd23f", "4cc06a", "4aa8ff", "9b5de5", "ff7eb9"]

var _balloons: Array[Node3D] = []
var _t := 0.0


func _init() -> void:
	landmark_name = "Town"
	discovery_radius = 420.0
	discovery_sound = "bells"


func build() -> void:
	var y := OuterIslands.TOWN_HEIGHT
	# Streets: a cross through the town square.
	BuildKit.add(self, BuildKit.box(Vector3(300, 0.3, 14)), "8f949c", Vector3(0, y + 0.1, 0))
	BuildKit.add(self, BuildKit.box(Vector3(14, 0.3, 300)), "8f949c", Vector3(0, y + 0.1, 0))
	BuildKit.add(self, BuildKit.cyl(26, 0.4, -1, 24), "c9c3b6", Vector3(0, y + 0.15, 0))
	# Clock tower in the square.
	BuildKit.add(self, BuildKit.box(Vector3(8, 34, 8)), "e9d8b4", Vector3(0, y + 17, 0))
	BuildKit.add(self, BuildKit.prism(Vector3(10, 8, 10)), "ff5a5f", Vector3(0, y + 38, 0))
	for side in 4:
		var face := BuildKit.add(self, BuildKit.cyl(2.6, 0.3, -1, 16), "ffffff", Vector3(0, y + 28, 0), Vector3(90, side * 90.0, 0))
		face.position += Vector3(sin(side * PI / 2.0), 0, cos(side * PI / 2.0)) * 4.1
	BuildKit.collider(self, BuildKit.box_shape(Vector3(8, 42, 8)), Vector3(0, y + 21, 0))
	BuildKit.push_volume(self, 24.0, 90.0)
	# Houses along the streets, roofs in bright colours.
	var k := 0
	for arm in 4:
		var dir := Vector2.from_angle(arm * PI / 2.0)
		var perp := Vector2(-dir.y, dir.x)
		for slot in 4:
			for side: float in [-1.0, 1.0]:
				var lp: Vector2 = dir * (45.0 + slot * 30.0) + perp * side * 22.0
				var use_b := (k % 3) == 2
				var house := AssetLib.place(self, "res://assets/environment/%s.glb" % ("house_b" if use_b else "house_a"),
					Vector3(lp.x, y, lp.y), 4.0 if use_b else 12.0, rad_to_deg(-perp.angle() * side) + 90.0)
				if not use_b:
					var rc := ModelRecolor.new()
					rc.target = house.find_children("*", "MeshInstance3D", true, false)[0]
					rc.to_color = Color(ROOFS[k % ROOFS.size()])
					house.add_child(rc)
				k += 1
	IslandDecor.scatter(self, "res://assets/environment/tree_round.glb", 30, C, 200.0, 380.0, OuterIslands.town_height, 2.2, 3.0, 8.0, 60.0, 41)
	# Hot-air balloons drifting above the town.
	for b in BALLOONS.size():
		var balloon := AssetLib.place(self, "res://assets/environment/balloon.glb", Vector3.ZERO, 0.06)
		balloon.rotation_degrees.x = -90.0  # model is stored lying down
		var rc := ModelRecolor.new()
		rc.target = balloon.find_children("*", "MeshInstance3D", true, false)[0]
		rc.to_color = Color(BALLOONS[b])
		balloon.add_child(rc)
		var holder := Node3D.new()
		add_child(holder)
		balloon.reparent(holder, false)
		_balloons.append(holder)
	_place_balloons()


func _place_balloons() -> void:
	for b in _balloons.size():
		var a := TAU * b / _balloons.size() + _t * 0.03
		var r := 140.0 + (b % 2) * 70.0
		_balloons[b].position = Vector3(cos(a) * r, 120.0 + (b % 3) * 35.0 + sin(_t * 0.5 + b) * 6.0, sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	_place_balloons()


func react() -> void:
	for holder in _balloons:
		var tw := create_tween()
		tw.tween_property(holder, "rotation:y", holder.rotation.y + TAU, 2.0).set_trans(Tween.TRANS_SINE)
