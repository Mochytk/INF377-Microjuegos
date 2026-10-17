
extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Movimiento horizontal
	var direction := Input.get_axis("ui_left", "ui_right")

	# Voltear el sprite según la dirección
	if direction != 0:
		$AnimatedSprite2D.flip_h = direction < 0

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
