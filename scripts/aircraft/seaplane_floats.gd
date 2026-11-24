class_name SeaplaneFloats
extends Node3D
## The seaplane's floats (Phase 14): two long white pontoons on struts under
## the prop plane, like a real amphibious floatplane (the wheels stay, so it
## still uses the runway). Built from simple shapes, in the model's own
## space (before model_scale).

const LENGTH := 4.4
const WIDTH := 0.46
const HEIGHT := 0.42
const APART := 0.95
## Float bottoms sit this far below the model's origin (ground_offset /
## model_scale in seaplane.tres).
const BOTTOM := 1.75


func _ready() -> void:
	var y := -BOTTOM + HEIGHT * 0.5
	for sx in [-APART, APART]:
		# The pontoon: a box with a pointed, upturned nose and a stripe.
		BuildKit.add(self, BuildKit.box(Vector3(WIDTH, HEIGHT, LENGTH)), "f4f4f4", Vector3(sx, y, 0.2))
		var nose := BuildKit.add(self, BuildKit.box(Vector3(WIDTH * 0.9, HEIGHT * 0.8, 0.9)), "f4f4f4", Vector3(sx, y + 0.08, -LENGTH * 0.5 - 0.2))
		nose.rotation.x = deg_to_rad(18.0)
		BuildKit.add(self, BuildKit.box(Vector3(WIDTH + 0.02, 0.07, LENGTH)), "e63946", Vector3(sx, y + 0.05, 0.2))
		# Struts up to the fuselage (front and back).
		for sz in [-0.9, 0.9]:
			var strut := BuildKit.add(self, BuildKit.box(Vector3(0.07, 0.95, 0.12)), "3a3a44", Vector3(sx * 0.62, y + 0.62, sz))
			strut.rotation.z = deg_to_rad(-22.0 * signf(sx))
	# A cross brace between the floats.
	for sz in [-0.9, 0.9]:
		BuildKit.add(self, BuildKit.box(Vector3(APART * 2.0, 0.05, 0.08)), "3a3a44", Vector3(0, y + 0.3, sz))
