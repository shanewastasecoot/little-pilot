class_name HatMenu
extends Control
## The hat chooser, opened with Y at the hat shop's mirror (no words, all
## pictures): a row of hats sliding left and right (the first is "no hat":
## her outfit's own); the one in the middle is on her head straight away.
## Under it: a green tick if it's hers already, or its price as little
## stars (gold if she has enough, grey if not). Her stars to spend are in
## the corner. A wears it (buying it first: the stars fly from her purse to
## the hat); a hat she can't afford wobbles "not yet". B puts back the hat
## she came in with. The stick (or D-pad) moves.

signal chosen(id: String)
signal cancelled

const ICON := 110.0
const GAP := 26.0
const SHOWN := 5
const STEP_DELAY := 0.25
const BUY_TIME := 0.8

## "" (no hat) and then every hat, in shop order.
var options: Array[String] = []
var index := 0
var _start := 0
var _cool := 0.0
var _open := false
var _t := 0.0
var _shake := 0.0
var _buying := -1.0
var _bought_price := 0
var _icons := {}
## Called with the hat id whenever the highlighted hat changes.
var preview := func(_id: String) -> void: pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	options.assign([""] + Hats.ids())
	for id in Hats.ids():
		_icons[id] = load("res://assets/ui/hats/%s.png" % id)


func is_open() -> bool:
	return _open


func open(current: String) -> void:
	_start = maxi(options.find(current), 0)
	index = _start
	_open = true
	_buying = -1.0
	_cool = 0.25  # don't take the Y that opened it as anything else
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	Sfx.play("ui_confirm", 1.1, -4.0)
	preview.call(options[index])


func current() -> String:
	return options[index]


## Move the highlight by `dir` (wraps round).
func move(dir: int) -> void:
	if not _open or _buying >= 0.0:
		return
	index = posmod(index + dir, options.size())
	_shake = 0.0
	Sfx.play("ui_move", 1.0 + (index % 8) * 0.06)
	preview.call(options[index])
	queue_redraw()


## Is the highlighted hat hers already (or "no hat")?
func owned(i := -1) -> bool:
	var id := options[index if i < 0 else i]
	return id == "" or SaveManager.hats_owned.has(id)


func affordable(i := -1) -> bool:
	return owned(i) or SaveManager.star_purse() >= Hats.price(options[index if i < 0 else i])


## A: wear it (buying it first if need be), or wobble if she can't yet.
func confirm() -> void:
	if not _open or _buying >= 0.0:
		return
	if not affordable():
		_shake = 0.6
		Sfx.play("ui_back", 0.8)
		return
	if owned():
		_close()
		Sfx.play("chime", 1.3)
		chosen.emit(options[index])
		return
	# Buy: the stars fly over first, then it closes.
	_bought_price = Hats.price(options[index])
	_buying = 0.0
	Sfx.play("chime", 0.9)


func cancel() -> void:
	if not _open or _buying >= 0.0:
		return
	_close()
	Sfx.play("ui_back")
	preview.call(options[_start])
	cancelled.emit()


func _close() -> void:
	_open = false
	create_tween().tween_property(self, "modulate:a", 0.0, 0.15).finished.connect(func(): if not _open: visible = false)


func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	_shake = maxf(_shake - delta, 0.0)
	queue_redraw()
	if _buying >= 0.0:
		_buying += delta
		if _buying >= BUY_TIME:
			_buying = -1.0
			_close()
			Sfx.play("chime", 1.3)
			chosen.emit(options[index])
		return
	_cool -= delta
	if _cool > 0.0:
		return
	var x := Input.get_axis("move_left", "move_right")
	if Input.is_action_pressed("ui_left"):
		x = -1.0
	elif Input.is_action_pressed("ui_right"):
		x = 1.0
	if absf(x) > 0.5:
		move(1 if x > 0.0 else -1)
		_cool = STEP_DELAY
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		confirm()
	elif Input.is_action_just_pressed("sprint") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("interact"):
		cancel()


func _panel() -> Rect2:
	var width := SHOWN * ICON + (SHOWN - 1) * GAP
	return Rect2(size.x * 0.5 - width * 0.5 - 40.0, size.y - 300.0, width + 80.0, 280.0)


## Where the purse is drawn (stars fly from here when buying).
func _purse_point() -> Vector2:
	var p := _panel()
	return Vector2(p.end.x - 70.0, p.position.y + 46.0)


func _draw() -> void:
	var panel := _panel()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.2, 0.82)
	sb.set_corner_radius_all(36)
	draw_style_box(sb, panel)
	# The hats: the highlighted one in the middle, two either side.
	var mid := Vector2(size.x * 0.5, panel.position.y + 150.0)
	var shake := sin(_t * 40.0) * 10.0 * _shake
	for k in range(-(SHOWN / 2), SHOWN / 2 + 1):
		var i := posmod(index + k, options.size())
		var c := mid + Vector2(k * (ICON + GAP) + (shake if k == 0 else 0.0), 0)
		var r := ICON * (0.56 if k == 0 else 0.4)
		if k == 0:
			r += sin(_t * 6.0) * 3.0
			draw_circle(c, r + 10.0, Color.WHITE)
		draw_circle(c, r, Color("2a2c3a") if k == 0 else Color("2a2c3a", 0.7))
		_draw_hat(i, c, r, k == 0)
	# Under the middle one: a tick if it's hers, else its price in stars.
	var below := mid + Vector2(shake, ICON * 0.56 + 40.0)
	if owned():
		draw_polyline(PackedVector2Array([below + Vector2(-16, 0), below + Vector2(-4, 13), below + Vector2(18, -12)]), Color("43c463"), 8.0, true)
	else:
		_price_stars(below, Hats.price(options[index]), affordable())
	# Her stars to spend: a big star and the number.
	var pp := _purse_point()
	var shown_purse := SaveManager.star_purse() - (int(_bought_price * clampf(_buying / BUY_TIME, 0.0, 1.0)) if _buying >= 0.0 else 0)
	draw_colored_polygon(UiIcon.star_points(pp + Vector2(-34, 0), 24.0, 11.0), Color("ffd23f"))
	draw_string(get_theme_default_font(), pp + Vector2(-6, 14), str(shown_purse), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
	# Buying: the stars fly from the purse to the hat.
	if _buying >= 0.0:
		for s in _bought_price:
			var u := clampf((_buying / BUY_TIME) * 1.6 - s * 0.06, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var p := pp.lerp(mid, u) + Vector2(0, -sin(u * PI) * 80.0)
			draw_colored_polygon(UiIcon.star_points(p, 16.0, 7.0), Color("ffd23f"))
	# A and B hints: tick to wear, cross to put back.
	_button_hint(Vector2(panel.position.x + 70.0, panel.position.y + 46.0), Color("ff5d5d"), false)
	_button_hint(Vector2(panel.end.x - 70.0, panel.end.y - 46.0), Color("43c463"), true)


## Hat `i`'s picture in a circle (or "no hat": her outfit's own, a head).
func _draw_hat(i: int, c: Vector2, r: float, big: bool) -> void:
	var id := options[i]
	if id == "":
		draw_circle(c + Vector2(0, r * 0.12), r * 0.42, Color("f1d7b8"))
		draw_circle(c + Vector2(-r * 0.14, r * 0.06), r * 0.05, Color("1c1d26"))
		draw_circle(c + Vector2(r * 0.14, r * 0.06), r * 0.05, Color("1c1d26"))
		draw_arc(c + Vector2(0, r * 0.18), r * 0.14, 0.3, PI - 0.3, 10, Color("1c1d26"), 3.0)
		return
	var tex: Texture2D = _icons.get(id)
	if tex:
		var s := r * 1.7
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color.WHITE if big or owned(i) or affordable(i) else Color(1, 1, 1, 0.55))
	if not big and owned(i):
		draw_circle(c + Vector2(r * 0.7, r * 0.7), r * 0.26, Color("43c463"))


## `n` little stars in a row (two rows past 5), gold or grey.
func _price_stars(c: Vector2, n: int, gold: bool) -> void:
	var per_row := 5 if n > 5 else n
	var rows := ceili(n / 5.0)
	for k in n:
		var row := k / per_row
		var in_row := mini(per_row, n - row * per_row)
		var col := k % per_row
		var p := c + Vector2((col - (in_row - 1) * 0.5) * 34.0, (row - (rows - 1) * 0.5) * 32.0)
		draw_colored_polygon(UiIcon.star_points(p, 15.0, 7.0), Color("ffd23f") if gold else Color("8a8d99"))


func _button_hint(c: Vector2, col: Color, tick: bool) -> void:
	draw_circle(c, 30.0, Color("1c1d26"))
	draw_arc(c, 30.0, 0.0, TAU, 32, Color.WHITE, 3.0)
	if tick:
		draw_polyline(PackedVector2Array([c + Vector2(-13, 0), c + Vector2(-3, 11), c + Vector2(14, -10)]), col, 6.0, true)
	else:
		draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), col, 6.0, true)
		draw_line(c + Vector2(11, -11), c + Vector2(-11, 11), col, 6.0, true)
