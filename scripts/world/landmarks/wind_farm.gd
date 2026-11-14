class_name WindFarm
extends Landmark
## A row of turbines along the north-east ridge. Blades spin faster with a
## whoosh when discovered. Push volumes keep the plane out of the blade sweep.

const COUNT := 5
const TOWER_H := 55.0
const BLADE_LEN := 20.0

var _rotors: Array[Node3D] = []
var _spin := 1.0


func _init() -> void:
	landmark_name = "Wind Farm"
	discovery_radius = 230.0
	discovery_sound = "whoosh"


func build() -> void:
	# This node sits at the ridge midpoint; turbines are placed along it.
	var a := IslandShape.RIDGE_A
	var b := IslandShape.RIDGE_B
	var mid := (a + b) * 0.5
	for i in COUNT:
		var p := a.lerp(b, (i + 0.5) / COUNT)
		var ground := IslandShape.height(p.x, p.y)
		var t := Node3D.new()
		t.position = Vector3(p.x - mid.x, ground - position.y, p.y - mid.y)
		t.rotation_degrees.y = 35.0  # rotors face south-west
		add_child(t)
		BuildKit.add(t, BuildKit.cyl(2.2, TOWER_H, 1.4, 10), "f4f4f4", Vector3(0, TOWER_H * 0.5, 0))
		BuildKit.add(t, BuildKit.box(Vector3(3, 3, 7)), "f4f4f4", Vector3(0, TOWER_H + 1, 0))
		var rotor := Node3D.new()
		rotor.position = Vector3(0, TOWER_H + 1, -3.8)
		t.add_child(rotor)
		BuildKit.add(rotor, BuildKit.sphere(1.4, 8), "ff5a5f")
		for k in 3:
			var arm := Node3D.new()
			arm.rotation.z = TAU * k / 3.0
			rotor.add_child(arm)
			BuildKit.add(arm, BuildKit.box(Vector3(1.6, BLADE_LEN, 0.4)), "ffffff", Vector3(0, BLADE_LEN * 0.5 + 1, 0))
		rotor.rotation.z = randf() * TAU
		_rotors.append(rotor)
		BuildKit.collider(t, BuildKit.cyl_shape(2.5, TOWER_H), Vector3(0, TOWER_H * 0.5, 0))
		BuildKit.push_volume(t, BLADE_LEN + 14.0, TOWER_H + BLADE_LEN + 40.0)


func _process(delta: float) -> void:
	for r in _rotors:
		r.rotate_z(_spin * delta)
	_spin = move_toward(_spin, 1.0, delta * 0.3)


func react() -> void:
	_spin = 4.0
