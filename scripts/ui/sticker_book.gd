class_name StickerBook
extends CanvasLayer
## Her sticker book (Phase 14), from the pause menu (the purple book): all
## pictures, five tabs (LB / RB, or tap the tab pictures):
##   places     every landmark: its picture once she's been there, a "?"
##   animals    farm animals, penguins, dinosaurs, the whale, dolphins, the
##              dragon: pictures once she's seen them
##   friends    everyone she can deliver to: pictures once she's met them
##   stickers   the stickers from the buildings
##   postcards  the photos she took with LB, newest first
## The stick (or D-pad) moves round the page; B closes. The pictures are
## taken by Spotter. Names are small, for the grown-up reading along.

signal closed

const TABS := ["place", "animal", "friend", "sticker", "postcard"]
const STICKERS := ["post_office", "city_house", "hat_shop"]
const COLS := 5

var spotter: Spotter
var tab := 0
var index := 0
var _grid: GridContainer
var _tabs: HBoxContainer
var _cards: Array[Control] = []
var _cool := 0.0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.32, 0.2, 0.42, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 24
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 24)
	col.add_child(_tabs)
	for i in TABS.size():
		var b := BigButton.new()
		b.icon_type = [UiIcon.Icon.CITY, UiIcon.Icon.STAR, UiIcon.Icon.PERSON, UiIcon.Icon.CHECK, UiIcon.Icon.CAMERA][i]
		b.button_size = Vector2(96, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): show_tab(i))
		_tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_grid)
	hide()


func open() -> void:
	show()
	show_tab(tab)
	Sfx.play("ui_confirm")


func close() -> void:
	if visible:
		hide()
		Sfx.play("ui_back")
		closed.emit()


func show_tab(t: int) -> void:
	tab = posmod(t, TABS.size())
	index = 0
	for i in _tabs.get_child_count():
		var b := _tabs.get_child(i) as BigButton
		b.set_color(Color("ffd23f") if i == tab else Color("8a6bd1"))
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	for e in entries(TABS[tab]):
		var card := _card(e)
		_grid.add_child(card)
		_cards.append(card)
	_highlight()


## [id, name, picture path or "", seen] for the tab `kind`.
func entries(kind: String) -> Array:
	var out := []
	match kind:
		"place", "animal", "friend":
			for tg in (spotter.targets if spotter else []):
				if tg[1] == kind:
					var id: String = tg[0]
					var nm := id.split(":")[1].replace("_", " ")
					out.append([id, nm, "user://book/%s.png" % id.replace(":", "_"), SaveManager.book_has(id)])
		"sticker":
			for s in STICKERS:
				out.append(["sticker:" + s, s.replace("_", " "), "", SaveManager.stickers.has(s)])
		"postcard":
			var list := SaveManager.postcards.duplicate()
			list.reverse()
			for n in list:
				out.append(["postcard:%d" % n, "", "user://postcards/%d.png" % n, true])
	return out


func _card(e: Array) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(212, 168)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(212, 134)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff7e6") if e[3] else Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.0)
	frame.add_theme_stylebox_override("panel", sb)
	box.add_child(frame)
	var kind := String(e[0]).split(":")[0]
	if kind == "sticker":
		var st := Hud.Sticker.new()
		st.id = String(e[0]).split(":")[1]
		st.size = Vector2(120, 120)
		st.position = Vector2(46, 7)
		st.modulate = Color.WHITE if e[3] else Color(0.3, 0.3, 0.35, 0.8)
		frame.add_child(st)
	elif e[3] and String(e[2]) != "":
		var tex := Spotter.picture(e[2])
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 8
			tr.offset_top = 8
			tr.offset_right = -8
			tr.offset_bottom = -8
			frame.add_child(tr)
	else:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 72)
		q.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(q)
	var l := Label.new()
	l.text = String(e[1]).capitalize() if e[3] else ""
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(l)
	return box


func _highlight() -> void:
	for i in _cards.size():
		var frame := _cards[i].get_child(0) as Panel
		var sb := frame.get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = Color("ffd23f") if i == index else Color(1, 1, 1, 0.0)


## How many cards the open tab shows, and how many are filled in (tests).
func counts() -> Vector2i:
	var seen := 0
	for e in entries(TABS[tab]):
		if e[3]:
			seen += 1
	return Vector2i(_cards.size(), seen)


func _process(delta: float) -> void:
	if not visible:
		return
	_cool -= delta
	if _cool > 0.0:
		return
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if v.length() > 0.5 and not _cards.is_empty():
		var step := (1 if v.x > 0.5 else (-1 if v.x < -0.5 else 0)) + (COLS if v.y > 0.5 else (-COLS if v.y < -0.5 else 0))
		index = clampi(index + step, 0, _cards.size() - 1)
		_highlight()
		Sfx.play("ui_move")
		_cool = 0.22


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("tab_next"):
		show_tab(tab + 1)
		Sfx.play("ui_move", 1.2)
	elif event.is_action_pressed("tab_prev"):
		show_tab(tab - 1)
		Sfx.play("ui_move", 1.0)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()
