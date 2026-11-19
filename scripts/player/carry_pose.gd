class_name CarryPose
extends SkeletonModifier3D
## Bends a KayKit character's arms round a parcel held in front of the
## chest, on top of whatever animation is playing (so walking, running and
## jumping still move the legs and body). Directions are in the skeleton's
## own space: +Z is the character's front, +X its left, +Y up.

## Where the parcel sits (model space, metres at model scale).
const PARCEL_AT := Vector3(0.0, 0.88, 0.58)
## Upper arms reach forward and a little down; forearms come in round the
## parcel's sides. Mirrored for the right arm.
const UPPER := Vector3(0.45, -0.7, 0.6)
const LOWER := Vector3(-0.3, 0.12, 0.95)

var _bones := {}


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		for side in ["l", "r"]:
			_bones[side] = [sk.find_bone("upperarm." + side), sk.find_bone("lowerarm." + side)]
	for side in ["l", "r"]:
		var mirror := 1.0 if side == "l" else -1.0
		var b: Array = _bones[side]
		if b[0] < 0 or b[1] < 0:
			continue
		_aim(sk, b[0], Vector3(UPPER.x * mirror, UPPER.y, UPPER.z))
		_aim(sk, b[1], Vector3(LOWER.x * mirror, LOWER.y, LOWER.z))


## Turn bone `i` (keeping where it starts) so it points along `dir`.
static func _aim(sk: Skeleton3D, i: int, dir: Vector3) -> void:
	var g := sk.get_bone_global_pose(i)
	var along := g.basis.y.normalized()  # a bone points along its own +Y
	var want := dir.normalized()
	if along.dot(want) > 0.9999:
		return
	var q := Quaternion(along, want)
	sk.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))
