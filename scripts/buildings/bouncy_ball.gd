class_name BouncyBall
extends RigidBody3D
## A big bouncy ball to kick about indoors: walk into it and it rolls away
## (Walker pushes rigid bodies it bumps). Boing when it hits something hard.
## reset() puts it back where it started.

const RADIUS := 1.8

var home := Vector3.ZERO


func _ready() -> void:
	collision_layer = GameSettings.LAYER_WORLD
	collision_mask = GameSettings.LAYER_WORLD | GameSettings.LAYER_PLAYER
	mass = 3.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.7
	pm.friction = 0.4
	physics_material_override = pm
	linear_damp = 0.25
	angular_damp = 0.4
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	var ball := BuildKit.add(self, BuildKit.sphere(RADIUS, 20), "ff5a5f")
	ball.material_override = BuildingGenerator._mat("ff5a5f")
	var band := BuildKit.add(self, BuildKit.cyl(RADIUS * 1.01, 0.9, -1, 24), "ffffff")
	band.material_override = BuildingGenerator._mat("ffffff")
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(func(_b):
		if linear_velocity.length() > 5.0:
			Sfx.play("pop", 0.9 + randf() * 0.2, -6.0))
	position = home


func reset() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	position = home
