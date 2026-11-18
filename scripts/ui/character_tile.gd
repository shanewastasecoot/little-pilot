class_name CharacterTile
extends Button
## One choice on the character screen, drawn as a picture so it needs no
## reading: a boy or girl face (body), a head with that hairstyle (hair), or
## a little set of clothes in that outfit's colours (outfit). Selected tiles
## get a thick white border and pop up a little.

enum Kind { BODY, HAIR, OUTFIT, TAB }

## Colours match tools/blender/build_characters.py.
const SKIN := Color("f2c19e")
const HAIR_COLOURS := [Color("6b4226"), Color("2a2522"), Color("e8c35a"), Color("3b2418")]
## [top, bottoms, shoes] per outfit.
const OUTFIT_COLOURS := [
	[Color("ff5a5f"), Color("2f6fdb"), Color("f4f4f4")],
	[Color("4cc06a"), Color("3b5b8c"), Color("333a44")],
	[Color("8b5a2b"), Color("c9b27c"), Color("4a3324")],
	[Color("4aa8ff"), Color("f2b134"), Color("ffd23f")],
]
const TAB_COLOURS := [Color("ff8c42"), Color("9b5de5"), Color("4cc06a")]

var kind := Kind.BODY
var index := 0
var selected := false:
	set(v):
		if v == selected:
			return
		selected = v
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE * (1.1 if v else 1.0), 0.18)
		queue_redraw()


func _init(k: Kind = Kind.BODY, i: int = 0, tile_size := Vector2(150, 150)) -> void:
	kind = k
	index = i
	custom_minimum_size = tile_size
	focus_mode = Control.FOCUS_NONE
	flat = true


func _ready() -> void:
	pivot_offset = custom_minimum_size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var bg: Color = Color(1, 1, 1, 0.92) if kind != Kind.TAB else TAB_COLOURS[index]
	if kind == Kind.TAB and not selected:
		bg = bg.darkened(0.35)
	_round_rect(Rect2(Vector2.ZERO, size), s * 0.18, bg)
	if selected:
		_round_rect_outline(Rect2(Vector2.ZERO, size).grow(-3), s * 0.17, Color.WHITE if kind == Kind.TAB else Color("ffb703"), 7.0)
	match kind:
		Kind.BODY:
			_face(c + Vector2(0, s * 0.05), s * 0.3, index == 1)
		Kind.HAIR:
			_head_with_hair(c + Vector2(0, s * 0.06), s * 0.27, index)
		Kind.OUTFIT:
			_outfit(c, s * 0.8, index)
		Kind.TAB:
			var icon_c := Color.WHITE
			match index:
				0:
					_face(c + Vector2(0, s * 0.05), s * 0.28, false, icon_c)
				1:
					_head_with_hair(c + Vector2(0, s * 0.06), s * 0.25, 2, icon_c)
				2:
					_shirt(c + Vector2(0, -s * 0.02), s * 0.62, icon_c)


func _face(c: Vector2, r: float, girl: bool, tint := Color.TRANSPARENT) -> void:
	var skin := SKIN if tint.a == 0.0 else tint
	var hair: Color = HAIR_COLOURS[0] if not girl else HAIR_COLOURS[2]
	if tint.a > 0.0:
		hair = tint.darkened(0.25)
	if girl:  # ponytail behind
		draw_circle(c + Vector2(r * 0.95, -r * 0.1), r * 0.38, hair)
		draw_circle(c + Vector2(r * 1.15, r * 0.35), r * 0.3, hair)
	draw_circle(c, r, skin)
	# hair cap
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(c + Vector2(cos(a), sin(a) * 0.85) * r * 1.06)
	pts.append(c + Vector2(r * 1.02, -r * 0.05))
	pts.append(c + Vector2(-r * 1.02, -r * 0.05))
	draw_colored_polygon(pts, hair)
	if tint.a > 0.0:
		return
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * r * 0.36, r * 0.12), r * 0.13, Color("2b2622"))
		draw_circle(c + Vector2(sx * r * 0.32, r * 0.07), r * 0.04, Color.WHITE)
		draw_circle(c + Vector2(sx * r * 0.6, r * 0.42), r * 0.12, Color("f29a8a"))
		if girl:
			draw_line(c + Vector2(sx * r * 0.42, -r * 0.04), c + Vector2(sx * r * 0.58, -r * 0.16), Color("2b2622"), r * 0.06)
	draw_arc(c + Vector2(0, r * 0.38), r * 0.26, 0.25, PI - 0.25, 12, Color("9e3b3b"), r * 0.08)


func _head_with_hair(c: Vector2, r: float, style: int, tint := Color.TRANSPARENT) -> void:
	var col: Color = HAIR_COLOURS[style] if tint.a == 0.0 else tint.darkened(0.2)
	var skin := SKIN if tint.a == 0.0 else tint
	match style:
		1:  # bob: hair behind the face down to the chin
			draw_circle(c + Vector2(0, r * 0.15), r * 1.18, col)
			draw_rect(Rect2(c + Vector2(-r * 1.18, r * 0.15), Vector2(r * 2.36, r * 0.75)), col)
		2:  # ponytail
			draw_circle(c + Vector2(r * 1.05, r * 0.1), r * 0.4, col)
			draw_circle(c + Vector2(r * 1.3, r * 0.55), r * 0.32, col)
			draw_circle(c + Vector2(r * 0.85, -r * 0.35), r * 0.2, Color("e63946"))
		3:  # puffs
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(sx * r * 0.9, -r * 0.75), r * 0.62, col)
	draw_circle(c, r, skin)
	var pts := PackedVector2Array()
	var low := 0.15 if style != 1 else 0.35
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * 1.08)
	pts.append(c + Vector2(r * 1.06, r * low))
	pts.append(c + Vector2(r * 0.6, -r * 0.25))
	pts.append(c + Vector2(-r * 0.6, -r * 0.25))
	pts.append(c + Vector2(-r * 1.06, r * low))
	draw_colored_polygon(pts, col)
	if style == 0:  # tousled tufts
		for k in 4:
			draw_circle(c + Vector2((k - 1.5) * r * 0.42, -r * 0.95), r * 0.24, col)
	if tint.a > 0.0:
		return
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * r * 0.36, r * 0.22), r * 0.12, Color("2b2622"))
	draw_arc(c + Vector2(0, r * 0.45), r * 0.22, 0.3, PI - 0.3, 10, Color("9e3b3b"), r * 0.08)


func _outfit(c: Vector2, s: float, n: int) -> void:
	var cols: Array = OUTFIT_COLOURS[n]
	var top: Color = cols[0]
	var bottom: Color = cols[1]
	var shoe: Color = cols[2]
	# bottoms: shorts for outfit 1, long otherwise
	var leg_len := s * (0.2 if n == 0 else 0.34)
	for sx in [-1.0, 1.0]:
		if n == 0:
			draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.09, s * 0.02), Vector2(s * 0.18, s * 0.34)), SKIN)
		draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.09, s * 0.02), Vector2(s * 0.18, leg_len)), bottom)
		draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.1, s * 0.36), Vector2(s * 0.2, s * 0.08)), shoe)
	if n == 3:  # dungarees bib over a stripy top
		_shirt(c + Vector2(0, -s * 0.18), s * 0.7, top, true)
		draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.2), Vector2(s * 0.3, s * 0.26)), bottom)
	else:
		_shirt(c + Vector2(0, -s * 0.18), s * 0.7, top)
		if n == 2:  # scarf
			draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.38), Vector2(s * 0.24, s * 0.06)), Color("f8f8f2"))
			draw_rect(Rect2(c + Vector2(s * 0.02, -s * 0.36), Vector2(s * 0.07, s * 0.16)), Color("f8f8f2"))
		if n == 1:  # pocket
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.1), Vector2(s * 0.2, s * 0.07)), top.darkened(0.15))


func _shirt(c: Vector2, s: float, col: Color, stripes := false) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-s * 0.22, -s * 0.28), c + Vector2(-s * 0.48, -s * 0.12), c + Vector2(-s * 0.38, s * 0.04),
		c + Vector2(-s * 0.24, -s * 0.04), c + Vector2(-s * 0.24, s * 0.32), c + Vector2(s * 0.24, s * 0.32),
		c + Vector2(s * 0.24, -s * 0.04), c + Vector2(s * 0.38, s * 0.04), c + Vector2(s * 0.48, -s * 0.12),
		c + Vector2(s * 0.22, -s * 0.28), c + Vector2(s * 0.1, -s * 0.22), c + Vector2(-s * 0.1, -s * 0.22),
	])
	draw_colored_polygon(pts, Color.WHITE if stripes else col)
	if stripes:
		for k in 4:
			var y := -s * 0.2 + k * s * 0.13
			draw_rect(Rect2(c + Vector2(-s * 0.46 + (0.0 if y < 0.0 else s * 0.2), y), Vector2(s * (0.92 if y < 0.0 else 0.52), s * 0.05)), col)


func _round_rect(r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _round_rect_outline(r: Rect2, radius: float, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
