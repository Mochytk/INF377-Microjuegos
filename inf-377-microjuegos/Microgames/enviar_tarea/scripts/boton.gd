extends Sprite2D

var click = false
var velocidad: float = 1000.0
var direccion: Vector2 = Vector2(1, 1).normalized()
var move = false

@onready var timer: Timer = $Timer 
@onready var label: Label = $Timer/Label

func _ready() -> void:
	randomize()
	direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	timer.wait_time = 5.0
	timer.one_shot = true
	await get_tree().create_timer(1.0).timeout
	move = true
	timer.start()
	

func _process(delta: float) -> void:
	if timer.time_left > 0:
		label.text = str(snapped(timer.time_left, 0.1))
	else:
		label.text = "5.0"
	
	# mov
	if not click and move:
		position += direccion * velocidad * delta
		var limite = get_viewport_rect().size
		if position.x < 0 or position.x > limite.x:
			direccion.x *= -1
		if position.y < 0 or position.y > limite.y:
			direccion.y *= -1

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if Input.is_action_pressed("left_click"):
		click = true
