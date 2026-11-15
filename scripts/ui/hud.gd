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
