class_name DebugHud
extends CanvasLayer
## Developer overlay: FPS, speed, altitude and safety state. Toggle with F3.
## Shown by default only in debug builds.

@export var aircraft: Aircraft

@onready var label: Label = $Label


func _ready() -> void:
	visible = OS.is_debug_build()
	add_to_group("hide_in_photos")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
	# With the overlay showing, T flips the tonemapper between AgX (the
	# game's since Graphics G2) and Linear, to compare. Not saved.
	if visible and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_T:
		toggle_tonemap()


## AgX <-> Linear on the world's environment (for comparing). Returns the new one.
func toggle_tonemap() -> int:
	var env := _environment()
	if env == null:
		return -1
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if env.tonemap_mode == Environment.TONE_MAPPER_LINEAR else Environment.TONE_MAPPER_LINEAR
	return env.tonemap_mode


func _process(_delta: float) -> void:
	if not visible or aircraft == null:
		return
	var s := aircraft.safety
	label.text = "FPS %d\nSpeed %.1f m/s  Boost %.0f%%\nAlt %.1f  Clearance %.1f\nPitch %.1f°  floor %.1f  ceil %.1f\nTurn bias %.2f\nTonemap %s (T to compare)" % [
		Engine.get_frames_per_second(),
		aircraft.speed, aircraft.boost_amount * 100.0,
		aircraft.global_position.y, s.clearance,
		rad_to_deg(aircraft.pitch), s.pitch_floor_deg, s.pitch_ceiling_deg,
		s.turn_bias, _tonemap_name(),
	]


var _env: Environment


func _environment() -> Environment:
	if _env == null:
		var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
		if not we.is_empty():
			_env = (we[0] as WorldEnvironment).environment
	return _env


func _tonemap_name() -> String:
	var env := _environment()
	if env == null:
		return "-"
	return "AgX" if env.tonemap_mode == Environment.TONE_MAPPER_AGX else "Linear"
