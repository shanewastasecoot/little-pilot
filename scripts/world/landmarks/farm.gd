class_name Farm
extends Landmark
## Red barn, silo, striped fields and sheep. The sheep hop when discovered.

var _sheep: Array[Node3D] = []
var _t := 0.0


func _init() -> void:
	landmark_name = "Farm"
	discovery_radius = 200.0
	discovery_sound = "moo"


func build() -> void:
	# Barn
	BuildKit.add(self, BuildKit.box(Vector3(22, 12, 30)), "d7263d", Vector3(0, 6, 0))
	BuildKit.add(self, BuildKit.prism(Vector3(24, 8, 31)), "8c1c2b", Vector3(0, 16, 0))
	BuildKit.add(self, BuildKit.box(Vector3(8, 9, 0.5)), "ffffff", Vector3(0, 4.5, 15.1))
	BuildKit.collider(self, BuildKit.box_shape(Vector3(24, 20, 31)), Vector3(0, 10, 0))
	# Silo
	BuildKit.add(self, BuildKit.cyl(5, 26, -1, 14), "c9ced6", Vector3(18, 13, -8))
	BuildKit.add(self, BuildKit.sphere(5, 12), "6f7a8a", Vector3(18, 26, -8))
	BuildKit.collider(self, BuildKit.cyl_shape(5.5, 32), Vector3(18, 16, -8))
	# Fields: striped patches around the barn
	var palette := [["e9c46a", "d4a843"], ["8ac926", "6fa81e"], ["b5835a", "9a6b45"], ["e9c46a", "d4a843"]]
	var spots := [Vector2(-80, -60), Vector2(70, -70), Vector2(-75, 70), Vector2(75, 75)]
	for i in spots.size():
		for s in 6:
			var col: String = palette[i][s % 2]
			BuildKit.add(self, BuildKit.box(Vector3(60, 0.3, 10)), col, Vector3(spots[i].x, 0.3, spots[i].y - 25 + s * 10))
	# Fence posts around the nearest field
	for k in 24:
		var a := TAU * k / 24.0
		BuildKit.add(self, BuildKit.box(Vector3(0.5, 2, 0.5)), "8a5a3c", Vector3(-30 + cos(a) * 22, 1, 40 + sin(a) * 14))
	# Sheep
	for k in 7:
		var sheep := Node3D.new()
		var a := TAU * k / 7.0
		sheep.position = Vector3(-30 + cos(a) * 12, 0, 40 + sin(a) * 7)
		sheep.rotation.y = randf() * TAU
		add_child(sheep)
		BuildKit.add(sheep, BuildKit.sphere(1.3, 8), "ffffff", Vector3(0, 1.5, 0), Vector3.ZERO, Vector3(1, 0.85, 1.3))
		BuildKit.add(sheep, BuildKit.sphere(0.6, 6), "333333", Vector3(0, 1.9, -1.5))
		_sheep.append(sheep)


func react() -> void:
	for i in _sheep.size():
		var sheep := _sheep[i]
		var tw := create_tween().set_loops(4)
		tw.tween_property(sheep, "position:y", 2.5, 0.18).set_delay(i * 0.05).set_ease(Tween.EASE_OUT)
		tw.tween_property(sheep, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
