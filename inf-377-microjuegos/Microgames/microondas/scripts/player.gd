extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var paso := 32.0
@export var duracion_paso := 0.15

var direcciones := {
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN,
	"ui_left": Vector2.LEFT,
	"ui_right": Vector2.RIGHT,
}

func mover_en_direccion(action: String) -> void:
	var dir: Vector2 = direcciones[action]
	_animar_direccion(dir)

	var tween := create_tween()
	tween.tween_property(self, "position", position + dir * paso, duracion_paso)
	await tween.finished
	sprite.play("idle_" + _nombre_direccion(dir))

func _animar_direccion(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		sprite.flip_h = dir.x < 0
		sprite.play("walk_side")
	else:
		sprite.play("walk_up" if dir.y < 0 else "walk_down")

func _nombre_direccion(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "side"
	return "up" if dir.y < 0 else "down"
