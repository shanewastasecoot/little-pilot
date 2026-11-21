class_name HerHouse
extends Landmark
## Her own two-storey house south-west of the runway (built in Blender by
## tools/blender/build_house.py), the first building you can walk into.
## Walking into the front door (on the porch, facing north towards the
## runway) takes you inside (main.gd's INDOORS state); coming out puts you
## back on the doorstep. Placed by IslandMap on its flattened pad
## (IslandShape.HOUSE), outside the city plan.

signal door_entered

const MODEL := "res://assets/buildings/her_house/her_house.glb"
## House size (metres, matching build_house.py): footprint and wall height.
const SIZE := Vector3(30.0, 19.2, 20.0)
## The front door, in the house's own space (its front faces +Z here, which
## the house's rotation turns to face north).
const DOOR := Vector3(0.0, 1.2, 10.8)
## Standing here (in front of the porch steps) when you come out.
const DOORSTEP := Vector3(0.0, 0.0, 22.0)
const DOOR_RADIUS := 3.2

var _door: Area3D


func _init() -> void:
	landmark_name = "Her House"
	discovery_radius = 120.0
	discovery_sound = "ding"


func build() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	# The house is coloured with vertex colours: give it the toon look the
	# characters wear (soft outline, cel shading).
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, CharacterLook.material(null, 0.08))
		mi.visibility_range_end = 0.0
	# Solid: walls and roof as one box (you bump into it; the plane crashes).
	BuildKit.collider(self, BuildKit.box_shape(Vector3(SIZE.x, SIZE.y + 11.0, SIZE.z)), Vector3(0, (SIZE.y + 11.0) * 0.5, 0))
	BuildKit.push_volume(self, 34.0, 48.0, Vector3(0, 16, 0))
	# The porch: a floor to stand on and an invisible gentle ramp up from
	# the path (so you walk up instead of sinking into the steps).
	BuildKit.collider(self, BuildKit.box_shape(Vector3(11.0, 1.4, 6.0)), Vector3(0, 0.7, 13.0))
	var ramp := BuildKit.collider(self, BuildKit.box_shape(Vector3(7.0, 0.4, 5.0)), Vector3(0, 0.55, 18.0))
	ramp.rotation.x = atan2(1.4, 5.0)  # high end at the porch, low end at the path
	# The front door: walk into it to go in.
	_door = Area3D.new()
	_door.name = "FrontDoor"
	_door.collision_layer = 0
	_door.collision_mask = GameSettings.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = DOOR_RADIUS
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = DOOR + Vector3(0, 2.0, 1.2)
	_door.add_child(cs)
	add_child(_door)
	_door.body_entered.connect(func(b): if b is Walker: door_entered.emit())


func react() -> void:
	# A little hop of the whole house when the plane first flies by.
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var model: Node3D = get_child(0)
	tw.tween_property(model, "position:y", 2.0, 0.2)
	tw.tween_property(model, "position:y", 0.0, 0.5)


## Where you stand when you come out (world space, on the ground).
func doorstep() -> Vector3:
	return to_global(DOORSTEP)


## Which way you face when you come out: away from the door (the house's
## front, its local +Z; a walker's yaw 0 faces -Z).
func doorstep_yaw() -> float:
	return wrapf(global_rotation.y + PI, -PI, PI)
