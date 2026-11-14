
extends Sprite2D
var velocidad = 250.0

func _process(delta):
	var direccion = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
        "ui_down"
	)

	position += direccion * velocidad * delta
