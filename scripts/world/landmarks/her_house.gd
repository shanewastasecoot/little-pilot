class_name HerHouse
extends Landmark
## Her own two-storey house south-west of the runway, the first building you
## can walk into. The outside is built from the same floor plan as the
## inside (HouseExterior, from resources/buildings/her_house.json), so every
## wall, window and the front door are where they are inside; round it is a
## big fenced garden (HouseGarden) with a backyard to play in, the same one
## you see out of the windows. Walking into the front door takes you inside
## (main.gd's INDOORS state); coming out puts you back on the doorstep.
## Placed by IslandMap on its flattened pad (IslandShape.HOUSE_YARD), outside
## the city plan, turned so the front door faces north (the runway).

signal door_entered

const DATA := "res://resources/buildings/her_house.json"
## Standing this far out from the front door when you come out.
const DOORSTEP_OUT := 24.0
const DOOR_RADIUS := 4.0

var exterior: HouseExterior
var garden: HouseGarden
var _door: Area3D


func _init() -> void:
	landmark_name = "Her House"
	discovery_radius = 160.0
	discovery_sound = "ding"


func build() -> void:
	var data := BuildingGenerator.load_data(DATA)
	exterior = HouseExterior.new()
	exterior.name = "Exterior"
	exterior.data = data
	add_child(exterior)
	garden = HouseGarden.new()
	garden.name = "Garden"
	garden.outdoor = true
	garden.footprint = exterior.footprint
	garden.front_door = Vector2(exterior.door_point.x, exterior.door_point.z)
	# Plan point -> the island's ground height there, relative to the house.
	garden.ground_at = func(x: float, z: float) -> float:
		var w := global_transform * Vector3(x, 0, z)
		return IslandShape.height(w.x, w.z) - global_position.y
	add_child(garden)
	BuildKit.push_volume(self, exterior.footprint.size.length() * 0.5, 40.0, Vector3(exterior.footprint.get_center().x, 16, exterior.footprint.get_center().y))
	# The front door: walk into it to go in.
	_door = Area3D.new()
	_door.name = "FrontDoor"
	_door.collision_layer = 0
	_door.collision_mask = GameSettings.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = DOOR_RADIUS
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = door_local() + exterior.door_out * 1.5 + Vector3(0, 2.5, 0)
	_door.add_child(cs)
	add_child(_door)
	_door.body_entered.connect(func(b): if b is Walker: door_entered.emit())


func react() -> void:
	# A little hop of the whole house when the plane first flies by.
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(exterior, "position:y", 2.0, 0.2)
	tw.tween_property(exterior, "position:y", 0.0, 0.5)


## The front door in the house's own space (on the ground, at the wall).
func door_local() -> Vector3:
	return exterior.door_point


## Where you stand when you come out (world space, on the ground).
func doorstep() -> Vector3:
	return to_global(exterior.door_point + exterior.door_out * DOORSTEP_OUT)


## Which way you face when you come out: away from the door.
func doorstep_yaw() -> float:
	var out := global_transform.basis * exterior.door_out
	return atan2(-out.x, -out.z)


## Is this world point inside the house's walls (not out in the garden)?
func is_inside_walls(p: Vector3) -> bool:
	var l := to_local(p)
	return exterior.footprint.grow(0.8).has_point(Vector2(l.x, l.z)) and l.y < 30.0
