extends Node
## Parachute drops (Phase 14): friends where the plane can't land.
##   riders    the sailor stands on the moving sail boat and the captain on
##             the pirate ship, going wherever they go
##   friends   the hiker stands on the mountain summit
##   drops     for each: a pass high over them drops nothing; a low pass
##             drops the parcel, which follows them down and is delivered
##             (reward stars)
## Exit code 0 = pass, 1 = fail.

const PATH := "user://test_parachute.cfg"
const FRIENDS := ["sailor", "hiker", "captain"]
var _fails := 0
var _main: Node
var _dm: DeliveryManager
var _plane: Aircraft


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.use_path(PATH)
	SaveManager.dragon = false
	SaveManager.crashes = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_main.title.hide()
	await _frames(15)
	_dm = _main.delivery
	_plane = _main.aircraft
	_plane.input.override_enabled = true
	# --- where they are -------------------------------------------------------------------
	var sailor: Recipient = _dm.recipients["sailor"]
	var captain: Recipient = _dm.recipients["captain"]
	var hiker: Recipient = _dm.recipients["hiker"]
	var on_boat := sailor.get_parent().get_parent() is Boat
	var on_ship := captain.get_parent().get_parent() is PirateShip
	var p0 := sailor.global_position
	await _frames(120)
	var moved := sailor.global_position.distance_to(p0)
	var boat: Node3D = sailor.get_parent().get_parent()
	var deck_dist := Vector2(sailor.global_position.x - boat.global_position.x, sailor.global_position.z - boat.global_position.z).length()
	print("  note: sailor moved %.1f m with the boat (%.1f m from its middle), captain at %s" % [moved, deck_dist, str(captain.global_position.round())])
	_check("the sailor rides the sail boat and the captain the pirate ship", on_boat and on_ship and moved > 4.0 and deck_dist < 9.0
			and captain.global_position.y > 4.0)
	var summit := IslandShape.height(195, -897)
	_check("the hiker stands on the mountain top", absf(hiker.global_position.y - summit) < 6.0 and summit > 200.0)
	# --- the drops ---------------------------------------------------------------------------
	_main._enter(_main.State.FLYING)
	for id in FRIENDS:
		await _drop_to(id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\nPARACHUTE TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _drop_to(id: String) -> void:
	_dm._start(id, true)
	var who: Recipient = _dm.target()
	var stars0 := SaveManager.lifetime_stars
	var done := [false]
	_dm.delivered.connect(func(d, _f): if d == id: done[0] = true, CONNECT_ONE_SHOT)
	for i in 40:
		_plane.global_position = who.global_position + Vector3(0, who.data.drop_height + 40.0, 0)
		await get_tree().physics_frame
	var high_kept: bool = _dm.carrying() and not done[0]
	var caught := 999.0
	for i in 260:
		if i < 20:
			_plane.global_position = who.global_position + Vector3(-8, who.data.drop_height - 20.0, 0)
		await get_tree().physics_frame
		var drop := _main.get_node_or_null("AirDrop") as Node3D
		if drop:
			caught = drop.global_position.distance_to(who.catch_point())
		if done[0]:
			break
	print("  note: %s: high pass kept it %s, delivered %s, parcel ended %.1f m from their arms" % [id, high_kept, done[0], caught])
	_check("%s: a high pass drops nothing; a low pass parachutes the parcel into their arms" % id,
			high_kept and done[0] and not _dm.carrying() and caught < 3.0
			and SaveManager.lifetime_stars == stars0 + DeliveryManager.REWARD_STARS)
	await _frames(30)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
