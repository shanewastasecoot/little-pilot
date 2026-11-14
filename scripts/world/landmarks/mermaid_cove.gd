class_name MermaidCove
extends Landmark
## A rocky islet where mermaids sit on the big rock waving their tails,
## and more leap out of the water around it. They all leap and the cove
## sparkles when discovered.

var radius: float = 110.0
## Ground height at the cove centre (set by Islets before adding).
var ground_y: float = 10.0
var _sitters: Array[Node3D] = []
var _swimmers: SeaLeapers
var _t := 0.0


func _init() -> void:
	landmark_name = "Mermaid Cove"
	discovery_radius = 230.0
	discovery_sound = "lala"


func build() -> void:
	var env := "res://assets/environment/"
	# Big rocks in the middle for the mermaids to sit on.
	var g := ground_y - 1.0
	AssetLib.place(self, env + "rocks.glb", Vector3(0, g, 0), 170.0, 20.0)
	AssetLib.place(self, env + "rock.glb", Vector3(12, g, -8), 120.0, 70.0)
	BuildKit.collider(self, BuildKit.cyl_shape(26, 28), Vector3(0, g + 14, 0))
	var tails: Array[Color] = [Color("ff7eb9"), Color("3fd0c9"), Color("9b5de5")]
	for k in 3:
		var a := TAU * k / 3.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(a) * 24.0, ground_y + 9.0, sin(a) * 24.0)
		holder.rotation.y = -a + PI * 0.5  # facing out to sea
		add_child(holder)
		var mi := MeshInstance3D.new()
		mi.mesh = AssetLib.merged_mesh(env + "mermaid.glb", 0.24, 0.08, tails[k])
		mi.scale = Vector3.ONE * 8.0
		holder.add_child(mi)
		_sitters.append(holder)
	_swimmers = SeaLeapers.new()
	_swimmers.setup("mermaid", radius + 70.0, 3, int(position.x))
	add_child(_swimmers)


func _process(delta: float) -> void:
	_t += delta
	for i in _sitters.size():
		# Gentle sway, like waving a tail.
		_sitters[i].rotation.z = sin(_t * 1.8 + i * 2.0) * 0.12
		_sitters[i].position.y = ground_y + 9.0 + sin(_t * 1.2 + i) * 0.4


func react() -> void:
	_swimmers.leap_all()
	var bubbles := PickupBurst.new(60, 16.0, [Color("bff3ff"), Color("ffffff"), Color("ff7eb9")])
	bubbles.position = Vector3(0, 25, 0)
	add_child(bubbles)
