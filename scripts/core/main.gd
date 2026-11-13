extends Node3D
## Root of the game scene: puts the plane at the map's spawn point and
## points the camera at it. Menus and plane switching arrive in Phase 2.

@onready var map: GreyboxMap = $Map
@onready var aircraft: Aircraft = $Aircraft
@onready var chase_camera: ChaseCamera = $ChaseCamera


func _ready() -> void:
	aircraft.teleport(map.spawn_position, map.spawn_heading())
	chase_camera.snap_to_target()
