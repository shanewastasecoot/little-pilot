class_name ColourPicker
extends Node3D
## A row of things to walk into to pick a colour, no reading needed: paint
## pots (walls) or cushions (the bed) in each colour. Walking into one picks
## it (a pop and a sparkle); the choice is saved by whoever listens.
## Origin at the row's centre on the floor; the row runs along local X.

signal picked(index: int)

const COLOURS := [Color("ff9fc4"), Color("9fd8ff"), Color("b6f0a0"), Color("fff08a"), Color("d0b3ff"), Color("ffc38a")]

## "pot" (walls) or "cushion" (bed).
var kind := "pot"
var spacing := 3.8
var _armed := {}


func _ready() -> void:
	for i in COLOURS.size():
		var spot := Node3D.new()
		spot.position = Vector3((i - (COLOURS.size() - 1) * 0.5) * spacing, 0, 0)
		add_child(spot)
		var hex: String = (COLOURS[i] as Color).to_html(false)
		if kind == "pot":
			var tin := BuildKit.add(spot, BuildKit.cyl(1.0, 1.6, -1, 16), "cfd4da", Vector3(0, 0.8, 0))
			tin.material_override = BuildingGenerator._mat("cfd4da")
			var paint := BuildKit.add(spot, BuildKit.cyl(0.85, 0.25, -1, 16), hex, Vector3(0, 1.62, 0))
			paint.material_override = BuildingGenerator._mat(hex)
			var drip := BuildKit.add(spot, BuildKit.box(Vector3(0.4, 0.9, 0.12)), hex, Vector3(0.4, 1.1, 0.95))
			drip.material_override = BuildingGenerator._mat(hex)
		else:
			var cushion := BuildKit.add(spot, BuildKit.sphere(1.0, 14), hex, Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1.3, 0.55, 1.0))
			cushion.material_override = BuildingGenerator._mat(hex)
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = GameSettings.LAYER_PLAYER
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.9  # small: walking between two picks neither, not both
		cs.shape = s
		cs.position = Vector3(0, 1.0, 0)
		area.add_child(cs)
		spot.add_child(area)
		_armed[i] = true
		area.body_entered.connect(func(b): if b is Walker and _armed[i]: _armed[i] = false; _pick(i, spot))
		area.body_exited.connect(func(b): if b is Walker: _armed[i] = true)


func _pick(i: int, spot: Node3D) -> void:
	var burst := PickupBurst.new(24, 7.0, [COLOURS[i], Color.WHITE])
	burst.position = Vector3(0, 2.0, 0)
	spot.add_child(burst)
	Sfx.play("pop", 1.2 + i * 0.08)
	picked.emit(i)
