extends Node
## Renders Steam library artwork for the non-Steam game shortcut, straight
## from the game world. Needs a window (not --headless):
##   flatpak run org.godotengine.Godot --path . res://tools/steam_art.tscn
## Output: ~/LittlePilot-builds/steam-art/ (grid, capsule, hero, logo, icon)

const SHOTS := {
	# name: [size, camera pos, look-at, plane offset (ahead, right, up) from
	#        the camera, plane heading relative to the view (deg), with logo]
	"grid_portrait": [Vector2i(600, 900), Vector3(-200, 70, 60), Vector3(-150, 55, -60), Vector3(13, 0, -2.5), 50.0, true],
	"grid_wide": [Vector2i(920, 430), Vector3(-330, 60, 40), Vector3(-200, 48, -10), Vector3(14, 3, -1.5), 60.0, true],
	"hero": [Vector2i(1920, 620), Vector3(-420, 75, 140), Vector3(-120, 60, -260), Vector3(16, -7, -2), 55.0, false],
}

var _out := OS.get_environment("HOME") + "/LittlePilot-builds/steam-art"
var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.use_path("user://steam_art.cfg")
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	for ui in ["TitleScreen", "Hud", "DebugHud"]:
		_main.get_node(ui).hide()
	var plane: Aircraft = _main.get_node("Aircraft")
	plane.set_physics_process(false)  # hold the pose
	for name in SHOTS:
		var s: Array = SHOTS[name]
		var dir: Vector3 = (s[2] - s[1]).normalized()
		var right := dir.cross(Vector3.UP).normalized()
		var off: Vector3 = s[3]
		var view_yaw := atan2(-dir.x, -dir.z)
		plane.teleport(s[1] + dir * off.x + right * off.y + Vector3.UP * off.z, view_yaw + deg_to_rad(s[4]))
		plane.visuals.rotation.z = deg_to_rad(-18)  # a happy bank
		await _render(name, s[0], s[1], s[2], s[5])
	await _render_logo()
	_render_icon()
	print("Steam artwork written to ", _out)
	get_tree().quit()


func _render(name: String, size: Vector2i, cam_pos: Vector3, look: Vector3, logo: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.world_3d = get_viewport().world_3d
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	vp.add_child(cam)
	cam.look_at_from_position(cam_pos, look)
	cam.current = true
	if logo:
		var label := _logo_label(int(size.x * 0.15))
		label.size = Vector2(size.x, size.y * 0.3)
		label.position = Vector2(0, size.y * 0.04)
		vp.add_child(label)
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	vp.queue_free()


func _render_logo() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 400)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var label := _logo_label(190)
	label.size = Vector2(1280, 400)
	vp.add_child(label)
	for i in 3:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_out + "/logo.png")
	vp.queue_free()


func _render_icon() -> void:
	var img := Image.new()
	img.load_svg_from_buffer(FileAccess.get_file_as_bytes("res://icon.svg"), 2.0)
	img.save_png(_out + "/icon.png")


func _logo_label(font_size: int) -> Label:
	var l := Label.new()
	l.text = "Little Pilot"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("ffd23f"))
	l.add_theme_color_override("font_outline_color", Color("ff5a5f"))
	l.add_theme_constant_override("outline_size", maxi(font_size / 4, 8))
	return l
