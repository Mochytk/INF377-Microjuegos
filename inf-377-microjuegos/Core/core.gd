extends Control

@onready var transition_ui = $TransitionUI
@onready var instruction_label = $TransitionUI/InstructionLabel
# Asigna aquí las rutas correctas a tus nodos ReferenceRect en el editor
@onready var border_simon = $TransitionUI/HBoxContainer/IconSimon/BordeRojo
@onready var border_lluvia = $TransitionUI/HBoxContainer/IconLluvia/BordeRojo

var microgames: Array[String] = [
	"res://Microgames/Simon_Says/simon_says_microgame.tscn",
    "res://Microgames/lluvia-de-notas/scenes/lluvia_de_notas.tscn"
]

var score: int = 0
var lives: int = 3
var current_game_instance: Node = null

func _ready() -> void:
	start_roulette()

func start_roulette() -> void:
	transition_ui.show()
	instruction_label.text = "Micro Juegos"
	
	var borders = [border_simon, border_lluvia]
	# El número de saltos ahora es aleatorio (entre 5 y 15 veces)
	var loops = randi_range(5, 15) 
	var delay = 0.15 
	var selected_index = 0
	
	for i in range(loops):
		for b in borders:
			b.hide()
			
		selected_index = i % borders.size()
		borders[selected_index].show()
		
		await get_tree().create_timer(delay).timeout
		delay *= 0.9 

	var chosen_game_path = microgames[selected_index]
	
	instruction_label.text = "¡PREPÁRATE!"
	await get_tree().create_timer(0.8).timeout 
	
	for b in borders:
		b.hide()
	
	transition_ui.hide()
	var scene_resource = load(chosen_game_path)
	current_game_instance = scene_resource.instantiate()
	add_child(current_game_instance)

func end_microgame(won: bool) -> void:
	if current_game_instance:
		current_game_instance.queue_free()
		
	if won:
		score += 1
		print("¡Minijuego superado! Puntaje: ", score)
	else:
		lives -= 1
		print("¡Fallaste! Vidas restantes: ", lives)
		
	if lives > 0:
		start_roulette()
	else:
		instruction_label.text = "GAME OVER"
		transition_ui.show()
