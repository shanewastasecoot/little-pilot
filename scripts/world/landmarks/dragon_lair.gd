class_name DragonLair
extends Landmark
## The dragon's cave at the foot of Dragon Peak: a hollow, lumpy rock dome
## (outside and inside surfaces, both solid) with a big arched mouth facing
## the valley, a hoard of gold glowing inside and smoke drifting out while
## the dragon sleeps. The Dragon lives here (see dragon.gd); its `mouth()` and
## `nest()` points are where it flies out from and sleeps.

const RADIUS := 80.0     # dome footprint (matches IslandShape.LAIR_RADIUS)
const HEIGHT := 62.0
const WALL := 11.0
const MOUTH_HALF := 0.44     # mouth half-width (radians of azimuth)
const MOUTH_TOP := 0.78      # mouth height (radians of elevation)

var _smoke: CPUParticles3D


func _init() -> void:
	landmark_name = "Dragon's Cave"
	discovery_radius = 230.0
	discovery_sound = "roar"


func build() -> void:
	var rock := _dome()
	var mi := MeshInstance3D.new()
	mi.mesh = rock
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(rock.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_build_arch(body)
	_build_hoard()
	# Warm glow from the hoard (one light, short range).
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb347")
	glow.light_energy = 2.5
	glow.omni_range = 70.0
	glow.position = nest() + Vector3(0, 8, 0)
	add_child(glow)
	# Rocks round the entrance.
	var env := "res://assets/environment/"
	for k in 7:
		var a := (k - 3) * 0.28
		var r := RADIUS + 14.0 + (k % 2) * 12.0
		var p := Vector3(sin(a) * r, -2.0, cos(a) * r)
		if absf(a) < MOUTH_HALF * 1.1:
			p.x += signf(a + 0.001) * 26.0  # keep the doorway clear
		AssetLib.place(self, env + ("rocks.glb" if k % 2 == 0 else "rock.glb"), p, randf_range(30.0, 50.0), k * 53.0)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 24
	_smoke.lifetime = 7.0
	_smoke.position = mouth() + Vector3(0, 22, -6)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(14, 4, 4)
	_smoke.direction = Vector3(0, 1, 0.4)
	_smoke.spread = 20.0
	_smoke.gravity = Vector3(0, 1.5, 0)
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 4.0
	_smoke.scale_amount_min = 6.0
	_smoke.scale_amount_max = 11.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1))
	_smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.42, 0.42, 0.55))
	grad.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	_smoke.color_ramp = grad
	_smoke.mesh = _puff_mesh()
	add_child(_smoke)


## Where the dragon leaves the cave (local space, centre of the doorway).
func mouth() -> Vector3:
	return Vector3(0, 18, RADIUS * 0.95)


## Where the dragon sleeps, deep inside.
func nest() -> Vector3:
	return Vector3(0, 4, -RADIUS * 0.25)


## Smoke drifts out of the mouth while the dragon is home.
func set_sleeping(on: bool) -> void:
	if _smoke:
		_smoke.emitting = on


func react() -> void:
	var puff := PickupBurst.new(40, 14.0, [Color("ff7b2e"), Color("ffd23f"), Color("666666")])
	puff.position = mouth() + Vector3(0, 10, 0)
	add_child(puff)


## Outer and inner rock surfaces of a squashed hemisphere, with the mouth
## cut out of the front (+Z) and the two surfaces joined round its edge.
func _dome() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.03
	var az_n := 72
	var el_n := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := []
	var inner := []
	for j in el_n + 1:
		var e := (PI * 0.5) * j / el_n
		var orow := []
		var irow := []
		for i in az_n + 1:
			var a := TAU * i / az_n
			var dir := Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))
			var base := Vector3(dir.x * RADIUS, dir.y * HEIGHT, dir.z * RADIUS)
			if j == 0:
				base.y = -6.0  # sink the rim into the ground
			var bump := noise.get_noise_3dv(base) * 9.0 + noise.get_noise_3dv(base * 3.0) * 3.0
			orow.append(base + dir * bump)
			var ib := Vector3(dir.x * (RADIUS - WALL), dir.y * (HEIGHT - WALL), dir.z * (RADIUS - WALL))
			if j == 0:
				ib.y = -6.0
			irow.append(ib + dir * bump * 0.5)
		outer.append(orow)
		inner.append(irow)
	for j in el_n:
		for i in az_n:
			var a0 := TAU * (i + 0.5) / az_n
			var e0 := (PI * 0.5) * (j + 0.5) / el_n
			if _in_mouth(a0, e0):
				# Seal the wall where the mouth's edge cuts it.
				if not _in_mouth(TAU * (i - 0.5) / az_n, e0):
					_quad(st, outer[j][i], outer[j + 1][i], inner[j + 1][i], inner[j][i], _rock(outer[j][i], 0.8))
				if not _in_mouth(TAU * (i + 1.5) / az_n, e0):
					_quad(st, inner[j][i + 1], inner[j + 1][i + 1], outer[j + 1][i + 1], outer[j][i + 1], _rock(outer[j][i + 1], 0.8))
				if not _in_mouth(a0, (PI * 0.5) * (j + 1.5) / el_n):
					_quad(st, outer[j + 1][i], outer[j + 1][i + 1], inner[j + 1][i + 1], inner[j + 1][i], _rock(outer[j + 1][i], 0.8))
				continue
			# Outside faces outward; inside faces in, and is darker.
			_quad(st, outer[j][i], outer[j][i + 1], outer[j + 1][i + 1], outer[j + 1][i], _rock(outer[j][i], 1.0, float(j) / el_n))
			_quad(st, inner[j][i + 1], inner[j][i], inner[j + 1][i], inner[j + 1][i + 1], _rock(inner[j][i], 0.35))
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # wall edges round the mouth
	mesh.surface_set_material(0, mat)
	return mesh


func _in_mouth(a: float, e: float) -> bool:
	# Arch-shaped: full width at the bottom, rounding off toward the top.
	var w := absf(wrapf(a, -PI, PI)) / MOUTH_HALF
	return e < MOUTH_TOP * sqrt(maxf(0.0, 1.0 - w * w))


func _rock(p: Vector3, shade: float, height := 0.0) -> Color:
	var n := sin(p.x * 0.21) * sin(p.z * 0.17) * 0.08 + sin(p.y * 0.3) * 0.05
	var col := Color("7a6f6a").lerp(Color("5a524f"), 0.5 + n * 3.0) * (shade + n)
	# A little moss on top, scorch marks low down near the mouth.
	if height > 0.8:
		col = col.lerp(Color("6f9a4a"), (height - 0.8) * 2.0)
	col.a = 1.0
	return col


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	for p in [a, c, b, a, d, c]:
		st.add_vertex(p)


## A rugged rock arch framing the doorway.
func _build_arch(body: StaticBody3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 33.0
	torus.outer_radius = 47.0
	torus.rings = 40
	torus.ring_segments = 12
	var rock := MermaidLagoon._rocky(torus)
	var mi := MeshInstance3D.new()
	mi.mesh = rock
	var bare := StandardMaterial3D.new()  # no moss on the dragon's doorstep
	bare.albedo_color = Color("6e6460")
	bare.roughness = 0.95
	mi.material_override = bare
	# Stand it up across the doorway, half buried.
	mi.basis = Basis(Vector3.RIGHT, PI * 0.5)
	mi.position = Vector3(0, -4.0, RADIUS * 0.9)
	add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(rock.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = mi.transform
	body.add_child(cs)


## A heap of gold coins and a few gems where the dragon sleeps.
func _build_hoard() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var gold := SphereMesh.new()
	gold.radial_segments = 8
	gold.rings = 4
	var gem := PrismMesh.new()
	var c := nest()
	for k in 70:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 24.0
		var h := (1.0 - r / 24.0) * 7.0
		var s := rng.randf_range(2.5, 5.0)
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.45, s)), c + Vector3(cos(a) * r, h - 3.0, sin(a) * r))
		MermaidLagoon._append(st, gold, xf, Color("ffcc33") * rng.randf_range(0.85, 1.1))
	for k in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, 18.0)
		var xf := Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 2.2), c + Vector3(cos(a) * r, 4.0, sin(a) * r))
		MermaidLagoon._append(st, gem, xf, [Color("ff4d6d"), Color("4dd2ff"), Color("7dff6b")][k % 3])
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.metallic = 0.7
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color("664400")
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


static func _puff_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PickupBurst._soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_keep_scale = true
	quad.material = mat
	return quad
