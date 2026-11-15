class_name IceIsland
extends Landmark
## Snowy island far to the north: snowy pines, igloos, waddling penguins and
## icebergs bobbing offshore. Penguins hop when discovered.

const C := OuterIslands.ICE
var _penguins: Array[Node3D] = []
var _bergs: Array[Node3D] = []
var _t := 0.0


func _init() -> void:
	landmark_name = "Ice Island"
	discovery_radius = 420.0
	discovery_sound = "bells"


func build() -> void:
	var h := OuterIslands.ice_height
	IslandDecor.scatter(self, "res://assets/environment/snow_pine.glb", 70, C, 60.0, 360.0, h, 3.6, 5.0, 8.0, 90.0, 5)
	for k in 5:
		var a := 2.2 + k * 0.45
		var lp := Vector2(cos(a), sin(a)) * 200.0
		AssetLib.place(self, "res://assets/environment/igloo.glb", Vector3(lp.x, IslandDecor.ground(h, C, lp) + 0.56 * 7.0 - 1.0, lp.y), 7.0, rad_to_deg(-a) - 90.0)
	for k in 9:
		var a := 2.0 + k * 0.22
		var lp := Vector2(cos(a), sin(a)) * (280.0 + (k % 3) * 12.0)
		var p := AssetLib.place(self, "res://assets/environment/penguin.glb", Vector3(lp.x, IslandDecor.ground(h, C, lp) + 88.0 * 0.05, lp.y), 0.05, randf() * 360.0)
		_penguins.append(p)
	for k in 8:
		var a := TAU * k / 8.0 + 0.3
		var berg := AssetLib.place(self, "res://assets/environment/iceberg.glb", Vector3(cos(a) * 560.0, -10.0, sin(a) * 560.0), randf_range(0.25, 0.45), randf() * 360.0)
		_bergs.append(berg)


func _process(delta: float) -> void:
	_t += delta
	for i in _penguins.size():
		_penguins[i].rotation.z = sin(_t * 5.0 + i) * 0.12  # waddle
	for i in _bergs.size():
		_bergs[i].position.y = -10.0 + sin(_t * 0.6 + i) * 0.8


func react() -> void:
	for i in _penguins.size():
		var p := _penguins[i]
		var tw := create_tween().set_loops(4)
		tw.tween_property(p, "position:y", p.position.y + 3.0, 0.2).set_delay(i * 0.04)
		tw.tween_property(p, "position:y", p.position.y, 0.2)
	var snow := PickupBurst.new(60, 20.0, [Color.WHITE, Color("cfe8ff")])
	snow.position = Vector3(0, 60, 0)
	add_child(snow)
