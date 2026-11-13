class_name Mountains
extends Landmark
## Marks the valley between the big peaks (the peaks are terrain).
## Discovery plays a "yoo-hoo" echo.

func _init() -> void:
	landmark_name = "Mountains"
	discovery_radius = 170.0
	discovery_sound = "echo"
