extends Node
## Realistic-aircraft touches (Phase 9):
##   camera    the camera button cycles close -> far -> cockpit -> close; the
##             cockpit view sits at the pilot's eyes and looks where the
##             plane looks
##   gauges    the instrument panel shows only in the cockpit view while
##             flying, and reads the plane's speed, height and heading
##   lights    both aircraft have red (left) and green (right) wingtip lights,
##             a white tail light and a beacon that flashes
##   vapour    streams off the wingtips in a hard, fast turn, not when cruising
##   name      the jet is the "Trainer Jet"
## Exit code 0 = pass, 1 = fail.

var _main: Node
var _fails := 0


func _ready() -> void:
	SaveManager.use_path("user://test_aircraft_view.cfg")
	SaveManager.dragon = false
	SaveManager.crashes = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(10)
	_main._enter(_main.State.FLYING)
	var plane: Aircraft = _main.aircraft
	var cam: ChaseCamera = _main.chase_camera
	plane.input.override_enabled = true
	plane.teleport(Vector3(-150, 90, 300), 0.0)
	plane.mode = Aircraft.Mode.FLYING
	await _frames(20)
	# --- Camera cycle ----------------------------------------------------------------
	cam.preset = 0
	var seen: Array[bool] = []
	for i in 3:
		plane.input.camera_pressed.emit()
		await _frames(5)
		seen.append(cam.in_cockpit())
	_check("the camera button cycles close -> far -> cockpit -> close", seen == [false, true, false])
	cam.preset = ChaseCamera.COCKPIT
	await _frames(10)
	var eye := plane.visuals.cockpit_point(plane.stats)
	var at_eye := cam.cam.global_position.distance_to(eye) < 0.6
	var fwd := -cam.cam.global_transform.basis.z
	var plane_fwd := -plane.visuals.global_transform.basis.z.normalized()
	_check("the cockpit view sits at the pilot's eyes, looking where the plane looks", at_eye and fwd.dot(plane_fwd) > 0.9)
	# --- Gauges ----------------------------------------------------------------------
	await _frames(5)
	var g: CockpitGauges = _main.gauges
	var reads := absf(g.speed - plane.speed) < 0.5 and absf(g.heading - plane.heading) < 0.01 and g.altitude > 50.0
	var shown_in_cockpit := g.visible
	cam.preset = 0
	await _frames(3)
	var hidden_outside := not g.visible
	_check("the instruments show only in the cockpit view, reading speed, height and heading", shown_in_cockpit and hidden_outside and reads)
	# --- Lights, vapour, for both aircraft ----------------------------------------------
	for id in ["prop", "jet"]:
		plane.set_stats(AircraftCatalog.get_stats(id))
		await _frames(5)
		var ex: AircraftExtras = plane.visuals.extras
		# (The user asked for the red/green light dots to go: they looked like
		# stray circles on the model. None anywhere on the plane now.)
		var dots := 0
		for mi: MeshInstance3D in plane.visuals.find_children("*", "MeshInstance3D", true, false):
			var m := mi.material_override as StandardMaterial3D
			if mi.mesh is SphereMesh and m and m.emission_enabled and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				dots += 1
		_check("%s: no glowing light dots on the model" % plane.stats.display_name, dots == 0)
		plane.input.override_stick = Vector2.ZERO
		plane.input.override_throttle = 0.0
		await _frames(40)
		var calm := not ex.vapour_on
		plane.input.override_stick = Vector2(1.0, 0.0)
		plane.input.override_throttle = 1.0
		await _frames(90)
		var streaming := ex.vapour_on
		plane.input.override_stick = Vector2.ZERO
		plane.input.override_throttle = 0.0
		await _frames(30)
		_check("%s: wingtip vapour in a hard, fast turn, none when cruising" % plane.stats.display_name, calm and streaming)
	_check("the jet is the Trainer Jet", AircraftCatalog.get_stats("jet").display_name == "Trainer Jet")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_aircraft_view.cfg"))
	print("\nAIRCRAFT VIEW TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
