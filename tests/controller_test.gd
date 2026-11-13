extends Node
## Gamepad mapping test. Feeds standard (Xbox-layout) joypad events from two
## devices (0 = Steam Deck built-in, 1 = external Xbox pad) and checks every
## game and menu action responds. Also lists real connected controllers.
## Run: flatpak run org.godotengine.Godot --headless --path . res://tests/controller_test.tscn

var _fails := 0


func _ready() -> void:
	print("Connected controllers:")
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		print("  (none detected by this process)")
	for id in pads:
		print("  #%d %s  known-mapping=%s  guid=%s" % [id, Input.get_joy_name(id), Input.is_joy_known(id), Input.get_joy_guid(id)])
	print("")
	for device in [0, 1]:
		print("--- device %d (%s) ---" % [device, "built-in" if device == 0 else "external Xbox pad"])
		_axis(device, JOY_AXIS_LEFT_Y, -1.0, "fly_up")
		_axis(device, JOY_AXIS_LEFT_Y, 1.0, "fly_down")
		_axis(device, JOY_AXIS_LEFT_X, -1.0, "turn_left")
		_axis(device, JOY_AXIS_LEFT_X, 1.0, "turn_right")
		_axis(device, JOY_AXIS_RIGHT_X, -1.0, "look_left")
		_axis(device, JOY_AXIS_RIGHT_X, 1.0, "look_right")
		_axis(device, JOY_AXIS_RIGHT_Y, -1.0, "look_up")
		_axis(device, JOY_AXIS_RIGHT_Y, 1.0, "look_down")
		_axis(device, JOY_AXIS_TRIGGER_RIGHT, 1.0, "boost")
		_axis(device, JOY_AXIS_TRIGGER_LEFT, 1.0, "slow")
		_button(device, JOY_BUTTON_A, "boost")
		_button(device, JOY_BUTTON_B, "honk")
		_button(device, JOY_BUTTON_Y, "camera")
		_button(device, JOY_BUTTON_START, "pause")
		# Menus
		_button(device, JOY_BUTTON_A, "ui_accept")
		_button(device, JOY_BUTTON_B, "ui_cancel")
		_button(device, JOY_BUTTON_DPAD_LEFT, "ui_left")
		_button(device, JOY_BUTTON_DPAD_RIGHT, "ui_right")
		_axis(device, JOY_AXIS_LEFT_X, -1.0, "ui_left")
		_axis(device, JOY_AXIS_LEFT_X, 1.0, "ui_right")
		# Dead zone: a resting thumb (0.15) must not steer
		_axis(device, JOY_AXIS_LEFT_X, 0.15, "turn_right", false)
		# Some drivers report released triggers as -1: must not boost
		_axis(device, JOY_AXIS_TRIGGER_RIGHT, -1.0, "boost", false)
		# Unused buttons must do nothing harmful
		for b in [JOY_BUTTON_BACK, JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_button_none(device, b, ["pause", "honk", "camera", "ui_cancel"])
	print("\nCONTROLLER TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _axis(device: int, axis: JoyAxis, value: float, action: String, expect := true) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	var hit := InputMap.event_is_action(e, action) and e.get_action_strength(action) > 0.0
	_check("%s axis %d = %.2f -> %s" % ["" if expect else "NOT", axis, value, action], hit == expect)


func _button(device: int, button: JoyButton, action: String) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	_check("button %d -> %s" % [button, action], InputMap.event_is_action(e, action))


func _button_none(device: int, button: JoyButton, actions: Array) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	var bad := actions.filter(func(a): return InputMap.event_is_action(e, a))
	_check("button %d triggers nothing important" % button, bad.is_empty())


func _check(name: String, ok: bool) -> void:
	if not ok:
		print("FAIL  " + name)
		_fails += 1
