extends Node
## One place the world hears what she does (Phase 6). Anything can listen to
## `happened` and react nearby: the dragon pricks up its ears at honks, sheep
## scatter, cows moo, birds lift off, townspeople cheer back...
##
## Kinds (and who sends them):
##   "honk"      the plane honked (AircraftController), at the plane
##   "low_pass"  the plane swept low over the ground (AircraftController),
##               at the ground below it; info.height = metres above it
##   "landing"   the wheels touched down (AircraftController)
##   "takeoff"   the wheels left the ground (AircraftController);
##               info.surface = "runway" | "grass"
##   "crash"     the plane crashed (AircraftController); info.water = bool
##   "cheer"     she cheered on foot (X; main.gd), at her
##
## Listeners decide for themselves how near counts (see `near`).

signal happened(kind: String, where: Vector3, info: Dictionary)

## The last few events, newest last (tests and the debug overlay).
var recent: Array[Dictionary] = []
const KEEP := 16


func send(kind: String, where: Vector3, info := {}) -> void:
	recent.append({"kind": kind, "where": where, "info": info, "ms": Time.get_ticks_msec()})
	if recent.size() > KEEP:
		recent.pop_front()
	happened.emit(kind, where, info)


## Is `p` within `radius` of `where` (flat distance; heights ignored)?
static func near(where: Vector3, p: Vector3, radius: float) -> bool:
	return Vector2(where.x - p.x, where.z - p.z).length() <= radius


## How many events of `kind` have been sent (in `recent`).
func count(kind: String) -> int:
	var n := 0
	for e in recent:
		if e.kind == kind:
			n += 1
	return n
