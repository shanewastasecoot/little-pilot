class_name StarMesh
extends RefCounted
## Builds a chunky, puffy 5-point star mesh in code (cached), so the star needs
## no imported model. Faces +Z/-Z; the star stands upright.

static var _cache: ArrayMesh


static func get_mesh() -> ArrayMesh:
	if _cache == null:
		_cache = build(1.6, 0.75, 0.55)
	return _cache


static func build(outer: float, inner: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector2] = []
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := outer if i % 2 == 0 else inner
		rim.append(Vector2(cos(a), sin(a)) * r)
	var front := Vector3(0, 0, depth)   # puffy centre bulges out
	var back := Vector3(0, 0, -depth)
	for i in 10:
		var a := Vector3(rim[i].x, rim[i].y, 0)
		var b := Vector3(rim[(i + 1) % 10].x, rim[(i + 1) % 10].y, 0)
		_tri(st, front, a, b)
		_tri(st, back, b, a)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot uses clockwise winding for front faces.
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
