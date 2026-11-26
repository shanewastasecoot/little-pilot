class_name Star
extends Area3D
## A floating star. Spins and bobs; collected by flying through it.
## The pickup radius is deliberately generous: no precision needed.

signal collected(star: Star)

@export var pickup_radius: float = 5.0
## Within this distance the star flies into the plane by itself.
@export var magnet_radius: float = 16.0
@export var spin_speed: float = 1.6
@export var bob_height: float = 0.6

static var _material: ShaderMaterial

var is_collected: bool = false
## Where it sits, as a key for the save (every star she's ever found).
var key := ""
var _time: float = 0.0
var _mesh: MeshInstance3D
var _home: Vector3
var _pull_speed: float = 0.0  # > 0 while being pulled in
var _plane: Aircraft


func _ready() -> void:
	add_to_group("stars")
	key = "%d,%d,%d" % [roundi(global_position.x), roundi(global_position.y), roundi(global_position.z)]
	collision_layer = GameSettings.LAYER_COLLECTIBLES
	collision_mask = GameSettings.LAYER_AIRCRAFT
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = pickup_radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = StarMesh.get_mesh()
	_mesh.material_override = _get_material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The spin and bob happen in the shader (star.gdshader): room for the bob.
	_mesh.extra_cull_margin = bob_height + 0.5
	add_child(_mesh)
	_time = randf() * TAU  # stars don't bob in lockstep
	_mesh.set_instance_shader_parameter("phase", _time)
	_home = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_collected:
		return
	if _plane == null:
		_plane = get_tree().get_first_node_in_group("aircraft") as Aircraft
		if _plane == null:
			return
	var to_plane := _plane.global_position - global_position
	var dist := to_plane.length()
	if _pull_speed <= 0.0 and dist > magnet_radius:
		return
	# Magnet: accelerate towards the plane, always faster than it flies.
	_pull_speed = maxf(_pull_speed + 90.0 * delta, _plane.speed + 12.0)
	var step := _pull_speed * delta
	if dist <= maxf(step, 2.0):
		_collect()
	else:
		global_position += to_plane / dist * step


func _on_body_entered(body: Node3D) -> void:
	if body is Aircraft:
		_collect()


func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	_pull_speed = 0.0
	set_deferred("monitoring", false)
	collected.emit(self)
	var burst := PickupBurst.new()
	var parent := get_parent()
	burst.position = (parent as Node3D).to_local(_mesh.global_position) if parent is Node3D else _mesh.global_position  # (placed before adding: a burst added first starts its sparks where it was added)
	parent.add_child(burst)
	var tw := create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mesh, "scale", Vector3.ONE * 1.6, 0.08)
	tw.tween_property(_mesh, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(_mesh.hide)


## Bring the star back with a little pop-in.
func respawn() -> void:
	is_collected = false
	_pull_speed = 0.0
	global_position = _home
	_mesh.show()
	_mesh.scale = Vector3.ZERO
	var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.8).set_delay(randf() * 0.6)
	set_deferred("monitoring", true)


static func _get_material() -> ShaderMaterial:
	if _material == null:
		# Gold and glowing, spinning and bobbing on the graphics card (G1).
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/collectibles/star.gdshader")
		_material.set_shader_parameter("albedo", Color("ffd23f"))
		_material.set_shader_parameter("emission_color", Color("ffb800"))
		_material.set_shader_parameter("emission_energy", 1.6)
		_material.set_shader_parameter("roughness", 0.3)
	return _material
