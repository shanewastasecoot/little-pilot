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
## Liveries (Phase 13): per plane, the trim colour (Paint index) and decal
## (Livery.DECALS).
var trims: Dictionary = {}
var decals: Dictionary = {}
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
## Outfits to choose from (Outfits: pilot, princess, astronaut, superhero, dino).
const OUTFIT_COUNT := 5
var look_sensitivity: float = 1.0
## Deliveries: the parcel being carried (who it's for; "" = none), how many
## have been delivered, and everyone who has had one (first-time stickers).
var delivery_job: String = ""
var deliveries: int = 0
var delivered_to: Array[String] = []
## Parent setting: the delivery arrow (the picture bubble still shows).
var delivery_arrow: bool = true
## Her house: her bedroom's wall and quilt colours (PaintStation.COLOURS index, -1 =
## as built), and whether she was inside when the game last stopped (then
## she starts outside the front door).
var house_wall: int = -1
var house_bed: int = -1
var house_inside: bool = false
## Dragon treasure she's taken from the lair (shown on her trophy shelf), and
## the playtime (s) when the next piece is back on the hoard.
var treasures: int = 0
## Stickers she's been given (one per kind of building, on her first visit).
var stickers: Array[String] = []
## The hat shop: stars she's spent there (her purse is lifetime_stars minus
## these), the hats she's bought (Hats ids) and the one she's wearing
## ("" = her outfit's own headgear).
var stars_spent: int = 0
## Save safety (Phase 10): the format version written now; the version of
## the file that was loaded (0 = none, defaults); the city plan version the
## saved city was made with (CityPlan.VERSION).
const SAVE_VERSION := 2
var loaded_version := 0
var city_plan_version := 0
## Parent setting: the loudest the game gets (0.2..1.0 of full; 1.0 = no cap).
var max_volume: float = 1.0
const MAX_VOLUME_MIN := 0.2
var hats_owned: Array[String] = []
var hat: String = ""
var treasure_ready_at: float = 0.0
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


## Bring an older save's values up to date (from `from_version` to
## SAVE_VERSION), before anything is read from it. New features add new keys,
## which simply start at their defaults, so nothing needs changing yet:
##   1 -> 2  (Phase 10: progress/city_plan_version, the shop, the volume cap)
func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	if from_version >= SAVE_VERSION:
		return
	# (Future migrations go here, one `if from_version < N:` per step.)


## The city's plan: made from the seed by the current plan code, unless the
## saved city was made by older plan code (city_plan_version differs from
## CityPlan.VERSION), in which case the plan kept when it was made is used,
## so an update never silently swaps her city for a different one. The plan
## is kept beside the save (city_snapshot_path) whenever it's made.
func city_plan() -> Array[Dictionary]:
	if city_plan_version > 0 and city_plan_version != CityPlan.VERSION:
		var kept := ConfigFile.new()
		if kept.load(city_snapshot_path()) == OK and int(kept.get_value("plan", "seed", -1)) == city_seed:
			var events: Array[Dictionary] = []
			events.assign(kept.get_value("plan", "events", []))
			if not events.is_empty():
				return events
		push_warning("No kept plan for this city; making it with the current plan code.")
	var plan := CityPlan.make(city_seed)
	if city_plan_version != CityPlan.VERSION:
		city_plan_version = CityPlan.VERSION
		request_save()
	var snap := ConfigFile.new()
	if snap.load(city_snapshot_path()) != OK or int(snap.get_value("plan", "seed", -1)) != city_seed \
			or int(snap.get_value("plan", "version", -1)) != CityPlan.VERSION:
		snap = ConfigFile.new()
		snap.set_value("plan", "seed", city_seed)
		snap.set_value("plan", "version", CityPlan.VERSION)
		snap.set_value("plan", "events", plan)
		snap.save(city_snapshot_path())
	return plan


## Where the city's plan is kept, beside the save (save.cfg -> save_city.cfg).
func city_snapshot_path() -> String:
	return path.get_basename() + "_city.cfg"


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
	# The save, else (if it's there but broken) the newer copy left beside it
	# when a swap failed, else the last good save (.bak), else the defaults.
	# Never an error for her.
	var cfg := ConfigFile.new()
	var found := false
	# No save at all is a fresh start (deleting save.cfg resets the game): the
	# copies are only for a save that's there but broken.
	var there := FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
	if not there:
		return
	for p in [path, path + ".tmp", path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var err := cfg.load(p)
		# (A file that parses to nothing at all isn't a save: garbage text
		# can do that. Try the next one.)
		if err == OK and cfg.get_sections().is_empty():
			err = ERR_FILE_CORRUPT
		if err == OK:
			found = true
			if p != path:
				push_warning("Save file %s unreadable; loaded %s instead." % [path, p])
			break
		push_warning("Save file %s unreadable (error %d)." % [p, err])
		cfg = ConfigFile.new()
	if not found:
		return
	loaded_version = int(cfg.get_value("meta", "version", 1))
	_migrate(cfg, loaded_version)
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
	# (Saves from before the plan had a version were made by version 1.)
	var cpv = cfg.get_value("progress", "city_plan_version", 1)
	city_plan_version = cpv if cpv is int and cpv > 0 else 1
	var saved_paints = cfg.get_value("player", "paints", {})
	if saved_paints is Dictionary:
		for id in saved_paints:
			var idx = saved_paints[id]
			if id is String and AircraftCatalog.has(id) and idx is int and idx >= 0 and idx < Paint.COLORS.size():
				paints[id] = idx
	music_volume = _volume(cfg.get_value("settings", "music_volume", music_volume), music_volume)
	max_volume = clampf(_volume(cfg.get_value("settings", "max_volume", 1.0), 1.0), MAX_VOLUME_MIN, 1.0)
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
	if co is int and co >= 1 and co <= OUTFIT_COUNT:
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
	var darrow = cfg.get_value("settings", "delivery_arrow", delivery_arrow)
	if darrow is bool:
		delivery_arrow = darrow
	# Who the job is for is checked by DeliveryManager (it knows everyone).
	var job = cfg.get_value("delivery", "job", "")
	if job is String:
		delivery_job = job
	var dc = cfg.get_value("delivery", "count", 0)
	if dc is int and dc >= 0:
		deliveries = dc
	var hw = cfg.get_value("house", "wall", -1)
	if hw is int and hw >= -1 and hw < 6:
		house_wall = hw
	var hb = cfg.get_value("house", "bed", -1)
	if hb is int and hb >= -1 and hb < 6:
		house_bed = hb
	var hi = cfg.get_value("house", "inside", false)
	if hi is bool:
		house_inside = hi
	var st = cfg.get_value("stickers", "have", [])
	if st is Array:
		stickers.clear()
		for x in st:
			if x is String and not stickers.has(x):
				stickers.append(x)
	var sp = cfg.get_value("shop", "stars_spent", 0)
	if sp is int and sp >= 0:
		stars_spent = mini(sp, lifetime_stars)
	var ho = cfg.get_value("shop", "hats_owned", [])
	if ho is Array:
		for x in ho:
			if x is String and Hats.has(x) and not hats_owned.has(x):
				hats_owned.append(x)
	var tr_saved = cfg.get_value("livery", "trims", {})
	if tr_saved is Dictionary:
		for k in tr_saved:
			if k is String and AircraftCatalog.has(k) and tr_saved[k] is int:
				trims[k] = posmod(tr_saved[k], Paint.COLORS.size())
	var dc_saved = cfg.get_value("livery", "decals", {})
	if dc_saved is Dictionary:
		for k in dc_saved:
			if k is String and AircraftCatalog.has(k) and dc_saved[k] is String and dc_saved[k] in Livery.DECALS:
				decals[k] = dc_saved[k]
	var hat_on = cfg.get_value("shop", "hat", "")
	if hat_on is String and hats_owned.has(hat_on):
		hat = hat_on
	var tr = cfg.get_value("dragon", "treasures", 0)
	if tr is int and tr >= 0 and tr < 1000:
		treasures = tr
	var tra = cfg.get_value("dragon", "treasure_ready_at", 0.0)
	if (tra is float or tra is int) and float(tra) >= 0.0:
		treasure_ready_at = float(tra)
	var met = cfg.get_value("delivery", "delivered_to", [])
	if met is Array:
		for m in met:
			if m is String and not delivered_to.has(m):
				delivered_to.append(m)
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
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("player", "selected_aircraft", selected_aircraft)
	cfg.set_value("player", "paints", paints)
	cfg.set_value("progress", "lifetime_stars", lifetime_stars)
	cfg.set_value("progress", "playtime", playtime)
	cfg.set_value("progress", "city_time", city_time)
	cfg.set_value("progress", "city_seed", city_seed)
	cfg.set_value("progress", "city_plan_version", city_plan_version if city_plan_version > 0 else CityPlan.VERSION)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "max_volume", max_volume)
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
	cfg.set_value("settings", "delivery_arrow", delivery_arrow)
	cfg.set_value("delivery", "job", delivery_job)
	cfg.set_value("delivery", "count", deliveries)
	cfg.set_value("delivery", "delivered_to", delivered_to)
	cfg.set_value("house", "wall", house_wall)
	cfg.set_value("house", "bed", house_bed)
	cfg.set_value("house", "inside", house_inside)
	cfg.set_value("stickers", "have", stickers)
	cfg.set_value("livery", "trims", trims)
	cfg.set_value("livery", "decals", decals)
	cfg.set_value("shop", "stars_spent", stars_spent)
	cfg.set_value("shop", "hats_owned", hats_owned)
	cfg.set_value("shop", "hat", hat)
	cfg.set_value("dragon", "treasures", treasures)
	cfg.set_value("dragon", "treasure_ready_at", treasure_ready_at)
	# Write to a temp file, then swap it in, so a crash mid-write
	# can't leave a broken save behind.
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("Could not write save file %s" % tmp)
		return
	# Only swap in a file that reads back.
	if ConfigFile.new().load(tmp) != OK:
		push_warning("Save file %s didn't read back; keeping the old save." % tmp)
		return
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	# Keep the last good save as .bak (only one that reads).
	if FileAccess.file_exists(path) and ConfigFile.new().load(path) == OK:
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
	if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
		# The swap failed: try copying over instead; if that fails too, the
		# new save stays beside it as .tmp (loaded next time) and the old
		# save and the .bak are untouched. Nothing is lost.
		if DirAccess.copy_absolute(abs_tmp, abs_path) == OK:
			DirAccess.remove_absolute(abs_tmp)
		else:
			push_warning("Could not replace %s; the new save is kept in %s." % [path, tmp])


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
	city_plan_version = CityPlan.VERSION
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


func get_trim(id: String) -> int:
	return trims.get(id, 4)


func set_trim(id: String, idx: int) -> void:
	trims[id] = posmod(idx, Paint.COLORS.size())
	settings_changed.emit()
	request_save()


func get_decal(id: String) -> String:
	return decals.get(id, "none")


## Wear decal `d` on plane `id` (only one she's earned). True if it's on.
func set_decal(id: String, d: String) -> bool:
	if not d in Livery.DECALS or not Livery.unlocked(d):
		return false
	decals[id] = d
	settings_changed.emit()
	request_save()
	return true


func set_paint(id: String, idx: int) -> void:
	paints[id] = posmod(idx, Paint.COLORS.size())
	request_save()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	settings_changed.emit()
	request_save()


## The parent's cap on how loud everything gets (MAX_VOLUME_MIN..1).
func set_max_volume(v: float) -> void:
	max_volume = clampf(v, MAX_VOLUME_MIN, 1.0)
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
	char_outfit = clampi(outfit, 1, OUTFIT_COUNT)
	char_made = true
	settings_changed.emit()
	request_save()


func set_look_sensitivity(v: float) -> void:
	look_sensitivity = clampf(v, LOOK_SENSITIVITY_MIN, LOOK_SENSITIVITY_MAX)
	settings_changed.emit()
	request_save()


func set_delivery_arrow(on: bool) -> void:
	delivery_arrow = on
	settings_changed.emit()
	request_save()


## Stars she has to spend in the shop.
func star_purse() -> int:
	return maxi(lifetime_stars - stars_spent, 0)


## Buy hat `id` (if she hasn't already and has the stars) and put it on.
## True if it's bought (or already hers).
func buy_hat(id: String) -> bool:
	if not Hats.has(id):
		return false
	if not hats_owned.has(id):
		if star_purse() < Hats.price(id):
			return false
		stars_spent += Hats.price(id)
		hats_owned.append(id)
	wear_hat(id)
	return true


## Wear hat `id` (one of hers; "" = the outfit's own).
func wear_hat(id: String) -> void:
	if id != "" and not hats_owned.has(id):
		return
	if id != hat:
		hat = id
		request_save()
		settings_changed.emit()


## Give her sticker `id` (first time only). True if it's new.
func add_sticker(id: String) -> bool:
	if stickers.has(id):
		return false
	stickers.append(id)
	request_save()
	return true


## She took a piece of dragon treasure: one more on her shelf; the next is
## back on the hoard after `refill` seconds of play.
func add_treasure(refill: float) -> void:
	treasures += 1
	treasure_ready_at = playtime + refill
	request_save()


## Her bedroom's colours (PaintStation.COLOURS indices, -1 = as built).
func set_house_colours(wall: int, bed: int) -> void:
	house_wall = clampi(wall, -1, 5)
	house_bed = clampi(bed, -1, 5)
	request_save()


## Inside her house or not (saved straight away: quitting inside means
## starting outside the front door next time).
func set_house_inside(on: bool) -> void:
	house_inside = on
	save_now()


## Picked up a parcel for `id` ("" = nothing being carried).
func set_delivery_job(id: String) -> void:
	delivery_job = id
	request_save()


## A parcel reached `id`. Returns true the first time they get one.
func add_delivery(id: String) -> bool:
	deliveries += 1
	delivery_job = ""
	var first := not delivered_to.has(id)
	if first:
		delivered_to.append(id)
	request_save()
	return first


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
	city_plan_version = 0
	loaded_version = 0
	_unsaved_play = 0.0
	paints = {}
	music_volume = 0.7
	max_volume = 1.0
	sfx_volume = 1.0
	battery_saver = false
	city_arrow = true
	crashes = true
	dragon = true
	dragon_level = 0
	look_sensitivity = 1.0
	invert_y = false
	delivery_job = ""
	deliveries = 0
	delivered_to = []
	delivery_arrow = true
	house_wall = -1
	house_bed = -1
	house_inside = false
	treasures = 0
	treasure_ready_at = 0.0
	stickers = []
	stars_spent = 0
	trims = {}
	decals = {}
	hats_owned = []
	hat = ""
	char_body = "M"
	char_hair = 1
	char_outfit = 1
	char_made = false
