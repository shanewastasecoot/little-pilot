class_name DragonTreasure
extends Node3D
## A piece of the dragon's treasure, glowing and turning in front of its
## hoard (the safe outlet for "taking things": only from the dragon). On
## foot, walk into it and it's yours: a sparkle and a fanfare, it goes on
## the trophy shelf in her house (SaveManager.treasures), and the dragon
## wakes with a roar, stomps and huffs smoke (it never hurts her on foot),
## then hunts her plane when she takes off. Only while the dragon is
## switched on. One piece per visit: the next is back after REFILL seconds
## of play, once she's left the cave.

signal taken

const REFILL := 150.0
const GRAB_RADIUS := 4.5
## She has to be this far away before a new piece appears.
const AWAY := 250.0

var _piece: Node3D
var _area: Area3D
var _player: Node3D
var _t := 0.0
## She took one and hasn't left the cave yet.
var _taken_here := false


## The `i`th kind of treasure (a crown, a cup, a gem, coins, a necklace),
## about 2 m across, golden and glowing.
static func piece(i: int) -> Node3D:
	var n := Node3D.new()
	var gold := BuildingGenerator._glow_mat(Color("ffd23f"))
	var add := func(mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = at
		mi.rotation = rot
		mi.scale = scl
		mi.material_override = mat
		n.add_child(mi)
	var gem := func(c: String) -> Material: return BuildingGenerator._glow_mat(Color(c))
	match i % 5:
		0:  # a crown: a gold band with points and jewels
			add.call(BuildKit.cyl(1.0, 0.7, -1, 20), Vector3(0, 0.35, 0), gold)
			for k in 5:
				var a := TAU * k / 5.0
				add.call(BuildKit.cyl(0.25, 0.8, 0.02, 6), Vector3(cos(a) * 0.9, 1.1, sin(a) * 0.9), gold)
				add.call(BuildKit.sphere(0.16, 8), Vector3(cos(a) * 1.0, 0.4, sin(a) * 1.0), gem.call(["ff4d6d", "4dd2ff", "7dff6b"][k % 3]))
		1:  # a cup with handles
			add.call(BuildKit.cyl(0.5, 0.3, -1, 16), Vector3(0, 0.15, 0), gold)
			add.call(BuildKit.cyl(0.15, 0.8, -1, 8), Vector3(0, 0.7, 0), gold)
			add.call(BuildKit.cyl(0.8, 1.0, 0.45, 18), Vector3(0, 1.5, 0), gold)
			for s in [-1.0, 1.0]:
				var h := TorusMesh.new()
				h.inner_radius = 0.2
				h.outer_radius = 0.35
				add.call(h, Vector3(s * 0.85, 1.5, 0), gold, Vector3(PI * 0.5, 0, 0))
		2:  # a big gem
			var pm := PrismMesh.new()
			pm.size = Vector3(1.2, 1.4, 1.2)
			add.call(pm, Vector3(0, 1.4, 0), gem.call("ff4dd2"))
			add.call(pm, Vector3(0, 0.0, 0), gem.call("ff4dd2"), Vector3(PI, 0, 0))
			add.call(BuildKit.cyl(0.8, 0.2, -1, 12), Vector3(0, 0.1, 0), gold)
		3:  # a pile of coins
			for k in 9:
				var a := TAU * k / 9.0
				var r := 0.6 if k < 6 else 0.25
				add.call(BuildKit.cyl(0.4, 0.12, -1, 12), Vector3(cos(a) * r, 0.1 + (k / 6) * 0.25 + (k % 3) * 0.12, sin(a) * r), gold,
						Vector3(0.2 * (k % 2), 0, 0.15))
		_:  # a necklace of pearls with a heart
			var neck := TorusMesh.new()
			neck.inner_radius = 0.75
			neck.outer_radius = 0.95
			add.call(neck, Vector3(0, 0.15, 0), gold)
			add.call(BuildKit.sphere(0.35, 10), Vector3(0, 0.4, 1.05), gem.call("ff4d6d"), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
	return n


func _ready() -> void:
	_piece = piece(SaveManager.treasures)
	_piece.scale = Vector3.ONE * 1.6
	_piece.position = Vector3(0, 2.0, 0)
	add_child(_piece)
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 14
	sparkle.lifetime = 1.4
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 2.4
	sparkle.gravity = Vector3(0, 1.0, 0)
	sparkle.initial_velocity_max = 0.5
	sparkle.scale_amount_min = 0.15
	sparkle.scale_amount_max = 0.35
	var dot := SphereMesh.new()
	dot.radius = 0.5
	dot.height = 1.0
	sparkle.mesh = dot
	sparkle.material_override = BuildingGenerator._glow_mat(Color("fff3a8"))
	sparkle.position = Vector3(0, 2.5, 0)
	_piece.add_child(sparkle)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = GRAB_RADIUS
	cs.shape = s
	cs.position = Vector3(0, 2.0, 0)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(func(b): if b is Walker and is_available(): take())
	_refresh()


## Is there a piece to take right now?
func is_available() -> bool:
	return _piece.visible


func _process(delta: float) -> void:
	_piece.rotation.y += delta * 1.2
	_piece.position.y = 2.0 + sin(Time.get_ticks_msec() * 0.003) * 0.3
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_refresh()


## Show a piece when the dragon's on and one's ready (and she's away, so
## it never pops up under her nose).
func _refresh() -> void:
	var ready := SaveManager.dragon and SaveManager.playtime >= SaveManager.treasure_ready_at
	if not ready:
		_piece.visible = false
		return
	if _piece.visible:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
	if _taken_here:
		if _player and _player.global_position.distance_to(global_position) < AWAY:
			return  # one per visit: not while she's still in the cave
		_taken_here = false
	_swap_piece()
	_piece.visible = true


## The next kind of treasure (what she'll get).
func _swap_piece() -> void:
	var fresh := piece(SaveManager.treasures)
	fresh.scale = _piece.scale
	fresh.position = _piece.position
	for c in _piece.get_children():
		if c is CPUParticles3D:
			c.reparent(fresh, false)
	_piece.replace_by(fresh)
	_piece.queue_free()
	_piece = fresh


## She takes it: a sparkle and a fanfare, onto her shelf, and the dragon
## wakes up grumpy.
func take() -> void:
	if not is_available():
		return
	SaveManager.add_treasure(REFILL)
	_piece.visible = false
	_taken_here = true
	var burst := PickupBurst.new(60, 12.0, [Color("ffd23f"), Color("fff3a8"), Color("ff4d6d"), Color("4dd2ff")])
	burst.position = Vector3(0, 3.0, 0)
	add_child(burst)
	Sfx.play("fanfare")
	Sfx.play("chime", 1.4)
	taken.emit()
	var dragon := get_tree().get_first_node_in_group("dragon") as Dragon
	if dragon:
		dragon.treasure_taken(global_position)
