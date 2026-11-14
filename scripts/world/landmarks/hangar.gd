class_name Hangar
extends Node3D
## A classic arched aircraft hangar built in code: corrugated barrel roof,
## blue arched façade with a big open door and slid-back door panels, star
## emblem, side windows, blinking roof beacon, concrete apron with a taxi
## line, and two planes parked out front. The door faces +Z.

const WIDTH := 48.0       # x
const LENGTH := 40.0      # z (depth)
const HEIGHT := 21.0      # top of the arch
const WALL := 4.0         # straight wall below the arch
const DOOR_W := 30.0
const DOOR_H := 14.0
const ARCH_SEGMENTS := 18

## Colours
const ROOF_A := Color("e6ebf1")
const ROOF_B := Color("c7d0da")
const ROOF_BAND := Color("4aa8ff")
const WALL_BLUE := Color("3d8fe8")
const TRIM := Color("ffffff")
const INSIDE := Color("39404d")
const DOOR := Color("2b6cc4")

var _beacon: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_build_shell()
	_build_facade(LENGTH * 0.5, true)
	_build_facade(-LENGTH * 0.5, false)
	_build_details()
	_build_apron()
	BuildKit.collider(self, BuildKit.box_shape(Vector3(WIDTH, HEIGHT, LENGTH)), Vector3(0, HEIGHT * 0.5, 0))


func _process(delta: float) -> void:
	_t += delta
	_beacon.visible = fmod(_t, 1.2) < 0.6


# --- Shell ------------------------------------------------------------------

## Point on the hangar cross-section: straight walls, then a half-ellipse.
## u goes 0..1 from the left ground edge over the top to the right.
func _profile(i: int) -> Vector2:
	var a := PI - PI * float(i) / ARCH_SEGMENTS
	return Vector2(cos(a) * WIDTH * 0.5, WALL + sin(a) * (HEIGHT - WALL))


func _build_shell() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := -LENGTH * 0.5
	var z1 := LENGTH * 0.5
	# Side walls (vertical part), blue.
	for side in [-1.0, 1.0]:
		var x: float = side * WIDTH * 0.5
		_quad(st, Vector3(x, 0, z0), Vector3(x, WALL, z0), Vector3(x, WALL, z1), Vector3(x, 0, z1), WALL_BLUE, Vector3(side, 0, 0))
	# Barrel roof: alternating panel shades read as corrugated metal; a blue
	# band runs over the top third.
	for i in ARCH_SEGMENTS:
		var p0 := _profile(i)
		var p1 := _profile(i + 1)
		var mid := (p0 + p1) * 0.5
		var normal := Vector3(mid.x / (WIDTH * 0.5), (mid.y - WALL) / (HEIGHT - WALL), 0).normalized()
		var col := ROOF_A if i % 2 == 0 else ROOF_B
		if i == ARCH_SEGMENTS / 2 - 1 or i == ARCH_SEGMENTS / 2:
			col = ROOF_BAND
		_quad(st, Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p1.x, p1.y, z1), Vector3(p0.x, p0.y, z1), col, normal)
	# Dark interior shell (seen through the open door).
	var inset := 0.4
	for i in ARCH_SEGMENTS:
		var p0 := _profile(i) * Vector2(1, 1) - Vector2(signf(_profile(i).x) * inset, inset)
		var p1 := _profile(i + 1) - Vector2(signf(_profile(i + 1).x) * inset, inset)
		var mid := (p0 + p1) * 0.5
		var normal := -Vector3(mid.x, mid.y - WALL, 0).normalized()
		_quad(st, Vector3(p0.x, p0.y, z1), Vector3(p1.x, p1.y, z1), Vector3(p1.x, p1.y, z0), Vector3(p0.x, p0.y, z0), INSIDE, normal)
	# Inner faces of the low side walls, then the floor.
	for side in [-1.0, 1.0]:
		var xi: float = side * (WIDTH * 0.5 - inset)
		_quad(st, Vector3(xi, 0, z0), Vector3(xi, WALL, z0), Vector3(xi, WALL, z1), Vector3(xi, 0, z1), INSIDE, Vector3(-side, 0, 0))
	_quad(st, Vector3(-WIDTH * 0.5, 0.05, z1), Vector3(WIDTH * 0.5, 0.05, z1), Vector3(WIDTH * 0.5, 0.05, z0), Vector3(-WIDTH * 0.5, 0.05, z0), INSIDE.darkened(0.3), Vector3.UP)
	_add(st)


## Arched end wall. The front one has the door opening cut out.
func _build_facade(z: float, front: bool) -> void:
	var outline := PackedVector2Array()
	for i in ARCH_SEGMENTS + 1:
		outline.append(_profile(i))
	outline.append(Vector2(WIDTH * 0.5, 0))
	if front:
		outline.append_array([Vector2(DOOR_W * 0.5, 0), Vector2(DOOR_W * 0.5, DOOR_H), Vector2(-DOOR_W * 0.5, DOOR_H), Vector2(-DOOR_W * 0.5, 0)])
	outline.append(Vector2(-WIDTH * 0.5, 0))
	outline.reverse()  # wind so the outside faces away from the hangar
	var tris := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0, 0, 1 if front else -1)
	for k in range(0, tris.size(), 3):
		var a := outline[tris[k]]
		var b := outline[tris[k + 1]]
		var c := outline[tris[k + 2]]
		_tri(st, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), WALL_BLUE, n)
		if not front:
			# Dark inner face of the back wall, seen through the door.
			var zi := z + 0.4
			_tri(st, Vector3(a.x, a.y, zi), Vector3(b.x, b.y, zi), Vector3(c.x, c.y, zi), INSIDE.darkened(0.15), -n)
	_add(st)
	if not front:
		return
	# White trim around the door and along the arch edge.
	var d := 0.6
	BuildKit.add(self, BuildKit.box(Vector3(DOOR_W + d * 2, d, d)), "ffffff", Vector3(0, DOOR_H + d * 0.5, z + 0.3))
	for side in [-1.0, 1.0]:
		BuildKit.add(self, BuildKit.box(Vector3(d, DOOR_H, d)), "ffffff", Vector3(side * (DOOR_W * 0.5 + d * 0.5), DOOR_H * 0.5, z + 0.3))
	for i in ARCH_SEGMENTS:
		var p0 := _profile(i)
		var p1 := _profile(i + 1)
		var mid := (p0 + p1) * 0.5
		var seg := BuildKit.add(self, BuildKit.box(Vector3(p0.distance_to(p1) + 0.4, d, d)), "ffffff", Vector3(mid.x, mid.y, z + 0.3))
		seg.rotation.z = (p1 - p0).angle()
	# Sliding door panels pushed back to the sides (just inside the opening).
	for side in [-1.0, 1.0]:
		var panel := Node3D.new()
		panel.position = Vector3(side * (DOOR_W * 0.5 - 3.5), 0, z - 1.0)
		add_child(panel)
		BuildKit.add(panel, BuildKit.box(Vector3(7, DOOR_H - 0.4, 0.4)), DOOR.to_html(false), Vector3(0, (DOOR_H - 0.4) * 0.5, 0))
		for k in 4:
			BuildKit.add(panel, BuildKit.box(Vector3(7.05, 0.25, 0.45)), "ffffff", Vector3(0, 2.5 + k * 3.0, 0))
	# Emblem: yellow star on a red disc above the door.
	var disc := BuildKit.add(self, BuildKit.cyl(3.4, 0.3, -1, 24), "ff5a5f", Vector3(0, DOOR_H + 3.8, z + 0.35), Vector3(90, 0, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var star := MeshInstance3D.new()
	star.mesh = _flat_star(2.6, 1.15)
	star.material_override = BuildKit.mat("ffd23f")
	star.position = Vector3(0, DOOR_H + 3.8, z + 0.55)
	add_child(star)


func _build_details() -> void:
	# Window strip along both sides.
	for side in [-1.0, 1.0]:
		for k in 6:
			var z := -LENGTH * 0.5 + 5.0 + k * 6.0
			BuildKit.add(self, BuildKit.box(Vector3(0.3, 1.6, 3.6)), "a8e2ff", Vector3(side * (WIDTH * 0.5 + 0.1), WALL - 1.4, z))
	# Roof beacon (blinks).
	BuildKit.add(self, BuildKit.cyl(0.25, 2.0), "dddddd", Vector3(0, HEIGHT + 1.0, LENGTH * 0.5 - 4.0))
	_beacon = BuildKit.add(self, BuildKit.sphere(0.7, 8), "ff3b3b", Vector3(0, HEIGHT + 2.2, LENGTH * 0.5 - 4.0))
	_beacon.material_override = BuildKit.mat("ff3b3b", true)


func _build_apron() -> void:
	# Concrete pad in front of the door, and a yellow taxi line leading out.
	var apron_depth := 34.0
	var apron := BuildKit.add(self, BuildKit.box(Vector3(WIDTH + 24, 0.3, apron_depth)), "a8a298", Vector3(0, 0.15, LENGTH * 0.5 + apron_depth * 0.5))
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 8:
		BuildKit.add(self, BuildKit.box(Vector3(0.8, 0.1, 3.0)), "ffd23f", Vector3(0, 0.36, LENGTH * 0.5 + 3.0 + k * 4.5))
	# Planes parked on the apron (toy-sized so they read from the air).
	var biplane: Node3D = load("res://scenes/aircraft/models/prop_plane_model.tscn").instantiate()
	biplane.scale = Vector3.ONE * 2.2
	biplane.position = Vector3(-14, 1.9 * 2.2, LENGTH * 0.5 + 15)
	biplane.rotation_degrees.y = 200
	add_child(biplane)
	var jet: Node3D = load("res://scenes/aircraft/models/jet_model.tscn").instantiate()
	jet.scale = Vector3.ONE * 2.2
	jet.position = Vector3(15, 1.2 * 2.2, LENGTH * 0.5 + 17)
	jet.rotation_degrees.y = 160
	add_child(jet)


# --- Mesh helpers ------------------------------------------------------------

func _flat_star(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := UiIcon.star_points(Vector2.ZERO, outer, inner)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		# y is flipped: UI space points down, 3D points up.
		_tri(st, Vector3.ZERO, Vector3(b.x, -b.y, 0), Vector3(a.x, -a.y, 0), Color.WHITE, Vector3.BACK)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	_tri(st, a, b, c, col, n)
	_tri(st, a, c, d, col, n)


## Adds a triangle facing `n` (winding fixed up automatically).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	var order := [a, b, c] if (b - a).cross(c - a).dot(n) < 0.0 else [a, c, b]
	for v in order:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


func _add(st: SurfaceTool) -> void:
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.6
	m.metallic = 0.1
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
