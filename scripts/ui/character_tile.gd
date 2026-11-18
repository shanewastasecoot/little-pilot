class_name CharacterTile
extends Button
## One choice on the character screen, drawn as a picture so it needs no
## reading: a boy or girl face (body), a head with that hairstyle (hair), or
## a little set of clothes in that outfit's colours (outfit). Selected tiles
## get a thick white border and pop up a little.

enum Kind { BODY, HAIR, OUTFIT, TAB }

## Colours match tools/blender/build_characters.py.
const SKIN := Color("f7c9a8")
## Long princess waves, short tousled, ponytail with a bow, bob with a band.
const HAIR_COLOURS := [Color("f5cf6a"), Color("7a4a2a"), Color("c0602e"), Color("2e2420")]
## [top, bottoms/skirt, shoes, trim] per outfit: pink gown, blue gown,
## pilot, explorer.
const OUTFIT_COLOURS := [
	[Color("f06aa8"), Color("ffa6d6"), Color("f06aa8"), Color("ffd23f")],
	[Color("4a9be8"), Color("8fd0ff"), Color("4a9be8"), Color("dfe6f0")],
	[Color("8b5a2b"), Color("c9b27c"), Color("4a3324"), Color("f1e2c6")],
	[Color("d8c38a"), Color("a68a52"), Color("6b4a2b"), Color("fafaf5")],
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
	var hair: Color = HAIR_COLOURS[1] if not girl else HAIR_COLOURS[0]
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
		0:  # long waves: ringlets down both sides and behind
			for sx in [-1.0, 1.0]:
				for k in 3:
					draw_circle(c + Vector2(sx * r * 0.98, r * (0.1 + k * 0.45)), r * 0.3, col)
		2:  # ponytail with a pink bow
			draw_circle(c + Vector2(r * 1.05, r * 0.1), r * 0.4, col)
			draw_circle(c + Vector2(r * 1.3, r * 0.55), r * 0.32, col)
		3:  # bob
			draw_circle(c + Vector2(0, r * 0.1), r * 1.16, col)
			draw_rect(Rect2(c + Vector2(-r * 1.16, r * 0.1), Vector2(r * 2.32, r * 0.55)), col)
	draw_circle(c, r, skin)
	var pts := PackedVector2Array()
	var low := 0.1 if style != 3 else 0.3
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * 1.08)
	pts.append(c + Vector2(r * 1.06, r * low))
	pts.append(c + Vector2(r * 0.6, -r * 0.42))
	pts.append(c + Vector2(-r * 0.6, -r * 0.42))
	pts.append(c + Vector2(-r * 1.06, r * low))
	draw_colored_polygon(pts, col)
	if style == 0:  # side-swept fringe
		draw_circle(c + Vector2(-r * 0.25, -r * 0.62), r * 0.38, col)
	if style == 1:  # tousled tufts and a cowlick
		for k in 4:
			draw_circle(c + Vector2((k - 1.5) * r * 0.42, -r * 0.95), r * 0.24, col)
		draw_line(c + Vector2(r * 0.1, -r * 1.1), c + Vector2(r * 0.25, -r * 1.4), col, r * 0.14)
	if style == 2 and tint.a == 0.0:  # bow
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(r * 0.85 + sx * r * 0.22, -r * 0.55), r * 0.2, Color("ff6fae"))
	if style == 3:  # red headband
		draw_arc(c, r * 1.12, PI + 0.35, TAU - 0.35, 16, Color("e63946") if tint.a == 0.0 else tint, r * 0.16)
	if tint.a > 0.0:
		return
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * r * 0.36, r * 0.2), r * 0.17, Color.WHITE)
		draw_circle(c + Vector2(sx * r * 0.37, r * 0.22), r * 0.12, Color("3a8fd9"))
		draw_circle(c + Vector2(sx * r * 0.37, r * 0.23), r * 0.06, Color("1c1a24"))
	draw_arc(c + Vector2(0, r * 0.45), r * 0.24, 0.3, PI - 0.3, 10, Color("c2454e"), r * 0.08)


func _outfit(c: Vector2, s: float, n: int) -> void:
	var cols: Array = OUTFIT_COLOURS[n]
	var top: Color = cols[0]
	var bottom: Color = cols[1]
	var shoe: Color = cols[2]
	var trim: Color = cols[3]
	if n <= 1:  # ball gown: bell skirt, puffed sleeves, crown above
		var skirt := PackedVector2Array([c + Vector2(-s * 0.12, -s * 0.02), c + Vector2(s * 0.12, -s * 0.02),
			c + Vector2(s * 0.36, s * 0.4), c + Vector2(-s * 0.36, s * 0.4)])
		draw_colored_polygon(skirt, bottom)
		draw_rect(Rect2(c + Vector2(-s * 0.37, s * 0.37), Vector2(s * 0.74, s * 0.05)), trim)
		draw_rect(Rect2(c + Vector2(-s * 0.13, -s * 0.28), Vector2(s * 0.26, s * 0.28)), top)
		draw_rect(Rect2(c + Vector2(-s * 0.13, -s * 0.04), Vector2(s * 0.26, s * 0.04)), trim)
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(sx * s * 0.17, -s * 0.24), s * 0.08, top)
		# crown / tiara
		var cy := -s * 0.38
		var pts := PackedVector2Array([c + Vector2(-s * 0.12, cy + s * 0.06), c + Vector2(-s * 0.12, cy - s * 0.03),
			c + Vector2(-s * 0.06, cy + s * 0.02), c + Vector2(0, cy - s * 0.06), c + Vector2(s * 0.06, cy + s * 0.02),
			c + Vector2(s * 0.12, cy - s * 0.03), c + Vector2(s * 0.12, cy + s * 0.06)])
		draw_colored_polygon(pts, trim if n == 0 else Color("dfe6f0"))
		draw_circle(c + Vector2(0, cy + s * 0.025), s * 0.022, Color("e63946") if n == 0 else Color("3aa0ff"))
		return
	var leg_len := s * (0.34 if n == 2 else 0.18)
	for sx in [-1.0, 1.0]:
		if n == 3:
			draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.08, s * 0.02), Vector2(s * 0.16, s * 0.34)), SKIN)
			draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.08, s * 0.24), Vector2(s * 0.16, s * 0.1)), trim)
		draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.09, s * 0.02), Vector2(s * 0.18, leg_len)), bottom)
		draw_rect(Rect2(c + Vector2(sx * s * 0.11 - s * 0.11, s * 0.34), Vector2(s * 0.22, s * 0.1)), shoe)
	_shirt(c + Vector2(0, -s * 0.18), s * 0.7, top)
	if n == 2:  # fur collar, scarf, goggles
		draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.4), Vector2(s * 0.32, s * 0.07)), trim)
		draw_rect(Rect2(c + Vector2(s * 0.04, -s * 0.36), Vector2(s * 0.07, s * 0.18)), Color("fafaf5"))
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(sx * s * 0.08, -s * 0.5), s * 0.06, Color("b8860b"))
			draw_circle(c + Vector2(sx * s * 0.08, -s * 0.5), s * 0.04, Color("9fd8ff"))
	else:  # explorer: pockets, belt, satchel strap
		for sx in [-1.0, 1.0]:
			draw_rect(Rect2(c + Vector2(sx * s * 0.1 - s * 0.05, -s * 0.28), Vector2(s * 0.1, s * 0.07)), top.darkened(0.12))
		draw_rect(Rect2(c + Vector2(-s * 0.17, -s * 0.02), Vector2(s * 0.34, s * 0.04)), Color("5b3a1e"))
		draw_line(c + Vector2(s * 0.16, -s * 0.4), c + Vector2(-s * 0.2, s * 0.02), Color("8b5a2b"), s * 0.04)
		draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.02), Vector2(s * 0.13, s * 0.11)), Color("8b5a2b"))


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
