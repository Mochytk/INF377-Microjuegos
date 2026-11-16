extends Node2D
## Dibuja la lluvia: gotas que caen inclinadas según `dir` (-1 = hacia la izquierda, 1 = hacia la derecha).

const CANTIDAD := 110
const VEL_Y := 640.0
const VEL_X := 300.0

var dir := 0.0
var gotas: Array[Vector2] = []

func _ready() -> void:
	for i in range(CANTIDAD):
		gotas.append(Vector2(randf_range(-200, 1352), randf_range(0, 648)))

func _process(delta: float) -> void:
	var v := Vector2(dir * VEL_X, VEL_Y)
	for i in range(gotas.size()):
		gotas[i] += v * delta
		if gotas[i].y > 660.0:
			gotas[i] = Vector2(randf_range(-200, 1352), randf_range(-40, 0))
	queue_redraw()

func _draw() -> void:
	var cola := Vector2(dir * VEL_X, VEL_Y).normalized() * 22.0
	for g in gotas:
		draw_line(g - cola, g, Color(0.75, 0.87, 1.0, 0.7), 2.0)
