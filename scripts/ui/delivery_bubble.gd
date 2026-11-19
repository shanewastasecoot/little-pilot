class_name DeliveryBubble
extends Control
## Top-left while carrying a parcel: a round picture of who it's for (their
## own character, rendered once into a little viewport), ringed in their
## colour, with a parcel badge and a bobbing arrow round the bubble that
## points their way (relative to where the camera looks). No text.

const R := 78.0
const PORTRAIT := 256

var angle := 0.0          # radians, 0 = ahead, + = to the right
var show_arrow := true
var colour := Color("ffd23f")
var _t := 0.0
var _viewport: SubViewport
var _stage: Node3D
var _who: CharacterModel
var _picture: TextureRect

const MASK := """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.47, 0.5, d);
}
"""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(24, 24)
	size = Vector2(R * 2.0 + 70.0, R * 2.0 + 70.0)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PORTRAIT, PORTRAIT)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bfe3ff")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.environment.ambient_light_energy = 0.75
	_stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -30, 0)
	_stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 4.3, 8.4)
	cam.rotation_degrees.x = -7.0
	_stage.add_child(cam)
	_picture = TextureRect.new()
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.position = Vector2(35, 35)
	_picture.size = Vector2(R * 2.0, R * 2.0)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MASK
	m.shader = sh
	_picture.material = m
	add_child(_picture)
	hide()


## Show the bubble for `who` (or hide it with null).
func set_recipient(who: RecipientData) -> void:
	if _who:
		_who.queue_free()
		_who = null
	if who == null:
		hide()
		return
	colour = who.colour
	_who = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	_who.look_override = who.look
	_who.head_override = who.head
	_who.rotation.y = PI + 0.35  # facing the camera, a little turned
	_stage.add_child(_who)
	show()
	_render_portrait()
	# Pop in.
	scale = Vector2.ONE * 0.3
	pivot_offset = Vector2(35 + R, 35 + R)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.45)


## Draw the picture a few times while the idle pose settles, then keep it
## (UPDATE_ONCE each frame for a few frames: no ongoing cost).
func _render_portrait() -> void:
	var who := _who
	if who:
		who.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 6:
		if not is_inside_tree():
			return
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
	if is_instance_valid(who) and who == _who:
		who.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := Vector2(35 + R, 35 + R)
	draw_circle(c, R + 9.0, Color(0.08, 0.15, 0.3, 0.55))
	draw_arc(c, R + 4.0, 0, TAU, 64, colour, 9.0, true)
	draw_arc(c, R + 9.0, 0, TAU, 64, Color.WHITE, 3.0, true)
	# Parcel badge at the bottom right: "a parcel for them".
	var b := c + Vector2(R * 0.72, R * 0.72)
	draw_circle(b, 26.0, Color.WHITE)
	var box := Rect2(b - Vector2(15, 12), Vector2(30, 24))
	draw_rect(box, Color("d9a066"))
	draw_rect(Rect2(b - Vector2(3, 12), Vector2(6, 24)), Color("e63946"))
	draw_rect(Rect2(b - Vector2(15, 3), Vector2(30, 6)), Color("e63946"))
	draw_circle(b + Vector2(-5, -14), 5.0, Color("e63946"))
	draw_circle(b + Vector2(5, -14), 5.0, Color("e63946"))
	if not show_arrow:
		return
	var dir := Vector2(sin(angle), -cos(angle))
	var bob := 6.0 + sin(_t * 6.0) * 5.0
	var tip := c + dir * (R + 46.0 + bob)
	var base := c + dir * (R + 14.0 + bob)
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, base + side * 24.0, base + dir * 8.0, base - side * 24.0])
	draw_colored_polygon(pts, colour)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.1, 0.15, 0.3), 4.0, true)
