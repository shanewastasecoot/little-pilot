class_name AmbientZone
extends AudioStreamPlayer3D
## A quiet, looping sound of a place (Phase 12): heard only near it, fading
## with distance. The loops are Sfx's (a real file in assets/audio/loops/
## if there is one, else made in code):
##   amb_birds   birdsong at the farm
##   amb_city    the city's murmur
##   amb_waves   waves on the shore
##   amb_rumble  the volcano's rumble
##   amb_wind    wind in the forest
##   amb_cave    drips and a sleepy snore in the dragon's cave

static func make(loop_name: String, at: Vector3, reach: float, volume_db := -12.0) -> AmbientZone:
	var z := AmbientZone.new()
	z.name = "Ambient_" + loop_name.trim_prefix("amb_")
	z.stream = Sfx.get_loop(loop_name)
	z.position = at
	z.volume_db = volume_db
	z.unit_size = reach * 0.35
	z.max_distance = reach
	z.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	z.bus = GameSettings.BUS_SFX
	z.autoplay = true
	z.panning_strength = 0.6
	return z
