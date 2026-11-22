class_name TrophyShelf
extends Node3D
## The living room's trophy shelf: a long wall shelf with little golden
## stands, waiting for the dragon treasure she brings home (Phase 4 fills it
## with show_trophies()). Origin on the wall at the shelf's height; the
## front faces +Z.

const SPOTS := 5
const WIDTH := 16.0

var _stands: Array[Node3D] = []


func _ready() -> void:
	var board := BuildKit.add(self, BuildKit.box(Vector3(WIDTH, 0.5, 2.2)), "8b5a2b", Vector3(0, 0, 1.1))
	board.material_override = BuildingGenerator._mat("8b5a2b")
	for side in [-1.0, 1.0]:
		var bracket := BuildKit.add(self, BuildKit.box(Vector3(0.4, 1.4, 1.6)), "6b4226", Vector3(side * (WIDTH * 0.5 - 1.0), -0.9, 0.8))
		bracket.material_override = BuildingGenerator._mat("6b4226")
	for i in SPOTS:
		var stand := Node3D.new()
		stand.position = Vector3(-WIDTH * 0.5 + (i + 0.5) * WIDTH / SPOTS, 0.25, 1.1)
		add_child(stand)
		var disc := BuildKit.add(stand, BuildKit.cyl(0.9, 0.3, -1, 20), "ffd23f", Vector3(0, 0.15, 0))
		disc.material_override = BuildingGenerator._mat("e9b23a")
		_stands.append(stand)


## Show `count` pieces of treasure on the stands (Phase 4).
func show_trophies(count: int) -> void:
	for i in _stands.size():
		var stand := _stands[i]
		var has := stand.get_node_or_null("Treasure")
		if i < count and has == null:
			var t := BuildKit.add(stand, BuildKit.sphere(0.8, 12), "ffd23f", Vector3(0, 1.1, 0))
			t.name = "Treasure"
			t.material_override = BuildingGenerator._glow_mat(Color("ffd23f"))
		elif i >= count and has != null:
			has.queue_free()


func stand_count() -> int:
	return _stands.size()
