extends Control
## Simón dice: un profesor dice una secuencia de colores en un globo de texto y el
## jugador la repite haciendo clic con el mouse en los botones de colores.

const COLORS := [
	{"name": "Rojo", "color": Color("#e63946")},
	{"name": "Verde", "color": Color("#2ecc71")},
	{"name": "Azul", "color": Color("#3a7bd5")},
	{"name": "Amarillo", "color": Color("#ffd23f")},
	{"name": "Naranja", "color": Color("#ff8c1a")},
	{"name": "Morado", "color": Color("#9b5de5")},
]
const INK := Color("#141414")
const TEX_BOCA_CERRADA := preload("res://Microgames/simon_says/assets/profesor_0.png")
const TEX_BOCA_ABIERTA := preload("res://Microgames/simon_says/assets/profesor_1.png")

@onready var botones = $Barra/Botones
@onready var timer_bar = $ProgressBar
@onready var profesor: Sprite2D = $Profesor
@onready var texto: Label = $Globo/Panel/VBox/Texto
@onready var fila: HBoxContainer = $Globo/Panel/VBox/Fila

var sequence: Array = []
var slots: Array = []        # casillas de la fila durante el turno del jugador
var player_step: int = 0
var is_player_turn: bool = false
var finished: bool = false
var talking: bool = false
var talk_clock: float = 0.0
var time_left: float = 3.0

# Ajustes según dificultad (se calculan en _ready). Nivel 1: 3 colores, 0.9s cada uno.
var sequence_length: int = 3
var show_time: float = 0.9
var time_limit: float = 5.0

func _ready() -> void:
	var level := _get_level()
	sequence_length = 3 + int(level / 2.0)           # 3 -> 5 como máximo
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	show_time = maxf(0.6, 0.9 - 0.04 * level) / apuro
	time_limit = maxf(4.0, 5.0 - 0.2 * level) / apuro

	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_build_buttons()
	start_microgame()

# Nivel de dificultad relativo: 0 = inicial. Se limita a 6 para no volverse imposible.
func _get_level() -> float:
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	return clampf(d - 1.0, 0.0, 6.0)

func _process(delta: float) -> void:
	# Animación de "hablar": alterna boca abierta/cerrada
	if talking:
		talk_clock += delta
		profesor.texture = TEX_BOCA_ABIERTA if int(talk_clock / 0.14) % 2 == 0 else TEX_BOCA_CERRADA
	else:
		profesor.texture = TEX_BOCA_CERRADA

	if is_player_turn and time_left > 0:
		time_left -= delta
		timer_bar.value = time_left
		if time_left <= 0:
			lose_game()

# ---------- Botones ----------

func _flat_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(5)
	s.border_color = INK
	s.set_corner_radius_all(10)
	return s

func _build_buttons() -> void:
	for i in range(COLORS.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 110)
		b.text = COLORS[i]["name"].to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 22)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, INK)
		# Mismo estilo en todos los estados: el color no cambia al pasar el mouse
		var style := _flat_style(COLORS[i]["color"])
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pivot_offset = b.custom_minimum_size / 2.0
		b.pressed.connect(_on_button_pressed.bind(i))
		botones.add_child(b)

# ---------- Globo de texto ----------

func _make_chip(idx: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(96, 70)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", INK)
	chip.add_child(label)
	_set_chip(chip, idx)
	chip.pivot_offset = chip.custom_minimum_size / 2.0
	return chip

# idx = -1: casilla oculta ("?")
func _set_chip(chip: PanelContainer, idx: int) -> void:
	var label: Label = chip.get_child(0)
	if idx < 0:
		chip.add_theme_stylebox_override("panel", _flat_style(Color("#cfcfcf")))
		label.text = "?"
	else:
		chip.add_theme_stylebox_override("panel", _flat_style(COLORS[idx]["color"]))
		label.text = COLORS[idx]["name"]

func _pop(node: Control) -> void:
	node.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clear_fila() -> void:
	for c in fila.get_children():
		fila.remove_child(c)
		c.queue_free()

# ---------- Flujo del juego ----------

func start_microgame() -> void:
	sequence.clear()
	player_step = 0
	for i in range(sequence_length):
		sequence.append(randi() % COLORS.size())
	show_sequence()

func show_sequence() -> void:
	is_player_turn = false
	texto.text = "¡Memoriza lo que digo!"
	_clear_fila()
	talking = true
	await get_tree().create_timer(0.8).timeout
	for idx in sequence:
		if not is_inside_tree() or finished:
			return
		var chip := _make_chip(idx)
		fila.add_child(chip)
		_pop(chip)
		Sonido.play("pop", -2.0, 0.85 + 0.12 * idx)
		await get_tree().create_timer(show_time).timeout
	talking = false
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or finished:
		return

	# Se oculta la secuencia: el jugador debe recordarla
	_clear_fila()
	slots.clear()
	for i in range(sequence.size()):
		var slot := _make_chip(-1)
		fila.add_child(slot)
		slots.append(slot)
	texto.text = "¡Tu turno! Haz clic en los colores"
	time_left = time_limit
	is_player_turn = true

func _on_button_pressed(index: int) -> void:
	if not is_player_turn:
		return
	var btn: Control = botones.get_child(index)
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.08)

	if index == sequence[player_step]:
		_set_chip(slots[player_step], index)   # la casilla muestra el color acertado
		_pop(slots[player_step])
		player_step += 1
		Sonido.play("pop", -2.0, 0.85 + 0.12 * index)
		if player_step >= sequence.size():
			win_game()
	else:
		lose_game()

func win_game() -> void:
	if finished:
		return
	finished = true
	is_player_turn = false
	# Rendimiento según qué tan rápido completó la secuencia
	var core = get_parent()
	var used_ratio := (time_limit - time_left) / time_limit
	var performance: float = core.time_performance(used_ratio)
	texto.text = "¡Muy bien!"
	await get_tree().create_timer(0.7).timeout
	core.end_microgame(true, performance)

func lose_game() -> void:
	if finished:
		return
	finished = true
	Sonido.play("error")
	is_player_turn = false
	talking = false
	texto.text = "¡Ups! Esa no era..."
	await get_tree().create_timer(0.8).timeout
	get_parent().end_microgame(false)
