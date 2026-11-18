extends Node
## Saves and loads player progress (autoload: SaveManager).
## Uses ConfigFile at user://save.cfg. A missing, corrupt or half-written
## file never crashes the game: bad values fall back to defaults.

signal loaded
signal settings_changed
## The parents restarted the city (city_time went back to 0).
signal city_reset

const DEFAULT_PATH := "user://save.cfg"
const SAVE_DELAY := 1.0  # seconds; batches rapid changes into one write
## Playtime is written at least this often (seconds of play) while flying,
## so a flat battery or the Deck sleeping loses at most this much.
const PLAYTIME_SAVE_EVERY := 30.0
## Longest single tick counted as play (seconds). A Deck resumed from sleep
## hands us one huge frame; it mustn't count as hours of flying.
const MAX_PLAY_TICK := 0.5

var path: String = DEFAULT_PATH
var selected_aircraft: String = AircraftCatalog.DEFAULT_ID
var lifetime_stars: int = 0
## Seconds spent actually flying, ever (shown to parents).
var playtime: float = 0.0
## Seconds of flying since the city was last restarted; the city grows from
## this. Never more than `playtime`.
var city_time: float = 0.0
## Seeds the city's growth plan (CityPlan), so each family's city grows a
## little differently but always the same way for them. New on each restart.
var city_seed: int = 0
## Paint index per aircraft id.
var paints: Dictionary = {}
# Parent settings (0..1 volumes)
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var battery_saver: bool = false
## Show the arrow that points to the city before its fireworks.
var city_arrow: bool = true
## The plane can crash (bonk, then back to the runway). Off = the old
## can't-crash mode where it steers itself away from everything.
var crashes: bool = true
## The dragon lives on the island (Dragon Peak) and how tough it is:
## 0 easy, 1 medium, 2 hard.
var dragon: bool = true
var dragon_level: int = 0
## On-foot camera: right-stick speed (0.4 slow .. 2.5 fast) and whether
## pushing the stick up tilts the view down.
## The player's character: body "M"/"F", hair 1..4, outfit 1..4.
var char_body: String = "M"
var char_hair: int = 1
var char_outfit: int = 1
## False until the player has made their character (phase 4 asks then).
var char_made: bool = false
var look_sensitivity: float = 1.0
var invert_y: bool = false
const LOOK_SENSITIVITY_MIN := 0.4
const LOOK_SENSITIVITY_MAX := 2.5
const DRAGON_LEVELS := 3

var _save_timer: Timer
var _unsaved_play := 0.0


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
		if (_save_timer and not _save_timer.is_stopped()) or _unsaved_play > 0.0:
			save_now()


## Switch to another save file (used by tests) and load it.
func use_path(new_path: String) -> void:
	path = new_path
	load_game()


func load_game() -> void:
	_load_file()
	if city_seed <= 0:
		city_seed = _new_seed()  # saved with the next save (playtime autosaves)
	loaded.emit()


func _new_seed() -> int:
	return randi_range(1, 999999)


func _load_file() -> void:
	_reset_to_defaults()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("Save file %s unreadable (error %d); using defaults." % [path, err])
		return
	var plane = cfg.get_value("player", "selected_aircraft", selected_aircraft)
	if plane is String and AircraftCatalog.has(plane):
		selected_aircraft = plane
	var stars = cfg.get_value("progress", "lifetime_stars", 0)
	if stars is int and stars >= 0:
		lifetime_stars = stars
	playtime = _seconds(cfg.get_value("progress", "playtime", 0.0))
	city_time = minf(_seconds(cfg.get_value("progress", "city_time", playtime)), playtime)
	var cs = cfg.get_value("progress", "city_seed", 0)
	if cs is int and cs > 0:
		city_seed = cs
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
	var arrow = cfg.get_value("settings", "city_arrow", city_arrow)
	if arrow is bool:
		city_arrow = arrow
	var crash = cfg.get_value("settings", "crashes", crashes)
	if crash is bool:
		crashes = crash
	var drg = cfg.get_value("settings", "dragon", dragon)
	if drg is bool:
		dragon = drg
	var lvl = cfg.get_value("settings", "dragon_level", dragon_level)
	if lvl is int and lvl >= 0 and lvl < DRAGON_LEVELS:
		dragon_level = lvl
	var cb = cfg.get_value("character", "body", char_body)
	if cb is String and cb in ["M", "F"]:
		char_body = cb
	var ch = cfg.get_value("character", "hair", char_hair)
	if ch is int and ch >= 1 and ch <= 4:
		char_hair = ch
	var co = cfg.get_value("character", "outfit", char_outfit)
	if co is int and co >= 1 and co <= 4:
		char_outfit = co
	var cm = cfg.get_value("character", "made", char_made)
	if cm is bool:
		char_made = cm
	var sens = cfg.get_value("settings", "look_sensitivity", look_sensitivity)
	if sens is float or sens is int:
		look_sensitivity = clampf(float(sens), LOOK_SENSITIVITY_MIN, LOOK_SENSITIVITY_MAX)
	var inv = cfg.get_value("settings", "invert_y", invert_y)
	if inv is bool:
		invert_y = inv
	settings_changed.emit()


## A saved duration: a finite, non-negative number, else 0.
func _seconds(value) -> float:
	if not (value is float or value is int):
		return 0.0
	var v := float(value)
	return v if is_finite(v) and v >= 0.0 else 0.0


func _volume(value, fallback: float) -> float:
	return clampf(float(value), 0.0, 1.0) if (value is float or value is int) else fallback


## Save soon. Call freely; writes are batched.
func request_save() -> void:
	_save_timer.start()


func save_now() -> void:
	_save_timer.stop()
	_unsaved_play = 0.0
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("player", "selected_aircraft", selected_aircraft)
	cfg.set_value("player", "paints", paints)
	cfg.set_value("progress", "lifetime_stars", lifetime_stars)
	cfg.set_value("progress", "playtime", playtime)
	cfg.set_value("progress", "city_time", city_time)
	cfg.set_value("progress", "city_seed", city_seed)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "battery_saver", battery_saver)
	cfg.set_value("settings", "city_arrow", city_arrow)
	cfg.set_value("settings", "crashes", crashes)
	cfg.set_value("settings", "dragon", dragon)
	cfg.set_value("settings", "dragon_level", dragon_level)
	cfg.set_value("character", "body", char_body)
	cfg.set_value("character", "hair", char_hair)
	cfg.set_value("character", "outfit", char_outfit)
	cfg.set_value("character", "made", char_made)
	cfg.set_value("settings", "look_sensitivity", look_sensitivity)
	cfg.set_value("settings", "invert_y", invert_y)
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


## Count `delta` seconds of flying. Call every frame while playing.
func add_playtime(delta: float) -> void:
	var d := clampf(delta, 0.0, MAX_PLAY_TICK)
	if d <= 0.0:
		return
	playtime += d
	city_time += d
	_unsaved_play += d
	if _unsaved_play >= PLAYTIME_SAVE_EVERY:
		_unsaved_play = 0.0
		request_save()


## Parents' "Restart the city": the city goes back to how it started.
## Total playtime and stars are kept.
func reset_city() -> void:
	city_time = 0.0
	city_seed = _new_seed()  # a restarted city grows a new way
	city_reset.emit()
	request_save()


## "3 h 20 m" / "12 m" for the parents' panel.
static func format_duration(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	if mins < 60:
		return "%d m" % mins
	return "%d h %d m" % [mins / 60, mins % 60]


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


func set_city_arrow(on: bool) -> void:
	city_arrow = on
	settings_changed.emit()
	request_save()


func set_crashes(on: bool) -> void:
	crashes = on
	settings_changed.emit()
	request_save()


func set_dragon(on: bool) -> void:
	dragon = on
	settings_changed.emit()
	request_save()


func set_dragon_level(lvl: int) -> void:
	dragon_level = posmod(lvl, DRAGON_LEVELS)
	settings_changed.emit()
	request_save()


## Dress the character (saved). Bad values clamp to the nearest choice.
func set_character(body: String, hair: int, outfit: int) -> void:
	char_body = body if body in ["M", "F"] else "M"
	char_hair = clampi(hair, 1, 4)
	char_outfit = clampi(outfit, 1, 4)
	char_made = true
	settings_changed.emit()
	request_save()


func set_look_sensitivity(v: float) -> void:
	look_sensitivity = clampf(v, LOOK_SENSITIVITY_MIN, LOOK_SENSITIVITY_MAX)
	settings_changed.emit()
	request_save()


func set_invert_y(on: bool) -> void:
	invert_y = on
	settings_changed.emit()
	request_save()


func _reset_to_defaults() -> void:
	selected_aircraft = AircraftCatalog.DEFAULT_ID
	lifetime_stars = 0
	playtime = 0.0
	city_time = 0.0
	city_seed = 0
	_unsaved_play = 0.0
	paints = {}
	music_volume = 0.7
	sfx_volume = 1.0
	battery_saver = false
	city_arrow = true
	crashes = true
	dragon = true
	dragon_level = 0
	look_sensitivity = 1.0
	invert_y = false
	char_body = "M"
	char_hair = 1
	char_outfit = 1
	char_made = false
