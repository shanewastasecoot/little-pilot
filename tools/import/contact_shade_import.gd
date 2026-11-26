@tool
extends EditorScenePostImport
## Graphics G3: bakes soft contact shading into a STATIC_WORLD model's
## vertex colours when Godot imports it (scripts/world/contact_shade.gd).
## Set as import_script/path in that model's .glb.import; the result is
## saved with the imported model, so the game loads it at no extra cost.

const Shade := preload("res://scripts/world/contact_shade.gd")
## These sit in water, not on the ground.
const NO_GROUND := ["pirate_ship", "sail_boat", "iceberg"]


func _post_import(scene: Node) -> Object:
	var name := get_source_file().get_file().get_basename()
	var t0 := Time.get_ticks_msec()
	var n := Shade.bake_scene(scene, not name in NO_GROUND)
	print("Contact shading: %s, %d vertices in %d ms" % [name, n, Time.get_ticks_msec() - t0])
	return scene
