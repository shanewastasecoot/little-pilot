class_name StarManager
extends Node
## Tracks stars in the world: counts pickups, plays the chime (rising pitch
## for quick pickups in a row), fires milestones and respawns all stars once
## every one is collected. Finds stars through the "stars" group.

signal star_collected(count: int, total: int)
signal milestone_reached(count: int)
signal all_collected

## Session counts that trigger a small celebration.
@export var milestones: Array[int] = [10, 25]
## Pickups closer together than this raise the chime pitch.
@export var combo_window: float = 1.6
## Pause between the "all collected" party and stars coming back.
@export var respawn_delay: float = 4.0

var count: int = 0
var total: int = 0
var _combo: int = 0
var _last_pickup_ms: int = -100000


func _ready() -> void:
	# Wait one frame so every star in the map has run _ready().
	await get_tree().process_frame
	for star in get_tree().get_nodes_in_group("stars"):
		star.collected.connect(_on_star_collected)
		total += 1


func _on_star_collected(_star: Star) -> void:
	count += 1
	var now := Time.get_ticks_msec()
	_combo = mini(_combo + 1, 8) if now - _last_pickup_ms < combo_window * 1000.0 else 0
	_last_pickup_ms = now
	# Major-scale steps upward for each quick pickup.
	var steps := [0, 2, 4, 5, 7, 9, 11, 12, 14]
	Sfx.play("chime", pow(2.0, steps[_combo] / 12.0))
	SaveManager.add_lifetime_star()
	star_collected.emit(count, total)
	if count >= total:
		_celebrate_all()
	elif count in milestones:
		milestone_reached.emit(count)
		Sfx.play("jingle")


func _celebrate_all() -> void:
	all_collected.emit()
	Sfx.play("fanfare")
	await get_tree().create_timer(respawn_delay, false).timeout
	respawn_all()


func respawn_all() -> void:
	count = 0
	for star in get_tree().get_nodes_in_group("stars"):
		star.respawn()
	Sfx.play("pop", 1.2)
	star_collected.emit(count, total)
