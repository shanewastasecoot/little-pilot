class_name DebugHud
extends CanvasLayer
## Developer overlay: FPS, speed, altitude and safety state. Toggle with F3.
## Shown by default only in debug builds.

@export var aircraft: Aircraft

@onready var label: Label = $Label


func _ready() -> void:
	visible = OS.is_debug_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or aircraft == null:
		return
	var s := aircraft.safety
	label.text = "FPS %d\nSpeed %.1f m/s  Boost %.0f%%\nAlt %.1f  Clearance %.1f\nPitch %.1f°  floor %.1f  ceil %.1f\nTurn bias %.2f" % [
		Engine.get_frames_per_second(),
		aircraft.speed, aircraft.boost_amount * 100.0,
		aircraft.global_position.y, s.clearance,
		rad_to_deg(aircraft.pitch), s.pitch_floor_deg, s.pitch_ceiling_deg,
		s.turn_bias,
	]
