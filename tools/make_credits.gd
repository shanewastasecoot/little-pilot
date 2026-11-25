extends Node
## Writes CREDITS.md from resources/credits.json (Credits.markdown()).
## Run: ./dev.sh credits

func _ready() -> void:
	var f := FileAccess.open("res://CREDITS.md", FileAccess.WRITE)
	f.store_string(Credits.markdown())
	f.close()
	print("Wrote CREDITS.md from resources/credits.json")
	get_tree().quit()
