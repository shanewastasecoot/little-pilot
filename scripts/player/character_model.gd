class_name CharacterModel
extends Node3D
## The player's character, built from KayKit Adventurers parts (CC0,
## assets/characters/kaykit_adventurers): every KayKit character shares one
## 41-bone rig, so a body from one and a head from another fit together.
## Scene: scenes/characters/player_character.tscn (this script on the root).
##
## apply(body, hair, outfit) builds it: the outfit picks the base character
## (body, arms, legs and animations) and repaints its palette texture; the
## hair choice picks a head (moved onto the base skeleton) and maybe repaints
## its hair; props (crowns, goggles, capes...) hang on bones. animate()
## picks Idle / walk / jog / jump from how the walker moves, at a playback
## speed that matches the feet to the ground. Origin at the feet, faces -Z.

const DIR := "res://assets/characters/kaykit_adventurers/"
## Head choices: [character whose head it is, palette repaints {cell: colour}].
## Cells are "r<row>c<col>" in the 8x4 palette texture (r0c1 = hair).
const HEADS := [
	["Rogue", {}],                              # long auburn hair
	["Knight", {}],                             # short sandy hair
	["Mage", {}],                               # short black hair
	["Rogue", {"r0c1": Color("f2c45a")}],       # long golden hair
]
const HAIRS := 4
const OUTFITS := 5
## KayKit characters are ~2.2 m tall: this makes them ~5 m like the townspeople.
const MODEL_HEIGHT := 2.2
const SCALE := Walker.HEIGHT / MODEL_HEIGHT
## Ground speed (game m/s) at which each loop's feet don't slide (measured:
## Walking_A 0.75 m/s, Running_A 1.5 m/s at model scale, times SCALE).
const WALK_NATURAL := 0.75 * SCALE
const RUN_NATURAL := 1.5 * SCALE
## Faster than this the walk becomes a jog (the legs are short).
const JOG_FROM := 2.0
const BLEND := 0.15

var body := "M"
var hair := 1
var outfit := 1
var anim := ""

var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _parts: Array[MeshInstance3D] = []
static var _atlases: Dictionary = {}


func _ready() -> void:
	if _model == null:
		_build()


## Show this hair (1..4) and outfit (1..5). Body is kept for old saves.
func apply(new_body: String, new_hair: int, new_outfit: int) -> void:
	body = new_body if new_body in ["M", "F"] else "M"
	hair = clampi(new_hair, 1, HAIRS)
	outfit = clampi(new_outfit, 1, OUTFITS)
	if is_inside_tree():
		_build()


## The parts that are showing (for tests): their names.
func visible_parts() -> Array[String]:
	var out: Array[String] = []
	for mi in _parts:
		if mi.visible:
			out.append(String(mi.name))
	return out


func _build() -> void:
	var playing := anim
	if _model:
		_model.free()
	_parts.clear()
	var look := Outfits.get_outfit(outfit)
	_model = (load(DIR + look.base + ".glb") as PackedScene).instantiate()
	_model.scale = Vector3.ONE * SCALE
	_model.rotation.y = PI  # KayKit faces +Z; the walker's forward is -Z
	add_child(_model)
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Cheer"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# Keep the base's body, arms and legs; hide its head, hat, cape, weapons.
	var keep := [look.base + "_Body", look.base + "_ArmLeft", look.base + "_ArmRight", look.base + "_LegLeft", look.base + "_LegRight"]
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.visible = String(mi.name) in keep and not String(mi.name) in look.hide
		if mi.visible:
			_paint(mi, look.base, look.palette)
			_parts.append(mi)
	# The head (maybe from another character), onto this skeleton.
	var head: Array = HEADS[hair - 1]
	var head_mesh: MeshInstance3D
	if head[0] == look.base:
		head_mesh = _model.find_children(look.base + "_Head", "MeshInstance3D", true, false)[0]
		head_mesh.visible = true
	else:
		var donor: Node3D = (load(DIR + head[0] + ".glb") as PackedScene).instantiate()
		head_mesh = donor.find_children(head[0] + "_Head", "MeshInstance3D", true, false)[0]
		head_mesh.get_parent().remove_child(head_mesh)
		donor.free()
		_skel.add_child(head_mesh)
		head_mesh.skeleton = head_mesh.get_path_to(_skel)
		head_mesh.visible = true
	_paint(head_mesh, head[0], head[1])
	_parts.append(head_mesh)
	for mi in _parts:
		mi.extra_cull_margin = 0.5
	_attach_props(look)
	anim = ""
	play(playing if playing != "" else "Idle")


## Give a part its character's palette texture, repainted for this look.
func _paint(mi: MeshInstance3D, who: String, repaint: Dictionary) -> void:
	var tex := atlas(who, repaint)
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, CharacterLook.material(tex))


## A character's palette texture with some cells repainted (cached).
static func atlas(who: String, repaint: Dictionary) -> Texture2D:
	var key := who + str(repaint)
	if _atlases.has(key):
		return _atlases[key]
	var src: Texture2D = load(DIR + who.to_lower() + "_texture.png")
	if repaint.is_empty():
		_atlases[key] = src
		return src
	var img := src.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var cw := img.get_width() / 8
	var ch := img.get_height() / 4
	for cell: String in repaint:
		var row := int(cell.substr(1, 1))
		var col := int(cell.substr(3))
		var c: Color = repaint[cell]
		# Like KayKit's own swatches: lighter at the top, darker below.
		for y in ch:
			var t := float(y) / ch
			var shade := c.lightened(0.18 * (1.0 - t)).darkened(0.3 * t)
			img.fill_rect(Rect2i(col * cw, row * ch + y, cw, 1), shade)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_atlases[key] = tex
	return tex


func _attach_props(look: OutfitData) -> void:
	for p in look.props + [["Face_Smile", "head"]]:
		var prop := CharacterLook.prop(p[0])
		if prop == null:
			continue
		var holder := BoneAttachment3D.new()
		holder.bone_name = p[1]
		_skel.add_child(holder)
		# Props are modelled in character space: undo the bone's rest pose
		# so they sit where they were made, then follow the bone.
		prop.transform = _skel.get_bone_global_rest(_skel.find_bone(p[1])).affine_inverse()
		holder.add_child(prop)
		for mi: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false) + ([prop] if prop is MeshInstance3D else []):
			_parts.append(mi)


## Pick the animation for this movement. speed: ground speed (m/s).
func animate(speed: float, on_floor: bool, rising: bool, _sprinting: bool) -> void:
	if not on_floor:
		if anim != "Jump_Start" and anim != "Jump_Idle":
			play("Jump_Start" if rising else "Jump_Idle")
			_anim.speed_scale = 1.4
		elif anim == "Jump_Start" and not _anim.is_playing():
			play("Jump_Idle")
		return
	if speed < 0.3:
		play("Idle")
		_anim.speed_scale = 1.0
	elif speed > JOG_FROM:
		play("Running_A")
		_anim.speed_scale = clampf(speed / RUN_NATURAL, 0.7, 2.6)
	else:
		play("Walking_A")
		_anim.speed_scale = clampf(speed / WALK_NATURAL, 0.5, 2.0)


## A little wave (the cheer) then back to idle: for the character screen.
func wave() -> void:
	play("Cheer")
	_anim.speed_scale = 1.0
	var t := get_tree().create_timer(_anim.current_animation_length * 0.95, true, false, true)
	t.timeout.connect(func():
		if anim == "Cheer":
			play("Idle"))


func play(name: String) -> void:
	if anim == name or _anim == null:
		return
	anim = name
	_anim.play(name, BLEND)
