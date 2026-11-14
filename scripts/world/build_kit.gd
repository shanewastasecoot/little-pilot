class_name BuildKit
extends RefCounted
## Helpers for building low-poly props from Godot primitives in code.
## Materials are cached per colour so props share them (fewer state changes).

static var _mats: Dictionary = {}


static func mat(hex: String, emissive := false) -> StandardMaterial3D:
	var key := hex + ("e" if emissive else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.8
		if emissive:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = 1.5
		_mats[key] = m
	return _mats[key]


static func add(parent: Node3D, mesh: Mesh, hex: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(hex)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cyl(radius: float, height: float, top_radius := -1.0, segments := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func sphere(radius: float, segments := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 3)
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


## Static collider (world layer) with one shape at a local position.
static func collider(parent: Node3D, shape: Shape3D, pos := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.position = pos
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


static func cyl_shape(radius: float, height: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s


static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


## Soft keep-away zone around a tall object.
static func push_volume(parent: Node3D, radius: float, height: float, pos := Vector3.ZERO) -> PushVolume:
	var pv := PushVolume.new()
	pv.radius = radius
	pv.height = height
	pv.position = pos
	parent.add_child(pv)
	return pv
