class_name CityPlan
extends RefCounted
## The city's growth plan: a timed list of build events, made from the
## save's city seed. Pure data (no nodes), so it's cheap and testable.
##
## Today's city is a 5x5 grid of blocks round the plaza. It grows outward,
## ring by ring, up to an 11x11 grid (about 4.5 times the area), skipping
## blocks that would sit on the beach or crowd the runway, lighthouse or
## farm (IslandShape.city_cell_ok). Growth stays joined up: a lot can only
## be claimed next to the city as it is, and more often right beside lots
## claimed recently, so neighbourhoods form. Near downtown: towers, flats
## and shops; further out: shops and houses; the outskirts are mostly
## houses and parks. The three old construction sites finish early on, and
## late in the plan a few of downtown's old shop pairs become skyscrapers.
##
## IMPORTANT: a saved city is rebuilt from its seed with this code, so any
## change to what make() produces (models, order, kinds, timings) changes
## every family's city. After release, only add things in a way that keeps
## old seeds' plans the same (or bump a plan version and keep the old one).
##
## Builds are spread evenly so every city is finished after about
## FULL_CITY_HOURS of play (one every ~4-5 minutes), with a little jitter.
## Because the plan is a pure function of the seed, the city at any city
## time is always the same, and nothing is ever un-built as time goes on.
##
## Each event is a Dictionary:
##   kind   "site" | "upgrade" | "shop" | "house" | "apartment" | "tower" |
##          "park" | "playground" | "school"
##   cell   Vector2i block (grid coordinates, plaza = 0,0)
##   model  .glb name in assets/environment ("" for parks/playgrounds)
##   scale  model scale
##   pos    Vector3 in city space (city node origin, on the ground)
##   yaw    degrees
##   size   Vector3 collider (width, height, depth) before yaw
##   tint   roof colour for houses (Color), else null; tint_hue: the hue
##          (0..1) of the model's roof that gets swapped for it
##   offset Vector3 that centres the model on its spot (model pivot fix)
##   text   the message shown when it opens
##   lot    the lot's ground style the first time a lot is used, else ""
##   start, dur   seconds of city time

## The city plan's version (Phase 10). Raise it whenever a change here would
## make the same seed grow a different city: saved cities made with an older
## version then keep their own plan (SaveManager.city_plan()) instead of
## silently turning into a different city.
const VERSION := 1
const PITCH := IslandShape.CITY_PITCH
const FIRST_RING := 3
const MAX_RING := IslandShape.CITY_MAX_RING
const FIRST_START := 180.0   # the first build starts 3 minutes in
const FULL_CITY_HOURS := 22.0
const JITTER := 0.25         # +/- fraction of the gap between builds
## Star ring round today's city (IslandMap) is at 370 m, 55 m up: only lots
## well inside it get tall buildings; everything else stays under 40 m.
const LOW_RADIUS := 335.0
const UPGRADES := 6
## Old shop pairs downtown (CityDistrict) that can become towers late on.
const PAIR_CELLS := [Vector2i(0, -1), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(-2, -1),
	Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2)]
const SITE_CELLS := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]

const SHOPS := ["bakery", "toy shop", "ice cream shop", "pet shop", "book shop", "flower shop",
	"sweet shop", "bike shop", "pizza place", "music shop", "cafe", "sports shop", "art shop",
	"shoe shop", "hat shop", "kite shop", "cake shop", "fruit shop", "comic shop", "puppet theatre",
	"cinema", "library", "post office", "fire station", "doctor's", "vet's", "school", "museum",
	"aquarium", "dance studio", "bowling alley", "swimming pool", "noodle bar", "taco stand"]
const ROOFS := [Color("ff5a5f"), Color("4aa8ff"), Color("ffd23f"), Color("9b5de5"), Color("4cc06a"), Color("ff8c42")]
const TOWERS := [["sky_classic", 22.0, 3.15], ["sky_grey", 21.0, 4.08], ["sky_glass_b", 20.0, 4.48], ["sky_glass", 21.0, 4.08]]
## Model catalogue: [name, width, height, depth, centre x, centre z] at
## scale 1 (measured from each .glb's bounds). Each is scaled to fit its
## spot (and under the height cap) when placed.
const SHOP_MODELS := [["bld_b", 2.0, 3.05, 2.0, 0.0, 0.0], ["bld_c", 2.0, 2.35, 2.0, 0.0, 0.0],
	["office_a", 0.84, 1.68, 0.84, 0.0, 0.0], ["office_b", 2.32, 2.48, 1.82, -0.34, -0.09],
	["office_c", 1.24, 1.68, 1.24, 0.0, 0.0], ["office_d", 0.97, 1.68, 0.84, -0.065, 0.0],
	["office_e", 1.24, 2.08, 1.34, 0.0, -0.05], ["office_f", 2.04, 1.5, 0.845, 0.0, 0.0],
	["office_g", 2.04, 1.68, 1.24, 0.0, 0.0], ["shop_small_a", 1.64, 0.88, 0.968, 0.0, -0.064],
	["shop_small_b", 0.84, 1.28, 0.968, 0.0, -0.064]]
## Houses: roof hue to recolour (house_a: red, home_*: teal).
const HOUSE_MODELS := [["house_a", 1.108, 0.952, 1.172, 0.015, -0.307, 0.0], ["house_b", 2.144, 3.39, 2.659, 0.0, -0.013, -1.0],
	["home_1", 1.308, 0.7375, 1.308, 0.0, 0.0, 0.45], ["home_2", 1.308, 1.1375, 1.406, 0.0, 0.0, 0.45],
	["home_3", 1.736, 1.2, 1.006, 0.0, 0.0, 0.45], ["home_4", 1.3, 1.1375, 1.316, 0.0, 0.0, 0.45],
	["home_5", 1.3, 1.1375, 1.006, 0.0, 0.0, 0.45]]
const SCHOOL_MODELS := [["school_a", 13.18, 15.02, 15.31, 0.0, 0.0], ["school_b", 6.93, 10.05, 6.83, 0.34, 0.0]]
## Kenney roofs keep their teal or get one of these (fewer variants = fewer
## batches to draw).
const HOME_ROOFS := [Color("ff5a5f"), Color("4aa8ff"), Color("ffd23f")]
const SLOT := 22.0           # a quarter-lot spot (m)
const LOW_CAP := 38.0        # height cap away from downtown (star ring)
const SCHOOLS := 2

const DURATIONS := {"site": 300.0, "upgrade": 360.0, "tower": 360.0, "apartment": 300.0, "shop": 240.0,
	"house": 180.0, "park": 150.0, "playground": 120.0, "school": 300.0}
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func ring_of(cell: Vector2i) -> int:
	return maxi(absi(cell.x), absi(cell.y))


## Every lot the city can grow onto, inner rings first.
static func growth_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ring in range(FIRST_RING, MAX_RING + 1):
		for x in range(-ring, ring + 1):
			for z in range(-ring, ring + 1):
				var c := Vector2i(x, z)
				if ring_of(c) == ring and IslandShape.city_cell_ok(c):
					out.append(c)
	return out


static func cell_centre(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * PITCH, 0, cell.y * PITCH)


## Can this lot take a tall building without reaching the star ring?
static func tall_ok(cell: Vector2i) -> bool:
	var far := Vector2(absf(cell.x * PITCH) + 32.0, absf(cell.y * PITCH) + 32.0)
	return far.length() < LOW_RADIUS


static func make(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := growth_cells()
	var kinds := _choose_kinds(cells, rng)
	var order := _claim_order(cells, rng)
	# Events, lot by lot; the old construction sites finish early on.
	var events: Array[Dictionary] = []
	var shop_names := SHOPS.duplicate()
	_shuffle(shop_names, rng)
	var site_at := {0: 0, 3: 1, 7: 2}
	for c in order:
		for e in _lot_events(c, kinds[c], rng, shop_names):
			while site_at.has(events.size()):
				events.append(_site_event(SITE_CELLS[site_at[events.size()]]))
			events.append(e)
	# Downtown grows taller in the last third: some old shop pairs become towers.
	var pairs := PAIR_CELLS.duplicate()
	_shuffle(pairs, rng)
	for k in UPGRADES:
		var at := int(events.size() * (0.66 + 0.3 * k / float(UPGRADES)))
		events.insert(at, _upgrade_event(pairs[k], rng))
	# Timings: spread evenly so the whole city takes FULL_CITY_HOURS.
	var gap := (FULL_CITY_HOURS * 3600.0 - FIRST_START - 360.0) / (events.size() - 1)
	for i in events.size():
		var e := events[i]
		e.start = FIRST_START + i * gap + rng.randf_range(-JITTER, JITTER) * gap * (0.0 if i == 0 else 1.0)
		e.dur = DURATIONS[e.kind]
	return events


static func _choose_kinds(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Dictionary:
	var kinds := {}
	for c in cells:
		var ring := ring_of(c)
		var r := rng.randf()
		if ring == FIRST_RING and mini(absi(c.x), absi(c.y)) == FIRST_RING:
			kinds[c] = "park" if r < 0.25 else "houses"    # first-ring corners
		elif tall_ok(c):
			kinds[c] = "tower" if r < 0.3 else ("apartment" if r < 0.6 else "shops")
		elif ring == FIRST_RING:
			kinds[c] = "shops" if r < 0.5 else "houses"
		elif ring == FIRST_RING + 1:
			kinds[c] = "shops" if r < 0.35 else ("houses" if r < 0.8 else ("apartment" if r < 0.9 else "park"))
		else:
			kinds[c] = "houses" if r < 0.65 else ("shops" if r < 0.85 else "park")
	# A couple of schools out where the families live (whole-lot buildings).
	var homes := cells.filter(func(c): return ring_of(c) > FIRST_RING and kinds[c] == "houses")
	_shuffle(homes, rng)
	for k in mini(SCHOOLS, homes.size()):
		kinds[homes[k]] = "school"
	# At least one park per ring.
	for ring in range(FIRST_RING, MAX_RING + 1):
		var in_ring := cells.filter(func(c): return ring_of(c) == ring)
		if not in_ring.is_empty() and not in_ring.any(func(c): return kinds[c] == "park"):
			kinds[in_ring[rng.randi() % in_ring.size()]] = "park"
	return kinds


## Claim lots one at a time. Only lots touching the city so far can be
## claimed; ones touching more claimed lots are likelier (neighbourhoods).
static func _claim_order(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var claimed := {}
	var order: Array[Vector2i] = []
	var left := cells.duplicate()
	while not left.is_empty():
		var options: Array[Vector2i] = []
		var weights: Array[float] = []
		var total := 0.0
		for c in left:
			var touching := 0
			var joined := false
			for d in SIDES:
				var n: Vector2i = c + d
				if ring_of(n) < FIRST_RING:
					joined = true
				elif claimed.has(n):
					joined = true
					touching += 1
			if not joined:
				continue
			var w := 1.0 + 3.0 * touching
			options.append(c)
			weights.append(w)
			total += w
		if options.is_empty():
			break  # a lot cut off from the city: never built
		var pick := rng.randf() * total
		var i := 0
		while i < options.size() - 1 and pick > weights[i]:
			pick -= weights[i]
			i += 1
		order.append(options[i])
		claimed[options[i]] = true
		left.erase(options[i])
	return order


static func _event(kind: String, cell: Vector2i, model: String, scale: float, offset: Vector3, yaw: float, size: Vector3, text: String) -> Dictionary:
	return {"kind": kind, "cell": cell, "model": model, "scale": scale, "pos": cell_centre(cell) + offset,
		"yaw": yaw, "size": size, "tint": null, "tint_hue": 0.0, "offset": Vector3.ZERO, "text": text,
		"lot": "", "start": 0.0, "dur": 0.0}


static func _lot_events(c: Vector2i, kind: String, rng: RandomNumberGenerator, shop_names: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var face := 0.0 if absi(c.y) >= absi(c.x) and c.y > 0 else (180.0 if absi(c.y) >= absi(c.x) else (90.0 if c.x > 0 else -90.0))
	match kind:
		"tower":
			var t: Array = TOWERS[rng.randi() % TOWERS.size()]
			var h: float = t[2] * t[1]
			out.append(_event("tower", c, t[0], t[1], Vector3.ZERO, face, Vector3(1.25 * t[1], h, 1.35 * t[1]), "A new skyscraper is finished!"))
		"apartment":
			var axis := Vector3(14, 0, 0) if absi(c.y) >= absi(c.x) else Vector3(0, 0, 14)
			for side in [-1.0, 1.0]:
				out.append(_event("apartment", c, "bld_b", 13.0, axis * side, face, Vector3(26, 3.05 * 13.0, 26), "A new apartment building is ready!"))
		"shops":
			var cap := 50.0 if tall_ok(c) else LOW_CAP
			for p: Vector3 in _quad_spots(rng):
				if shop_names.is_empty():
					shop_names.append_array(SHOPS)
					_shuffle(shop_names, rng)
				var name: String = shop_names.pop_back()
				var m: Array = SHOP_MODELS[rng.randi() % SHOP_MODELS.size()]
				out.append(_fitted("shop", c, m, SLOT, cap, p, 0.0 if p.z > 0.0 else 180.0, _opened(name)))
		"houses":
			for p: Vector3 in _quad_spots(rng):
				var m: Array = HOUSE_MODELS[rng.randi() % HOUSE_MODELS.size()]
				# Each house faces the street on its side of the lot.
				var e := _fitted("house", c, m, SLOT, 24.0, p, 0.0 if p.z > 0.0 else 180.0, "A new house is ready!")
				var hue: float = m[6]
				if hue == 0.0:
					e.tint = ROOFS[rng.randi() % ROOFS.size()]
				elif hue > 0.0:
					var pick := rng.randi() % (HOME_ROOFS.size() + 1)
					if pick < HOME_ROOFS.size():
						e.tint = HOME_ROOFS[pick]
				e.tint_hue = maxf(hue, 0.0)
				out.append(e)
		"school":
			var m: Array = SCHOOL_MODELS[rng.randi() % SCHOOL_MODELS.size()]
			out.append(_fitted("school", c, m, 46.0, LOW_CAP, Vector3.ZERO, face, "A new school opened!"))
		"park":
			out.append(_event("park", c, "", 1.0, Vector3.ZERO, 0.0, Vector3.ZERO, "A new park opened!"))
			out.append(_event("playground", c, "", 1.0, Vector3(15, 0, -15), 0.0, Vector3(22, 8, 22), "A new playground opened!"))
	out[0].lot = "grass" if kind in ["houses", "park", "school"] else "paving"
	return out


## Kenney's teal roofs are soft (30% saturated): recolour them anyway.
static func tint_min_saturation(hue: float) -> float:
	return 0.18 if hue > 0.0 else 0.28


## A catalogue model scaled to fit a `slot` m spot and `cap` m high.
static func _fitted(kind: String, cell: Vector2i, m: Array, slot: float, cap: float, spot: Vector3, yaw: float, text: String) -> Dictionary:
	var s := minf(slot / maxf(m[1], m[3]), cap / m[2])
	var e := _event(kind, cell, m[0], s, spot, yaw, Vector3(m[1] * s, m[2] * s, m[3] * s), text)
	e.offset = Vector3(-m[4] * s, 0, -m[5] * s)
	return e


static func _opened(name: String) -> String:
	var a := "An" if name[0] in ["a", "e", "i", "o", "u"] else "A"
	return "%s new %s opened!" % [a, name]


## The four quarters of a lot, in a random order.
static func _quad_spots(rng: RandomNumberGenerator) -> Array:
	var spots := [Vector3(-14, 0, -14), Vector3(14, 0, -14), Vector3(-14, 0, 14), Vector3(14, 0, 14)]
	_shuffle(spots, rng)
	return spots


static func _site_event(cell: Vector2i) -> Dictionary:
	match cell:
		Vector2i(0, 1):
			return _event("site", cell, "sky_glass", 34.0, Vector3.ZERO, 0.0, Vector3(1.25 * 34.0, 4.08 * 34.0, 1.35 * 34.0), "The big glass tower is finished!")
		Vector2i(1, 1):
			return _event("site", cell, "sky_grey", 30.0, Vector3.ZERO, 90.0, Vector3(1.25 * 30.0, 4.08 * 30.0, 1.35 * 30.0), "A new skyscraper is finished!")
	return _event("site", cell, "sky_classic", 24.0, Vector3.ZERO, 0.0, Vector3(1.25 * 24.0, 3.15 * 24.0, 1.35 * 24.0), "A new skyscraper is finished!")


## An old downtown shop pair knocked down for a tall tower.
static func _upgrade_event(cell: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var t: Array = TOWERS[rng.randi() % TOWERS.size()]
	var s := 27.0 + rng.randf() * 3.0
	var h: float = t[2] * s
	return _event("upgrade", cell, t[0], s, Vector3.ZERO, 90.0 * rng.randi_range(0, 3), Vector3(1.25 * s, h, 1.35 * s), "The old shops became a skyscraper!")


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## The road segments round a lot that don't exist yet, as [from, to] in city
## space (along x or z). The old 5x5 roads cover everything within
## +/- 2.5 * PITCH.
static func lot_roads(cell: Vector2i) -> Array:
	var c := cell_centre(cell)
	var h := PITCH * 0.5
	var segs := [
		[c + Vector3(-h, 0, -h), c + Vector3(h, 0, -h)], [c + Vector3(-h, 0, h), c + Vector3(h, 0, h)],
		[c + Vector3(-h, 0, -h), c + Vector3(-h, 0, h)], [c + Vector3(h, 0, -h), c + Vector3(h, 0, h)],
	]
	var core := PITCH * 2.5 + 0.5
	return segs.filter(func(s): return not (absf(s[0].x) <= core and absf(s[0].z) <= core and absf(s[1].x) <= core and absf(s[1].z) <= core))
