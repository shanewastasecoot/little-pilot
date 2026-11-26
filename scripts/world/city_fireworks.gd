class_name CityFireworks
extends Node3D
## A fireworks show over the city: rockets whoosh up from between the towers
## and burst into big, bright, colourful balls high in the sky (seen from
## anywhere on the main island). Add as a child of the city; call start().

signal show_finished

const COLORS: Array[Color] = [Color("ff3b3b"), Color("ffd23f"), Color("4cc06a"), Color("3f8cff"),
	Color("ff7eb9"), Color("9b5de5"), Color("ff8c42"), Color.WHITE]

## Launch spots (city-local): street corners between the towers.
const PADS := [Vector3(-40, 0, -40), Vector3(40, 0, -40), Vector3(-40, 0, 40), Vector3(40, 0, 40),
	Vector3(0, 0, 0), Vector3(-120, 0, 0), Vector3(120, 0, 0), Vector3(0, 0, -120)]

var running := false
var _left := 0.0
var _next_launch := 0.0
var _rockets: Array[Dictionary] = []  # {node, velocity, burst_y}
var _rocket_mesh := BuildKit.sphere(1.2, 6)


func start(duration: float = 25.0) -> void:
	running = true
	_left = duration
	_next_launch = 0.0


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if running:
		_left -= delta
		_next_launch -= delta
		if _next_launch <= 0.0:
			# Volleys get busier towards the grand finale.
			var finale := _left < 5.0
			for k in (3 if finale else randi_range(1, 2)):
				_launch()
			_next_launch = randf_range(0.25, 0.45) if finale else randf_range(0.6, 1.2)
		if _left <= 0.0:
			running = false
			show_finished.emit()
	# Fly rockets; burst at the top.
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		var node: Node3D = r.node
		node.position += r.velocity * delta
		if node.position.y >= r.burst_y:
			_burst(node.position)
			node.queue_free()
			_rockets.remove_at(i)


func _launch() -> void:
	StallDetector.note("firework")
	var pad: Vector3 = PADS[randi() % PADS.size()] + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	var rocket := Node3D.new()
	rocket.position = pad
	add_child(rocket)
	var mi := MeshInstance3D.new()
	mi.mesh = _rocket_mesh
	mi.material_override = BuildKit.mat("fff2b0", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocket.add_child(mi)
	var trail := PickupBurst.new(12, 2.0, [Color("ffe08a"), Color("ff8c42")])
	trail.one_shot = false
	trail.explosiveness = 0.0
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.finished.disconnect(trail.queue_free)
	rocket.add_child(trail)
	var speed := randf_range(110.0, 140.0)
	var dir := Vector3(randf_range(-0.12, 0.12), 1.0, randf_range(-0.12, 0.12)).normalized()
	_rockets.append({node = rocket, velocity = dir * speed, burst_y = randf_range(215.0, 300.0)})
	Sfx.play_at("whistle", global_position + pad, randf_range(0.9, 1.2), -6.0)


func _burst(at: Vector3) -> void:
	StallDetector.note("firework burst")
	var burst := FireworkBurst.new(COLORS[randi() % COLORS.size()], COLORS[randi() % COLORS.size()])
	burst.position = at
	add_child(burst)
	Sfx.play_at("boom", global_position + at, randf_range(0.8, 1.2))
