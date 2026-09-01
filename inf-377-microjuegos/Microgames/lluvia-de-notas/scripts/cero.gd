extends Node2D
signal colision_cero()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		queue_free()
		colision_cero.emit()
	if body.is_in_group("ground"):
		queue_free()
