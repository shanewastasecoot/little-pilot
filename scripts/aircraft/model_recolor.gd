class_name ModelRecolor
extends Node
## Recolours an imported model at load time by shifting one hue range in its
## palette texture (or flat material colours) to another. Used to make the
## red trainer jet blue without editing the original asset.

@export var target: MeshInstance3D
## Hue (0..1) to replace and how far around it counts as a match.
@export var from_hue: float = 0.0
@export var hue_range: float = 0.06
@export var to_color: Color = Color("3f8cff")

static var _cache: Dictionary = {}


func _ready() -> void:
	apply(to_color)


## Recolour to `color` (cached per colour, so switching is instant).
func apply(color: Color) -> void:
	to_color = color
	if target == null or target.mesh == null:
		return
	for i in target.mesh.get_surface_count():
		var mat := target.mesh.surface_get_material(i) as BaseMaterial3D
		if mat == null:
			continue
		var key := "%s:%d:%s" % [target.mesh.resource_path, i, to_color.to_html()]
		if not _cache.has(key):
			_cache[key] = _recolored(mat)
		target.set_surface_override_material(i, _cache[key])


func _recolored(mat: BaseMaterial3D) -> BaseMaterial3D:
	var m := mat.duplicate() as BaseMaterial3D
	if _matches(m.albedo_color):
		m.albedo_color = _shift(m.albedo_color)
	if m.albedo_texture:
		var img := m.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if _matches(c):
					img.set_pixel(x, y, _shift(c))
		m.albedo_texture = ImageTexture.create_from_image(img)
	return m


func _matches(c: Color) -> bool:
	var d := absf(wrapf(c.h - from_hue, -0.5, 0.5))
	return c.s > 0.35 and d < hue_range


## Keep the original brightness (shading in the palette), take the new hue.
func _shift(c: Color) -> Color:
	# Keep the model's shading (value relative to its brightest red), take
	# the paint's hue, saturation and brightness.
	var shade := clampf(c.v / 0.96, 0.4, 1.1)
	return Color.from_hsv(to_color.h, to_color.s, clampf(to_color.v * shade, 0.0, 1.0), c.a)
