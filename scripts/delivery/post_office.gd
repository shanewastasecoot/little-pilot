class_name PostOffice
extends Node3D
## A little post office: a shop with a big red mailbox and an envelope sign,
## the postie at the door, and a golden pad in front where a parcel waits,
## glowing and bobbing. Walk into the parcel to pick it up (DeliveryManager
## checks; no button). Origin on the ground at the building's centre; the
## front faces +Z before `rotation`.

const SHOP_SCALE := 16.0
## The pad, in front of the door (local).
const PAD := Vector3(0, 0, 17.0)

var _parcel: Node3D
var _glow: MeshInstance3D
var _t := 0.0
var available := true
var _body: StaticBody3D


func _ready() -> void:
	var shop := AssetLib.place(self, "res://assets/environment/shop_small_a.glb", Vector3(0, 0, 0), SHOP_SCALE)
	shop.name = "Shop"
	_body = BuildKit.collider(self, BuildKit.box_shape(Vector3(1.64, 0.88, 0.97) * SHOP_SCALE), Vector3(0, 0.44 * SHOP_SCALE, 0))
	BuildKit.push_volume(self, 34.0, 40.0, Vector3(0, 10, 0))
	# The sign on the roof: a white envelope on blue.
	var sign := Node3D.new()
	sign.position = Vector3(0, 0.88 * SHOP_SCALE + 3.6, 2.0)
	add_child(sign)
	BuildKit.add(sign, BuildKit.box(Vector3(10, 6.4, 0.8)), "2f6fdb")
	BuildKit.add(sign, BuildKit.box(Vector3(7.0, 4.4, 0.3)), "ffffff", Vector3(0, 0, 0.5))
	BuildKit.add(sign, BuildKit.prism(Vector3(7.0, 2.2, 0.3)), "e1e8f0", Vector3(0, 1.1, 0.62), Vector3(0, 0, 180))
	BuildKit.add(sign, BuildKit.box(Vector3(0.5, 3.6, 0.8)), "2f6fdb", Vector3(-3.0, -5.0, 0))
	BuildKit.add(sign, BuildKit.box(Vector3(0.5, 3.6, 0.8)), "2f6fdb", Vector3(3.0, -5.0, 0))
	# A big red mailbox beside the door.
	var box := Node3D.new()
	box.position = Vector3(9.5, 0, 9.5)
	add_child(box)
	BuildKit.add(box, BuildKit.cyl(1.5, 4.2, -1.0, 16), "e63946", Vector3(0, 2.1, 0))
	BuildKit.add(box, BuildKit.sphere(1.5, 16), "e63946", Vector3(0, 4.2, 0))
	BuildKit.add(box, BuildKit.box(Vector3(1.8, 0.35, 0.3)), "1b1b2f", Vector3(0, 3.6, 1.42))
	BuildKit.collider(box, BuildKit.cyl_shape(1.6, 5.5), Vector3(0, 2.75, 0))
	# The pad: a golden disc with a soft glow over it.
	BuildKit.add(self, BuildKit.cyl(4.6, 0.3, -1.0, 32), "ffd23f", PAD + Vector3(0, 0.15, 0))
	BuildKit.add(self, BuildKit.cyl(3.6, 0.32, -1.0, 32), "fff2a8", PAD + Vector3(0, 0.17, 0))
	_parcel = CharacterLook.prop("Package")
	_parcel.scale = Vector3.ONE * 3.0
	add_child(_parcel)
	_glow = MeshInstance3D.new()
	_glow.mesh = BuildKit.sphere(3.2, 16)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.35, 0.35)
	_glow.material_override = m
	add_child(_glow)
	set_available(true)


func body_rid() -> RID:
	return _body.get_rid()


## The pad's spot in the world (where you walk to pick up).
func pickup_point() -> Vector3:
	return to_global(PAD)


## Show or hide the waiting parcel.
func set_available(on: bool) -> void:
	available = on
	_parcel.visible = on
	_glow.visible = on


func _process(delta: float) -> void:
	_t += delta
	if available:
		var bob := sin(_t * 2.4) * 0.4
		_parcel.position = PAD + Vector3(0, 2.6 + bob, 0)
		_parcel.rotation.y = _t * 0.9
		_glow.position = _parcel.position
		_glow.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.08)
