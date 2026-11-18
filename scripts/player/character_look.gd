class_name CharacterLook
extends RefCounted
## Shared look for the player character: the material every part wears and
## the outfit props (from assets/characters/props/props.glb).

static var _materials: Dictionary = {}


## The material for a part painted with `tex` (cached per texture).
static func material(tex: Texture2D) -> Material:
	if _materials.has(tex):
		return _materials[tex]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	_materials[tex] = m
	return m


## A new copy of the named prop, or null if there isn't one yet.
static func prop(_name: String) -> Node3D:
	return null
