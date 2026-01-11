extends Camera2D

@export_range(1, 10)
var movement_speed: int = 3

func _process(delta: float) -> void:
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += direction * movement_speed 
