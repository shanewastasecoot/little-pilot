extends Node
## Save safety (Phase 10):
##   fixtures   saves in the current format (tests/fixtures/save_v2.cfg) and
##              the one before it (save_v1.cfg, no version-2 keys) load with
##              everything in them; the old one is migrated (meta/version)
##   corrupt    a broken save.cfg with no backup: quietly the defaults
##   backup     each save keeps the last good one as save.cfg.bak; a broken
##              save.cfg loads the backup instead
##   swap fails the new save can't be swapped in: nothing is lost (it loads
##              from the new file left beside it, or the backup)
##   city       the saved city stays the same city: when the city plan's
##              code has changed (CITY_PLAN_VERSION), the kept plan is used,
##              not a newly generated, different one
## Exit code 0 = pass, 1 = fail.

const DIR := "user://test_save_safety/"
const FIX := "res://tests/fixtures/"

var _fails := 0


func _ready() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _run()
	_clean()
	SaveManager.use_path("user://test_save_safety_done.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_safety_done.cfg"))
	print("\nSAVE SAFETY TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	# --- Fixtures -------------------------------------------------------------------
	var p := DIR + "v2.cfg"
	_copy(FIX + "save_v2.cfg", p)
	SaveManager.use_path(p)
	_check("the current-format fixture loads with everything in it", SaveManager.lifetime_stars == 349
			and SaveManager.selected_aircraft == "jet" and SaveManager.char_outfit == 3 and SaveManager.stickers == ["post_office", "hat_shop"]
			and SaveManager.hats_owned == ["beret", "straw"] and SaveManager.hat == "beret" and SaveManager.stars_spent == 7
			and SaveManager.house_wall == 2 and absf(SaveManager.max_volume - 0.8) < 0.01 and SaveManager.city_seed == 990638
			and SaveManager.city_plan_version == CityPlan.VERSION and SaveManager.loaded_version == SaveManager.SAVE_VERSION)
	p = DIR + "v1.cfg"
	_copy(FIX + "save_v1.cfg", p)
	SaveManager.use_path(p)
	var v1_ok := SaveManager.lifetime_stars == 120 and SaveManager.char_outfit == 2 and SaveManager.city_seed == 4242 \
			and SaveManager.loaded_version == 1 and SaveManager.hat == "" and SaveManager.stars_spent == 0 \
			and SaveManager.city_plan_version == CityPlan.VERSION  # (made by the plan code of its day: version 1)
	SaveManager.save_now()
	var cfg := ConfigFile.new()
	cfg.load(p)
	_check("the older (version 1) fixture loads, and is saved again as the current version", v1_ok
			and int(cfg.get_value("meta", "version", 0)) == SaveManager.SAVE_VERSION and int(cfg.get_value("progress", "lifetime_stars", 0)) == 120)
	# --- Corrupt, no backup: defaults ---------------------------------------------------
	p = DIR + "corrupt.cfg"
	_write(p, "[progress\nlifetime_stars = = 12\n\u0000\u0001garbage")
	SaveManager.use_path(p)
	_check("a corrupt save with no backup quietly gives the defaults", SaveManager.lifetime_stars == 0 and SaveManager.char_outfit == 1)
	# --- Backup kept, and used --------------------------------------------------------
	p = DIR + "bak.cfg"
	SaveManager.use_path(p)
	SaveManager.lifetime_stars = 10
	SaveManager.save_now()
	SaveManager.lifetime_stars = 20
	SaveManager.save_now()
	var bak := ConfigFile.new()
	var bak_ok := bak.load(p + ".bak") == OK and int(bak.get_value("progress", "lifetime_stars", 0)) == 10
	_write(p, "this is not a save file [[[")
	SaveManager.use_path(p)
	_check("each save keeps the last good one as .bak; a broken save.cfg loads the backup", bak_ok and SaveManager.lifetime_stars == 10)
	# --- The swap fails: nothing lost ---------------------------------------------------
	p = DIR + "swap.cfg"
	SaveManager.use_path(p)
	SaveManager.lifetime_stars = 30
	SaveManager.save_now()
	# Make the final swap impossible: save.cfg becomes a folder.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(p))
	SaveManager.lifetime_stars = 31
	SaveManager.save_now()
	SaveManager.use_path(p)
	_check("when the new save can't be swapped in, nothing is lost (the newest save loads)", SaveManager.lifetime_stars == 31)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	# --- The city stays the same city ---------------------------------------------------
	p = DIR + "city.cfg"
	SaveManager.use_path(p)
	SaveManager.city_seed = 777
	SaveManager.city_time = 3600.0
	var made := SaveManager.city_plan()
	SaveManager.save_now()
	var snap_ok := FileAccess.file_exists(SaveManager.city_snapshot_path())
	# Pretend the plan code has changed since this city was made: its kept
	# plan (with a marker in it) must be used, not a new one.
	var kept := ConfigFile.new()
	kept.load(SaveManager.city_snapshot_path())
	var events: Array = kept.get_value("plan", "events", [])
	events[0]["text"] = "KEPT CITY"
	kept.set_value("plan", "events", events)
	kept.save(SaveManager.city_snapshot_path())
	var s := ConfigFile.new()
	s.load(p)
	s.set_value("progress", "city_plan_version", CityPlan.VERSION + 1)
	s.save(p)
	SaveManager.use_path(p)
	var after_change := SaveManager.city_plan()
	# Same plan code as the save: the plan is simply made again (identical).
	s.load(p)
	s.set_value("progress", "city_plan_version", CityPlan.VERSION)
	s.save(p)
	SaveManager.use_path(p)
	var same := SaveManager.city_plan()
	_check("a saved city made by older plan code keeps its own plan; with the same code it's made again, identical",
			snap_ok and str(after_change[0].get("text", "")) == "KEPT CITY" and after_change.size() == made.size()
			and str(same) == str(made))
	# A new city (restarted): a new snapshot for the new seed.
	SaveManager.city_seed = 778
	var fresh := SaveManager.city_plan()
	var k2 := ConfigFile.new()
	k2.load(SaveManager.city_snapshot_path())
	_check("restarting the city keeps the new city's plan instead", int(k2.get_value("plan", "seed", 0)) == 778
			and str(fresh) == str(CityPlan.make(778)))


func _copy(from: String, to: String) -> void:
	_write(to, FileAccess.get_file_as_string(from))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	var da := DirAccess.open(abs_dir)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(abs_dir + f)
	for d in da.get_directories():
		DirAccess.remove_absolute(abs_dir + d)
	DirAccess.remove_absolute(abs_dir)


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
