class_name WorldBounds
extends Node3D
## Marks the playable area for this map. FlightSafety reads it.
## Put one in each map; its position is the centre of the world.

## Horizontal radius of the play area (m).
@export var radius: float = 500.0
## Width of the zone near the edge where the plane is steered back.
@export var edge_band: float = 120.0
## Highest altitude (m).
@export var ceiling: float = 120.0
## Height below the ceiling where the plane starts levelling off.
@export var ceiling_band: float = 25.0


func _enter_tree() -> void:
	add_to_group("world_bounds")
