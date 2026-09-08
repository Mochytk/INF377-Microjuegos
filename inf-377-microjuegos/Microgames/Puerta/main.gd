extends Node2D

var correct_door: int
var game_finished:= false

func _ready() -> void:
	correct_door = randi_range(1 , 6)
	print("Puerta correcta", correct_door)
	
	$UI/InstructionLabel.text = "Puerta N°" + str(correct_door) + " !"
	$Timer.start()

func _process(delta: float) -> void:
	if game_finished:
		return

func win_game():
	if game_finished:
		return
	game_finished = true
	$Timer.stop()
	$CharacterBody2D.show_win_sprite()
	print("Ganaste!")
	
	# Pausa breve para ver la animación, luego avisar al Core
	await get_tree().create_timer(1.0).timeout
	get_parent().end_microgame(true)

func lose_game():
	if game_finished:
		return
	game_finished = true
	$Timer.stop()
	$CharacterBody2D.show_lose_sprite()
	print("Perdiste")
	
	# Pausa breve para ver la animación, luego avisar al Core
	await get_tree().create_timer(1.0).timeout
	get_parent().end_microgame(false)


func _on_timer_timeout() -> void:
	if game_finished:
		return
	
	lose_game()
