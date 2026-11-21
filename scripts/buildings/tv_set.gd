class_name TVSet
extends Node3D
## A TV on a low cabinet. It switches on when you come into the room (the
## little TvShow plays on its screen) and off when you leave, so it costs
## nothing while nobody's watching. Origin on the floor at the cabinet's
## centre; the screen faces +Z.

const ON_RADIUS := 26.0

## Screen size (metres) and how big the cabinet is (furniture scale).
var screen_size := Vector2(8.0, 4.6)
var furniture_scale := 2.27
var _viewport: SubViewport
var _screen: MeshInstance3D
var _on_mat: StandardMaterial3D
var _off_mat: StandardMaterial3D
var _on := false
var _player: Node3D
var _t := 0.0


func _ready() -> void:
	var stand: Node3D = (load(BuildingGenerator.FURNITURE + "cabinet_medium.gltf") as PackedScene).instantiate()
	stand.scale = Vector3.ONE * furniture_scale
	add_child(stand)
	BuildKit.collider(self, BuildKit.box_shape(Vector3(2.0, 1.0, 1.0) * furniture_scale), Vector3(0, 0.5, 0) * furniture_scale)
	var top := 1.0 * furniture_scale
	var body := BuildKit.add(self, BuildKit.box(Vector3(screen_size.x + 0.6, screen_size.y + 0.6, 0.5)), "26262e",
			Vector3(0, top + 0.5 + screen_size.y * 0.5 + 0.3, -0.1))
	body.material_override = BuildingGenerator._mat("26262e")
	BuildKit.add(self, BuildKit.box(Vector3(1.6, 0.5, 0.9)), "26262e", Vector3(0, top + 0.25, -0.1)).material_override = BuildingGenerator._mat("26262e")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 184)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var show := TvShow.new()
	show.size = Vector2(320, 184)
	_viewport.add_child(show)
	show.process_mode = Node.PROCESS_MODE_DISABLED
	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = screen_size
	_screen.mesh = quad
	_screen.position = Vector3(0, top + 0.5 + screen_size.y * 0.5 + 0.3, 0.17)
	_on_mat = StandardMaterial3D.new()
	_on_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_on_mat.albedo_texture = _viewport.get_texture()
	_off_mat = BuildingGenerator._mat("1b1d24")
	_screen.material_override = _off_mat
	add_child(_screen)


func reset() -> void:
	if _on:
		_set_on(false)


func is_on() -> bool:
	return _on


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	var near := is_visible_in_tree() and _player.global_position.distance_to(global_position) < ON_RADIUS
	if near != _on:
		_set_on(near)


func _set_on(on: bool) -> void:
	_on = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_viewport.get_child(0).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_screen.material_override = _on_mat if on else _off_mat
	if on:
		Sfx.play("ui_confirm", 0.8, -8.0)
