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

var button_colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, 
	Color.MAGENTA, Color.ORANGE, Color.WHITE, Color.PURPLE
]

func _ready() -> void:
	game_over_ui.hide()
	timer_bar.max_value = 3.0
	timer_bar.value = 3.0
	
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
		buttons[i].modulate = button_colors[i].darkened(0.6)
		
	start_microgame()

func _process(delta: float) -> void:
	if is_player_turn and time_left > 0:
		time_left -= delta
		timer_bar.value = time_left
		if time_left <= 0:
			lose_game()

func start_microgame() -> void:
	sequence.clear()
	player_step = 0
	for i in range(5):
		sequence.append(randi() % buttons.size())
	show_sequence()

func show_sequence() -> void:
	is_player_turn = false
	await get_tree().create_timer(0.5).timeout
	
	for index in sequence:
		await flash_button(index, 0.5)
		await get_tree().create_timer(0.3).timeout
		
	time_left = 3.0 # Segundos que tiene el jugador para completar todo
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
	print("¡GANASTE!")

func lose_game() -> void:
	is_player_turn = false
	game_over_ui.show()
	
	# Animación del corazón parpadeando (cambiando su opacidad/color)
	for i in range(3):
		heart_icon.modulate = Color(1, 1, 1, 0) # Invisible
		await get_tree().create_timer(0.2).timeout
		heart_icon.modulate = Color(1, 1, 1, 1) # Visible
		await get_tree().create_timer(0.2).timeout
		
	# Corazón vacío (oscurecido o puedes cambiar la textura aquí)
	heart_icon.modulate = Color(0.2, 0.2, 0.2, 1)
