extends Node
## Global, game-wide settings and constants (autoload: GameSettings).
## Physics layer bit values used across scripts. Keep in sync with
## [layer_names] in project.godot.

const LAYER_WORLD := 1          # terrain, water, obstacles
const LAYER_AIRCRAFT := 2
const LAYER_PUSH_VOLUMES := 4   # soft keep-away zones around tall objects
const LAYER_COLLECTIBLES := 8   # stars

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
## Frame cap when the parent turns on battery saver.
const BATTERY_SAVER_FPS := 30

## True when running on a Steam Deck (Steam sets SteamDeck=1 in Game Mode).
var is_steam_deck: bool = OS.get_environment("SteamDeck") == "1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Game Mode (gamescope) is fullscreen anyway; this also covers Desktop Mode.
	if is_steam_deck or "--fullscreen" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	# Safety net: many sounds at once (honk + chimes + music) never clip.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	SaveManager.settings_changed.connect(apply_settings)
	apply_settings()
	# A child never needs a mouse cursor over the game.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if is_steam_deck else Input.MOUSE_MODE_VISIBLE


func apply_settings() -> void:
	_set_bus_volume(BUS_MUSIC, SaveManager.music_volume)
	_set_bus_volume(BUS_SFX, SaveManager.sfx_volume)
	Engine.max_fps = BATTERY_SAVER_FPS if SaveManager.battery_saver else 0


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
