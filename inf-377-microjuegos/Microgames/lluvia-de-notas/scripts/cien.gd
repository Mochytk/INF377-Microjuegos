extends Node2D
# signal colision_cien()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# colision_cien.emit()
		queue_free()
	if body.is_in_group("ground"):
		queue_free()
