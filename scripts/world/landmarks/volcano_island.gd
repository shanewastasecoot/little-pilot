class_name VolcanoIsland
extends Landmark
## A friendly volcano (the cone is terrain): glowing lava pool, a lazy
## smoke plume, and every so often a big (harmless, far-off-looking)
## eruption with lava bombs, an ash column and falling ash
## (VolcanoEruption). It erupts when discovered too.
## Node sits at the crater floor.

## Seconds between eruptions, and how long each lasts.
@export var eruption_every := 75.0
@export var eruption_length := 18.0

var eruption: VolcanoEruption
var _lava_mat: StandardMaterial3D
var _next_eruption := 25.0


func _init() -> void:
	landmark_name = "Volcano"
	discovery_radius = 360.0
	discovery_sound = "rumble"


func build() -> void:
	_lava_mat = BuildKit.mat("ff6a1a", true).duplicate()
	_lava_mat.emission_energy_multiplier = 2.5
	var lava := MeshInstance3D.new()
	lava.mesh = BuildKit.cyl(IslandShape.CRATER_RADIUS * 0.75, 1.0, -1, 20)
	lava.material_override = _lava_mat
	lava.position.y = 4.0
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lava)
	eruption = VolcanoEruption.new()
	eruption.lava_material = _lava_mat
	eruption.position.y = 6.0
	add_child(eruption)
	# Rocks round the crater rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 10:
		var a := TAU * i / 10.0
		var p := IslandShape.VOLCANO + Vector2(cos(a), sin(a)) * IslandShape.CRATER_RADIUS * 1.4
		var y := IslandShape.volcano_height(p.x, p.y) - position.y
		AssetLib.place(self, "res://assets/environment/rocks.glb", Vector3(p.x - IslandShape.VOLCANO.x, y - 1.0, p.y - IslandShape.VOLCANO.y), rng.randf_range(40.0, 70.0), rng.randf() * 360.0)


func _process(delta: float) -> void:
	_next_eruption -= minf(delta, 0.1)
	if _next_eruption <= 0.0:
		_next_eruption = eruption_every
		eruption.erupt(eruption_length)


func react() -> void:
	eruption.erupt(eruption_length)
	_next_eruption = eruption_every
	var sparks := PickupBurst.new(50, 30.0, [Color("ff6a1a"), Color("ffd23f"), Color("ff3b3b")])
	sparks.position.y = 8.0
	add_child(sparks)
