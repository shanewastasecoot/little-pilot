extends Node
## The growing city:
##   plan    same seed -> same plan; different seeds -> different cities;
##           sensible pacing (first build within minutes, full 11x11 city
##           in ~22 h); every lot on flat ground, nothing on a road, no two
##           buildings overlapping, nothing tall under the star ring
##   live    in the real game: builds appear as city time passes, open with
##           an announcement, grow only (never un-build), roads arrive with
##           their lots, the old construction sites finish, and late on
##           old downtown shops are knocked down for skyscrapers
##   people  townspeople from the start, more as the city grows; after a
##           while of walking nobody is inside a building or out in the
##           road (except crossing at corners), and people really do go in
##           and come back out of doors
##   lights  no street light stands in a road (they used to at crossings)
##   reset   "Restart the city" puts everything back to the start
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_city.cfg"
var _fails := 0
var _news: Array[String] = []


func _ready() -> void:
	_plan_checks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.city_seed = 777
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_live_checks(main)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nCITY TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _plan_checks() -> void:
	var a := CityPlan.make(12345)
	var b := CityPlan.make(12345)
	_check("same seed gives the same plan", str(a) == str(b))
	var differs := 0
	for s in [1, 2, 3, 4, 5]:
		if str(CityPlan.make(s)) != str(a):
			differs += 1
	_check("different seeds grow different cities", differs == 5)
	var min_n := 9999
	var max_n := 0
	var min_h := 999.0
	var max_h := 0.0
	var all_ok := true
	for s in range(1, 41):
		var plan := CityPlan.make(s)
		min_n = mini(min_n, plan.size())
		max_n = maxi(max_n, plan.size())
		var last: Dictionary = plan[plan.size() - 1]
		var hours: float = (last.start + last.dur) / 3600.0
		min_h = minf(min_h, hours)
		max_h = maxf(max_h, hours)
		var problem := _plan_problem(plan)
		if problem != "":
			all_ok = false
			print("  seed %d: %s" % [s, problem])
	print("  note: %d-%d builds, full city in %.1f-%.1f h (40 seeds)" % [min_n, max_n, min_h, max_h])
	_check("full city takes about 22 hours of play", min_h >= 21.0 and max_h <= 23.0)
	var lots := CityPlan.growth_cells().size()
	print("  note: %d lots to grow onto (today's city is 24 + the plaza)" % lots)
	_check("the city can grow large (80+ new lots)", lots >= 80)
	_check("every plan is valid (40 seeds)", all_ok)
	_check("first build starts within 5 minutes", a[0].start <= 300.0)


## "" if fine, else what's wrong.
func _plan_problem(plan: Array[Dictionary]) -> String:
	var prev := -1.0
	var rects: Array[Rect2] = []
	var cells := {}
	for e in plan:
		if e.start <= prev:
			return "starts out of order"
		prev = e.start
		if e.kind in ["site", "upgrade"]:
			continue
		cells[e.cell] = true
		var c: Vector3 = e.pos
		for corner in [Vector2(-32, -32), Vector2(32, -32), Vector2(-32, 32), Vector2(32, 32)]:
			var g := CityPlan.cell_centre(e.cell)
			var w: Vector2 = IslandShape.CITY + Vector2(g.x, g.z) + corner
			if absf(IslandShape.height(w.x, w.y) - IslandShape.CITY_HEIGHT) > 0.05:
				return "lot %s not on flat ground" % e.cell
		if e.kind == "park":
			continue
		var half := Vector2(maxf(e.size.x, e.size.z), maxf(e.size.x, e.size.z)) * 0.5
		var r := Rect2(Vector2(c.x, c.z) - half, half * 2.0)
		# Inside its block (roads run along the block edges at +/-40).
		var g := CityPlan.cell_centre(e.cell)
		var block := Rect2(Vector2(g.x - 32.0, g.z - 32.0), Vector2(64, 64))
		if not block.grow(0.01).encloses(r):
			return "%s at %s spills onto a road" % [e.kind, e.cell]
		for o in rects:
			if o.grow(-0.01).intersects(r):
				return "%s at %s overlaps another building" % [e.kind, e.cell]
		rects.append(r)
		if not CityPlan.tall_ok(e.cell) and e.size.y > 40.0:
			return "tall %s at %s under the star ring" % [e.kind, e.cell]
	var lots := CityPlan.growth_cells().size()
	if cells.size() != lots:
		return "only %d of %d lots used" % [cells.size(), lots]
	if plan.filter(func(e): return e.kind == "upgrade").size() != CityPlan.UPGRADES:
		return "wrong number of upgrades"
	return ""


func _live_checks(main: Node) -> void:
	var city: CityDistrict = main._city
	var g: CityGrowth = city.growth
	g.building_opened.connect(func(t: String): _news.append(t))
	_check("a new save starts with today's city", g._builds.get_child_count() == 0 and city._sites.size() == 3 and city._pairs.size() == 10)
	var crowd: CityCrowd = city.crowd
	var start_people := crowd.population()
	_check("today's city has townspeople", start_people >= 100)
	_crowd_walk_checks(crowd)
	var first: Dictionary = g.plan[0]
	# Halfway through the first build: it's there, rising, not open yet.
	SaveManager.city_time = first.start + first.dur * 0.5
	g.advance(g.now(), true)
	_check("first build appears when due", g._builds.get_child_count() == 1 and g._active.size() == 1 and _news.is_empty())
	_check("site's old frame goes when its tower starts", first.kind != "site" or not city._sites[first.cell].has("core"))
	SaveManager.city_time = first.start + first.dur + 0.1
	g.advance(g.now(), true)
	_check("it opens with an announcement", _news.size() == 1 and _news[0] == first.text)
	_check("a finished site is cleared away", first.kind != "site" or not city._sites.has(first.cell))
	# Play on for 3 hours in 10-second steps: only ever grows.
	var grew_only := true
	var last := g._builds.get_child_count()
	for i in 3 * 360:
		SaveManager.city_time += 10.0
		g.advance(g.now(), true)
		var n := g._builds.get_child_count()
		if n < last:
			grew_only = false
		last = n
	var opened := g.opened_count(g.now())
	_check("city only ever grows", grew_only)
	_check("more people as the city grows", crowd.population() > start_people)
	_check("every opening announced", _news.size() == opened)
	_check("roads arrive with their lots", g._roads != null and g._segments.size() > 0)
	# Late on: an upgrade knocks down an old shop pair for a tower.
	var up: Dictionary = g.plan.filter(func(e): return e.kind == "upgrade")[0]
	SaveManager.city_time = up.start + up.dur + 1.0
	g.advance(g.now(), false)
	_check("upgrade replaces old shops with a tower", not city._pairs.has(up.cell))
	_check("finished buildings are batched", g._batches.size() > 3 and g._batches.size() < 70)
	# Reload: the same city comes back from the save.
	var built_before := g._builds.get_child_count()
	var seed_before := SaveManager.city_seed
	SaveManager.playtime = SaveManager.city_time
	SaveManager.save_now()
	SaveManager.use_path(PATH)
	_check("seed survives reload", SaveManager.city_seed == seed_before)
	g.rebuild()
	_check("same city after reload", g._builds.get_child_count() == built_before)
	# Restart the city.
	SaveManager.reset_city()
	_check("restart puts the city back", g._builds.get_child_count() == 0 and g._segments.is_empty() and city._sites.size() == 3 and city._pairs.size() == 10)
	_check("restart picks a new growth plan", SaveManager.city_seed != seed_before)
	_check("restart shrinks the crowd back", crowd.population() == start_people)
	# A full city builds without errors.
	SaveManager.city_time = 24.0 * 3600.0
	SaveManager.playtime = SaveManager.city_time
	g.rebuild()
	_check("the full city builds", g._active.is_empty() and g.opened_count(g.now()) == g.plan.size() and city._sites.is_empty())
	_check("a full city's crowd is capped", crowd.population() == CityCrowd.MAX_PEOPLE)
	_street_light_checks(city, g)
	_crowd_walk_checks(crowd)


## Walk everyone for 90 s (in 0.1 s steps) and check where they are.
func _crowd_walk_checks(crowd: CityCrowd) -> void:
	var went_in := 0
	var came_out := 0
	var bad := ""
	for step in 900:
		for p in crowd.people:
			var before: int = p.state
			crowd._step(p, 0.1)
			if before != CityCrowd.INSIDE and p.state == CityCrowd.INSIDE:
				went_in += 1
			if before == CityCrowd.INSIDE and p.state != CityCrowd.INSIDE:
				came_out += 1
			if bad == "" and step % 10 == 0:
				bad = _where_wrong(crowd, p)
	_check("people stay on pavements, doors, parks or crossings", bad == "")
	if bad != "":
		print("  " + bad)
	_check("people go into buildings (%d)" % went_in, went_in > 10)
	_check("people come back out (%d)" % came_out, came_out > 3)


func _where_wrong(crowd: CityCrowd, p: Dictionary) -> String:
	var pos: Vector3 = p.pos
	if not (is_finite(pos.x) and is_finite(pos.z)):
		return "a person at NaN"
	if p.state == CityCrowd.INSIDE or p.state == CityCrowd.CROSS:
		return ""
	var info: Dictionary = crowd.blocks.get(p.block, {})
	if info.is_empty():
		return "a person on a block that doesn't exist"
	var c := Vector3(p.block.x * CityCrowd.PITCH, 0, p.block.y * CityCrowd.PITCH)
	var l := pos - c
	var m := maxf(absf(l.x), absf(l.z))
	if m > CityCrowd.LOOP + 0.6:
		return "person in the road at %s (state %d, %.1f m out)" % [pos, p.state, m]
	if info.open:
		return ""
	if m < CityCrowd.EDGE - 0.6:
		return "person inside block %s at %s (state %d)" % [p.block, pos, p.state]
	return ""


## Every street light (the old city's and the growing city's) stands beside
## a road, never in one: none within half a road's width of a road's centre
## line (roads run between blocks, at (n + 0.5) * PITCH in the city).
func _street_light_checks(city: CityDistrict, g: CityGrowth) -> void:
	var spots: Array[Vector3] = city.street_lights.duplicate()
	for p in g.street_lights:
		spots.append(city.to_local(g.to_global(p)))
	var bad := ""
	for at in spots:
		for v: float in [at.x, at.z]:
			var off := absf(v - (roundf(v / CityDistrict.PITCH - 0.5) + 0.5) * CityDistrict.PITCH)
			if off < CityDistrict.ROAD_W * 0.5 and bad == "":
				bad = "- one in the road at %s" % at
	_check("street lights stand beside the roads, not in them (%d lights) %s" % [spots.size(), bad], spots.size() > 100 and bad == "")


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
