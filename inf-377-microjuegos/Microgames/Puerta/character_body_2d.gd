extends CharacterBody2D

@export var speed := 1000.0

@export var win_sprite:= Texture2D
@export var lose_sprite:= Texture2D

func _physics_process(delta):
	if get_parent().game_finished:
		velocity = Vector2.ZERO
		return
	
	velocity.x = speed
	velocity.y = 0
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if get_parent().game_finished:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_enter_room()
			
func try_enter_room():
	var door = $DoorDetector.current_door
	# no hay puerta delante
	if door == null:
		return
	
	print("intentando entrar a la puerta numero: " + str(door.door_number))
	
	var main = get_parent()
	
	if main.game_finished:
		return
	var correct_door = get_parent().correct_door
	
	if door.door_number == correct_door:
		main.win_game()
	else:
		main.lose_game()

func show_win_sprite():
	$Sprite2D.texture = win_sprite


func show_lose_sprite():
	$Sprite2D.texture = lose_sprite
