extends Node
## Graphics G4, close-up terrain detail:
##   texture  assets/terrain/detail.png loads, has mipmaps and tiles without
##            a seam (its wrap-around edge is no harsher than inside it)
##   terrain  every terrain built uses the one shared terrain shader with the
##            detail texture, and keeps it after the ground is shaded (G3)
##   runway   the runway uses the asphalt shader (grain, tyre marks)
##   default  both shaders' default strength is the picked look
## Exit code 0 = pass, 1 = fail.

const PICKED_STRENGTH := 1.0  ## the G4 pick (shaders' default `strength`)
var _fails := 0


func _ready() -> void:
	_texture_checks()
	_terrain_checks()
	_runway_checks()
	_default_checks()
	print("\nTERRAIN DETAIL TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _texture_checks() -> void:
	var tex := load(TerrainBuilder.DETAIL) as Texture2D
	_check("the detail texture loads", tex != null and tex.get_width() == 256 and tex.get_height() == 256)
	var import := ConfigFile.new()
	import.load(TerrainBuilder.DETAIL + ".import")
	_check("it has mipmaps (no shimmer far away)", import.get_value("params", "mipmaps/generate", false) == true)
	var img := Image.load_from_file(ProjectSettings.globalize_path(TerrainBuilder.DETAIL))
	var seam := 0.0
	var inside := 0.0
	var n := img.get_width()
	for y in n:
		seam += _diff(img.get_pixel(n - 1, y), img.get_pixel(0, y))
		inside += _diff(img.get_pixel(n / 2 - 1, y), img.get_pixel(n / 2, y))
	for x in n:
		seam += _diff(img.get_pixel(x, n - 1), img.get_pixel(x, 0))
		inside += _diff(img.get_pixel(x, n / 2 - 1), img.get_pixel(x, n / 2))
	_check("it tiles without a seam (edge %.1f vs inside %.1f)" % [seam, inside], seam <= inside * 1.5 + 1.0)


func _terrain_checks() -> void:
	var parent := Node3D.new()
	add_child(parent)
	var hill := func(x: float, z: float) -> float: return 20.0 - Vector2(x, z).length() * 0.2
	var green := func(_x: float, _z: float, _h: float, _s: float) -> Color: return Color(0.4, 0.7, 0.3)
	TerrainBuilder.build(parent, hill, green, Vector2.ZERO, 200.0, 20, "A")
	TerrainBuilder.build(parent, hill, green, Vector2(300, 0), 200.0, 20, "B")
	var mats := []
	for body in parent.get_children():
		mats.append((body.get_child(0) as MeshInstance3D).mesh.surface_get_material(0))
	var sm := mats[0] as ShaderMaterial
	_check("the terrain uses the terrain shader", sm != null and sm.shader.resource_path == TerrainBuilder.SHADER)
	_check("with the detail texture", sm != null and sm.get_shader_parameter("detail_tex") is Texture2D)
	_check("every island shares one material", mats.size() == 2 and mats[0] == mats[1])
	TerrainBuilder.add_spot(Vector2.ZERO, 10.0, TerrainBuilder.GROUND_SHADE)
	TerrainBuilder.shade_ground(get_tree())
	var after := (parent.get_child(0).get_child(0) as MeshInstance3D).mesh.surface_get_material(0)
	_check("it keeps the shader after the ground is shaded", after == TerrainBuilder.material())
	parent.free()


func _runway_checks() -> void:
	var airport := Airport.new()
	airport.build()
	var found := false
	for mi: MeshInstance3D in airport.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == Airport.runway_material():
			found = true
	var sm := Airport.runway_material()
	_check("the runway uses the asphalt shader", found and sm.shader.resource_path == "res://shaders/runway.gdshader")
	_check("with the detail texture and its real size", sm.get_shader_parameter("detail_tex") is Texture2D
		and sm.get_shader_parameter("half_size") == IslandShape.RUNWAY_HALF)
	airport.free()


func _default_checks() -> void:
	var re := RegEx.create_from_string("uniform float strength[^=]*=\\s*([0-9.]+)")
	for path in [TerrainBuilder.SHADER, "res://shaders/runway.gdshader"]:
		var m := re.search(FileAccess.get_file_as_string(path))
		var v := float(m.get_string(1)) if m else -1.0
		_check("%s strength defaults to the pick (%.2f)" % [path.get_file(), v], is_equal_approx(v, PICKED_STRENGTH))


func _diff(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)) * 255.0 / 4.0


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
