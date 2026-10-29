extends Sprite2D
## Microjuego "Enviar tarea": hay que hacer clic en el botón antes de que se acabe el tiempo.
## Gana si lo presiona a tiempo; pierde si el tiempo llega a 0.

var click := false
var ended := false
var velocidad: float = 450.0
var direccion: Vector2 = Vector2(1, 1).normalized()
var move := false

@onready var timer: Timer = $Timer
@onready var label: Label = $Timer/Label

func _ready() -> void:
	# Dificultad: nivel 1 va lento y con 5 s; sube la velocidad y baja el tiempo (con tope).
	var core = get_parent().get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	velocidad = minf(850.0, 450.0 + 65.0 * level)

	randomize()
	direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	timer.wait_time = maxf(3.5, 5.0 - 0.25 * level)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	label.text = str(timer.wait_time)
	# Un segundo para ubicar el botón antes de que empiece a moverse
	await get_tree().create_timer(1.0).timeout
	move = true
	timer.start()

func _process(delta: float) -> void:
	if move and not click and not timer.is_stopped():
		label.text = str(snapped(timer.time_left, 0.1))

	if not click and move:
		position += direccion * velocidad * delta
		var limite = get_viewport_rect().size
		if position.x < 0 or position.x > limite.x:
			direccion.x *= -1
		if position.y < 0 or position.y > limite.y:
			direccion.y *= -1
		position = position.clamp(Vector2.ZERO, limite)

func _on_area_2d_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	if move and not ended and Input.is_action_pressed("left_click"):
		click = true
		_finish(true)

func _on_timer_timeout() -> void:
	if not click:
		_finish(false)

func _finish(won: bool) -> void:
	if ended:
		return
	ended = true
	move = false
	var core = get_parent().get_parent()
	# Rendimiento: clic rápido = más puntos (ver Core.time_performance)
	var used_ratio := 1.0 - timer.time_left / timer.wait_time
	timer.stop()
	label.text = "¡Enviada!" if won else "¡Se acabó el tiempo!"
	await get_tree().create_timer(0.8).timeout
	core.end_microgame(won, core.time_performance(used_ratio) if won else 0.0)
