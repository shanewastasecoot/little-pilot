class_name TodayTracker
extends Node
## Keeps today's diary for the parent summary (SummaryScreen, Phase 14):
## every few seconds, which island she's at (by the plane or by her on
## foot), and each crash (WorldEvents). Stars, deliveries and time played
## are counted where they happen (StarManager, SaveManager).

const EVERY := 3.0

var main: Node
var _places: Array = []   # [id, Node3D, radius]
var _t := 0.0


func _ready() -> void:
	WorldEvents.happened.connect(func(kind: String, _w: Vector3, _i: Dictionary):
		if kind == "crash":
			SaveManager.today_add("crashes"))
	await get_tree().process_frame
	var by_class := {"PalmIsland": ["palm", 450.0], "VolcanoIsland": ["volcano", 520.0], "MermaidLagoon": ["mermaid", 380.0],
		"DragonLair": ["dragon", 420.0], "IceIsland": ["ice", 520.0], "DinoIsland": ["dino", 560.0],
		"CastleIsland": ["castle", 480.0], "TownIsland": ["town", 520.0]}
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		for cls in by_class:
			if n.get_script() and (n.get_script() as Script).get_global_name() == cls:
				_places.append([by_class[cls][0], n, by_class[cls][1]])


func _process(delta: float) -> void:
	_t += delta
	if _t < EVERY or main == null:
		return
	_t = 0.0
	if not main.state in [main.State.FLYING, main.State.LANDED, main.State.ON_FOOT, main.State.SAILING]:
		return
	var who: Node3D = main.walker if main.state == main.State.ON_FOOT else (main.boat if main.state == main.State.SAILING else main.aircraft)
	SaveManager.today_visit(place_of(who.global_position))


## Which island `p` is at ("" over open sea).
func place_of(p: Vector3) -> String:
	for pl in _places:
		var n: Node3D = pl[1]
		if Vector2(p.x - n.global_position.x, p.z - n.global_position.z).length() < pl[2]:
			return pl[0]
	var c := IslandShape.TERRAIN_CENTRE
	if absf(p.x - c.x) < IslandShape.SIZE * 0.5 and absf(p.z - c.y) < IslandShape.SIZE * 0.5 and IslandShape.height(p.x, p.z) > 0.5:
		return "main"
	return ""
