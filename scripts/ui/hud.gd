class_name Hud
extends CanvasLayer
## In-game display: star icon + count (top right), star jar, and celebrations.
## Built in code; connect it to a StarManager with bind().

var _count_label: Label
var _counter: Control
var _jar: StarJar
var _party: Celebration


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_counter = HBoxContainer.new()
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.add_theme_constant_override("separation", 10)
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_counter.position = Vector2(-300, 28)
	_counter.size = Vector2(170, 90)
	_counter.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_counter)
	var star := UiIcon.new()
	star.icon = UiIcon.Icon.STAR
	star.color = Color("ffd23f")
	star.custom_minimum_size = Vector2(80, 80)
	_counter.add_child(star)
	_count_label = Label.new()
	_count_label.text = "0"
	_count_label.add_theme_font_size_override("font_size", 64)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.35))
	_count_label.add_theme_constant_override("outline_size", 14)
	_count_label.custom_minimum_size = Vector2(80, 0)
	_counter.add_child(_count_label)
	_counter.pivot_offset = _counter.size * 0.5

	_jar = StarJar.new()
	_jar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_jar.position = Vector2(-110, 20)
	_jar.size = Vector2(80, 110)
	root.add_child(_jar)

	_party = Celebration.new()
	root.add_child(_party)


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
