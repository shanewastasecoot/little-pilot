class_name Spotter
extends Node
## Fills the sticker book (Phase 14) and takes postcards:
##   - every place, animal and friend in the book gets a picture the first
##     time it's near and on screen (taken automatically, the HUD hidden for
##     that one frame), and a friend is snapped when she hands them a parcel
##   - LB takes a postcard: a white flash, a click, the picture into the book
## Pictures are saved small (320x200) in user://book/<id>.png and
## user://postcards/<n>.png; which ones exist is saved in SaveManager's new
## [book] keys. Nothing ever leaves the computer.

const EVERY := 0.5
const SIZE := Vector2i(320, 200)
const MAX_POSTCARDS := 48
## Animals: [id, class name of where they live, how near counts (m)].
const ANIMALS := [
	["farm_animals", "Farm", 170.0], ["penguins", "IceIsland", 450.0], ["dinosaurs", "DinoIsland", 480.0],
	["whale", "Whale", 200.0], ["dolphins", "SeaLeapers", 160.0], ["dragon", "Dragon", 220.0],
]

var main: Node
var flash: ColorRect
## [id, kind ("place" | "animal" | "friend"), node, radius]
var targets: Array = []
var _t := 0.0
var _busy := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://book"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://postcards"))
	await get_tree().process_frame
	await get_tree().process_frame
	var named := {}
	for l in get_tree().get_nodes_in_group("landmarks"):
		var n := str(l.get("landmark_name"))
		if n == "Whale" or named.has(n):
			continue
		named[n] = true
		targets.append(["place:" + n, "place", l, maxf(float(l.get("discovery_radius")), 120.0)])
	for a in ANIMALS:
		for n in get_tree().root.find_children("*", "Node3D", true, false):
			if n.get_script() and (n.get_script() as Script).get_global_name() == a[1]:
				var at: Node3D = n
				if a[1] == "Whale" and n.get("_body"):
					at = n.get("_body")
				targets.append(["animal:" + a[0], "animal", at, a[2]])
				break
	if main and main.get("delivery"):
		for id in main.delivery.recipients:
			targets.append(["friend:" + id, "friend", main.delivery.recipients[id], 45.0])
		main.delivery.delivered.connect(func(id: String, _first: bool): snap("friend:" + id, true))


func _process(delta: float) -> void:
	_t += delta
	if _t < EVERY or _busy or main == null:
		return
	_t = 0.0
	if not main.state in [main.State.FLYING, main.State.LANDED, main.State.ON_FOOT, main.State.SAILING]:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for tg in targets:
		if SaveManager.book_has(tg[0]):
			continue
		var n: Node3D = tg[2]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var p := n.global_position + Vector3.UP * 6.0
		if p.distance_to(cam.global_position) < float(tg[3]) and cam.is_position_in_frustum(p) \
				and cam.unproject_position(p).distance_to(get_viewport().get_visible_rect().get_center()) < get_viewport().get_visible_rect().size.y * 0.45:
			snap(tg[0])
			return


## Take the book's picture for `id` (once, unless `again`).
func snap(id: String, again := false) -> void:
	if _busy or (SaveManager.book_has(id) and not again):
		return
	var img: Image = await _grab()
	if img == null:
		return
	img.save_png("user://book/%s.png" % id.replace(":", "_"))
	SaveManager.book_add(id)


## LB: a postcard, with a flash.
func postcard() -> bool:
	if _busy:
		return false
	_take_postcard()
	return true


func _take_postcard() -> void:
	var img: Image = await _grab()
	if img == null:
		return
	var n := SaveManager.next_postcard()
	img.save_png("user://postcards/%d.png" % n)
	var gone := SaveManager.add_postcard(n, MAX_POSTCARDS)
	if gone >= 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://postcards/%d.png" % gone))
	Sfx.play("pop", 1.6)
	Sfx.play("chime", 1.8, -8.0)
	if flash:
		flash.color = Color(1, 1, 1, 0.85)
		create_tween().tween_property(flash, "color:a", 0.0, 0.35)


## The screen without the HUD, small.
func _grab() -> Image:
	_busy = true
	StallDetector.note("photo")
	var hidden := []
	if main and main.get("hud"):
		hidden.append(main.hud)
	for n in get_tree().get_nodes_in_group("hide_in_photos"):
		hidden.append(n)
	if flash:
		hidden.append(flash)  # (not a postcard's own white flash either)
	var was := []
	for h in hidden:
		was.append(h.visible)
		h.visible = false
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame  # (nothing is drawn: no "drawn" signal)
	else:
		await RenderingServer.frame_post_draw
	var img: Image = null if DisplayServer.get_name() == "headless" else get_viewport().get_texture().get_image()
	for i in hidden.size():
		hidden[i].visible = was[i]
	_busy = false
	if img == null or img.is_empty():
		# (No screen to copy: headless runs. A plain sky-blue card instead.)
		img = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
		img.fill(Color("9fd8ff"))
		return img
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	return img


## A saved picture as a texture (null if none).
static func picture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null
