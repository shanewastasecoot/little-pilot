extends Node
## Global, game-wide settings and constants (autoload: GameSettings).
## Physics layer bit values used across scripts. Keep in sync with
## [layer_names] in project.godot.

const LAYER_WORLD := 1          # terrain, water, obstacles
const LAYER_AIRCRAFT := 2
const LAYER_PUSH_VOLUMES := 4   # soft keep-away zones around tall objects
const LAYER_COLLECTIBLES := 8   # stars
const LAYER_PLAYER := 16        # the player on foot

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
## Honk echoes (EchoZone): the honk goes through one of these, into SFX.
const BUS_HONK_ECHO := &"HonkEcho"
const BUS_HONK_CAVE := &"HonkCave"
const BUS_HONK_CITY := &"HonkCity"
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
	_make_echo_buses()
	# Safety net: many sounds at once (honk + chimes + music) never clip.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	# Underwater (a sea crash): everything goes muffled for a moment.
	var muffle := AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = 600.0
	AudioServer.add_bus_effect(0, muffle, 0)
	AudioServer.set_bus_effect_enabled(0, 0, false)
	SaveManager.settings_changed.connect(apply_settings)
	apply_settings()
	# A child never needs a mouse cursor over the game.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if is_steam_deck else Input.MOUSE_MODE_VISIBLE


## Muffle all sound (underwater) or not.
func set_muffled(on: bool) -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(0, i, on)


func is_muffled() -> bool:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLowPassFilter:
			return AudioServer.is_bus_effect_enabled(0, i)
	return false


func apply_settings() -> void:
	_set_bus_volume(BUS_MUSIC, SaveManager.music_volume)
	_set_bus_volume(BUS_SFX, SaveManager.sfx_volume)
	# The parent's loudest-it-gets cap (separate from the limiter, which
	# only stops clipping): everything, music and sounds, through Master.
	_set_bus_volume(&"Master", SaveManager.max_volume)
	Engine.max_fps = BATTERY_SAVER_FPS if SaveManager.battery_saver else 0


## The honk echo buses: each sends into SFX (so the sound volume applies).
##   HonkEcho  the mountains: two echoes coming back, quieter each time
##   HonkCave  the dragon's cave: a big, long reverb
##   HonkCity  among buildings: a short, bright reverb
func _make_echo_buses() -> void:
	for b in [BUS_HONK_ECHO, BUS_HONK_CAVE, BUS_HONK_CITY]:
		if AudioServer.get_bus_index(b) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, b)
		AudioServer.set_bus_send(idx, BUS_SFX)
		match b:
			BUS_HONK_ECHO:
				var d := AudioEffectDelay.new()
				d.dry = 1.0
				d.tap1_active = true
				d.tap1_delay_ms = 420.0
				d.tap1_level_db = -7.0
				d.tap1_pan = -0.3
				d.tap2_active = true
				d.tap2_delay_ms = 860.0
				d.tap2_level_db = -13.0
				d.tap2_pan = 0.3
				d.feedback_active = true
				d.feedback_delay_ms = 1300.0
				d.feedback_level_db = -20.0
				d.feedback_lowpass = 3000.0
				AudioServer.add_bus_effect(idx, d)
			BUS_HONK_CAVE:
				var r := AudioEffectReverb.new()
				r.room_size = 0.92
				r.damping = 0.35
				r.spread = 0.8
				r.wet = 0.55
				r.dry = 0.9
				r.predelay_msec = 60.0
				AudioServer.add_bus_effect(idx, r)
			BUS_HONK_CITY:
				var r := AudioEffectReverb.new()
				r.room_size = 0.42
				r.damping = 0.6
				r.wet = 0.3
				r.dry = 1.0
				r.predelay_msec = 25.0
				AudioServer.add_bus_effect(idx, r)


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
