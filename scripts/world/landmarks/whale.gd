class_name Whale
extends Landmark
## A friendly whale that surfaces every few seconds off the west coast and
## blows a big spout when discovered.

var _body: Node3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Whale"
	discovery_radius = 120.0
	discovery_sound = "splash"


func build() -> void:
	_body = Node3D.new()
	add_child(_body)
	BuildKit.add(_body, BuildKit.sphere(5, 10), "3d6fa8", Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.7, 2.6))
	BuildKit.add(_body, BuildKit.sphere(4.6, 10), "dbe9f6", Vector3(0, -1.2, -1), Vector3.ZERO, Vector3(0.9, 0.5, 2.3))
	BuildKit.add(_body, BuildKit.box(Vector3(9, 0.6, 3)), "3d6fa8", Vector3(0, 0.5, 13), Vector3(0, 0, 0))
	for side in [-1, 1]:
		BuildKit.add(_body, BuildKit.sphere(0.5, 6), "ffffff", Vector3(side * 3.6, 1.2, -9))


func _process(delta: float) -> void:
	_t += delta
	# Surface for a few seconds, then dive.
	var cycle := fmod(_t, 9.0)
	var up := smoothstep(0.0, 1.5, cycle) * (1.0 - smoothstep(5.0, 6.5, cycle))
	_body.position.y = lerpf(-8.0, 0.5, up)
	_body.rotation.x = sin(cycle * 0.7) * 0.08


func react() -> void:
	var spout := PickupBurst.new(40, 16.0, [Color.WHITE, Color("bfe6ff")])
	spout.spread = 15.0
	spout.gravity = Vector3(0, -14, 0)
	spout.lifetime = 1.6
	_body.add_child(spout)
	spout.position = Vector3(0, 4, -6)
	_t = 1.5  # pop up right away
