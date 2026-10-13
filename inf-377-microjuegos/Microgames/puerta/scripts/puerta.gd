extends Node2D

var correct_door: int
var game_finished:= false

func _ready() -> void:
	# Nivel 1: más lento y con más tiempo. Con la dificultad avanza más rápido y el tiempo baja.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	$CharacterBody2D.speed = minf(2000.0, 1300.0 + 100.0 * level)
	$Timer.wait_time = maxf(5.0, 9.0 - 0.4 * level)

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
