extends Node
## Saves and loads player progress (autoload: SaveManager).
## Uses ConfigFile at user://save.cfg. A missing, corrupt or half-written
## file never crashes the game: bad values fall back to defaults.

signal loaded
signal settings_changed

const DEFAULT_PATH := "user://save.cfg"
const SAVE_DELAY := 1.0  # seconds; batches rapid changes into one write

var path: String = DEFAULT_PATH
var selected_aircraft: String = AircraftCatalog.DEFAULT_ID
var lifetime_stars: int = 0
## Paint index per aircraft id.
var paints: Dictionary = {}
# Parent settings (0..1 volumes)
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var battery_saver: bool = false

var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	load_game()


func _notification(what: int) -> void:
	# Flush pending changes on quit (including Steam's "Exit game").
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _save_timer and not _save_timer.is_stopped():
			save_now()


## Switch to another save file (used by tests) and load it.
func use_path(new_path: String) -> void:
	path = new_path
	load_game()


func load_game() -> void:
	_reset_to_defaults()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == ERR_FILE_NOT_FOUND:
		loaded.emit()
		return
	if err != OK:
		push_warning("Save file %s unreadable (error %d); using defaults." % [path, err])
		loaded.emit()
		return
	var plane = cfg.get_value("player", "selected_aircraft", selected_aircraft)
	if plane is String and AircraftCatalog.has(plane):
		selected_aircraft = plane
	var stars = cfg.get_value("progress", "lifetime_stars", 0)
	if stars is int and stars >= 0:
		lifetime_stars = stars
	var saved_paints = cfg.get_value("player", "paints", {})
	if saved_paints is Dictionary:
		for id in saved_paints:
			var idx = saved_paints[id]
			if id is String and AircraftCatalog.has(id) and idx is int and idx >= 0 and idx < Paint.COLORS.size():
				paints[id] = idx
	music_volume = _volume(cfg.get_value("settings", "music_volume", music_volume), music_volume)
	sfx_volume = _volume(cfg.get_value("settings", "sfx_volume", sfx_volume), sfx_volume)
	var saver = cfg.get_value("settings", "battery_saver", battery_saver)
	if saver is bool:
		battery_saver = saver
	loaded.emit()
	settings_changed.emit()


func _volume(value, fallback: float) -> float:
	return clampf(float(value), 0.0, 1.0) if (value is float or value is int) else fallback


## Save soon. Call freely; writes are batched.
func request_save() -> void:
	_save_timer.start()


func save_now() -> void:
	_save_timer.stop()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("player", "selected_aircraft", selected_aircraft)
	cfg.set_value("player", "paints", paints)
	cfg.set_value("progress", "lifetime_stars", lifetime_stars)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "battery_saver", battery_saver)
	# Write to a temp file, then swap it in, so a crash mid-write
	# can't leave a broken save behind.
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("Could not write save file %s" % tmp)
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func set_selected_aircraft(id: String) -> void:
	if AircraftCatalog.has(id) and id != selected_aircraft:
		selected_aircraft = id
		request_save()


func add_lifetime_star() -> void:
	lifetime_stars += 1
	request_save()


func get_paint(id: String, fallback: int) -> int:
	return paints.get(id, fallback)


func set_paint(id: String, idx: int) -> void:
	paints[id] = posmod(idx, Paint.COLORS.size())
	request_save()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	settings_changed.emit()
	request_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	settings_changed.emit()
	request_save()


func set_battery_saver(on: bool) -> void:
	battery_saver = on
	settings_changed.emit()
	request_save()


func _reset_to_defaults() -> void:
	selected_aircraft = AircraftCatalog.DEFAULT_ID
	lifetime_stars = 0
	paints = {}
	music_volume = 0.7
	sfx_volume = 1.0
	battery_saver = false
