class_name HatMirror
extends Node3D
## The hat shop's try-on mirror: a tall oval mirror in a gold frame on a
## little round rug. Standing in front of it shows the Y prompt; Y opens the
## hat chooser (HatMenu: stick to try each hat on, A to buy or wear it, B
## to put it back). Never by walking past. Origin on the floor; the mirror
## faces +Z.

const NEAR_RADIUS := 5.5

var _player_near := false


func _ready() -> void:
	add_to_group("hat_mirror")
	_build()
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = NEAR_RADIUS
	cs.shape = s
	cs.position = Vector3(0, 1.0, 2.6)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b is Walker: _player_near = true)
	area.body_exited.connect(func(b): if b is Walker: _player_near = false)


func is_player_near() -> bool:
	return _player_near


## Where she stands to try hats on (in front of the mirror, facing out so
## the camera sees her face and the mirror behind her).
func stand_point() -> Vector3:
	return to_global(Vector3(0, 0, 3.2))


## A sparkle and a wobble when a hat is bought or put on.
func celebrate() -> void:
	var burst := PickupBurst.new(30, 8.0, [Color("ffd23f"), Color("ff9fc4"), Color.WHITE])
	burst.position = Vector3(0, 5.0, 0.6)
	add_child(burst)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3(1.06, 0.94, 1.06), 0.08)
	tw.tween_property(self, "scale", Vector3.ONE, 0.3)


func _build() -> void:
	var gold := "e8b84a"
	# The rug she stands on.
	BuildKit.add(self, BuildKit.cyl(2.6, 0.08, -1.0, 28), "ff9fc4", Vector3(0, 0.04, 3.0)).material_override = BuildingGenerator._mat("ff9fc4")
	BuildKit.add(self, BuildKit.cyl(2.0, 0.1, -1.0, 28), "ffe3f0", Vector3(0, 0.05, 3.0)).material_override = BuildingGenerator._mat("ffe3f0")
	# Feet and the post.
	BuildKit.add(self, BuildKit.box(Vector3(3.2, 0.35, 1.4)), gold, Vector3(0, 0.18, 0)).material_override = BuildingGenerator._mat(gold)
	# The oval: a gold disc with the glass in front, stretched tall.
	var frame := BuildKit.add(self, BuildKit.cyl(1.6, 0.3, -1.0, 32), gold, Vector3(0, 4.0, 0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.55))
	frame.material_override = BuildingGenerator._mat(gold)
	var glass := BuildKit.add(self, BuildKit.cyl(1.38, 0.1, -1.0, 32), "cfeeff", Vector3(0, 4.0, 0.16), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.55))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d8f2ff")
	m.metallic = 0.7
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = Color("bfe6ff")
	m.emission_energy_multiplier = 0.25
	glass.material_override = m
	# A shine across the glass, and a bow on top.
	BuildKit.add(self, BuildKit.box(Vector3(0.25, 2.2, 0.05)), "ffffff", Vector3(-0.55, 4.6, 0.24), Vector3(0, 0, -25)).material_override = BuildingGenerator._mat("ffffff")
	BuildKit.add(self, BuildKit.sphere(0.35, 10), "e63946", Vector3(0, 6.6, 0.1)).material_override = BuildingGenerator._mat("e63946")
	for sx in [-1.0, 1.0]:
		BuildKit.add(self, BuildKit.prism(Vector3(0.8, 0.6, 0.2)), "e63946", Vector3(sx * 0.5, 6.6, 0.1), Vector3(0, 0, 90 * sx)).material_override = BuildingGenerator._mat("e63946")
	BuildKit.collider(self, BuildKit.box_shape(Vector3(3.4, 6.8, 1.4)), Vector3(0, 3.4, 0))
