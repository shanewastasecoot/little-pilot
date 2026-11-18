class_name Hud
extends CanvasLayer
## In-game display: star icon + count (top right), star jar, and celebrations.
## Built in code; connect it to a StarManager with bind().

var _count_label: Label
var _counter: Control
var _jar: StarJar
var _party: Celebration
var _hint: StickHint
var _city_pointer: CityPointer
var _dragon: DragonWarning
var _news: PanelContainer
var _news_label: Label
var _news_queue: Array[String] = []
var _news_tween: Tween
var _prompt: PanelContainer
var _prompt_icon: UiIcon
var _prompt_kind := ""
var _foot_hints: HBoxContainer
var _hints_tween: Tween


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Soft rounded panel behind the counter and jar so they read on any sky.
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.15, 0.3, 0.35)
	sb.set_corner_radius_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -330
	panel.offset_right = -18
	panel.offset_top = 14
	panel.offset_bottom = 142
	root.add_child(panel)

	_counter = HBoxContainer.new()
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.add_theme_constant_override("separation", 10)
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_counter.position = Vector2(-320, 28)
	_counter.size = Vector2(190, 96)
	_counter.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_counter)
	var star := UiIcon.new()
	star.icon = UiIcon.Icon.STAR
	star.color = Color("ffd23f")
	star.custom_minimum_size = Vector2(88, 88)
	_counter.add_child(star)
	_count_label = Label.new()
	_count_label.text = "0"
	_count_label.add_theme_font_size_override("font_size", 70)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.35))
	_count_label.add_theme_constant_override("outline_size", 14)
	_count_label.custom_minimum_size = Vector2(80, 0)
	_counter.add_child(_count_label)
	_counter.pivot_offset = _counter.size * 0.5

	_jar = StarJar.new()
	_jar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_jar.position = Vector2(-112, 22)
	_jar.size = Vector2(80, 112)
	root.add_child(_jar)

	_party = Celebration.new()
	root.add_child(_party)

	_hint = StickHint.new()
	root.add_child(_hint)

	_city_pointer = CityPointer.new()
	_city_pointer.hide()
	root.add_child(_city_pointer)

	_dragon = DragonWarning.new()
	root.add_child(_dragon)
	root.move_child(_dragon, 0)  # under the counters

	# City news banner: "A new bakery opened!" slides down at the top.
	_news = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.2, 0.38, 0.85)
	style.set_corner_radius_all(26)
	style.content_margin_left = 22
	style.content_margin_right = 30
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_news.add_theme_stylebox_override("panel", style)
	_news.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_news.add_child(row)
	var city_icon := UiIcon.new()
	city_icon.icon = UiIcon.Icon.CITY
	city_icon.color = Color("ffd23f")
	city_icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(city_icon)
	_news_label = Label.new()
	_news_label.add_theme_font_size_override("font_size", 40)
	_news_label.add_theme_color_override("font_color", Color.WHITE)
	_news_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_news_label)
	_news.modulate.a = 0.0
	root.add_child(_news)

	# Button prompt (bottom right): [Y] + what it does (get out / get in).
	_prompt = PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.13, 0.2, 0.38, 0.85)
	pstyle.set_corner_radius_all(30)
	pstyle.content_margin_left = 18
	pstyle.content_margin_right = 22
	pstyle.content_margin_top = 12
	pstyle.content_margin_bottom = 12
	_prompt.add_theme_stylebox_override("panel", pstyle)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 14)
	_prompt.add_child(prow)
	var ybtn := UiIcon.new()
	ybtn.icon = UiIcon.Icon.BUTTON_Y
	ybtn.custom_minimum_size = Vector2(84, 84)
	prow.add_child(ybtn)
	_prompt_icon = UiIcon.new()
	_prompt_icon.custom_minimum_size = Vector2(84, 84)
	prow.add_child(_prompt_icon)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position += Vector2(-34, -34)
	_prompt.modulate.a = 0.0
	root.add_child(_prompt)

	# On-foot hints (bottom centre): [A] jump, [B] run. Shown for a few
	# seconds each time you get out.
	_foot_hints = HBoxContainer.new()
	_foot_hints.add_theme_constant_override("separation", 10)
	_foot_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [[UiIcon.Icon.BUTTON_A, UiIcon.Icon.JUMP], [UiIcon.Icon.BUTTON_B, UiIcon.Icon.RUN]]:
		for k in 2:
			var ic := UiIcon.new()
			ic.icon = pair[k]
			ic.custom_minimum_size = Vector2(70, 70)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_foot_hints.add_child(ic)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(36, 0)
		_foot_hints.add_child(gap)
	_foot_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_foot_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_foot_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_foot_hints.position.y -= 40
	_foot_hints.modulate.a = 0.0
	root.add_child(_foot_hints)


## The dragon warning: on while it hunts the plane. angle: where it is
## relative to the camera (0 ahead, + right); closeness 0..1.
func set_dragon_warning(on: bool, angle := 0.0, closeness := 0.0, breathing := false) -> void:
	_dragon.active = on
	_dragon.angle = angle
	_dragon.closeness = closeness
	_dragon.breathing = breathing


## Show/update the city arrow. seconds < 0 means the fireworks are on.
func show_city_pointer(angle: float, seconds: int) -> void:
	_city_pointer.angle = angle
	_city_pointer.fireworks_on = seconds < 0
	_city_pointer.seconds_left = maxi(seconds, 0)
	_city_pointer.show_arrow = SaveManager.city_arrow
	_city_pointer.show()


func hide_city_pointer() -> void:
	_city_pointer.hide()


func show_idle_hint(on: bool, instant := false) -> void:
	if instant and not on:
		_hint.hide_now()
	else:
		_hint.showing = on


func bind(stars: StarManager) -> void:
	stars.star_collected.connect(_on_star_collected)
	stars.milestone_reached.connect(func(_n): _party.play(false))
	stars.all_collected.connect(func(): _party.play(true))


## The Y button prompt: "exit" (get out and walk), "enter" (get back in
## the plane) or "" (hidden).
func set_prompt(kind: String) -> void:
	if kind == _prompt_kind:
		return
	_prompt_kind = kind
	if kind != "":
		_prompt_icon.icon = UiIcon.Icon.PERSON if kind == "exit" else UiIcon.Icon.PLANE
	create_tween().tween_property(_prompt, "modulate:a", 1.0 if kind != "" else 0.0, 0.2)


func prompt_kind() -> String:
	return _prompt_kind


## Show the on-foot button hints for a few seconds (or hide them now).
func show_foot_hints(on: bool) -> void:
	if _hints_tween:
		_hints_tween.kill()
	_hints_tween = create_tween()
	if on:
		_hints_tween.tween_property(_foot_hints, "modulate:a", 1.0, 0.3)
		_hints_tween.tween_interval(5.0)
	_hints_tween.tween_property(_foot_hints, "modulate:a", 0.0, 0.5)


func foot_hints_showing() -> bool:
	return _foot_hints.modulate.a > 0.01


## City news: a banner at the top for a few seconds, with bells. Several
## at once queue up.
func show_news(text: String) -> void:
	_news_queue.append(text)
	if _news_queue.size() == 1:
		_show_next_news()


func _show_next_news() -> void:
	if _news_queue.is_empty():
		return
	_news_label.text = _news_queue[0]
	_news.reset_size()
	var w := get_viewport().get_visible_rect().size.x
	var x := (w - _news.size.x) * 0.5
	_news.position = Vector2(x, -90)
	Sfx.play("bells", 1.0, -4.0)
	if _news_tween:
		_news_tween.kill()
	_news_tween = create_tween()
	_news_tween.tween_property(_news, "position:y", 150.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_news_tween.parallel().tween_property(_news, "modulate:a", 1.0, 0.3)
	_news_tween.tween_interval(4.0)
	_news_tween.tween_property(_news, "modulate:a", 0.0, 0.5)
	_news_tween.tween_callback(func():
		_news_queue.pop_front()
		_show_next_news())


## Small party when a new landmark is found (doesn't interrupt flying).
func celebrate_discovery() -> void:
	_party.play(false)


func _on_star_collected(count: int, total: int) -> void:
	_count_label.text = str(count)
	_jar.target_fill = float(count) / maxf(total, 1)
	if count > 0:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_counter.scale = Vector2.ONE * 1.35
		tw.tween_property(_counter, "scale", Vector2.ONE, 0.35)
