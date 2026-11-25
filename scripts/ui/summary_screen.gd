class_name SummaryScreen
extends CanvasLayer
## Today, for the grown-up (Phase 14): a picture page from the pause menu
## (the calendar button by the gear) showing what she did today: which
## islands she visited (their pictures lit up), the stars she collected,
## parcels delivered, crashes, and how long she's played. Numbers sit next to
## big pictures, so a parent can read it at a glance and a child can point
## at it. Counts come from SaveManager's "today" (new keys; a new day starts
## afresh). B / Esc or the back arrow closes it.

signal closed

const ISLANDS := [
	["main", "Home island", Color("6fcf6f")],
	["palm", "Palm Island", Color("ffd36b")],
	["volcano", "Volcano", Color("ff7b4a")],
	["mermaid", "Mermaid Lagoon", Color("4fd6c8")],
	["dragon", "Dragon Peak", Color("8a6bd1")],
	["ice", "Ice Island", Color("bfe6ff")],
	["dino", "Dino Island", Color("8bc34a")],
	["castle", "Castle Island", Color("d8b4fe")],
	["town", "Town Island", Color("ff9fc4")],
]

var _page: Control


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.09, 0.2, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.draw.connect(_draw_page)
	add_child(_page)
	var back := BigButton.new()
	back.icon_type = UiIcon.Icon.ARROW_LEFT
	back.base_color = Color("8a94a6")
	back.button_size = Vector2(90, 90)
	back.position = Vector2(30, 30)
	back.pressed.connect(close)
	add_child(back)
	hide()


func open() -> void:
	show()
	_page.queue_redraw()


func close() -> void:
	if visible:
		hide()
		Sfx.play("ui_back")
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _draw_page() -> void:
	var s := _page.size
	var font := _page.get_theme_default_font()
	var t: Dictionary = SaveManager.today()
	# Title: a little calendar page and "Today".
	_page.draw_string(font, Vector2(150, 90), "Today", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color.WHITE)
	# Every star found so far, ever (all of them: the rainbow sparkles).
	var total := 0
	var found := 0
	for st in get_tree().get_nodes_in_group("stars"):
		total += 1
		if SaveManager.stars_found.has(st.key):
			found += 1
	if total > 0:
		var txt := "%d / %d stars found" % [found, total]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_icon("star", Vector2(s.x - tw - 90, 78), 18.0, Color("ffd23f") if found < total else Color("ffe680"))
		_page.draw_string(font, Vector2(s.x - tw - 60, 88), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	# The four big counts.
	var items := [
		["star", int(t.get("stars", 0)), Color("ffd23f")],
		["parcel", int(t.get("deliveries", 0)), Color("c98b4b")],
		["crash", int(t.get("crashes", 0)), Color("ff7b4a")],
		["clock", int(t.get("seconds", 0.0) / 60.0), Color("4aa8ff")],
	]
	var w := s.x / items.size()
	for i in items.size():
		var c := Vector2(w * (i + 0.5), s.y * 0.36)
		_page.draw_circle(c, 78.0, Color(1, 1, 1, 0.08))
		_icon(items[i][0], c + Vector2(0, -18), 40.0, items[i][2])
		var label := str(items[i][1]) + (" min" if items[i][0] == "clock" else "")
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		_page.draw_string(font, c + Vector2(-lw * 0.5, 62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	# The islands: lit when visited today.
	var visited: Array = t.get("islands", [])
	var n := ISLANDS.size()
	var gap := minf(130.0, (s.x - 120.0) / n)
	var x0 := s.x * 0.5 - (n - 1) * gap * 0.5
	for i in n:
		var isl: Array = ISLANDS[i]
		var c := Vector2(x0 + i * gap, s.y * 0.74)
		var on: bool = visited.has(isl[0])
		_island(c, 44.0, isl[2] if on else Color(0.3, 0.33, 0.4))
		if on:
			_page.draw_polyline(PackedVector2Array([c + Vector2(22, 30), c + Vector2(30, 38), c + Vector2(44, 22)]), Color("43c463"), 6.0, true)
		var name: String = isl[1]
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_page.draw_string(font, c + Vector2(-nw * 0.5, 66), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.9, 1.0) if on else Color(0.5, 0.55, 0.65))


func _icon(kind: String, c: Vector2, r: float, col: Color) -> void:
	match kind:
		"star":
			_page.draw_colored_polygon(UiIcon.star_points(c, r, r * 0.45), col)
		"parcel":
			_page.draw_rect(Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6)), col)
			_page.draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.8), Vector2(r * 0.24, r * 1.6)), Color("e63946"))
			_page.draw_rect(Rect2(c - Vector2(r, r * 0.12), Vector2(r * 2, r * 0.24)), Color("e63946"))
		"crash":
			for k in 8:
				var a := TAU * k / 8.0
				_page.draw_line(c, c + Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.6), col, 7.0, true)
			_page.draw_circle(c, r * 0.35, Color.WHITE)
		"clock":
			_page.draw_circle(c, r, col)
			_page.draw_circle(c, r * 0.82, Color.WHITE)
			_page.draw_line(c, c + Vector2(0, -r * 0.6), Color("1c1d26"), 5.0, true)
			_page.draw_line(c, c + Vector2(r * 0.45, 0), Color("1c1d26"), 5.0, true)


## A little island: sand, grass and a palm.
func _island(c: Vector2, r: float, col: Color) -> void:
	_page.draw_circle(c + Vector2(0, r * 0.15), r, Color("2f7fc0") if col.s > 0.1 else Color(0.2, 0.22, 0.3))
	_page.draw_set_transform(c + Vector2(0, r * 0.2), 0.0, Vector2(1.0, 0.5))
	_page.draw_circle(Vector2.ZERO, r * 0.75, Color("f2d79b") if col.s > 0.1 else Color(0.35, 0.37, 0.45))
	_page.draw_circle(Vector2(0, -r * 0.15), r * 0.55, col)
	_page.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_page.draw_line(c + Vector2(0, r * 0.1), c + Vector2(r * 0.1, -r * 0.55), Color("8a5a3c"), 4.0, true)
	_page.draw_circle(c + Vector2(r * 0.1, -r * 0.58), r * 0.22, col.darkened(0.2))
