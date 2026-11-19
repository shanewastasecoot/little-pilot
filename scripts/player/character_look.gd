class_name CharacterLook
extends RefCounted
## Shared look for the player character: the toon material every part
## wears (shaders/toon.gdshader with a soft outline pass,
## shaders/toon_outline.gdshader) and the outfit props
## (assets/characters/props/props.glb, built in Blender by
## tools/blender/build_props.py: one smooth merged mesh each, coloured with
## vertex colours, modelled in character space).

const PROPS := "res://assets/characters/props/props.glb"
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/toon_outline.gdshader")
const OUTLINE_WIDTH := 0.014
const PROP_OUTLINE_WIDTH := 0.012
static var _materials: Dictionary = {}
static var _prop_meshes: Dictionary = {}


## The toon material for a part painted with `tex` (cached per texture);
## null texture = use the mesh's vertex colours (props). `outline_width`
## is in the mesh's own units (thin parts get a thinner one).
static func material(tex: Texture2D, outline_width := OUTLINE_WIDTH) -> Material:
	var key := [tex if tex else "vertex", outline_width]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("use_texture", tex != null)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	if outline_width > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("use_texture", tex != null)
		if tex:
			o.set_shader_parameter("albedo_tex", tex)
		o.set_shader_parameter("width", outline_width)
		m.next_pass = o
	_materials[key] = m
	return m


## A new copy of the named prop (a MeshInstance3D), or null if unknown.
static func prop(name: String) -> Node3D:
	if _prop_meshes.is_empty():
		var scene: Node3D = (load(PROPS) as PackedScene).instantiate()
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_prop_meshes[String(mi.name)] = mi.mesh
		scene.free()
	if not _prop_meshes.has(name):
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _prop_meshes[name]
	# The smile is a fine line on the face: no outline of its own.
	var w := 0.0 if name == "Face_Smile" else PROP_OUTLINE_WIDTH
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, material(null, w))
	return mi


static func prop_names() -> Array:
	prop("")
	return _prop_meshes.keys()
