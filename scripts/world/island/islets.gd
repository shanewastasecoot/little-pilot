class_name Islets
extends RefCounted
## Small islands scattered in the open sea, mostly beside the long star
## trails so there's always something to fly past. Kinds:
##   palm      sand + a few palms + crabs
##   rocky     rocks + basking seals
##   sandbar   low sand + crabs
##   mermaid   rocky cove with mermaids (a discoverable landmark)
##   lagoon    the big Mermaid Lagoon atoll (radius = its ring)

const LIST := [
	# centre, radius, peak, kind, dolphins?
	[Vector2(1000, -2180), 90.0, 14.0, "palm", true],
	[Vector2(-120, -2300), 270.0, 10.0, "lagoon", false],
	[Vector2(520, -2620), 70.0, 16.0, "rocky", false],
	[Vector2(-150, 1720), 100.0, 14.0, "palm", true],
	[Vector2(-880, 2220), 120.0, 10.0, "mermaid", false],
	[Vector2(-330, 2660), 70.0, 4.0, "sandbar", false],
	[Vector2(-1660, 620), 90.0, 18.0, "rocky", false],
	[Vector2(-2220, 120), 100.0, 14.0, "palm", true],
	[Vector2(-2620, 820), 70.0, 4.0, "sandbar", false],
	[Vector2(2080, 1150), 95.0, 16.0, "rocky", false],
	[Vector2(2420, 1560), 110.0, 10.0, "mermaid", false],
	[Vector2(2650, -1200), 120.0, 15.0, "palm", true],
	[Vector2(-2620, -2050), 110.0, 18.0, "rocky", false],
	[Vector2(1320, -2420), 90.0, 4.0, "sandbar", true],
	[Vector2(-2300, 2620), 115.0, 10.0, "mermaid", false],
	[Vector2(1500, 3220), 110.0, 14.0, "palm", true],
]


static func height(x: float, z: float, centre: Vector2, radius: float, peak: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(centre)
	var a := atan2(p.y - centre.y, p.x - centre.x)
	var n := sin(a * 3.0 + centre.x) * 0.12 + sin(a * 7.0 + centre.y) * 0.06
	var coast := radius * (1.0 + n)
	var land := smoothstep(coast + 45.0, coast - 40.0, d)
	var h := 3.0 + peak * smoothstep(coast, 0.0, d)
	return lerpf(-28.0, h, land)


static func color(_x: float, _z: float, h: float, slope: float, kind: String) -> Color:
	if kind == "rocky" and (h > 6.0 or slope > 0.4):
		return Color("8d8a96")
	if kind == "palm" and h > 8.0:
		return Color("8fdc5c")
	return Color("f4dc8f")


## Build terrain + decor for every islet under `parent` (the map).
static func build_all(parent: Node3D, stars: Node3D) -> void:
	for i in LIST.size():
		var e: Array = LIST[i]
		var c: Vector2 = e[0]
		var r: float = e[1]
		var peak: float = e[2]
		var kind: String = e[3]
		if kind == "lagoon":
			_build_lagoon(parent, stars, c, i)
			continue
		var hf := height.bind(c, r, peak)
		TerrainBuilder.build(parent, hf, color.bind(kind), c, r * 2.0 + 220.0, 24, "Islet%d" % i)
		var node: Node3D
		if kind == "mermaid":
			node = MermaidCove.new()
			node.set("radius", r)
			node.set("ground_y", hf.call(c.x, c.y))
			node.set("ground_fn", hf)
			node.set("centre", c)
		else:
			node = Node3D.new()
		node.position = Vector3(c.x, 0, c.y)
		parent.add_child(node)
		_decorate(node, kind, c, r, hf, i)
		if e[4]:
			var pod := SeaLeapers.new()
			pod.setup("dolphin", r * 1.2 + 95.0, 3, i)
			node.add_child(pod)
		# A little arc of stars over every islet.
		_star_arc(stars, c, r, kind == "mermaid")


## The big atoll: its own terrain shape, with the channel facing the main
## island so the arch is the first thing you see flying out from home.
static func _build_lagoon(parent: Node3D, stars: Node3D, c: Vector2, i: int) -> void:
	var chan := (-c).angle()
	var hf := MermaidLagoon.height.bind(c, chan)
	TerrainBuilder.build(parent, hf, MermaidLagoon.color, c, (MermaidLagoon.RING_RADIUS + 130.0) * 2.0, 80, "Islet%d" % i)
	var node := MermaidLagoon.new()
	node.centre = c
	node.channel_angle = chan
	node.position = Vector3(c.x, 0, c.y)
	parent.add_child(node)
	# A ring of stars over the lagoon itself (the ring's hills are tall).
	_star_arc(stars, c, MermaidLagoon.RING_RADIUS * 0.5, true)


static func _decorate(node: Node3D, kind: String, c: Vector2, r: float, hf: Callable, seed_value: int) -> void:
	var env := "res://assets/environment/"
	match kind:
		"palm":
			IslandDecor.scatter(node, env + "palm.glb", int(r / 18.0), c, 0.0, r * 0.7, hf, 4.5, 6.0, 3.5, 100.0, seed_value)
			_crabs(node, c, r, hf, 2, seed_value)
		"rocky":
			for k in 6:
				var a := TAU * k / 6.0 + seed_value
				var lp := Vector2(cos(a), sin(a)) * r * randf_range(0.2, 0.6)
				AssetLib.place(node, env + ("rocks.glb" if k % 2 == 0 else "rock.glb"), Vector3(lp.x, IslandDecor.ground(hf, c, lp) - 1.0, lp.y), randf_range(50.0, 90.0), randf() * 360.0)
			for k in 3:
				var a := TAU * k / 3.0 + 0.5
				var lp := Vector2(cos(a), sin(a)) * r * 0.75
				AssetLib.place(node, env + "seal.glb", Vector3(lp.x, IslandDecor.ground(hf, c, lp), lp.y), 0.4, rad_to_deg(-a) + 90.0)
		"sandbar":
			_crabs(node, c, r, hf, 3, seed_value)


static func _crabs(node: Node3D, c: Vector2, r: float, hf: Callable, count: int, seed_value: int) -> void:
	for k in count:
		var a := TAU * k / count + seed_value * 0.7
		var lp := Vector2(cos(a), sin(a)) * r * 0.8
		AssetLib.place(node, "res://assets/environment/crab.glb", Vector3(lp.x, IslandDecor.ground(hf, c, lp) + 168.0 * 0.008, lp.y), 0.008, randf() * 360.0)


static func _star_arc(stars: Node3D, c: Vector2, r: float, ring: bool) -> void:
	var curve := Curve3D.new()
	var n := 9 if ring else 3
	for k in n:
		var a := (TAU * k / 8.0) if ring else (PI * 0.25 + k * 0.6)
		var p := c + Vector2(cos(a), sin(a)) * (r + 25.0)
		curve.add_point(Vector3(p.x, 22.0, p.y))
	var trail := StarTrail.new()
	trail.curve = curve
	trail.star_count = 8 if ring else 3
	stars.add_child(trail)
