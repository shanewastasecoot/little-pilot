class_name CityGrowth
extends Node3D
## Grows the city from the save's city time (seconds flown since the city
## was last restarted), following CityPlan. On load it builds everything
## already due at once; while playing, new builds start, rise and open, and
## each opening is announced (building_opened). A child of CityDistrict, in
## city space.
##
## Preview: run with  -- --city-hours=N  to see the city N hours ahead of
## the save (not saved; ./dev.sh city N).

signal building_opened(text: String)

const ROAD_W := 16.0        # matches CityDistrict.ROAD_W
const TICK := 0.25          # seconds between progress updates

var city: CityDistrict
var plan: Array[Dictionary] = []
## Extra city time for previews (never saved).
var preview := 0.0

var _next := 0                       # first event not started yet
var _active: Dictionary = {}         # event index -> CityBuild
var _builds: Node3D
var _lots: Node3D
var _segments: Dictionary = {}       # "x,z,x,z" -> [from, to]
var _roads: Node3D
var _acc := 0.0
## Finished buildings are drawn in batches, one MultiMesh per model (and
## roof colour): a few dozen draw calls for hundreds of buildings.
## key -> {"mmi": MultiMeshInstance3D, "xforms": Array[Transform3D], "xf": Transform3D}
var _batches: Dictionary = {}
var _batch_root: Node3D
var _dirty: Dictionary = {}
var _lot_cells: Array[Vector2i] = []
var _crowd_dirty := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-hours="):
			preview = maxf(arg.get_slice("=", 1).to_float(), 0.0) * 3600.0
	SaveManager.city_reset.connect(rebuild)
	rebuild()


## City time now (seconds).
func now() -> float:
	return SaveManager.city_time + preview


## Throw away all growth and rebuild for the current city time (on load and
## when the parents restart the city).
func rebuild() -> void:
	for n in [_builds, _lots, _roads, _batch_root]:
		if n:
			n.free()
	_batch_root = Node3D.new()
	_batch_root.name = "Batches"
	add_child(_batch_root)
	_batches.clear()
	_dirty.clear()
	_builds = Node3D.new()
	_builds.name = "Builds"
	add_child(_builds)
	_lots = Node3D.new()
	_lots.name = "Lots"
	add_child(_lots)
	_roads = null
	_segments.clear()
	_lot_cells.clear()
	_active.clear()
	_next = 0
	plan = CityPlan.make(SaveManager.city_seed)
	city.reset_sites()
	_crowd_dirty = true
	advance(now(), false)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	advance(now(), true)


## Bring the city up to time `t`. `live`: the player is watching (announce
## openings with confetti); false on load.
func advance(t: float, live: bool) -> void:
	var roads_changed := false
	while _next < plan.size() and plan[_next].start <= t:
		var e: Dictionary = plan[_next]
		if e.kind == "site":
			city.clear_site_core(e.cell)
		elif e.kind == "upgrade":
			city.clear_pair(e.cell)
		if e.kind in ["site", "upgrade"]:
			_crowd_dirty = true  # old frame / shops gone
		if e.lot != "":
			_build_lot(e)
			_lot_cells.append(e.cell)
			roads_changed = true  # its pavement
			for seg in CityPlan.lot_roads(e.cell):
				var key := "%d,%d,%d,%d" % [seg[0].x, seg[0].z, seg[1].x, seg[1].z]
				if not _segments.has(key):
					_segments[key] = seg
					roads_changed = true
		var b := CityBuild.new().setup(e, city)
		_builds.add_child(b)
		_active[_next] = b
		_next += 1
	for i in _active.keys():
		var e: Dictionary = plan[i]
		var b: CityBuild = _active[i]
		var p: float = (t - e.start) / e.dur
		if p >= 1.0:
			b.finish(live)
			if e.model != "":
				b.release_model()
				_batch_add(e)
			if e.kind == "site":
				city.clear_site(e.cell)
			_active.erase(i)
			_crowd_dirty = true
			if live:
				building_opened.emit(e.text)
		else:
			b.set_progress(p)
	if roads_changed:
		_build_roads()
	for key in _dirty:
		_batch_flush(key)
	_dirty.clear()
	if _crowd_dirty and city.crowd:
		_crowd_dirty = false
		city.crowd.set_blocks(crowd_blocks())


## Where people can be: today's blocks plus every lot with something open
## on it. Finished buildings are doors; finished parks are open spaces.
func crowd_blocks() -> Dictionary:
	var out := city.core_blocks()
	for i in range(_next):
		if _active.has(i):
			continue
		var e: Dictionary = plan[i]
		if not out.has(e.cell):
			out[e.cell] = {"doors": [], "open": false}
		if e.kind == "park" or e.kind == "playground":
			out[e.cell].open = true
		elif e.kind == "upgrade" or e.kind == "site":
			out[e.cell].doors = [CityPlan.cell_centre(e.cell)]
		else:
			out[e.cell].doors.append(e.pos)
	return out


func _batch_add(e: Dictionary) -> void:
	var key: String = e.model + ("" if e.tint == null else "|%s|%.2f" % [(e.tint as Color).to_html(), e.tint_hue])
	if not _batches.has(key):
		var data: Array = AssetLib.mesh_of(CityDistrict.ENV + e.model + ".glb")
		var mesh: Mesh = data[0]
		if e.tint != null:
			mesh = _tinted(mesh, e.tint, e.tint_hue)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # never moves
		_batch_root.add_child(mmi)
		_batches[key] = {"mmi": mmi, "xforms": [] as Array[Transform3D], "xf": data[1]}
	var batch: Dictionary = _batches[key]
	var at := Transform3D(Basis(Vector3.UP, deg_to_rad(e.yaw)), e.pos) \
		* Transform3D(Basis().scaled(Vector3.ONE * e.scale), e.offset)
	batch.xforms.append(at * batch.xf)
	_dirty[key] = true


func _batch_flush(key: String) -> void:
	var batch: Dictionary = _batches[key]
	var mm: MultiMesh = batch.mmi.multimesh
	mm.instance_count = batch.xforms.size()
	for i in batch.xforms.size():
		mm.set_instance_transform(i, batch.xforms[i])


## A copy of `mesh` with ModelRecolor's roof colour baked into its materials.
func _tinted(mesh: Mesh, tint: Color, hue: float) -> Mesh:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var rc := ModelRecolor.new()
	rc.target = mi
	rc.from_hue = hue
	rc.min_saturation = CityPlan.tint_min_saturation(hue)
	rc.apply(tint)
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var m := mi.get_surface_override_material(i)
		if m:
			copy.surface_set_material(i, m)
	rc.free()
	mi.free()
	return copy


## How many builds have opened by city time `t` (for tests and the HUD).
func opened_count(t: float) -> int:
	var n := 0
	for e in plan:
		if e.start + e.dur <= t:
			n += 1
	return n


## A lot's ground: lawn for houses and parks, paving for the rest.
func _build_lot(e: Dictionary) -> void:
	var c := CityPlan.cell_centre(e.cell)
	var color := "8fd46f" if e.lot == "grass" else "d8d0c0"
	var pad := BuildKit.add(_lots, BuildKit.box(Vector3(64, 0.3, 64)), color, c + Vector3(0, 0.15, 0))
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## All outer-ring road segments in three draw calls: asphalt (one merged
## mesh), centre dashes and street lights (MultiMeshes). Rebuilt whenever a
## lot adds roads (rare: a few times an hour at most).
func _build_roads() -> void:
	if _roads:
		_roads.free()
	_roads = Node3D.new()
	_roads.name = "Roads"
	add_child(_roads)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dashes: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var light: Array = AssetLib.mesh_of(CityDistrict.ENV + "street_light.glb")
	for seg in _segments.values():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var along_x := absf(b.x - a.x) > 1.0
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + ROAD_W
		var size := Vector3(length, 0.3, ROAD_W) if along_x else Vector3(ROAD_W, 0.3, length)
		st.append_from(BuildKit.box(size), 0, Transform3D(Basis(), mid + Vector3(0, 0.08, 0)))
		var yaw := 0.0 if along_x else PI * 0.5
		for d in 4:
			var t := (d + 0.5) / 4.0
			dashes.append(Transform3D(Basis(Vector3.UP, yaw), a.lerp(b, t) + Vector3(0, 0.32, 0)))
		for t in [0.0, 0.5]:
			var p := a.lerp(b, t)
			var side := Vector3(0, 0, ROAD_W * 0.5 + 1.5) if along_x else Vector3(ROAD_W * 0.5 + 1.5, 0, 0)
			lights.append(Transform3D(Basis(Vector3.UP, PI if along_x else PI * 0.5).scaled(Vector3.ONE * 1.6), p + side) * light[1])
	_roads.add_child(CityDistrict.pavements(_lot_cells))
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = BuildKit.mat("4a4f57")
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_roads.add_child(road)
	_roads.add_child(_multi(BuildKit.box(Vector3(5, 0.1, 0.6)), dashes, BuildKit.mat("ffffff"), 900.0))
	_roads.add_child(_multi(light[0], lights, null, 1400.0))


func _multi(mesh: Mesh, xforms: Array[Transform3D], material: Material, view: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = view
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
