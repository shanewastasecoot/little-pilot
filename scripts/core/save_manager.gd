extends Node
## Saves and loads player progress (autoload: SaveManager).
## Uses ConfigFile at user://save.cfg. A missing, corrupt or half-written
## file never crashes the game: bad values fall back to defaults.

signal loaded

const DEFAULT_PATH := "user://save.cfg"
const SAVE_DELAY := 1.0  # seconds; batches rapid changes into one write

var path: String = DEFAULT_PATH
var selected_aircraft: String = AircraftCatalog.DEFAULT_ID
var lifetime_stars: int = 0

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
	loaded.emit()


## Save soon. Call freely; writes are batched.
func request_save() -> void:
	_save_timer.start()


func save_now() -> void:
	_save_timer.stop()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("player", "selected_aircraft", selected_aircraft)
	cfg.set_value("progress", "lifetime_stars", lifetime_stars)
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


func _reset_to_defaults() -> void:
	selected_aircraft = AircraftCatalog.DEFAULT_ID
	lifetime_stars = 0
