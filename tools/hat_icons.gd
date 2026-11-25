extends Node
## Renders the hat shop's menu pictures (assets/ui/hats/<id>.png): each hat
## from props.glb on a transparent background, seen a little from the front
## and above. Run: godot --path . res://tools/hat_icons.tscn
## (Needs a window: it renders.)

const OUT := "res://assets/ui/hats/"
const SIZE := 256


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in Hats.ids():
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		var hat := CharacterLook.prop(Hats.prop_of(id))
		vp.add_child(hat)
		var box: AABB = hat.get_aabb()
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(1, 1, 1)
		env.environment.ambient_light_energy = 0.55
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, 30, 0)
		sun.light_energy = 1.1
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var c := box.get_center()
		cam.size = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.35
		vp.add_child(cam)
		# KayKit faces +Z: look from the front, a little above and to the side.
		var dir := Vector3(0.45, 0.55, 1.0).normalized()
		cam.look_at_from_position(c + dir * 10.0, c, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + id + ".png")
		print("saved ", id)
		vp.queue_free()
	get_tree().quit()
