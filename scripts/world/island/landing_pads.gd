class_name LandingPads
extends RefCounted
## Flat landing meadows on the islands that are otherwise too bumpy or
## steep to land on, each marked with a windsock (IslandMap adds them).
## An island's height function calls flatten() last, so a pad is flat
## whatever the terrain (or the sea) was doing there.

const BLEND := 45.0  # metres over which a pad's edge eases into the terrain

## [centre, radius, ground height] in world coordinates.
const DINO := [Vector2(2900 - 250, 2300 - 220), 75.0, 16.0]
const VOLCANO := [Vector2(-1780 + 266, -1200 + 179), 65.0, 8.0]   # the beach facing home
const LAGOON_RADIUS := 46.0
const LAGOON_HEIGHT := 5.0
const LAGOON_ANGLE := PI * 0.22  # round the ring from the channel


static func flatten(h: float, x: float, z: float, pad: Array) -> float:
	var d := Vector2(x, z).distance_to(pad[0])
	return lerpf(pad[2], h, smoothstep(pad[1], pad[1] + BLEND, d))


## The lagoon's pad sits on its sand ring.
static func lagoon_pad(centre: Vector2, channel_angle: float, ring_radius: float) -> Array:
	var a := channel_angle + LAGOON_ANGLE
	return [centre + Vector2(cos(a), sin(a)) * ring_radius, LAGOON_RADIUS, LAGOON_HEIGHT]


## A windsock on a pole at a pad's edge (the same one as the airport's).
static func windsock(pad: Array) -> Node3D:
	var pole := Node3D.new()
	var c: Vector2 = pad[0]
	pole.position = Vector3(c.x + pad[1] * 0.75, pad[2], c.y)
	BuildKit.add(pole, BuildKit.cyl(0.3, 10), "dddddd", Vector3(0, 5, 0))
	var sock := Node3D.new()
	sock.position = Vector3(0, 9.6, 0)
	sock.rotation = Vector3(-0.15, 0.6, 0)
	pole.add_child(sock)
	BuildKit.add(sock, BuildKit.cyl(1.0, 5, 0.5, 8), "ff8c42", Vector3(0, 0, 2.5), Vector3(90, 0, 0))
	return pole
