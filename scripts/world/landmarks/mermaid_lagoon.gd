class_name MermaidLagoon
extends Landmark
## The big mermaid island: a ring-shaped atoll round a shallow turquoise
## lagoon. A rock arch spans the channel into the lagoon (with a star trail
## leading through it and a mermaid sitting on top), coral glows under the
## clear water, and a giant open clam with a pearl sits on a little island in
## the middle. Mermaids lounge on the inner beaches and round the clam, and
## more leap in the lagoon. Everyone waves as the plane flies by; on
## discovery they all wave, leap, and the pearl sparkles.

const RING_RADIUS := 270.0
const RING_WIDTH := 62.0
const CHANNEL_WIDTH := 115.0
## Arch over the channel: a rock torus standing in the water.
const ARCH_INNER := 55.0
const ARCH_THICK := 20.0
const ARCH_SINK := 10.0
const MERMAID_SCALE := 9.0
const TAILS := ["ff7eb9", "3fd0c9", "9b5de5", "ffd23f", "4cc06a", "ff8c42", "5aa9ff", "ff5a5f"]
const CORAL := ["ff6f91", "ff9671", "ffc75f", "c34a9c", "f9f871", "ff8fab"]

var centre := Vector2.ZERO
## Direction (radians, map XZ) from the centre through the channel.
var channel_angle := 0.0
var _sitters: Array[Mermaid] = []
var _swimmers: SeaLeapers
var _pearl: Node3D
var _lid: Node3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Mermaid Lagoon"
	discovery_radius = 360.0
	discovery_sound = "lala"


## Terrain height for the atoll (also used by the terrain builder).
static func height(x: float, z: float, c: Vector2, chan_angle: float) -> float:
	var p := Vector2(x, z) - c
	var d := p.length()
	var a := atan2(p.y, p.x)
	var wobble := sin(a * 3.0 + 1.3) * 16.0 + sin(a * 7.0) * 7.0
	var r := RING_RADIUS + wobble
	# Water: shallow inside the ring, deep outside.
	var floor_y := lerpf(-4.5 - 1.5 * sin(a * 5.0 + d * 0.03), -28.0, smoothstep(r - 10.0, r + 70.0, d))
	# The sand ring, with a rocky high side away from the channel.
	var off := absf(d - r)
	var land := smoothstep(RING_WIDTH * 0.5 + 26.0, RING_WIDTH * 0.5 - 14.0, off)
	var ang := absf(wrapf(a - chan_angle, -PI, PI))
	var gap := smoothstep(CHANNEL_WIDTH * 0.5 + 25.0, CHANNEL_WIDTH * 0.5 - 5.0, ang * d)
	land *= 1.0 - gap
	var crest := smoothstep(RING_WIDTH * 0.5, 0.0, off)
	var high := smoothstep(PI * 0.45, PI, ang)  # far side gets rocky hills
	var ring_h := 3.0 + crest * (5.0 + high * (10.0 + 6.0 * sin(a * 9.0)))
	var h := lerpf(floor_y, ring_h, land)
	# Little island in the middle for the clam.
	var mid := smoothstep(75.0, 42.0, d)
	h = lerpf(h, maxf(h, 3.2 + 4.0 * smoothstep(46.0, 0.0, d)), mid)
	return h


static func color(_x: float, _z: float, h: float, slope: float) -> Color:
	if h > 11.0 or slope > 0.45:
		return Color("9a8f8a")
	if h > 7.5:
		return Color("8fdc5c")
	if h < 0.0:
		return Color("f7e7b0")  # pale lagoon floor (reads as turquoise)
	return Color("f4dc8f")


func ground_at(local: Vector2) -> float:
	return height(centre.x + local.x, centre.y + local.y, centre, channel_angle)


func build() -> void:
	var watcher := MermaidWatcher.new()
	watcher.wave_radius = 240.0
	add_child(watcher)
	_build_arch(watcher)
	_build_clam()
	_build_coral()
	_build_decor()
	var scene: PackedScene = load("res://scenes/characters/mermaid.tscn")
	# Inner beaches round the lagoon, looking in at the clam.
	var n := 7
	for k in n:
		var a := channel_angle + PI * 0.35 + (TAU - PI * 0.7) * k / (n - 1)
		var spot := _inner_beach(a)
		var m := _add_mermaid(scene, spot, Vector2(-spot.x, -spot.z), k, watcher)
		m.rotation.y += randf_range(-0.3, 0.3)
		m.set_meta("home", m.rotation.y)
	# Round the clam on the middle island.
	for k in 3:
		var a := channel_angle + PI + (k - 1) * 0.9
		var lp := Vector2(cos(a), sin(a)) * 40.0
		_add_mermaid(scene, Vector3(lp.x, ground_at(lp), lp.y), lp, k + 7, watcher)
	_swimmers = SeaLeapers.new()
	_swimmers.setup("mermaid", RING_RADIUS * 0.55, 5, 77)
	add_child(_swimmers)
	var pod := SeaLeapers.new()
	pod.setup("dolphin", RING_RADIUS + 140.0, 4, 78)
	add_child(pod)


func _add_mermaid(scene: PackedScene, spot: Vector3, look: Vector2, k: int, watcher: MermaidWatcher) -> Mermaid:
	var m: Mermaid = scene.instantiate()
	m.tail_color = Color(TAILS[k % TAILS.size()])
	m.scale = Vector3.ONE * MERMAID_SCALE
	m.position = spot + Vector3(0, -0.4, 0)
	m.rotation.y = atan2(look.x, look.y)
	add_child(m)
	watcher.add(m)
	_sitters.append(m)
	return m


## A point on the inner sand, just above the lagoon's edge, in direction a.
func _inner_beach(a: float) -> Vector3:
	var dir := Vector2(cos(a), sin(a))
	var r := RING_RADIUS + 20.0
	while r > 60.0:
		var h := ground_at(dir * r)
		if h < 3.4:
			var back := dir * (r + 8.0)
			return Vector3(back.x, ground_at(back), back.y)
		r -= 3.0
	var p := dir * RING_RADIUS
	return Vector3(p.x, ground_at(p), p.y)


## A rock arch (half a torus above the water) over the channel, with a
## mermaid sitting on top and stars leading through it.
func _build_arch(watcher: MermaidWatcher) -> void:
	var dir := Vector2(cos(channel_angle), sin(channel_angle))
	var at := dir * (RING_RADIUS + 10.0)
	var torus := TorusMesh.new()
	torus.inner_radius = ARCH_INNER
	torus.outer_radius = ARCH_INNER + ARCH_THICK
	torus.rings = 48
	torus.ring_segments = 14
	var arch := Node3D.new()
	arch.name = "Arch"
	arch.position = Vector3(at.x, -ARCH_SINK, at.y)
	# Torus lies in XZ; stand it up and face its hole along the channel.
	arch.basis = Basis(Vector3.UP, -channel_angle + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(arch)
	var rock := _rocky(torus)
	var mi := MeshInstance3D.new()
	mi.mesh = rock
	arch.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(rock.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	arch.add_child(body)
	# Boulders and greenery on the arch so it reads as rock, not a ring.
	var env := "res://assets/environment/"
	var top := ARCH_INNER + ARCH_THICK - ARCH_SINK
	var side := Vector2(-dir.y, dir.x)
	for k in 5:
		var u := -0.8 + k * 0.4
		var ang := u * 1.1
		var r := ARCH_INNER + ARCH_THICK * 0.8
		var lp := at + side * sin(ang) * r
		AssetLib.place(self, env + ("rocks.glb" if k % 2 == 0 else "rock.glb"), Vector3(lp.x, cos(ang) * r - ARCH_SINK - 2.0, lp.y), 26.0, k * 70.0)
	# A mermaid sits on the very top, looking out to sea.
	var scene: PackedScene = load("res://scenes/characters/mermaid.tscn")
	_add_mermaid(scene, Vector3(at.x, top - 0.3, at.y), dir, 10, watcher)
	# Stars from the open sea, through the arch, into the lagoon.
	var curve := Curve3D.new()
	for k in 6:
		var p := centre + dir * (RING_RADIUS + 260.0 - k * 80.0)
		curve.add_point(Vector3(p.x, 15.0, p.y))
	var trail := StarTrail.new()
	trail.curve = curve
	trail.star_count = 7
	get_parent().get_node("Stars").add_child.call_deferred(trail)


## The torus made lumpy like weathered rock, grey-brown with moss on top.
static func _rocky(torus: TorusMesh) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.045
	var a := torus.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moved := PackedVector3Array()
	moved.resize(v.size())
	for i in v.size():
		var bump := noise.get_noise_3dv(v[i]) * 5.5 + noise.get_noise_3dv(v[i] * 3.0) * 1.5
		moved[i] = v[i] + nrm[i] * bump
	for i in idx:
		var p := moved[i]
		# Stood up, the torus's -Z side is the top of the arch.
		var top := clampf(-nrm[i].z, 0.0, 1.0)
		var shade := 0.85 + noise.get_noise_3dv(p * 2.0) * 0.25
		var col := Color("a39388") * shade
		if top > 0.55 and -p.z > 0.0:
			col = col.lerp(Color("7cc95a"), smoothstep(0.55, 0.85, top))
		st.set_color(col)
		st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	return mesh


## A giant open clam on the middle island with a glowing pearl.
func _build_clam() -> void:
	var g := ground_at(Vector2.ZERO)
	var clam := Node3D.new()
	clam.position = Vector3(0, g - 0.5, 0)
	clam.rotation.y = -channel_angle - PI * 0.5  # opens towards the channel
	clam.scale = Vector3.ONE * 1.6
	add_child(clam)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("ffc4d6")
	shell.roughness = 0.45
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color("fff1f5")
	inside.roughness = 0.3
	var bottom := _shell_half(shell, inside)
	clam.add_child(bottom)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 15.0)  # hinge at the back
	clam.add_child(_lid)
	var lid := _shell_half(shell, inside)
	lid.position = Vector3(0, 0, -15.0)
	lid.rotation.z = PI  # upside down
	_lid.add_child(lid)
	_lid.rotation.x = 1.0
	_pearl = Node3D.new()
	_pearl.position = Vector3(0, 5.5, 0)
	clam.add_child(_pearl)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("fffaf0")
	pm.metallic = 0.3
	pm.roughness = 0.15
	pm.emission_enabled = true
	pm.emission = Color("ffe6f0")
	pm.emission_energy_multiplier = 0.6
	var pearl := MeshInstance3D.new()
	pearl.mesh = BuildKit.sphere(5.5, 24)
	pearl.material_override = pm
	_pearl.add_child(pearl)
	BuildKit.collider(self, BuildKit.cyl_shape(27.0, 22.0), Vector3(0, g + 10.0, 0))


## One scalloped half shell: a flattened hemisphere plus raised ribs.
func _shell_half(shell: Material, inside: Material) -> Node3D:
	var half := Node3D.new()
	var dome := SphereMesh.new()
	dome.radius = 15.0
	dome.height = 15.0
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 8
	var outer := MeshInstance3D.new()
	outer.mesh = dome
	outer.material_override = shell
	outer.scale = Vector3(1.0, -0.38, 1.0)  # bowl, opening upwards
	half.add_child(outer)
	var lining := MeshInstance3D.new()
	lining.mesh = BuildKit.cyl(14.4, 0.4, -1, 28)
	lining.material_override = inside
	lining.position.y = 0.1
	half.add_child(lining)
	for k in 9:
		var a := PI * 0.1 + PI * 0.8 * k / 8.0
		var rib := MeshInstance3D.new()
		rib.mesh = BuildKit.cyl(0.9, 15.5, 0.4, 6)
		rib.material_override = shell
		rib.position = Vector3(cos(a) * 7.0, -2.6, sin(a) * 7.0 - 0.0)
		rib.rotation = Vector3(0, -a, PI * 0.5 - 0.35)
		rib.rotate_object_local(Vector3.FORWARD, 0.0)
		half.add_child(rib)
	return half


## Coral clusters on the lagoon floor, merged into one vertex-coloured mesh.
func _build_coral() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(70.0, RING_RADIUS - 40.0)
		var lp := Vector2(cos(a), sin(a)) * r
		var g := ground_at(lp)
		if g > -2.5 or g < -7.0:
			continue
		placed += 1
		var col := Color(CORAL[rng.randi() % CORAL.size()])
		for j in rng.randi_range(3, 6):
			var off := Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
			var base := Vector3(lp.x, g, lp.y) + off
			var tall := rng.randf_range(2.0, 4.0)
			if rng.randf() < 0.5:
				# Branchy finger coral.
				_append(st, BuildKit.cyl(0.7, tall, 0.35, 6), Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))), base + Vector3(0, tall * 0.5, 0)), col)
			else:
				# Round brain coral.
				_append(st, BuildKit.sphere(rng.randf_range(1.2, 2.4), 8), Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), base + Vector3(0, 0.6, 0)), col.lightened(0.15))
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.8
	mat.emission_enabled = true  # a soft glow so it reads through the water
	mat.emission = Color(0.25, 0.12, 0.15)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1500.0
	add_child(mi)


static func _append(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(col)
		st.add_vertex(xf * v[i])


## Palms on the sandy ring, rocks on the high side, starfish on the sand.
func _build_decor() -> void:
	var env := "res://assets/environment/"
	var hf := height.bind(centre, channel_angle)
	IslandDecor.scatter(self, env + "palm.glb", 26, centre, RING_RADIUS - 30.0, RING_RADIUS + 25.0, hf, 4.5, 6.5, 4.5, 9.0, 91)
	for k in 8:
		var a := channel_angle + PI + (k - 3.5) * 0.28
		var lp := Vector2(cos(a), sin(a)) * (RING_RADIUS + randf_range(-10.0, 10.0))
		AssetLib.place(self, env + ("rocks.glb" if k % 2 == 0 else "rock.glb"), Vector3(lp.x, ground_at(lp) - 2.0, lp.y), randf_range(55.0, 95.0), randf() * 360.0)
	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color("ff9f68")
	for k in 12:
		var a := channel_angle + 0.6 + k * 0.45
		var spot := _inner_beach(a)
		var fish := Node3D.new()
		fish.position = spot + Vector3(0, 0.15, 0) + Vector3(cos(a), 0, sin(a)) * 10.0
		fish.position.y = ground_at(Vector2(fish.position.x, fish.position.z)) + 0.15
		fish.rotation.y = randf() * TAU
		add_child(fish)
		for arm in 5:
			var b := MeshInstance3D.new()
			b.mesh = BuildKit.box(Vector3(0.9, 0.3, 2.6))
			b.material_override = star_mat
			b.rotation.y = arm * TAU / 5.0
			b.position = Vector3(sin(arm * TAU / 5.0), 0, cos(arm * TAU / 5.0)) * 1.1
			fish.add_child(b)


func _process(delta: float) -> void:
	_t += delta
	if _pearl:
		_pearl.position.y = 5.5 + sin(_t * 1.4) * 0.6
		_pearl.rotation.y += delta * 0.4
	if _lid:
		_lid.rotation.x = 1.0 + 0.08 * sin(_t * 0.9)


func react() -> void:
	_swimmers.leap_all()
	for m in _sitters:
		m.set_waving(true)
	var sparkle := PickupBurst.new(80, 22.0, [Color("ffffff"), Color("ffe6f0"), Color("bff3ff"), Color("ff7eb9")])
	_pearl.add_child(sparkle)
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", 1.35, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_lid, "rotation:x", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
