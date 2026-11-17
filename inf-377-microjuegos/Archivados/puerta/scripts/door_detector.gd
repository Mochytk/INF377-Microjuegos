extends Area2D

var current_door = null

func _on_area_entered(area):
	if area.is_in_group("doors"):
		current_door = area
		
func _on_area_exited(area):
	if area == current_door:
		current_door = null
