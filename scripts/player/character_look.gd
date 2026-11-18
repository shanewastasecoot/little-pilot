class_name CharacterLook
extends RefCounted
## Shared look for the player character: the material every part wears and
## the outfit props (assets/characters/props/props.glb, built in Blender by
## tools/blender/build_props.py: one smooth merged mesh each, coloured with
## vertex colours, modelled in character space).

const PROPS := "res://assets/characters/props/props.glb"
static var _materials: Dictionary = {}
static var _prop_meshes: Dictionary = {}


## The material for a part painted with `tex` (cached per texture); null
## texture = use the mesh's vertex colours (props).
static func material(tex: Texture2D) -> Material:
	var key: Variant = tex if tex else "vertex"
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	if tex:
		m.albedo_texture = tex
	else:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	m.roughness = 0.9
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
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, material(null))
	return mi


static func prop_names() -> Array:
	prop("")
	return _prop_meshes.keys()
