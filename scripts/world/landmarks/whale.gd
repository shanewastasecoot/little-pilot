class_name Whale
extends Landmark
## A friendly cartoon whale that surfaces every few seconds off the west
## coast, waggling as she swims, and blows a big spout when discovered.

var _body: Node3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Whale"
	discovery_radius = 120.0
	discovery_sound = "splash"


func build() -> void:
	_body = Node3D.new()
	add_child(_body)
	# A honk or a low pass near her (WorldEvents): she blows a spout.
	WorldReaction.add(self, 240.0, ["honk", "low_pass"], 5.0, func(_k: String, _w: Vector3): react()).centre = _body
	# Model is ~1.13 long, head along +Z, origin under her belly.
	AssetLib.place(_body, "res://assets/environment/whale.glb", Vector3(0, -6.0, 2.6), 23.0)


func _process(delta: float) -> void:
	_t += delta
	# Surface for a few seconds, then dive.
	var cycle := fmod(_t, 9.0)
	var up := smoothstep(0.0, 1.5, cycle) * (1.0 - smoothstep(5.0, 6.5, cycle))
	var gp := global_position
	_body.position.y = lerpf(-8.0, 0.5, up) + Waves.height(gp.x, gp.z) * up
	_body.rotation.x = sin(cycle * 0.7) * 0.08
	# A gentle side-to-side swim wiggle (the model has no rig).
	_body.rotation.y = sin(_t * 1.6) * 0.07
	_body.rotation.z = sin(_t * 1.6 + 1.0) * 0.04


func react() -> void:
	var spout := PickupBurst.new(40, 16.0, [Color.WHITE, Color("bfe6ff")])
	spout.spread = 15.0
	spout.gravity = Vector3(0, -14, 0)
	spout.lifetime = 1.6
	_body.add_child(spout)
	spout.position = Vector3(0, 6, 8)
	_t = 1.5  # pop up right away
