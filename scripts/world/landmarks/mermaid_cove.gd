class_name MermaidCove
extends Landmark
## A rocky islet where mermaids sit on the beach and wave at the plane as
## it flies past (Mermaid scene + MermaidWatcher), and more leap out of
## the deep water around it. They all leap and the cove
## sparkles when discovered.

var radius: float = 180.0
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
	discovery_radius = 330.0
	discovery_sound = "lala"


func build() -> void:
	var env := "res://assets/environment/"
	# Big rocks in the middle for the mermaids to sit on.
	# Everything scales with the islet (rocks were sized for a 115 m cove).
	var g := ground_y - 1.0
	var k := radius / 115.0
	AssetLib.place(self, env + "rocks.glb", Vector3(0, g, 0), 170.0 * k, 20.0)
	AssetLib.place(self, env + "rock.glb", Vector3(12, g, -8) * Vector3(k, 1, k), 120.0 * k, 70.0)
	BuildKit.collider(self, BuildKit.cyl_shape(26 * k, 28 * k), Vector3(0, g + 14 * k, 0))
	# A couple of smaller rocks out along the beach.
	for j in 3:
		var a := TAU * j / 3.0 + 1.1
		var lp := Vector2(cos(a), sin(a)) * radius * 0.55
		var h: float = ground_fn.call(centre.x + lp.x, centre.y + lp.y) if ground_fn.is_valid() else ground_y
		AssetLib.place(self, env + "rock.glb", Vector3(lp.x, h - 1.0, lp.y), 60.0, 40.0 * j)
	var tails: Array[Color] = [Color("ff7eb9"), Color("3fd0c9"), Color("9b5de5"), Color("ffd23f"), Color("ff8c42"), Color("7ee081")]
	var watcher := MermaidWatcher.new()
	add_child(watcher)
	var scene: PackedScene = load("res://scenes/characters/mermaid.tscn")
	for n in tails.size():
		var a := TAU * n / tails.size() + 0.4
		var spot := _beach_spot(a)
		var m: Mermaid = scene.instantiate()
		m.tail_color = tails[n]
		m.scale = Vector3.ONE * 9.0
		# Sitting on the sand looking out to sea, tail reaching for the water.
		m.position = spot + Vector3(0, -0.4, 0)
		var out := Vector2(spot.x, spot.z).normalized()
		m.rotation.y = atan2(out.x, out.y)
		add_child(m)
		watcher.add(m)
		_sitters.append(m)
	_swimmers = SeaLeapers.new()
	# Leap only over deep water (the islet's land reaches ~1.2r + 45 m).
	_swimmers.setup("mermaid", radius * 1.2 + 85.0, 5, int(position.x))
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
		m.greet(0.9)
	var bubbles := PickupBurst.new(60, 16.0, [Color("bff3ff"), Color("ffffff"), Color("ff7eb9")])
	bubbles.position = Vector3(0, 25 * radius / 115.0, 0)
	add_child(bubbles)
