extends Node
## SaveManager robustness: round trip, missing file, corrupt file, bad values.
## Run: flatpak run org.godotengine.Godot --headless --path . res://tests/save_test.tscn

const PATH := "user://test_save_roundtrip.cfg"
var _fails := 0


func _ready() -> void:
	# 1. Missing file -> defaults
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	_check("missing file gives default plane", SaveManager.selected_aircraft == AircraftCatalog.DEFAULT_ID)
	_check("missing file gives 0 stars", SaveManager.lifetime_stars == 0)

	# 2. Round trip
	SaveManager.set_selected_aircraft("jet")
	for i in 7:
		SaveManager.add_lifetime_star()
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("plane survives reload", SaveManager.selected_aircraft == "jet")
	_check("stars survive reload", SaveManager.lifetime_stars == 7)

	# 2b. Settings round trip
	SaveManager.set_music_volume(0.4)
	SaveManager.set_sfx_volume(0.0)
	SaveManager.set_battery_saver(true)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("music volume survives reload", is_equal_approx(SaveManager.music_volume, 0.4))
	_check("muted sounds survive reload", SaveManager.sfx_volume == 0.0)
	_check("battery saver survives reload", SaveManager.battery_saver)
	_check("battery saver caps at 30 FPS", Engine.max_fps == GameSettings.BATTERY_SAVER_FPS)
	_check("muted SFX bus", AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.BUS_SFX)))
	_write('[settings]\nmusic_volume=7.5\nsfx_volume="loud"\nbattery_saver=3\n')
	SaveManager.use_path(PATH)
	_check("bad settings clamp/fall back", SaveManager.music_volume == 1.0 and SaveManager.sfx_volume == 1.0 and not SaveManager.battery_saver)
	_check("FPS cap removed when saver off", Engine.max_fps == 0)

	# 3. Corrupt file -> defaults, no crash
	_write("this is { not [ a config ::: file \u0007\u0001")
	SaveManager.use_path(PATH)
	_check("corrupt file gives default plane", SaveManager.selected_aircraft == AircraftCatalog.DEFAULT_ID)
	_check("corrupt file gives 0 stars", SaveManager.lifetime_stars == 0)

	# 4. Valid file, nonsense values -> defaults per field
	_write('[player]\nselected_aircraft="spaceship"\n[progress]\nlifetime_stars=-5\n')
	SaveManager.use_path(PATH)
	_check("unknown plane id falls back", SaveManager.selected_aircraft == AircraftCatalog.DEFAULT_ID)
	_check("negative stars fall back", SaveManager.lifetime_stars == 0)
	_write('[player]\nselected_aircraft=42\n[progress]\nlifetime_stars="lots"\n')
	SaveManager.use_path(PATH)
	_check("wrong types fall back", SaveManager.selected_aircraft == AircraftCatalog.DEFAULT_ID and SaveManager.lifetime_stars == 0)

	# 5. Saving is atomic: no temp file left behind
	SaveManager.save_now()
	_check("no leftover temp file", not FileAccess.file_exists(PATH + ".tmp"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nSAVE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
