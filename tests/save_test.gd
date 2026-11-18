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

	# 2a. Paint per plane
	SaveManager.set_paint("prop", 5)
	SaveManager.set_paint("jet", -1)  # wraps to the last colour
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("prop paint survives reload", SaveManager.get_paint("prop", 0) == 5)
	_check("paint index wraps", SaveManager.get_paint("jet", 1) == Paint.COLORS.size() - 1)
	_write('[player]\npaints={"prop": 99, "rocket": 2, "jet": "red"}\n')
	SaveManager.use_path(PATH)
	_check("bad paints fall back to defaults", SaveManager.get_paint("prop", 0) == 0 and SaveManager.get_paint("jet", 1) == 1 and not SaveManager.paints.has("rocket"))

	# 2b. Settings round trip
	SaveManager.set_music_volume(0.4)
	SaveManager.set_sfx_volume(0.0)
	SaveManager.set_battery_saver(true)
	SaveManager.set_city_arrow(false)
	_check("crashes are on by default", SaveManager.crashes)
	SaveManager.set_crashes(false)
	_check("dragon is on and easy by default", SaveManager.dragon and SaveManager.dragon_level == 0)
	SaveManager.set_dragon(false)
	SaveManager.set_dragon_level(2)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("music volume survives reload", is_equal_approx(SaveManager.music_volume, 0.4))
	_check("muted sounds survive reload", SaveManager.sfx_volume == 0.0)
	_check("battery saver survives reload", SaveManager.battery_saver)
	_check("arrow setting survives reload", not SaveManager.city_arrow)
	_check("crash setting survives reload", not SaveManager.crashes)
	_check("dragon settings survive reload", not SaveManager.dragon and SaveManager.dragon_level == 2)
	SaveManager.set_dragon_level(3)
	_check("dragon level wraps round", SaveManager.dragon_level == 0)
	_check("battery saver caps at 30 FPS", Engine.max_fps == GameSettings.BATTERY_SAVER_FPS)
	_check("muted SFX bus", AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.BUS_SFX)))
	_write('[settings]\nmusic_volume=7.5\nsfx_volume="loud"\nbattery_saver=3\ncrashes="maybe"\ndragon=1\ndragon_level=9\n')
	SaveManager.use_path(PATH)
	_check("bad settings clamp/fall back", SaveManager.music_volume == 1.0 and SaveManager.sfx_volume == 1.0 and not SaveManager.battery_saver and SaveManager.crashes and SaveManager.dragon and SaveManager.dragon_level == 0)
	_check("FPS cap removed when saver off", Engine.max_fps == 0)

	# 2c. Playtime and city time
	SaveManager.use_path(PATH)
	_check("old saves start with no playtime", SaveManager.playtime == 0.0 and SaveManager.city_time == 0.0)
	for i in 3:
		SaveManager.add_lifetime_star()
	for i in 600:
		SaveManager.add_playtime(0.1)  # one minute of flying
	SaveManager.add_playtime(3600.0)  # Deck woke from an hour's sleep
	SaveManager.add_playtime(-5.0)    # clock went backwards
	_check("playtime counts flying only", is_equal_approx(SaveManager.playtime, 60.5))
	_check("city time follows playtime", is_equal_approx(SaveManager.city_time, 60.5))
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("playtime survives reload", is_equal_approx(SaveManager.playtime, 60.5))
	_check("city time survives reload", is_equal_approx(SaveManager.city_time, 60.5))
	var resets := [0]
	SaveManager.city_reset.connect(func(): resets[0] += 1)
	SaveManager.reset_city()
	SaveManager.add_playtime(0.5)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("restart city keeps playtime", is_equal_approx(SaveManager.playtime, 61.0) and is_equal_approx(SaveManager.city_time, 0.5) and resets[0] == 1)
	_check("restart city keeps stars", SaveManager.lifetime_stars == 3)
	_write('[progress]\nplaytime=-40.0\ncity_time="soon"\n')
	SaveManager.use_path(PATH)
	_check("bad playtime falls back to 0", SaveManager.playtime == 0.0 and SaveManager.city_time == 0.0)
	_write('[progress]\nplaytime=100\ncity_time=5000.0\n')
	SaveManager.use_path(PATH)
	_check("city time never exceeds playtime", SaveManager.playtime == 100.0 and SaveManager.city_time == 100.0)
	_write('[progress]\nplaytime=250.0\n')
	SaveManager.use_path(PATH)
	_check("missing city time uses playtime", SaveManager.city_time == 250.0)
	_check("durations read nicely", SaveManager.format_duration(12 * 60 + 5) == "12 m" and SaveManager.format_duration(200 * 60) == "3 h 20 m")
	# Autosave: 30 s of flying queues a save without anyone asking.
	SaveManager.use_path(PATH)
	SaveManager.save_now()
	for i in 61:
		SaveManager.add_playtime(0.5)
	_check("playtime autosaves while flying", not SaveManager._save_timer.is_stopped())
	SaveManager.save_now()

	# 2d. On-foot camera settings
	SaveManager.use_path(PATH)
	_check("camera settings default to normal", SaveManager.look_sensitivity == 1.0 and not SaveManager.invert_y)
	SaveManager.set_look_sensitivity(1.6)
	SaveManager.set_invert_y(true)
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("camera settings survive reload", is_equal_approx(SaveManager.look_sensitivity, 1.6) and SaveManager.invert_y)
	_write('[settings]\nlook_sensitivity=99\ninvert_y="yes"\n')
	SaveManager.use_path(PATH)
	_check("bad camera settings clamp/fall back", SaveManager.look_sensitivity == SaveManager.LOOK_SENSITIVITY_MAX and not SaveManager.invert_y)

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
