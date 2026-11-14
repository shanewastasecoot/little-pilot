class_name CastleIsland
extends Landmark
## A fairy-tale castle on a hill far to the south. Fireworks when discovered.

const C := OuterIslands.CASTLE
const CASTLE_SCALE := 1.0


func _init() -> void:
	landmark_name = "Castle"
	discovery_radius = 380.0
	discovery_sound = "fanfare"


func build() -> void:
	var top := OuterIslands.CASTLE_HILL
	AssetLib.place(self, "res://assets/environment/castle.glb", Vector3(0, top + 2.38 * CASTLE_SCALE - 1.0, 0), CASTLE_SCALE, 15.0)
	BuildKit.collider(self, BuildKit.box_shape(Vector3(115, 88, 120)), Vector3(0, top + 44.0, 0))
	BuildKit.push_volume(self, 100.0, top + 140.0)
	IslandDecor.scatter(self, "res://assets/environment/tree_round.glb", 40, C, 170.0, 360.0, OuterIslands.castle_height, 2.2, 3.0, 8.0, 60.0, 21)


func react() -> void:
	var colors: Array[Color] = [Color("ff5a5f"), Color("ffd23f"), Color("4aa8ff"), Color("9b5de5"), Color("4cc06a")]
	for k in 6:
		var burst := PickupBurst.new(50, 26.0, colors)
		burst.position = Vector3(randf_range(-60, 60), OuterIslands.CASTLE_HILL + 130.0 + randf() * 40.0, randf_range(-60, 60))
		add_child(burst)
		await get_tree().create_timer(0.3, false).timeout
