class_name SeaLeapers
extends Node3D
## Creatures that swim round a circle and leap out of the water in arcs:
## dolphins (animated model) or mermaids (merged model, own tail colour).
## Mostly hidden underwater; each leaps every few seconds.

const LEAP_TIME := 1.6
const LEAP_HEIGHT := 9.0

var radius := 120.0
var kind := "dolphin"
var _members: Array[Dictionary] = []
var _t := 0.0


func setup(creature: String, circle_radius: float, count: int, seed_value: int) -> void:
	kind = creature
	radius = circle_radius
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	for i in count:
		_members.append({angle = rng.randf() * TAU, speed = rng.randf_range(0.05, 0.09), period = rng.randf_range(4.0, 7.0), offset = rng.randf() * 7.0, node = null})


func _ready() -> void:
	var tails: Array[Color] = [Color("ff7eb9"), Color("9b5de5"), Color("3fd0c9"), Color("ffd23f"), Color("ff8c42")]
	for i in _members.size():
		var m := _members[i]
		var holder := Node3D.new()
		add_child(holder)
		if kind == "dolphin":
			AssetLib.place(holder, "res://assets/environment/dolphin.glb", Vector3.ZERO, 0.8, 180.0)
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = AssetLib.merged_mesh("res://assets/environment/mermaid.glb", 0.24, 0.08, tails[i % tails.size()])
			mi.scale = Vector3.ONE * 8.0
			mi.rotation_degrees = Vector3(0, 90, 0)  # face along the swim direction
			holder.add_child(mi)
		m.node = holder


func _process(delta: float) -> void:
	_t += delta
	for m in _members:
		m.angle += m.speed * delta
		var holder: Node3D = m.node
		var phase := fmod(_t + m.offset, m.period)
		var y := -8.0
		var pitch := 0.0
		if phase < LEAP_TIME:
			var u := phase / LEAP_TIME
			y = -2.0 + sin(u * PI) * LEAP_HEIGHT
			pitch = cos(u * PI) * 0.7  # nose up, then nose down
		holder.position = Vector3(cos(m.angle) * radius, y, sin(m.angle) * radius)
		holder.rotation = Vector3(0, -m.angle, 0)
		holder.rotation.x = 0.0
		holder.rotate_object_local(Vector3.RIGHT, pitch)
		holder.visible = y > -6.0


## Everyone leaps right now (used when a cove is discovered).
func leap_all() -> void:
	for m in _members:
		m.offset = m.period - fmod(_t, m.period)
