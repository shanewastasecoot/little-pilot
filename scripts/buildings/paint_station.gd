class_name PaintStation
extends Node3D
## Where she changes her room's colours, on purpose (never by walking past):
##   "walls"  a painter's easel with a canvas in the walls' colour and a
##            palette of the six paints
##   "quilt"  a toy chest at the foot of the bed with the six quilts
##            folded on top
## Standing beside it shows the Y prompt; pressing Y opens the colour menu
## (ColourMenu): stick to look at each colour on the room, A to keep it,
## B to put it back. Origin on the floor; the front faces +Z.

const COLOURS := [Color("ff9fc4"), Color("9fd8ff"), Color("b6f0a0"), Color("fff08a"), Color("d0b3ff"), Color("ffc38a")]
## How close you stand for the prompt (from the station's front).
const NEAR_RADIUS := 5.5

var kind := "walls"
var _swatch: StandardMaterial3D
var _player_near := false


func _ready() -> void:
	add_to_group("paint_station")
	if kind == "walls":
		_build_easel()
	else:
		_build_chest()
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = NEAR_RADIUS
	cs.shape = s
	cs.position = Vector3(0, 1.0, 2.0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b is Walker: _player_near = true)
	area.body_exited.connect(func(b): if b is Walker: _player_near = false)


func is_player_near() -> bool:
	return _player_near


## Show colour `i` on the station itself (the canvas, or the top quilt).
func show_colour(i: int) -> void:
	if _swatch and i == -1:
		_swatch.albedo_color = Color.WHITE
	elif _swatch and i >= 0 and i < COLOURS.size():
		_swatch.albedo_color = COLOURS[i] if kind == "quilt" else (COLOURS[i] as Color).lightened(0.35)


## A little hop and sparkle when a colour is kept.
func celebrate(i: int) -> void:
	var burst := PickupBurst.new(30, 8.0, [COLOURS[i], Color.WHITE])
	burst.position = Vector3(0, 4.0, 0.5)
	add_child(burst)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3(1.08, 0.92, 1.08), 0.08)
	tw.tween_property(self, "scale", Vector3.ONE, 0.3)


func _build_easel() -> void:
	var wood := "b98a5e"
	# Three legs leaning together, a ledge, the canvas.
	for leg in [[Vector3(-1.4, 3.2, 0.3), -10.0, 0.0], [Vector3(1.4, 3.2, 0.3), 10.0, 0.0], [Vector3(0, 3.0, -1.0), 0.0, -14.0]]:
		BuildKit.add(self, BuildKit.box(Vector3(0.35, 6.6, 0.35)), wood, leg[0], Vector3(leg[2], 0, leg[1])).material_override = BuildingGenerator._mat(wood)
	BuildKit.add(self, BuildKit.box(Vector3(3.8, 0.3, 0.8)), wood, Vector3(0, 2.6, 0.55)).material_override = BuildingGenerator._mat(wood)
	BuildKit.add(self, BuildKit.box(Vector3(3.6, 2.8, 0.2)), "ffffff", Vector3(0, 4.15, 0.45)).material_override = BuildingGenerator._mat("ffffff")
	var canvas := BuildKit.add(self, BuildKit.box(Vector3(3.2, 2.4, 0.1)), "ffffff", Vector3(0, 4.15, 0.58))
	_swatch = StandardMaterial3D.new()
	_swatch.albedo_color = Color.WHITE
	canvas.material_override = _swatch
	# The palette on the ledge with a blob of each paint.
	var palette := BuildKit.add(self, BuildKit.cyl(1.0, 0.12, -1, 20), "e8d2a8", Vector3(0, 2.82, 0.75), Vector3(0, 0, 0), Vector3(1.6, 1, 0.55))
	palette.material_override = BuildingGenerator._mat("e8d2a8")
	for k in COLOURS.size():
		var hex: String = (COLOURS[k] as Color).to_html(false)
		var a := PI * (0.1 + 0.8 * k / (COLOURS.size() - 1.0))
		BuildKit.add(self, BuildKit.sphere(0.2, 8), hex, Vector3(cos(a) * 1.3, 2.92, 0.75 + sin(a) * 0.3 - 0.15)).material_override = BuildingGenerator._mat(hex)
	BuildKit.collider(self, BuildKit.box_shape(Vector3(3.6, 6.0, 1.6)), Vector3(0, 3.0, 0))


func _build_chest() -> void:
	BuildKit.add(self, BuildKit.box(Vector3(6.0, 2.2, 2.6)), "f7c5d9", Vector3(0, 1.1, 0)).material_override = BuildingGenerator._mat("f7c5d9")
	BuildKit.add(self, BuildKit.box(Vector3(6.2, 0.3, 2.8)), "ffffff", Vector3(0, 2.3, 0)).material_override = BuildingGenerator._mat("ffffff")
	for x in [-1.8, 0.0, 1.8]:
		BuildKit.add(self, BuildKit.sphere(0.25, 8), "ffd166", Vector3(x, 1.1, 1.32)).material_override = BuildingGenerator._mat("ffd166")
	# Six folded quilts stacked on the lid, the top one in the bed's colour.
	for k in COLOURS.size():
		var hex: String = (COLOURS[k] as Color).to_html(false)
		var q := BuildKit.add(self, BuildKit.box(Vector3(4.0 - k * 0.1, 0.32, 1.8)), hex, Vector3(0, 2.6 + k * 0.33, 0))
		q.material_override = BuildingGenerator._mat(hex)
	var top := BuildKit.add(self, BuildKit.box(Vector3(3.6, 0.34, 1.7)), "ffffff", Vector3(0, 2.6 + COLOURS.size() * 0.33, 0))
	_swatch = StandardMaterial3D.new()
	_swatch.albedo_color = Color.WHITE
	top.material_override = _swatch
	BuildKit.collider(self, BuildKit.box_shape(Vector3(6.2, 2.5, 2.8)), Vector3(0, 1.25, 0))
