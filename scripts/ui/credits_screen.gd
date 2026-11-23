class_name CreditsScreen
extends CanvasLayer
## The credits, for grown-ups (Phase 7): opened from the parent settings
## (the heart button). Everyone whose work is in the game: the engine and
## every asset with its author, licence and where it came from, read from
## resources/credits.json (Credits). Scroll with the stick or D-pad; B, Esc
## or the back arrow closes it.

signal closed

var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.09, 0.2, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 30
	col.offset_bottom = -30
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)
	var back := BigButton.new()
	back.icon_type = UiIcon.Icon.ARROW_LEFT
	back.base_color = Color("8a94a6")
	back.button_size = Vector2(90, 90)
	back.pressed.connect(close)
	top.add_child(back)
	var heart := UiIcon.new()
	heart.icon = UiIcon.Icon.CREDITS
	heart.custom_minimum_size = Vector2(80, 80)
	top.add_child(heart)
	var title := Label.new()
	title.text = "Thank you!"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	var d := Credits.data()
	_line(str(d.get("code", "")).replace("`", ""), 22, Color("ffd23f"))
	for l in Credits.screen_lines(d):
		_line(l, 20, Color(0.92, 0.95, 1.0))
	_line("CC0 assets need no credit; they're listed so you know where they came from. Everything else is made by this project's own code and tools.", 18, Color(0.7, 0.78, 0.9))
	hide()


func _line(text: String, size: int, colour: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(l)


## How many lines (tests).
func line_count() -> int:
	return _list.get_child_count()


func open() -> void:
	_scroll.scroll_vertical = 0
	show()


func close() -> void:
	if visible:
		hide()
		Sfx.play("ui_back")
		closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	var y := Input.get_axis("ui_up", "ui_down")
	var stick := Input.get_axis("fly_up", "fly_down")
	if absf(stick) > absf(y):
		y = stick
	if absf(y) > 0.3:
		_scroll.scroll_vertical += int(y * 900.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
