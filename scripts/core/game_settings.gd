extends Node
## Global, game-wide settings and constants (autoload: GameSettings).
## Physics layer bit values used across scripts. Keep in sync with
## [layer_names] in project.godot.

const LAYER_WORLD := 1          # terrain, water, obstacles
const LAYER_AIRCRAFT := 2
const LAYER_PUSH_VOLUMES := 4   # soft keep-away zones around tall objects

## True when running on a Steam Deck (Steam sets SteamDeck=1 in Game Mode).
var is_steam_deck: bool = OS.get_environment("SteamDeck") == "1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Game Mode (gamescope) is fullscreen anyway; this also covers Desktop Mode.
	if is_steam_deck or "--fullscreen" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# A child never needs a mouse cursor over the game.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if is_steam_deck else Input.MOUSE_MODE_VISIBLE
