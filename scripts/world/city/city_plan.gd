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
## Builds are spread evenly so every city is finished after about
## FULL_CITY_HOURS of play (one every ~4-5 minutes), with a little jitter.
## Because the plan is a pure function of the seed, the city at any city
## time is always the same, and nothing is ever un-built as time goes on.
##
## Each event is a Dictionary:
##   kind   "site" | "upgrade" | "shop" | "house" | "apartment" | "tower" |
##          "park" | "playground"
##   cell   Vector2i block (grid coordinates, plaza = 0,0)
##   model  .glb name in assets/environment ("" for parks/playgrounds)
##   scale  model scale
##   pos    Vector3 in city space (city node origin, on the ground)
##   yaw    degrees
##   size   Vector3 collider (width, height, depth) before yaw
##   tint   roof colour for houses (Color), else null
##   text   the message shown when it opens
##   lot    the lot's ground style the first time a lot is used, else ""
##   start, dur   seconds of city time

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
	"aquarium", "dance school", "bowling alley", "swimming pool", "noodle bar", "taco stand"]
const ROOFS := [Color("ff5a5f"), Color("4aa8ff"), Color("ffd23f"), Color("9b5de5"), Color("4cc06a"), Color("ff8c42")]
const TOWERS := [["sky_classic", 22.0, 3.15], ["sky_grey", 21.0, 4.08], ["sky_glass_b", 20.0, 4.48], ["sky_glass", 21.0, 4.08]]
const DURATIONS := {"site": 300.0, "upgrade": 360.0, "tower": 360.0, "apartment": 300.0, "shop": 240.0,
	"house": 180.0, "park": 150.0, "playground": 120.0}
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
		"yaw": yaw, "size": size, "tint": null, "text": text, "lot": "", "start": 0.0, "dur": 0.0}


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
			for p: Vector3 in _quad_spots(rng):
				var model := "bld_b" if rng.randf() < 0.5 else "bld_c"
				var h := (3.05 if model == "bld_b" else 2.35) * 11.0
				if shop_names.is_empty():
					shop_names.append_array(SHOPS)
					_shuffle(shop_names, rng)
				var name: String = shop_names.pop_back()
				out.append(_event("shop", c, model, 11.0, p, 0.0 if p.z > 0.0 else 180.0, Vector3(22, h, 22), _opened(name)))
		"houses":
			for p: Vector3 in _quad_spots(rng):
				var use_b := rng.randf() < 0.3
				# Each house faces the street on its side of the lot.
				var yaw := 0.0 if p.z > 0.0 else 180.0
				var e := _event("house", c, "house_b" if use_b else "house_a", 6.5 if use_b else 20.0, p, yaw,
					Vector3(14, 22, 18) if use_b else Vector3(22, 19, 24), "A new house is ready!")
				if not use_b:
					e.tint = ROOFS[rng.randi() % ROOFS.size()]
				out.append(e)
		"park":
			out.append(_event("park", c, "", 1.0, Vector3.ZERO, 0.0, Vector3.ZERO, "A new park opened!"))
			out.append(_event("playground", c, "", 1.0, Vector3(15, 0, -15), 0.0, Vector3(22, 8, 22), "A new playground opened!"))
	out[0].lot = "grass" if kind in ["houses", "park"] else "paving"
	return out


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
