class_name HoldButton
extends BigButton
## A BigButton that must be held (A button, Enter or a finger) for
## `hold_time` seconds. Used for Quit so a child can't leave by accident.
## A ring fills up while holding; letting go early resets it.

signal held

@export var hold_time: float = 2.0

var progress: float = 0.0
var _pointer_down := false


func _ready() -> void:
	super()
	button_down.connect(func(): _pointer_down = true)
	button_up.connect(func(): _pointer_down = false)


func _process(delta: float) -> void:
	var holding := _pointer_down or (has_focus() and Input.is_action_pressed("ui_accept"))
	if not is_visible_in_tree():
		holding = false
	var before := progress
	progress = clampf(progress + (delta / hold_time if holding else -delta * 3.0), 0.0, 1.0)
	if progress >= 1.0 and before < 1.0:
		progress = 0.0
		_pointer_down = false
		held.emit()
	if progress != before:
		queue_redraw()


func _draw() -> void:
	if progress <= 0.0:
		return
	var r := minf(size.x, size.y) * 0.5 - 10.0
	draw_arc(size * 0.5, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color.WHITE, 12.0, true)


func _on_pressed() -> void:
	pass  # a tap does nothing; only a full hold counts
