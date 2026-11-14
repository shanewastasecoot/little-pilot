class_name Farm
extends Landmark
## Red barn, silo, striped fields, sheep and cows (Quaternius CC0 models).
## The animals jump when discovered.

const ENV := "res://assets/environment/"

var _animals: Array[Node3D] = []
var _t := 0.0


func _init() -> void:
	landmark_name = "Farm"
	discovery_radius = 200.0
	discovery_sound = "moo"


func build() -> void:
	# Barn and silo (barn doors face south, towards the runway side)
	AssetLib.place(self, ENV + "barn.glb", Vector3.ZERO, 3.5)
	BuildKit.collider(self, BuildKit.box_shape(Vector3(27, 21, 29)), Vector3(0, 10.5, 0))
	AssetLib.place(self, ENV + "silo.glb", Vector3(20, 0, -8), 3.0)
	BuildKit.collider(self, BuildKit.cyl_shape(6, 28), Vector3(20, 14, -8))
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
	# Animals in the fenced field: sheep and cows, grazing (idle animation)
	for k in 8:
		var a := TAU * k / 8.0
		var cow := k % 3 == 0
		var animal := AssetLib.place(self, ENV + ("cow.glb" if cow else "sheep.glb"),
			Vector3(-30 + cos(a) * 13, 0, 40 + sin(a) * 7), 1.1 if cow else 1.3, randf() * 360.0, "Armature|Idle")
		_animals.append(animal)


func react() -> void:
	# Everyone jumps for a few seconds, then goes back to grazing.
	for animal in _animals:
		AssetLib.play_loop(animal, "Armature|Jump")
	await get_tree().create_timer(4.0, false).timeout
	for animal in _animals:
		AssetLib.play_loop(animal, "Armature|Idle")
