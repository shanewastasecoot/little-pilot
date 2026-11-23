class_name Livery
extends Node3D
## The plane's livery (Phase 13): its main paint stays as it is (D-pad); on
## top, a trim colour and one decal, painted in the trim colour:
##   none
##   stripe     a cheat line along both sides            (always)
##   checker    a chequered band round the tail          (50 stars)
##   rescue     a broad band round the middle            (100 stars)
##   letters    registration-style letters on both sides (150 stars)
##   star       a gold star on both sides of the tail    (220 stars)
## The basic colours are never locked; decals are earned at star
## milestones (lifetime stars), and once earned they stay. Built from the
## aircraft's `livery_body` box (the fuselage, model space), so any model
## can wear one. A child of AircraftVisuals.

const DECALS := ["none", "stripe", "checker", "rescue", "letters", "star"]
## Lifetime stars that earn each decal.
const NEEDS := {"none": 0, "stripe": 0, "checker": 50, "rescue": 100, "letters": 150, "star": 220}
const LETTERS := "LP-STAR"

var body := AABB(Vector3(-0.6, 0.2, -2.0), Vector3(1.2, 1.0, 4.0))
var _parts: Array[Node3D] = []


static func unlocked(decal: String) -> bool:
	return SaveManager.lifetime_stars >= int(NEEDS.get(decal, 0))


## Show `decal` in `trim`.
func show_livery(decal: String, trim: Color) -> void:
	for p in _parts:
		p.queue_free()
	_parts.clear()
	var c := body.get_center()
	var s := body.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = trim
	mat.roughness = 0.6
	match decal:
		"stripe":
			for side in [-1.0, 1.0]:
				_box(Vector3(0.04, s.y * 0.12, s.z * 0.86), Vector3(side * (s.x * 0.5 + 0.02), c.y, c.z), mat)
		"checker":
			var z := body.end.z - s.z * 0.18
			var n := 8
			for i in n:
				var a := TAU * i / n
				for row in 2:
					var on := (i + row) % 2 == 0
					var m := mat if on else _white()
					var r := Vector3(cos(a) * (s.x * 0.5 + 0.03), c.y + sin(a) * (s.y * 0.5 + 0.03), z + row * s.z * 0.06)
					var b := _box(Vector3(s.x * 0.42, s.y * 0.42 / 1.2, s.z * 0.06), r, m)
					b.rotation.z = a + PI * 0.5
		"rescue":
			for side in [-1.0, 1.0]:
				_box(Vector3(0.04, s.y * 0.9, s.z * 0.16), Vector3(side * (s.x * 0.5 + 0.02), c.y, c.z + s.z * 0.12), mat)
			_box(Vector3(s.x * 0.9, 0.04, s.z * 0.16), Vector3(0, body.end.y + 0.02, c.z + s.z * 0.12), mat)
		"letters":
			for side in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = LETTERS
				l.font_size = 64
				l.pixel_size = s.y * 0.0045
				l.modulate = trim
				l.outline_size = 0
				l.double_sided = false
				l.position = Vector3(side * (s.x * 0.5 + 0.03), c.y + s.y * 0.08, c.z + s.z * 0.22)
				l.rotation.y = side * PI * 0.5
				add_child(l)
				_parts.append(l)
		"star":
			for side in [-1.0, 1.0]:
				var st := MeshInstance3D.new()
				st.mesh = _star_mesh(s.y * 0.28)
				var gold := StandardMaterial3D.new()
				gold.albedo_color = Color("ffd23f")
				gold.emission_enabled = true
				gold.emission = Color("ffb800")
				gold.emission_energy_multiplier = 0.4
				st.material_override = gold
				st.position = Vector3(side * (s.x * 0.5 + 0.03), c.y + s.y * 0.1, body.end.z - s.z * 0.2)
				st.rotation.y = side * PI * 0.5
				add_child(st)
				_parts.append(st)


## (Tests) how many decal pieces are showing.
func pieces() -> int:
	return _parts.size()


func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.append(mi)
	return mi


static var _w: StandardMaterial3D


static func _white() -> StandardMaterial3D:
	if _w == null:
		_w = StandardMaterial3D.new()
		_w.albedo_color = Color.WHITE
		_w.roughness = 0.6
	return _w


## A flat five-pointed star facing +Z (radius r).
static func _star_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := -PI * 0.5 + TAU * i / 10.0
		var a1 := -PI * 0.5 + TAU * (i + 1) / 10.0
		var r0 := r if i % 2 == 0 else r * 0.45
		var r1 := r if (i + 1) % 2 == 0 else r * 0.45
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * r1, -sin(a1) * r1, 0))
		st.add_vertex(Vector3(cos(a0) * r0, -sin(a0) * r0, 0))
	return st.commit()
