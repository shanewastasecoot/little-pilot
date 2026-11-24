class_name SeaplaneFloats
extends Node3D
## The seaplane's floats (Phase 14): two long white pontoons on struts under
## the plane, like a real amphibious floatplane (the wheels stay, so it
## still uses the runway). Built from simple shapes, in the model's own
## space (before model_scale); sized to the plane by the scene.

@export var length := 3.4
@export var width := 0.3
@export var height := 0.28
## How far each float is from the middle.
@export var apart := 0.62
## Float bottoms sit this far below the model's origin (ground_offset /
## model_scale in seaplane.tres).
@export var bottom := 1.0
## Where the struts reach up to (the underside of the fuselage).
@export var belly := -0.15
@export var forward := -0.1


func _ready() -> void:
	var y := -bottom + height * 0.5
	var strut_h := belly - (y + height * 0.5)
	for sx in [-apart, apart]:
		# The pontoon: a box with a pointed, upturned nose and a stripe.
		BuildKit.add(self, BuildKit.box(Vector3(width, height, length)), "f4f4f4", Vector3(sx, y, forward))
		var nose := BuildKit.add(self, BuildKit.box(Vector3(width * 0.9, height * 0.8, length * 0.2)), "f4f4f4",
				Vector3(sx, y + height * 0.2, forward - length * 0.5 - length * 0.05))
		nose.rotation.x = deg_to_rad(18.0)
		BuildKit.add(self, BuildKit.box(Vector3(width + 0.02, height * 0.17, length)), "e63946", Vector3(sx, y + height * 0.12, forward))
		# Struts up to the fuselage (front and back), leaning in.
		for sz in [-length * 0.2, length * 0.2]:
			var strut := BuildKit.add(self, BuildKit.box(Vector3(0.05, strut_h, 0.08)), "3a3a44",
					Vector3(sx * 0.62, y + height * 0.5 + strut_h * 0.5, forward + sz))
			strut.rotation.z = atan2(sx * 0.38, strut_h) * -1.0
	# Cross braces between the floats.
	for sz in [-length * 0.2, length * 0.2]:
		BuildKit.add(self, BuildKit.box(Vector3(apart * 2.0, 0.04, 0.06)), "3a3a44", Vector3(0, y + height * 0.5 + strut_h * 0.35, forward + sz))
