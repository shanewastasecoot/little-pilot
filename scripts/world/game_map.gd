class_name GameMap
extends Node3D
## Base for playable maps. main.gd only needs the spawn point.

@export var spawn_position: Vector3 = Vector3(0, 30, 200)
## Degrees; 0 faces -Z (north).
@export var spawn_heading_deg: float = 0.0


func spawn_heading() -> float:
	return deg_to_rad(spawn_heading_deg)
