class_name WindFarm
extends Landmark
## A row of turbines along the north-east ridge. Blades spin faster with a
## whoosh when discovered. Push volumes keep the plane out of the blade sweep.

const COUNT := 5
const MODEL_SCALE := 11.0
## Hub height and blade length after scaling the model (Colin Hopkins, CC-BY 3.0).
const TOWER_H := 3.9 * MODEL_SCALE
const BLADE_LEN := 1.9 * MODEL_SCALE
## Where the three blades meet, in the model's own units.
const HUB := Vector3(0.0, 0.76, -0.12)
## Blade meshes inside the .glb (spun around the hub).
const BLADE_NODES := ["group1638284413", "group319097306", "group2091045647"]

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
		t.rotation_degrees.y = 35.0 + 180.0  # rotors face south-west
		add_child(t)
		# Model's tower base sits 3.14 units below its origin.
		var model := AssetLib.place(t, "res://assets/environment/wind_turbine.glb", Vector3(0, 3.14 * MODEL_SCALE, 0), MODEL_SCALE)
		_rotors.append(_make_rotor(model))
		BuildKit.collider(t, BuildKit.cyl_shape(2.5, TOWER_H), Vector3(0, TOWER_H * 0.5, 0))
		BuildKit.push_volume(t, BLADE_LEN + 14.0, TOWER_H + BLADE_LEN + 40.0)


## Regroup the blade meshes under a pivot at the hub so they can spin.
func _make_rotor(model: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = HUB
	var holder: Node3D = model.find_child(BLADE_NODES[0], true, false).get_parent()
	holder.add_child(pivot)
	for blade_name in BLADE_NODES:
		var blade: Node3D = model.find_child(blade_name, true, false)
		var xf := blade.transform
		blade.get_parent().remove_child(blade)
		pivot.add_child(blade)
		blade.transform = Transform3D(Basis.IDENTITY, -HUB) * xf
	pivot.rotation.z = randf() * TAU
	return pivot


func _process(delta: float) -> void:
	for r in _rotors:
		r.rotate_z(_spin * delta)
	_spin = move_toward(_spin, 1.0, delta * 0.3)


func react() -> void:
	_spin = 4.0
