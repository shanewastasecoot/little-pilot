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
## Where they are (a little picture at the bubble's bottom left).
var place := ""
const MERMAID_PORTRAIT_SCALE := 4.0
const MERMAID_PORTRAIT_Y := 0.2
var _t := 0.0
var _viewport: SubViewport
var _stage: Node3D
var _who: Node3D
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
	place = who.place
	if who.kind == "mermaid":
		# A mermaid's portrait: her model, framed like the people.
		_who = (load("res://scenes/characters/mermaid.tscn") as PackedScene).instantiate()
		_who.set("tail_color", who.tail_colour)
		_who.scale = Vector3.ONE * MERMAID_PORTRAIT_SCALE
		_who.position = Vector3(0, MERMAID_PORTRAIT_Y, 0)
	else:
		var person := (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
		person.look_override = who.look
		person.head_override = who.head
		_who = person
	# Facing the camera, a little turned (the mermaid model faces the other way).
	_who.rotation.y = 0.35 if who.kind == "mermaid" else PI + 0.35
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
	_draw_place(c + Vector2(-R * 0.72, R * 0.72), 26.0)
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


## A tiny picture of where they are, in a white badge.
func _draw_place(b: Vector2, r: float) -> void:
	draw_circle(b, r, Color.WHITE)
	var k := r / 26.0
	match place:
		"sea":
			# Waves and a rock.
			draw_circle(b + Vector2(0, 2) * k, 9.0 * k, Color("8a8f99"))
			for row in 2:
				var pts := PackedVector2Array()
				for i in 9:
					pts.append(b + Vector2(-16 + i * 4, 8 + row * 6 + (2.0 if i % 2 else -2.0)) * k)
				draw_polyline(pts, Color("3a8fd9"), 3.0 * k, true)
		"airport":
			# A little plane seen from above.
			draw_rect(Rect2(b + Vector2(-3, -15) * k, Vector2(6, 30) * k), Color("e63946"))
			draw_rect(Rect2(b + Vector2(-16, -5) * k, Vector2(32, 7) * k), Color("e63946"))
			draw_rect(Rect2(b + Vector2(-7, 10) * k, Vector2(14, 4) * k), Color("e63946"))
		"farm":
			draw_rect(Rect2(b + Vector2(-13, -3) * k, Vector2(26, 17) * k), Color("d64545"))
			draw_colored_polygon(PackedVector2Array([b + Vector2(-16, -2) * k, b + Vector2(0, -16) * k, b + Vector2(16, -2) * k]), Color("8b2e2e"))
			draw_rect(Rect2(b + Vector2(-4, 4) * k, Vector2(8, 10) * k), Color.WHITE)
		"lighthouse":
			for i in 3:
				draw_rect(Rect2(b + Vector2(-6 + i, -8 + i * 7) * k, Vector2(12 - i * 2, 7) * k), Color("e63946") if i % 2 == 0 else Color("dddddd"))
			draw_circle(b + Vector2(0, -13) * k, 5.0 * k, Color("ffd23f"))
		"city":
			draw_rect(Rect2(b + Vector2(-15, -4) * k, Vector2(9, 18) * k), Color("4aa8ff"))
			draw_rect(Rect2(b + Vector2(-5, -16) * k, Vector2(10, 30) * k), Color("2f6fdb"))
			draw_rect(Rect2(b + Vector2(6, -8) * k, Vector2(9, 22) * k), Color("7cc4ff"))
		"town":
			draw_rect(Rect2(b + Vector2(-15, 0) * k, Vector2(16, 13) * k), Color("ffd23f"))
			draw_colored_polygon(PackedVector2Array([b + Vector2(-17, 1) * k, b + Vector2(-7, -9) * k, b + Vector2(3, 1) * k]), Color("ff5a5f"))
			draw_rect(Rect2(b + Vector2(5, -14) * k, Vector2(9, 27) * k), Color("e9d8b4"))
			draw_circle(b + Vector2(9.5, -7) * k, 3.5 * k, Color("4a4a4a"))
		"ice":
			for i in 3:
				var d := Vector2.from_angle(i * PI / 3.0) * 15.0 * k
				draw_line(b - d, b + d, Color("4cc9f0"), 3.5 * k, true)
			draw_circle(b, 3.0 * k, Color("4cc9f0"))
		"dino":
			draw_circle(b + Vector2(-2, 4) * k, 11.0 * k, Color("4cc06a"))
			draw_rect(Rect2(b + Vector2(4, -14) * k, Vector2(6, 16) * k), Color("4cc06a"))
			draw_circle(b + Vector2(9, -14) * k, 5.0 * k, Color("4cc06a"))
			for i in 3:
				var x := -12.0 + i * 7.0
				draw_colored_polygon(PackedVector2Array([b + Vector2(x - 3, -5) * k, b + Vector2(x, -12) * k, b + Vector2(x + 3, -5) * k]), Color("ff9f1c"))
		"castle":
			draw_rect(Rect2(b + Vector2(-13, -6) * k, Vector2(26, 20) * k), Color("9a96a3"))
			for i in 3:
				draw_rect(Rect2(b + Vector2(-13 + i * 10, -11) * k, Vector2(6, 6) * k), Color("9a96a3"))
			draw_rect(Rect2(b + Vector2(-4, 4) * k, Vector2(8, 10) * k), Color("5a4a6a"))
			draw_line(b + Vector2(0, -11) * k, b + Vector2(0, -20) * k, Color("5a4a6a"), 2.0 * k)
			draw_colored_polygon(PackedVector2Array([b + Vector2(0, -20) * k, b + Vector2(9, -17) * k, b + Vector2(0, -14) * k]), Color("ff5fa2"))
