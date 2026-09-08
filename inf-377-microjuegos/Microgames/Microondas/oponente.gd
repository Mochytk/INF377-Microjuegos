extends Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func reaccionar(success: bool) -> void:
	if success:
		sprite.play("derrotado")
	else:
		sprite.play("bloqueando")
