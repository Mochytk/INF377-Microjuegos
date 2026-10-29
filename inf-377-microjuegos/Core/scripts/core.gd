extends Control

const SCORES_PATH := "user://scores.json"
const MAX_SCORES := 10
const MIN_DIFFICULTY := 1.0
const START_LIVES := 3
# Puntaje por juego: 20 puntos con rendimiento perfecto, multiplicado por la dificultad.
const MAX_POINTS := 20.0
# Juegos por tiempo: si terminan usando <= 20% del tiempo es rendimiento perfecto;
# luego baja linealmente hasta MIN_PERFORMANCE si usan todo el tiempo (5 de 20 puntos).
const PERFECT_TIME_RATIO := 0.2
const MIN_PERFORMANCE := 0.25

@onready var transition_ui = $TransitionUI
@onready var instruction_label = $TransitionUI/InstructionLabel
@onready var stats_label = $TransitionUI/StatsLabel
@onready var landing_ui = $LandingUI
@onready var tabla_ui = $TablaUI
@onready var creditos_ui = $CreditosUI
@onready var game_over_ui = $GameOverUI
@onready var scores_label = $TablaUI/Center/VBox/ScoresLabel
@onready var puntaje_label = $GameOverUI/Center/VBox/LabelPuntaje
@onready var iniciales = $GameOverUI/Center/VBox/Iniciales
@onready var btn_guardar = $GameOverUI/Center/VBox/BtnGuardar

@onready var carrusel = $TransitionUI/Carrusel
@onready var nombre_label = $TransitionUI/NombreLabel
@onready var controles = $TransitionUI/Controles
@onready var controles_iconos = $TransitionUI/Controles/Iconos
@onready var controles_texto = $TransitionUI/Controles/Texto

const ICON_MOUSE := preload("res://Core/assets/controles/mouse.png")
const ICON_IZQ := preload("res://Core/assets/controles/flecha_left.png")
const ICON_DER := preload("res://Core/assets/controles/flecha_right.png")
const ICON_ARR := preload("res://Core/assets/controles/flecha_up.png")
const ICON_ABA := preload("res://Core/assets/controles/flecha_down.png")

# Orden igual al de los iconos del carrusel.
var game_names: Array[String] = ["Simon Dice", "Puerta", "Lluvia de Notas", "Microondas", "Enviar Tarea"]
# Controles de cada juego (mismo orden): iconos y texto que se muestran en "¡PREPÁRATE!".
var game_controls: Array[Dictionary] = [
	{"icons": [ICON_MOUSE], "text": "Haz clic en los botones con el mouse"},
	{"icons": [ICON_MOUSE], "text": "Haz clic con el mouse para entrar a la puerta"},
	{"icons": [ICON_IZQ, ICON_DER], "text": "Muévete con las flechas o A y D (W o Espacio salta)"},
	{"icons": [ICON_ARR, ICON_ABA, ICON_IZQ, ICON_DER], "text": "Presiona las flechas o W A S D"},
	{"icons": [ICON_MOUSE], "text": "Haz clic en el botón antes de que escape"},
]
var microgames: Array[String] = [
	"res://Microgames/simon_says/scenes/simon_says.tscn",
	"res://Microgames/puerta/scenes/puerta.tscn",
	"res://Microgames/lluvia_de_notas/scenes/lluvia_de_notas.tscn",
	"res://Microgames/microondas/scenes/microondas.tscn",
	"res://Microgames/enviar_tarea/scenes/enviar_tarea.tscn",
]

# Juegos que aún no salen en la ronda actual. Cuando se vacía, la dificultad sube.
var pending_games: Array[int] = []
var score: float = 0.0
var lives: int = START_LIVES
# Dificultad global que leen los microjuegos (1.0 = nivel inicial, el más fácil).
var difficulty: float = MIN_DIFFICULTY
var last_points: float = 0.0
var current_game_instance: Node = null

func _ready() -> void:
	$LandingUI/Center/VBox/BtnJugar.pressed.connect(start_game)
	$LandingUI/Center/VBox/BtnTabla.pressed.connect(show_scores)
	$LandingUI/Center/VBox/BtnCreditos.pressed.connect(_show_only.bind(creditos_ui))
	$TablaUI/Center/VBox/BtnVolver.pressed.connect(show_landing)
	$CreditosUI/Center/VBox/BtnVolver.pressed.connect(show_landing)
	btn_guardar.pressed.connect(save_initials)
	iniciales.text_changed.connect(_on_initials_changed)
	iniciales.text_submitted.connect(func(_t): save_initials())
	show_landing()

# ---------- Menús ----------

func _show_only(panel: Control) -> void:
	for p in [landing_ui, tabla_ui, creditos_ui, game_over_ui, transition_ui]:
		p.visible = (p == panel)

func show_landing() -> void:
	_show_only(landing_ui)

func show_scores() -> void:
	var lines: Array[String] = []
	var scores := load_scores()
	for i in range(scores.size()):
		lines.append("%d.  %s   %s" % [i + 1, scores[i]["name"], _fmt(scores[i]["score"])])
	scores_label.text = "\n".join(lines) if not lines.is_empty() else "Aún no hay puntajes"
	_show_only(tabla_ui)

# ---------- Flujo de la partida ----------

func start_game() -> void:
	score = 0.0
	last_points = 0.0
	lives = START_LIVES
	difficulty = MIN_DIFFICULTY
	_refill_bag()
	start_roulette()

func _refill_bag() -> void:
	pending_games.clear()
	for i in range(microgames.size()):
		pending_games.append(i)
	pending_games.shuffle()

func start_roulette() -> void:
	_show_only(transition_ui)
	instruction_label.text = "ReMechón!"
	stats_label.text = "Vidas: %d     Puntaje: %s (+%s)     Nivel: %s" % [lives, _fmt(score), _fmt(last_points), _fmt(difficulty)]
	nombre_label.text = ""
	controles.hide()
	carrusel.show()

	# Se elige el juego de la bolsa y el carrusel gira frenando hasta caer en él.
	var target: int = pending_games.pop_back()
	await carrusel.spin_to(target)
	nombre_label.text = game_names[target]

	instruction_label.text = "¡PREPÁRATE!"
	_show_controls(target)
	await get_tree().create_timer(1.8).timeout
	controles.hide()
	carrusel.show()

	transition_ui.hide()
	current_game_instance = load(microgames[target]).instantiate()
	add_child(current_game_instance)

# Reemplaza el carrusel por los iconos de los controles del juego elegido.
func _show_controls(game: int) -> void:
	for child in controles_iconos.get_children():
		child.queue_free()
	for tex in game_controls[game]["icons"]:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(130, 130)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		controles_iconos.add_child(rect)
	controles_texto.text = game_controls[game]["text"]
	carrusel.hide()
	controles.show()

# performance: 0.0 a 1.0 (1.0 = perfecto). Los juegos sin medición de rendimiento usan 1.0.
func end_microgame(won: bool, performance: float = 1.0) -> void:
	if current_game_instance:
		current_game_instance.queue_free()
		current_game_instance = null

	if won:
		last_points = MAX_POINTS * clampf(performance, 0.0, 1.0) * difficulty
		score += last_points
		print("¡Minijuego superado! +", last_points, " Puntaje: ", score)
	else:
		last_points = 0.0
		lives -= 1
		difficulty = maxf(MIN_DIFFICULTY, difficulty - 0.5)
		print("¡Fallaste! Vidas restantes: ", lives)

	if lives <= 0:
		show_game_over()
		return

	# Al terminar todos los juegos de la ronda sube la dificultad.
	if pending_games.is_empty():
		difficulty += 1.0
		_refill_bag()
		print("¡Ronda completa! Dificultad: ", difficulty)
	start_roulette()

# Rendimiento (0-1) según la fracción del tiempo usada (0 = instantáneo, 1 = justo a tiempo).
func time_performance(used_ratio: float) -> float:
	if used_ratio <= PERFECT_TIME_RATIO:
		return 1.0
	var t := (clampf(used_ratio, 0.0, 1.0) - PERFECT_TIME_RATIO) / (1.0 - PERFECT_TIME_RATIO)
	return lerpf(1.0, MIN_PERFORMANCE, t)

# ---------- Game over y tabla de posiciones ----------

func show_game_over() -> void:
	puntaje_label.text = "Puntaje: " + _fmt(score)
	iniciales.text = ""
	btn_guardar.disabled = true
	_show_only(game_over_ui)
	iniciales.grab_focus()

func _on_initials_changed(text: String) -> void:
	# Solo letras (A-Z) en mayúscula, como en los arcades.
	var clean := ""
	for c in text.to_upper():
		if c >= "A" and c <= "Z":
			clean += c
	if clean != text:
		iniciales.text = clean
		iniciales.caret_column = clean.length()
	btn_guardar.disabled = clean.length() != 3

func save_initials() -> void:
	if iniciales.text.length() != 3:
		return
	var scores := load_scores()
	scores.append({"name": iniciales.text, "score": score})
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	scores = scores.slice(0, MAX_SCORES)
	var f := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(scores))
		f.close() # cerrar antes de volver a leer el archivo
	show_scores()

func load_scores() -> Array:
	if not FileAccess.file_exists(SCORES_PATH):
		return []
	var raw := FileAccess.get_file_as_string(SCORES_PATH)
	if raw.is_empty():
		return []
	var data = JSON.parse_string(raw)
	return data if data is Array else []

# 3.0 -> "3", 2.5 -> "2.5"
func _fmt(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")
