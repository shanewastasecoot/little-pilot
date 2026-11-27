extends SceneTree
## Graphics G4: writes assets/terrain/detail.png, the terrain's small,
## seamless detail texture (made here, no credit needed). Four channels of
## soft noise around mid-grey, read by shaders/terrain.gdshader:
##   R  clumps    blotchy grass clumps / tufts (a few metres)
##   G  grain     fine speckle (sand grain, gravel)
##   B  cracks    cellular edges (rock cracks, flagstone-ish)
##   A  patches   big soft blobs (meadow patches, rock tone)
## Run: flatpak run org.godotengine.Godot --headless --path . -s res://tools/make_terrain_detail.gd

const SIZE := 256
const OUT := "res://assets/terrain/detail.png"


func _init() -> void:
	var chans: Array[Image] = [
		_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 6.0, 3, 11),
		_noise(FastNoiseLite.TYPE_VALUE, 48.0, 2, 12),
		_cells(9.0, 13),
		_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2.0, 2, 14),
	]
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			out.set_pixel(x, y, Color(chans[0].get_pixel(x, y).r, chans[1].get_pixel(x, y).r,
				chans[2].get_pixel(x, y).r, chans[3].get_pixel(x, y).r))
	out.save_png(OUT)
	print("Wrote ", OUT)
	quit()


## Seamless fractal noise, `freq` features across the tile, normalised 0-1.
func _noise(kind: int, freq: float, octaves: int, seed_value: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.seed = seed_value
	n.frequency = freq / SIZE
	n.fractal_octaves = octaves
	return _normalised(n.get_seamless_image(SIZE, SIZE, false, false, 0.1))


## Seamless cellular edges (distance to the second-nearest cell minus the
## nearest): dark lines between cells.
func _cells(freq: float, seed_value: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.seed = seed_value
	n.frequency = freq / SIZE
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return _normalised(n.get_seamless_image(SIZE, SIZE, false, false, 0.1))


func _normalised(img: Image) -> Image:
	img.convert(Image.FORMAT_RF)
	var lo := INF
	var hi := -INF
	for y in SIZE:
		for x in SIZE:
			var v := img.get_pixel(x, y).r
			lo = minf(lo, v)
			hi = maxf(hi, v)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, Color((img.get_pixel(x, y).r - lo) / maxf(hi - lo, 1e-5), 0, 0))
	return img
