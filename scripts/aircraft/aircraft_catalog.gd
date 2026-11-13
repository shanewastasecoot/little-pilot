class_name AircraftCatalog
extends RefCounted
## Every flyable aircraft, in menu order. Adding a plane = add its .tres here.

const PATHS := {
	"prop": "res://resources/aircraft/prop_plane.tres",
	"jet": "res://resources/aircraft/fighter_jet.tres",
}
const DEFAULT_ID := "prop"


static func ids() -> Array:
	return PATHS.keys()


static func has(id: String) -> bool:
	return PATHS.has(id)


## Stats for `id`, or the default plane if the id is unknown.
static func get_stats(id: String) -> AircraftStats:
	return load(PATHS.get(id, PATHS[DEFAULT_ID])) as AircraftStats
