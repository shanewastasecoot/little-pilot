class_name DinoIsland
extends Landmark
## Jungle island far to the south-east with friendly dinosaurs: some graze,
## some stroll round in big circles. Everyone jumps when discovered.

const C := OuterIslands.DINO
const ENV := "res://assets/environment/"
## [model, scale, idle anim, walk anim]
const KINDS := {
	"apatosaurus": [1.0, "Armature|Apatosaurus_Idle", "Armature|Apatosaurus_Walk", "Armature|Apatosaurus_Jump"],
	"triceratops": [2.2, "Armature|Triceratops_Idle", "Armature|Triceratops_Walk", "Armature|Triceratops_Jump"],
	"stegosaurus": [1.3, "Armature|Stegosaurus_Idle", "Armature|Stegosaurus_Walk", "Armature|Stegosaurus_Jump"],
	"trex": [1.1, "Armature|TRex_Idle", "Armature|TRex_Walk", "Armature|TRex_Jump"],
}

var _dinos: Array[Dictionary] = []  # {node, kind, walker, angle, radius, speed, centre}


func _init() -> void:
	landmark_name = "Dino Island"
	discovery_radius = 450.0
	discovery_sound = "rawr"


func build() -> void:
	var h := OuterIslands.dino_height
	IslandDecor.scatter(self, ENV + "tree_round.glb", 70, C, 40.0, 420.0, h, 2.6, 3.6, 8.0, 120.0, 9)
	IslandDecor.scatter(self, ENV + "palm.glb", 30, C, 300.0, 460.0, h, 4.5, 6.0, 4.0, 40.0, 10)
	var plan := [
		["apatosaurus", false, Vector2(-80, 60)], ["apatosaurus", true, Vector2(40, 120)],
		["triceratops", false, Vector2(120, 160)], ["triceratops", true, Vector2(-160, -40)],
		["stegosaurus", false, Vector2(-40, -150)], ["stegosaurus", true, Vector2(160, -20)],
		["trex", true, Vector2(-200, 160)],
	]
	for item in plan:
		var kind: String = item[0]
		var info: Array = KINDS[kind]
		var lp: Vector2 = item[2]
		var node := AssetLib.place(self, ENV + kind + ".glb", Vector3(lp.x, IslandDecor.ground(h, C, lp), lp.y), info[0], randf() * 360.0, info[2] if item[1] else info[1])
		for gi in node.find_children("*", "GeometryInstance3D", true, false):
			gi.visibility_range_end = 1600.0
		_dinos.append({node = node, kind = kind, walker = item[1], angle = randf() * TAU, radius = 45.0, speed = 0.12, centre = lp})


func _process(delta: float) -> void:
	var h := OuterIslands.dino_height
	for d in _dinos:
		if not d.walker:
			continue
		d.angle += d.speed * delta
		var lp: Vector2 = d.centre + Vector2(cos(d.angle), sin(d.angle)) * d.radius
		var node: Node3D = d.node
		node.position = Vector3(lp.x, IslandDecor.ground(h, C, lp), lp.y)
		node.rotation.y = -d.angle  # face along the circle


func react() -> void:
	for d in _dinos:
		AssetLib.play_loop(d.node, KINDS[d.kind][3])
	await get_tree().create_timer(3.0, false).timeout
	for d in _dinos:
		AssetLib.play_loop(d.node, KINDS[d.kind][2] if d.walker else KINDS[d.kind][1])
