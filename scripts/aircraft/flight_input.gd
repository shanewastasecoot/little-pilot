class_name FlightInput
extends Node
## Reads player input and turns it into smoothed flight intent.
## Knows nothing about physics, so it can be swapped for AI or test input.

signal honk_pressed
signal camera_pressed

## Smoothed stick: x = turn (+right), y = pitch (+climb). Range -1..1.
var stick: Vector2 = Vector2.ZERO
## +1 boosting, -1 slowing, 0 cruising.
var throttle: float = 0.0
## Raw (unsmoothed) stick magnitude, used for auto-level decisions.
var has_stick_input: bool = false

## Set by tests to drive the plane without a controller.
var override_enabled: bool = false
var override_stick: Vector2 = Vector2.ZERO
var override_throttle: float = 0.0

var smoothing: float = 3.0


func _physics_process(delta: float) -> void:
	var raw: Vector2
	var raw_throttle: float
	if override_enabled:
		raw = override_stick.limit_length(1.0)
		raw_throttle = override_throttle
	else:
		# get_vector applies the 0.2 radial dead zone from the input map.
		raw = Input.get_vector("turn_left", "turn_right", "fly_down", "fly_up")
		# Boost wins if both are held, so mashing never feels "stuck slow".
		raw_throttle = Input.get_action_strength("boost") - Input.get_action_strength("slow") * (1.0 - Input.get_action_strength("boost"))

	has_stick_input = raw.length() > 0.05
	var t := 1.0 - exp(-smoothing * delta)
	stick = stick.lerp(raw, t)
	throttle = lerpf(throttle, clampf(raw_throttle, -1.0, 1.0), t)


func _unhandled_input(event: InputEvent) -> void:
	if override_enabled:
		return  # menus, autopilot and tests: buttons do nothing here
	if event.is_action_pressed("honk"):
		honk_pressed.emit()
	elif event.is_action_pressed("camera"):
		camera_pressed.emit()
