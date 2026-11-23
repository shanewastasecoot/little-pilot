class_name HatShop
extends Node3D
## The hat shop by the airport (Phase 5), next to the post office: a little
## shop with a big straw hat turning slowly on its roof (the sign: no words)
## and a pink-and-white awning. Walk into the front door to go in (main.gd's
## INDOORS); its inside is HatShopLayout's. Origin on the ground at the
## building's centre; the front faces +Z.

signal door_entered

const MODEL := "shop_small_a"
## shop_small_a's size (model units) and the offset that centres it.
const MODEL_SIZE := Vector3(1.64, 0.88, 0.968)
const MODEL_OFFSET := Vector3(0.0, 0.0, 0.064)
const SHOP_SCALE := 16.0
## Where you stand when you come out: well out in front, so the camera
## behind you isn't inside the shop.
const DOORSTEP_OUT := 14.0

var _sign: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("hat_shops")
	var size := footprint()
	var shop := AssetLib.place(self, "res://assets/environment/%s.glb" % MODEL, MODEL_OFFSET * SHOP_SCALE, SHOP_SCALE)
	shop.name = "Shop"
	BuildKit.collider(self, BuildKit.box_shape(size), Vector3(0, size.y * 0.5, 0))
	BuildKit.push_volume(self, 34.0, 40.0, Vector3(0, 10, 0))
	# The sign: a giant straw hat on the roof, turning.
	_sign = Node3D.new()
	_sign.name = "Sign"
	_sign.position = Vector3(-size.x * 0.25, size.y + 0.4, 0.5)
	add_child(_sign)
	var hat := CharacterLook.prop("Straw_Hat") as MeshInstance3D
	hat.scale = Vector3.ONE * 9.0
	var b := hat.get_aabb()
	hat.position = -Vector3(b.get_center().x, b.position.y, b.get_center().z) * 9.0
	_sign.add_child(hat)
	# A striped awning over the front windows.
	var door := door_local()
	var aw_w := size.x * 0.5
	var aw := Node3D.new()
	aw.position = Vector3(door.x - 4.0 - aw_w * 0.5, 7.5, size.z * 0.5 + 1.0)
	add_child(aw)
	var stripes := 8
	for k in stripes:
		var col := "ff9fc4" if k % 2 == 0 else "ffffff"
		var sx := -aw_w * 0.5 + (k + 0.5) * aw_w / stripes
		BuildKit.add(aw, BuildKit.box(Vector3(aw_w / stripes, 0.25, 2.6)), col, Vector3(sx, 0, 0), Vector3(-18, 0, 0))
		# The flap hanging down at the front (what you see from the street).
		BuildKit.add(aw, BuildKit.box(Vector3(aw_w / stripes, 1.1, 0.15)), col, Vector3(sx, -0.85, 1.25))
	# The doorway trigger.
	var area := Area3D.new()
	area.name = "FrontDoor"
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 3.0
	cs.shape = s
	cs.position = door + Vector3(0, 2.5, 0.8)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body): if body is Walker: door_entered.emit())


func _process(delta: float) -> void:
	_t += delta
	if _sign:
		_sign.rotation.y = _t * 0.5
		_sign.position.y = footprint().y + 0.4 + sin(_t * 1.6) * 0.3


## The shop's size in metres (centred on the origin).
func footprint() -> Vector3:
	return MODEL_SIZE * SHOP_SCALE


func door_local() -> Vector3:
	return HatShopLayout.door_local(MODEL, SHOP_SCALE, footprint())


func door_point() -> Vector3:
	return to_global(door_local())


func doorstep() -> Vector3:
	return to_global(door_local() + Vector3(0, 0, DOORSTEP_OUT))


## Facing away from the door when you come out.
func doorstep_yaw() -> float:
	var out := global_transform.basis.z
	return atan2(-out.x, -out.z)


func building_id() -> String:
	return String(name)


func interior_layout() -> Dictionary:
	return HatShopLayout.layout(MODEL, SHOP_SCALE, footprint(), 7)
