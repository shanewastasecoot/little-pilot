class_name CityBuild
extends Node3D
## One building from the CityPlan, from first dig to opening day.
## While building: a dirt pad, a scaffold cage a little ahead of the walls,
## the building rising up out of the ground inside it, and a turning crane
## beside tall ones. Finished: scaffold and crane go, confetti if it just
## happened in front of the player. Parks grow their trees instead.

const ENV := "res://assets/environment/"
const SCAFFOLD := "e8a33d"
## Growth buildings are out on the edge of the city: no need to draw them
## from the far side of the map.
const VIEW_RANGE := 2600.0

var event: Dictionary
var city: CityDistrict
var done := false

var _model: Node3D
var _site: Node3D          # pad, scaffold, crane: freed on completion
var _cage: Node3D
var _body: StaticBody3D
var _shape: BoxShape3D
var _trees: Array[Node3D] = []
var _pieces: Array[Node3D] = []
var _height := 0.0


func setup(e: Dictionary, owner_city: CityDistrict) -> CityBuild:
	event = e
	city = owner_city
	position = e.pos
	rotation_degrees.y = e.yaw
	return self


func _ready() -> void:
	if event.kind == "park":
		_build_park()
		return
	if event.kind == "playground":
		_build_playground()
		return
	_height = event.size.y
	_model = AssetLib.place(self, ENV + event.model + ".glb", event.offset, event.scale)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = VIEW_RANGE
	if event.tint != null:
		var rc := ModelRecolor.new()
		rc.target = _model
		rc.from_hue = event.tint_hue
		rc.min_saturation = CityPlan.tint_min_saturation(event.tint_hue)
		rc.to_color = event.tint
		_model.add_child(rc)
	if CityGrowth.is_walk_in(str(event.model)):
		_solid_while_building()
	_shape = BoxShape3D.new()
	_body = BuildKit.collider(self, _shape)
	# Steer the no-crash plane round it like the city's other buildings.
	var reach := maxf(event.size.x, event.size.z) * 0.5
	BuildKit.push_volume(self, reach + 16.0, _height + 40.0)
	_site = Node3D.new()
	add_child(_site)
	var pad := BuildKit.add(_site, BuildKit.box(Vector3(event.size.x + 6.0, 0.4, event.size.z + 6.0)), "b9a88a", Vector3(0, 0.25, 0))
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cage = _scaffold(Vector3(event.size.x + 3.0, 1.0, event.size.z + 3.0))
	_site.add_child(_cage)
	if _height > 45.0:
		city.make_crane(_site, Vector3(event.size.x * 0.5 + 10.0, 0, -event.size.z * 0.5 - 6.0), _height + 20.0)
	set_progress(0.0)


## A walk-in house's walls are drawn from the outside only, with open
## window holes: while it goes up you'd see right through it. Like the
## finished ones (CityGrowth._batch_add, _glass_core): both sides of every
## face, and the dim box just inside the walls, rising with them.
func _solid_while_building() -> void:
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m:
				mi.set_surface_override_material(i, CityGrowth.two_sided(m))
	var s: float = event.scale
	for b: Array in CityGrowth.walls_of(str(event.model), s, event.offset):
		var box := MeshInstance3D.new()
		box.name = "Inside"
		box.mesh = CityGrowth.inside_box()
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# (walls_of is house-local; the model is offset and scaled.)
		box.transform = Transform3D(Basis().scaled(b[1] / s), (b[0] - event.offset) / s)
		_model.add_child(box)


## 0 = just started, 1 = finished (but still has its scaffold).
func set_progress(p: float) -> void:
	p = clampf(p, 0.0, 1.0)
	if event.kind == "park":
		for t in _trees:
			t.scale = Vector3.ONE * t.get_meta("full") * maxf(p, 0.05)
		return
	if event.kind == "playground":
		# Piece by piece: sandpit, swings, slide, roundabout.
		for k in _pieces.size():
			_pieces[k].visible = p >= float(k) / _pieces.size()
		return
	# The walls rise out of the ground; the scaffold stays a storey ahead.
	_model.position = event.offset + Vector3(0, -_height * (1.0 - p) - 0.5 * (1.0 - p), 0)
	var cage_h := clampf(_height * p + 6.0, 4.0, _height + 3.0)
	_cage.scale.y = cage_h
	var solid := maxf(_height * p, 2.0)
	_shape.size = Vector3(event.size.x, solid, event.size.z)
	_body.position.y = solid * 0.5


## Opening day. `celebrate`: it happened just now (confetti), not on load.
func finish(celebrate: bool) -> void:
	if done:
		return
	done = true
	set_progress(1.0)
	if is_house() or is_hat_shop():
		_add_front_door()
	if _site:
		_site.queue_free()
		_site = null
	if celebrate:
		var top := 18.0 if event.kind in ["park", "playground"] else _height + 6.0
		var confetti := PickupBurst.new(50, 18.0, [Color("ffd23f"), Color("ff5a5f"), Color("4aa8ff"), Color("4cc06a")])
		confetti.position = Vector3(0, top, 0)
		add_child(confetti)


## Finished and handed over to CityGrowth's batches: drop our own copy of
## the model (the collider and push volume stay).
func release_model() -> void:
	if _model:
		_model.queue_free()
		_model = null


## A cage of poles and walkways, 1 m tall: scale.y sets its height.
func _scaffold(size: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pole := BuildKit.box(Vector3(0.12, 1.0, 0.12))
	var nx := maxi(int(size.x / 8.0), 2)
	var nz := maxi(int(size.z / 8.0), 2)
	for i in nx + 1:
		for side in [-1.0, 1.0]:
			var x := -size.x * 0.5 + size.x * i / nx
			st.append_from(pole, 0, Transform3D(Basis(), Vector3(x, 0.5, side * size.z * 0.5)))
	for i in range(1, nz):
		for side in [-1.0, 1.0]:
			var z := -size.z * 0.5 + size.z * i / nz
			st.append_from(pole, 0, Transform3D(Basis(), Vector3(side * size.x * 0.5, 0.5, z)))
	# Walkway bands (they stretch with the cage, which reads fine as boards).
	for k in 6:
		var y := (k + 0.5) / 6.0
		for side in [-1.0, 1.0]:
			st.append_from(BuildKit.box(Vector3(size.x, 0.02, 1.4)), 0, Transform3D(Basis(), Vector3(0, y, side * size.z * 0.5)))
			st.append_from(BuildKit.box(Vector3(1.4, 0.02, size.z)), 0, Transform3D(Basis(), Vector3(side * size.x * 0.5, y, 0)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = BuildKit.mat(SCAFFOLD)
	mi.visibility_range_end = VIEW_RANGE
	return mi


## Grass, a round pond, a path and trees that grow while it's "built".
func _build_park() -> void:
	var green := BuildKit.add(self, BuildKit.box(Vector3(62, 0.5, 62)), "7ccf6a", Vector3(0, 0.3, 0))
	green.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = int(event.pos.x * 7.0 + event.pos.z)
	# Pond and trees keep clear of the playground corner (+x, -z).
	var pond := Vector3(rng.randf_range(-10, 0), 0, rng.randf_range(0, 8))
	BuildKit.add(self, BuildKit.cyl(11.0, 0.6, -1, 24), "c9c3b6", pond + Vector3(0, 0.45, 0))
	BuildKit.add(self, BuildKit.cyl(9.8, 0.3, -1, 24), "4fb6ff", pond + Vector3(0, 0.8, 0))
	BuildKit.add(self, BuildKit.box(Vector3(62, 0.4, 3)), "e2d6b8", Vector3(0, 0.6, 22))
	for k in 12:
		var p := Vector3(rng.randf_range(-27, 27), 0, rng.randf_range(-27, 27))
		if p.distance_to(pond) < 15.0 or absf(p.z - 22.0) < 4.0 or (p.x > 2.0 and p.z < -2.0):
			continue
		var full := rng.randf_range(1.8, 2.6)
		var t := AssetLib.place(self, ENV + "tree_round.glb", p, full, rng.randf() * 360.0)
		t.set_meta("full", full)
		_trees.append(t)
	set_progress(0.0)


## Storybook-sized play things (people are ~5 m tall): a sandpit, swings,
## a slide and a roundabout, appearing one by one while it's "built".
func _build_playground() -> void:
	var sand := Node3D.new()
	add_child(sand)
	BuildKit.add(sand, BuildKit.box(Vector3(20, 0.5, 20)), "f4dc8f", Vector3(0, 0.6, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var swings := Node3D.new()
	swings.position = Vector3(-4, 0, -5)
	add_child(swings)
	for x in [-6.0, 6.0]:
		for z in [-1.6, 1.6]:
			var leg := BuildKit.add(swings, BuildKit.box(Vector3(0.5, 8.6, 0.5)), "ff5a5f", Vector3(x, 4.1, z * 0.6))
			leg.rotation.x = z * 0.12
	BuildKit.add(swings, BuildKit.box(Vector3(13, 0.5, 0.5)), "ff5a5f", Vector3(0, 8.2, 0))
	for x in [-3.0, 3.0]:
		BuildKit.add(swings, BuildKit.box(Vector3(0.12, 5.4, 0.12)), "555555", Vector3(x - 0.8, 5.4, 0))
		BuildKit.add(swings, BuildKit.box(Vector3(0.12, 5.4, 0.12)), "555555", Vector3(x + 0.8, 5.4, 0))
		BuildKit.add(swings, BuildKit.box(Vector3(2.2, 0.3, 1.0)), "ffd23f", Vector3(x, 2.6, 0))
	var slide := Node3D.new()
	slide.position = Vector3(5, 0, 4)
	add_child(slide)
	BuildKit.add(slide, BuildKit.box(Vector3(3, 6, 3)), "4aa8ff", Vector3(0, 3, -3))
	var chute := BuildKit.add(slide, BuildKit.box(Vector3(2.4, 0.4, 9)), "ffd23f", Vector3(0, 3.2, 3.6))
	chute.rotation.x = -0.62
	var ring := Node3D.new()
	ring.position = Vector3(-5, 0, 5)
	add_child(ring)
	BuildKit.add(ring, BuildKit.cyl(3.4, 0.5, -1, 16), "4cc06a", Vector3(0, 1.0, 0))
	BuildKit.add(ring, BuildKit.cyl(0.3, 2.6, -1, 8), "9b5de5", Vector3(0, 2.2, 0))
	_pieces = [sand, swings, slide, ring]
	set_progress(0.0)


# --- Going in (houses, hat shops) -------------------------------------------------------

## A finished house you can walk into (its model has a floor plan).
func is_house() -> bool:
	return event.get("kind", "") == "house" and CityHouseLayouts.has(str(event.model))


## A shop the city's news named a hat shop, on a model with a front door
## (HatShopLayout): you can walk into it too.
func is_hat_shop() -> bool:
	return event.get("kind", "") == "shop" and "hat shop" in str(event.get("text", "")) and HatShopLayout.has(str(event.model))


func _add_front_door() -> void:
	var door := Area3D.new()
	door.name = "FrontDoor"
	door.collision_layer = 0
	door.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.6
	cs.shape = s
	cs.position = door_local() + Vector3(0, 2.5, 1.2)
	door.add_child(cs)
	add_child(door)
	door.body_entered.connect(func(b):
		if b is Walker:
			var game := get_tree().get_first_node_in_group("game_main")
			if game:
				game.door_walked_into(self))
	if is_hat_shop():
		# The sign: a big straw hat on the roof (seen from the air too).
		var size: Vector3 = event.size
		var hat := CharacterLook.prop("Straw_Hat") as MeshInstance3D
		var hat_s := size.x * 0.3
		hat.scale = Vector3.ONE * hat_s
		var hb := hat.get_aabb()
		hat.position = Vector3(-size.x * 0.22, size.y + 0.3, 0) - Vector3(hb.get_center().x, hb.position.y, hb.get_center().z) * hat_s
		hat.rotation.y = 0.4
		add_child(hat)
	if is_hat_shop() and HatShopLayout.adds_door(str(event.model)):
		# This model has no door on the ground floor: a blue one, with a
		# pink-and-white awning over it.
		var d := door_local()
		BuildKit.add(self, BuildKit.box(Vector3(4.6, 7.4, 0.3)), "3a7bd5", d + Vector3(0, 3.7, 0.1))
		BuildKit.add(self, BuildKit.box(Vector3(5.4, 0.5, 0.4)), "ffffff", d + Vector3(0, 7.6, 0.15))
		for k in 6:
			BuildKit.add(self, BuildKit.box(Vector3(1.2, 0.25, 2.4)), "ff9fc4" if k % 2 == 0 else "ffffff",
					d + Vector3(-3.0 + (k + 0.5), 8.6, 1.1), Vector3(-18, 0, 0))


## The front door (local, on the ground at the front wall).
func door_local() -> Vector3:
	if is_hat_shop():
		return HatShopLayout.door_local(str(event.model), float(event.scale), event.size)
	return CityHouseLayouts.door_local(str(event.model))


func door_point() -> Vector3:
	return to_global(door_local())


## Where you stand coming out: out in front, so the camera behind you isn't
## inside the house.
func doorstep() -> Vector3:
	return to_global(door_local() + Vector3(0, 0, 13.0))


func doorstep_yaw() -> float:
	var out := global_transform.basis.z
	return atan2(-out.x, -out.z)


func building_id() -> String:
	var p: Vector3 = event.pos
	return "city_%s_%d_%d" % ["hat_shop" if is_hat_shop() else "house", roundi(p.x), roundi(p.z)]


## Its floor plan (one per model; the furniture varies with where it stands).
func interior_layout() -> Dictionary:
	var p: Vector3 = event.pos
	var seed := absi(roundi(p.x) * 73856093 ^ roundi(p.z) * 19349663) % 100000 + 1
	if is_hat_shop():
		return HatShopLayout.layout(str(event.model), float(event.scale), event.size, seed)
	return CityHouseLayouts.layout(str(event.model), seed)
