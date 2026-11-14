class_name PalmIsland
extends Landmark
## Little tropical island east of the main island: palm trees round the
## beach, beach shacks, striped umbrellas and a giant sandcastle.
## Node sits at the island centre at sea level.

const PALM := "res://assets/environment/palm.glb"
const PALM_SCALE := 5.2

var _umbrellas: Array[Node3D] = []


func _init() -> void:
	landmark_name = "Palm Island"
	discovery_radius = 300.0
	discovery_sound = "tropical"


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := IslandShape.PALM_ISLAND
	# Palms in a loose ring round the beach (one MultiMesh).
	var data: Array = AssetLib.mesh_of(PALM)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data[0]
	var xforms: Array[Transform3D] = []
	for i in 46:
		var a := TAU * i / 46.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(150.0, 215.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		var h := IslandShape.palm_height(p.x, p.y)
		if h < 3.0:
			continue
		var s := PALM_SCALE * rng.randf_range(0.8, 1.25)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x - c.x, h - 0.3, p.y - c.y)) * data[1])
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 1400.0
	add_child(mmi)
	# Beach shacks on the south shore.
	for k in 3:
		var a := 1.2 + k * 0.35
		var p := c + Vector2(cos(a), sin(a)) * 120.0
		AssetLib.place(self, "res://assets/environment/shack.glb", Vector3(p.x - c.x, IslandShape.palm_height(p.x, p.y), p.y - c.y), 11.0, rad_to_deg(-a) + 90.0)
	# Striped umbrellas near the shacks.
	var stripes := ["ff5a5f", "ffd23f", "4aa8ff", "9b5de5", "4cc06a", "ff8c42"]
	for k in 6:
		var a := 1.0 + k * 0.17
		var p := c + Vector2(cos(a), sin(a)) * 160.0
		var u := _umbrella(stripes[k])
		u.position = Vector3(p.x - c.x, IslandShape.palm_height(p.x, p.y), p.y - c.y)
		add_child(u)
		_umbrellas.append(u)
	# A giant sandcastle in the middle.
	var castle_h := IslandShape.palm_height(c.x + 10, c.y - 20)
	AssetLib.place(self, "res://assets/environment/sand_castle.glb", Vector3(10, castle_h - 1.0, -20), 1.3, 20.0)
	BuildKit.collider(self, BuildKit.cyl_shape(26, 24), Vector3(10, castle_h + 11.0, -20))


func _umbrella(hex: String) -> Node3D:
	var root := Node3D.new()
	BuildKit.add(root, BuildKit.cyl(0.2, 5.0), "ffffff", Vector3(0, 2.5, 0))
	for i in 8:
		var seg := BuildKit.add(root, BuildKit.cyl(0.0, 1.2, 3.6, 3), hex if i % 2 == 0 else "ffffff", Vector3(0, 5.2, 0))
		seg.rotation.y = TAU * i / 8.0
	root.rotation.z = randf_range(-0.12, 0.12)
	return root


func react() -> void:
	for u in _umbrellas:
		var tw := create_tween()
		tw.tween_property(u, "rotation:y", u.rotation.y + TAU, 1.2).set_trans(Tween.TRANS_BACK)
	var burst := PickupBurst.new(40, 14.0, [Color("ffd23f"), Color("ff7eb9"), Color("4cc06a")])
	burst.position = Vector3(0, 40, 0)
	add_child(burst)
