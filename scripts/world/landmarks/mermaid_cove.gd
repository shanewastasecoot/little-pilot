class_name MermaidCove
extends Landmark
## A rocky islet where mermaids sit on the beach and wave at the plane as
## it flies past (Mermaid scene + MermaidWatcher), and more leap out of
## the deep water around it. They all leap and the cove
## sparkles when discovered.

var radius: float = 110.0
## Ground height at the cove centre (set by Islets before adding).
var ground_y: float = 10.0
## The islet's height function and centre, to find the beach.
var ground_fn: Callable
var centre: Vector2
var _sitters: Array[Mermaid] = []
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
	var tails: Array[Color] = [Color("ff7eb9"), Color("3fd0c9"), Color("9b5de5"), Color("ffd23f")]
	var watcher := MermaidWatcher.new()
	add_child(watcher)
	var scene: PackedScene = load("res://scenes/characters/mermaid.tscn")
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var spot := _beach_spot(a)
		var m: Mermaid = scene.instantiate()
		m.tail_color = tails[k]
		m.scale = Vector3.ONE * 10.0
		# Sitting on the sand, tail curled into it, looking out to sea.
		m.position = spot + Vector3(0, 0.96 * 10.0 - 3.5, 0)
		var out := Vector2(spot.x, spot.z).normalized()
		m.rotation.y = atan2(-out.x, -out.y)
		add_child(m)
		watcher.add(m)
		_sitters.append(m)
	_swimmers = SeaLeapers.new()
	# Leap only over deep water (the islet's land reaches ~1.2r + 45 m).
	_swimmers.setup("mermaid", radius * 1.2 + 85.0, 3, int(position.x))
	add_child(_swimmers)


## A point on the sand just above the waterline in direction `a`.
func _beach_spot(a: float) -> Vector3:
	var dir := Vector2(cos(a), sin(a))
	var r := radius * 0.4
	while r < radius * 1.6:
		var p := centre + dir * r
		var h: float = ground_fn.call(p.x, p.y) if ground_fn.is_valid() else ground_y
		if h < 3.6:
			var back := centre + dir * (r - 6.0)
			return Vector3(dir.x * (r - 6.0), ground_fn.call(back.x, back.y), dir.y * (r - 6.0))
		r += 3.0
	return Vector3(dir.x * radius * 0.7, ground_y, dir.y * radius * 0.7)


func react() -> void:
	_swimmers.leap_all()
	for m in _sitters:
		m.set_waving(true)
	var bubbles := PickupBurst.new(60, 16.0, [Color("bff3ff"), Color("ffffff"), Color("ff7eb9")])
	bubbles.position = Vector3(0, 25, 0)
	add_child(bubbles)
