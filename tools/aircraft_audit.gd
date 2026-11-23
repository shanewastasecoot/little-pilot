extends Node
## ./dev.sh audit-aircraft (Phase 9): what each aircraft model is made of,
## to see which can move control surfaces, spin wheels, retract gear and so
## on. For every aircraft in AircraftCatalog it prints the model scene's node
## tree (with mesh names, triangle counts and materials), its animations,
## and whether these parts are separate (named) nodes:
##   propeller, wheels, ailerons (L/R), elevator, rudder, retractable gear,
##   a cockpit camera marker, wingtip markers (L/R)
## The report is printed and written to user://aircraft_audit.txt.
## (The standard model contract the parts are checked against is in
## docs/AIRCRAFT_MODELS.md.)

const PARTS := {
	"Propeller": ["prop", "propeller", "spinner", "blade"],
	"Wheels": ["wheel", "tyre", "tire"],
	"Aileron_L": ["aileron_l", "aileron.l", "aileronl", "left_aileron"],
	"Aileron_R": ["aileron_r", "aileron.r", "aileronr", "right_aileron"],
	"Elevator": ["elevator", "stabilizer", "stabiliser"],
	"Rudder": ["rudder"],
	"Gear": ["gear", "landing_gear", "undercarriage", "strut"],
	"CockpitCameraMarker": ["cockpitcameramarker", "cockpit_camera", "pilot_eye"],
	"Wingtip_L": ["wingtip_l", "wingtip.l"],
	"Wingtip_R": ["wingtip_r", "wingtip.r"],
}

var _out := PackedStringArray()


func _ready() -> void:
	for id in AircraftCatalog.ids():
		var stats := AircraftCatalog.get_stats(id)
		_line("=== %s (%s): %s" % [stats.display_name, id, stats.model_scene.resource_path])
		var model: Node3D = stats.model_scene.instantiate()
		add_child(model)
		await get_tree().process_frame
		var tris := [0]
		var names: Array[String] = []
		_walk(model, 0, tris, names)
		names.erase(String(model.name))  # (the model's own name isn't a part)
		_line("  total triangles: %d" % tris[0])
		var anims: Array[String] = []
		for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			for a in ap.get_animation_list():
				anims.append(String(a))
		_line("  animations: %s" % (", ".join(anims) if not anims.is_empty() else "none"))
		_line("  separate parts:")
		for part in PARTS:
			var hits: Array[String] = []
			for n in names:
				for key in PARTS[part]:
					if n.to_lower().contains(key):
						hits.append(n)
						break
			_line("    %-20s %s" % [part, ("yes: " + ", ".join(hits.slice(0, 4))) if not hits.is_empty() else "no"])
		model.queue_free()
		_line("")
	var f := FileAccess.open("user://aircraft_audit.txt", FileAccess.WRITE)
	f.store_string("\n".join(_out))
	print("Written to ", ProjectSettings.globalize_path("user://aircraft_audit.txt"))
	get_tree().quit()


func _walk(n: Node, depth: int, tris: Array, names: Array[String]) -> void:
	var info := ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m := (n as MeshInstance3D).mesh
		var t := 0
		var mats: Array[String] = []
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := (n as MeshInstance3D).get_active_material(s)
			mats.append(mat.resource_name if mat and mat.resource_name != "" else (mat.get_class() if mat else "none"))
		tris[0] += t
		info = "  [%d tris; materials: %s]" % [t, ", ".join(mats)]
	names.append(String(n.name))
	_line("  %s%s (%s)%s" % ["  ".repeat(depth), n.name, n.get_class(), info])
	for c in n.get_children():
		_walk(c, depth + 1, tris, names)


func _line(s: String) -> void:
	_out.append(s)
	print(s)
