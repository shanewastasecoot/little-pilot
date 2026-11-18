extends Node
## The character screen, driven with (fake) controller presses:
##   first    a fresh save: Start opens the screen; B goes back to the title
##            and saves nothing; Start, pick, A saves and goes on to the
##            plane select; the next Start skips the screen
##   pad      LB / RB (and D-pad up / down) change tab (hair, outfit) and wrap;
##            D-pad and left stick pick, the preview changes at once; the
##            right stick spins the preview; tiles can be tapped
##   pause    from the pause menu: B undoes the changes and returns to the
##            pause menu; A saves, and the walker wears the new look
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_charscreen.cfg"
## Fake presses come from a pad number no real controller uses, so the
## Deck's own sticks (device 0, resting at zero) can't cancel them.
const FAKE_PAD := 7
var _main: Node
var _cs: CharacterScreen
var _fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_cs = _main.character_screen
	await _frames(5)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nCHARACTER SCREEN TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	# --- first start -------------------------------------------------------------
	_main._on_start()
	await _frames(2)
	_check("a fresh save: Start opens the character screen", _main.state == _main.State.CHARACTER_CREATE and _cs.visible)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _press(JOY_BUTTON_B)
	_check("B goes back to the title and saves nothing", _main.state == _main.State.TITLE and not _cs.visible
			and not SaveManager.char_made and SaveManager.char_hair == 1)
	_main._on_start()
	await _frames(2)
	_check("the screen opens on the hair tab with the saved look", _cs.tab == 0 and _cs.current_look().slice(1) == [1, 1])
	# --- tabs (hair, outfit) ---------------------------------------------------------
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	_check("RB: next tab (outfit)", _cs.tab == 1)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	_check("RB wraps round to the first tab", _cs.tab == 0)
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	_check("LB wraps back to the last tab (outfit)", _cs.tab == 1)
	await _press(JOY_BUTTON_DPAD_UP)
	_check("D-pad up: previous tab", _cs.tab == 0)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_DOWN)
	_check("D-pad down: next tab (wraps)", _cs.tab == 0)
	# --- picking ----------------------------------------------------------------------
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _stick(JOY_AXIS_LEFT_X, 1.0)
	_check("D-pad and left stick pick hair; the preview changes at once", _cs.current_look()[1] == 3 and _cs.preview().hair == 3)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	_check("the outfit tab shows all %d outfits" % Outfits.count(), _cs._tiles.size() == Outfits.count())
	await _press(JOY_BUTTON_DPAD_LEFT)
	_check("picking left from the first wraps to the last (dino)", _cs.current_look()[2] == 5 and _cs.preview().outfit == 5
			and _cs.preview().visible_parts().has("Dino_Hood"))
	_cs._tiles[1].pressed.emit()
	await _frames(1)
	_check("tapping a tile picks it (princess)", _cs.current_look()[2] == 2 and _cs.preview().visible_parts().has("Princess_Tiara"))
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	var before: float = _cs._turntable.rotation.y
	await _hold_axis(JOY_AXIS_RIGHT_X, 1.0, 30)
	_check("right stick spins the character", absf(_cs._turntable.rotation.y - before) > 0.5)
	_check("nothing is saved until A", not SaveManager.char_made)
	await _press(JOY_BUTTON_A)
	_check("A saves the look (hair 3, superhero)", SaveManager.char_made and SaveManager.char_hair == 3 and SaveManager.char_outfit == 4)
	_check("and goes on to the plane select", _main.state == _main.State.SELECT and not _cs.visible)
	_main._on_plane_confirmed("prop")
	await _frames(2)
	_main._enter(_main.State.TITLE)
	_main._on_start()
	await _frames(2)
	_check("next Start skips the screen (already made)", _main.state == _main.State.SELECT)
	_main._on_plane_confirmed("prop")
	await _frames(2)
	# --- from the pause menu --------------------------------------------------------------
	_main._show_pause()
	_main.pause_menu.character_requested.emit()
	await _frames(2)
	_check("pause menu person button opens the screen", _cs.visible and not _main.pause_menu.visible and _main.state == _main.State.PAUSED)
	await _press(JOY_BUTTON_DPAD_LEFT)  # hair 3 -> 2
	await _press(JOY_BUTTON_B)
	_check("B undoes the changes and returns to the pause menu", not _cs.visible and _main.pause_menu.visible
			and SaveManager.char_hair == 3 and _cs.preview().hair == 3)
	_main.pause_menu.character_requested.emit()
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_RIGHT)  # hair 4
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	await _press(JOY_BUTTON_DPAD_RIGHT)  # outfit 5 (dino)
	await _press(JOY_BUTTON_A)
	_check("A saves and returns to the pause menu", not _cs.visible and _main.pause_menu.visible
			and SaveManager.char_hair == 4 and SaveManager.char_outfit == 5)
	_check("the walker wears the new look", _main.walker.model.hair == 4 and _main.walker.model.outfit == 5)
	_main._resume()


func _press(button: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = FAKE_PAD
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(1)


func _stick(axis: JoyAxis, value: float) -> void:
	await _hold_axis(axis, value, 2)


func _hold_axis(axis: JoyAxis, value: float, frames: int) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = FAKE_PAD
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await _frames(frames)
	var r := InputEventJoypadMotion.new()
	r.device = FAKE_PAD
	r.axis = axis
	r.axis_value = 0.0
	Input.parse_input_event(r)
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
