extends Control

@onready var grid = $GridContainer
@onready var buttons = grid.get_children()
@onready var timer_bar = $ProgressBar
@onready var game_over_ui = $GameOverUI
@onready var heart_icon = $GameOverUI/HeartIcon # Asegúrate de que los nombres coincidan

var sequence: Array = []
var player_step: int = 0
var is_player_turn: bool = false
var time_left: float = 3.0

# Ajustes según dificultad (se calculan en _ready). Nivel 1: 3 botones, 0.6s por destello.
var sequence_length: int = 3
var flash_time: float = 0.6
var time_limit: float = 5.0

var button_colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, 
	Color.MAGENTA, Color.ORANGE, Color.WHITE, Color.PURPLE
]

func _ready() -> void:
	var level := _get_level()
	sequence_length = 3 + int(level / 2.0)           # 3 -> 5 como máximo
	flash_time = maxf(0.4, 0.6 - 0.03 * level)
	time_limit = maxf(4.0, 5.0 - 0.2 * level)

	game_over_ui.hide()
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
		buttons[i].modulate = button_colors[i].darkened(0.6)
		
	start_microgame()

# Nivel de dificultad relativo: 0 = inicial. Se limita a 6 para no volverse imposible.
func _get_level() -> float:
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	return clampf(d - 1.0, 0.0, 6.0)

func _process(delta: float) -> void:
	if is_player_turn and time_left > 0:
		time_left -= delta
		timer_bar.value = time_left
		if time_left <= 0:
			lose_game()

func start_microgame() -> void:
	sequence.clear()
	player_step = 0
	for i in range(sequence_length):
		sequence.append(randi() % buttons.size())
	show_sequence()

func show_sequence() -> void:
	is_player_turn = false
	await get_tree().create_timer(0.5).timeout
	
	for index in sequence:
		await flash_button(index, flash_time)
		await get_tree().create_timer(0.3).timeout
		
	time_left = time_limit # Segundos que tiene el jugador para completar todo
	is_player_turn = true

func flash_button(index: int, time: float) -> void:
	var btn = buttons[index]
	# Al multiplicar el color por un valor > 1, el WorldEnvironment lo hace brillar
	btn.modulate = button_colors[index] * 2.5 
	
	await get_tree().create_timer(time).timeout
	btn.modulate = button_colors[index].darkened(0.6)

func _on_button_pressed(index: int) -> void:
	if not is_player_turn:
		return
		
	flash_button(index, 0.2)
	
	if index == sequence[player_step]:
		player_step += 1
		if player_step >= sequence.size():
			win_game()
	else:
		lose_game()

func win_game() -> void:
	is_player_turn = false
	# get_parent() llama al Core y ejecuta su función
	get_parent().end_microgame(true) 

func lose_game() -> void:
	is_player_turn = false
	# get_parent() llama al Core y ejecuta su función
	get_parent().end_microgame(false)
