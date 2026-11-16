extends Control

const SCORES_PATH := "user://scores.json"
const MAX_SCORES := 10
const MIN_DIFFICULTY := 1.0
const START_LIVES := 3
# Segundos que se muestran los controles en "¡PREPÁRATE!" (el testing mostró que pasaban muy rápido)
const PREPARE_TIME := 4.0
# Puntaje por juego: 20 puntos con rendimiento perfecto, multiplicado por la dificultad.
const MAX_POINTS := 20.0
# Juegos por ronda: se sacan al azar de todos los microjuegos; al terminarlos sube la dificultad.
const BAG_SIZE := 5
# Bono por racha: cada victoria seguida suma +10% al puntaje del juego (x1.1, x1.2, ...), con tope x1.5.
const STREAK_STEP := 0.1
const STREAK_MAX := 1.5
# Juegos por tiempo: si terminan usando <= 20% del tiempo es rendimiento perfecto;
# luego baja linealmente hasta MIN_PERFORMANCE si usan todo el tiempo (5 de 20 puntos).
const PERFECT_TIME_RATIO := 0.2
const MIN_PERFORMANCE := 0.25

@onready var transition_ui = $TransitionUI
@onready var instruction_label = $TransitionUI/InstructionLabel
@onready var vidas_label: Label = $TransitionUI/Hud/Vidas/VidasLabel
@onready var heart_icon: TextureRect = $TransitionUI/Hud/Vidas/HeartIcon
@onready var puntaje_hud: Label = $TransitionUI/Hud/PuntajeLabel
@onready var nivel_hud: Label = $TransitionUI/Hud/NivelLabel
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

const HEART_FULL := preload("res://Core/assets/corazon.png")
const HEART_LEFT := preload("res://Core/assets/corazon_izq.png")
const HEART_RIGHT := preload("res://Core/assets/corazon_der.png")
const ICON_ESPACIO := preload("res://Core/assets/controles/espacio.png")
const ICON_TECLADO := preload("res://Core/assets/controles/teclado.png")
const ICON_MOUSE := preload("res://Core/assets/controles/mouse.png")
const ICON_IZQ := preload("res://Core/assets/controles/flecha_left.png")
const ICON_DER := preload("res://Core/assets/controles/flecha_right.png")
const ICON_ARR := preload("res://Core/assets/controles/flecha_up.png")
const ICON_ABA := preload("res://Core/assets/controles/flecha_down.png")

# Orden igual al de los iconos del carrusel.
var game_names: Array[String] = ["Simon Dice", "Puerta", "Lluvia de Notas", "Microondas", "Enviar Tarea", "Bandeja", "Impresora", "Wi-Fi", "No te duermas", "Copiar el pizarrón", "Firma la lista", "Fila del casino", "Despertador", "Micro lleno", "Bicicletero"]
# Controles de cada juego (mismo orden): iconos y texto que se muestran en "¡PREPÁRATE!".
var game_controls: Array[Dictionary] = [
	{"icons": [ICON_MOUSE], "text": "Memoriza los colores que dice el profesor y haz clic en ellos"},
	{"icons": [ICON_MOUSE], "text": "Haz clic con el mouse para entrar a la puerta"},
	{"icons": [ICON_IZQ, ICON_DER], "text": "Muévete con las flechas o A y D (W o Espacio salta)"},
	{"icons": [ICON_ARR, ICON_ABA, ICON_IZQ, ICON_DER], "text": "Presiona las flechas (o WASD) para llegar primero al microondas"},
	{"icons": [ICON_MOUSE], "text": "Haz clic en el botón antes de que escape"},
	{"icons": [ICON_MOUSE], "text": "Mueve el mouse para mantener la bandeja derecha"},
	{"icons": [ICON_MOUSE], "text": "Sigue los pasos haciendo clic en la impresora"},
	{"icons": [ICON_ARR, ICON_ABA, ICON_IZQ, ICON_DER], "text": "Muévete con las flechas (o WASD) y quédate quieto donde haya señal"},
	{"icons": [ICON_ESPACIO], "text": "Aprieta ESPACIO varias veces para mantener los ojos abiertos"},
	{"icons": [ICON_TECLADO], "text": "Escribe en el teclado la palabra del pizarrón antes de que la borren"},
	{"icons": [ICON_MOUSE], "text": "Busca tu nombre en la lista y haz clic en su fila para firmar"},
	{"icons": [ICON_IZQ, ICON_DER], "text": "Cámbiate a la fila más rápida con las flechas (o A y D)"},
	{"icons": [ICON_MOUSE], "text": "Haz clic en APAGAR en cada alarma. ¡No toques POSPONER!"},
	{"icons": [ICON_MOUSE], "text": "Haz clic en los pasajeros para abrirte paso y subir a la micro"},
	{"icons": [ICON_ARR, ICON_ABA, ICON_IZQ, ICON_DER], "text": "Maneja con las flechas (o WASD) hasta el puesto LIBRE sin chocar"},
]
var microgames: Array[String] = [
	"res://Microgames/simon_says/scenes/simon_says.tscn",
	"res://Microgames/puerta/scenes/puerta.tscn",
	"res://Microgames/lluvia_de_notas/scenes/lluvia_de_notas.tscn",
	"res://Microgames/microondas/scenes/microondas.tscn",
	"res://Microgames/enviar_tarea/scenes/enviar_tarea.tscn",
	"res://Microgames/bandeja/scenes/bandeja.tscn",
	"res://Microgames/impresora/scenes/impresora.tscn",
	"res://Microgames/wifi/scenes/wifi.tscn",
	"res://Microgames/no_te_duermas/scenes/no_te_duermas.tscn",
	"res://Microgames/copiar_pizarron/scenes/copiar_pizarron.tscn",
	"res://Microgames/firma_lista/scenes/firma_lista.tscn",
	"res://Microgames/fila_casino/scenes/fila_casino.tscn",
	"res://Microgames/despertador/scenes/despertador.tscn",
	"res://Microgames/micro_lleno/scenes/micro_lleno.tscn",
	"res://Microgames/bicicletero/scenes/bicicletero.tscn",
]

# Juegos que aún no salen en la ronda actual. Cuando se vacía, la dificultad sube.
var pending_games: Array[int] = []
var last_bag: Array[int] = []    # juegos de la ronda anterior
var last_game: int = -1
var score: float = 0.0
var lives: int = START_LIVES
# Dificultad global que leen los microjuegos (1.0 = nivel inicial, el más fácil).
var difficulty: float = MIN_DIFFICULTY
var last_points: float = 0.0
var streak: int = 0   # victorias seguidas
# Valores que muestra el HUD: se actualizan con las animaciones, no de golpe
var shown_score: float = 0.0
var shown_lives: int = START_LIVES
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
	streak = 0
	lives = START_LIVES
	shown_score = 0.0
	shown_lives = START_LIVES
	difficulty = MIN_DIFFICULTY
	last_bag.clear()
	last_game = -1
	_refill_bag()
	start_roulette()

# Arma la bolsa de la ronda: BAG_SIZE juegos al azar. Tienen prioridad los que no salieron
# en la ronda anterior, para que se vayan jugando todos; el resto se completa al azar.
func _refill_bag() -> void:
	var nuevos: Array[int] = []
	var repetidos: Array[int] = []
	for i in range(microgames.size()):
		if last_bag.has(i):
			repetidos.append(i)
		else:
			nuevos.append(i)
	nuevos.shuffle()
	repetidos.shuffle()
	var bag: Array[int] = []
	bag.append_array(nuevos)
	bag.append_array(repetidos)
	bag = bag.slice(0, mini(BAG_SIZE, bag.size()))
	bag.shuffle()
	# Que la ronda nueva no empiece con el mismo juego que se acaba de jugar (se saca con pop_back)
	if bag.size() > 1 and bag[-1] == last_game:
		bag.push_front(bag.pop_back())
	last_bag = bag.duplicate()
	pending_games = bag

func start_roulette() -> void:
	_show_only(transition_ui)
	instruction_label.text = "ReMechón!"
	_update_hud()
	nombre_label.text = ""
	controles.hide()
	carrusel.show()

	# Se elige el juego de la bolsa y el carrusel gira frenando hasta caer en él.
	var target: int = pending_games.pop_back()
	last_game = target
	await carrusel.spin_to(target)
	nombre_label.text = game_names[target]

	instruction_label.text = "¡PREPÁRATE!"
	_show_controls(target)
	await get_tree().create_timer(PREPARE_TIME).timeout
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
		streak += 1
		last_points = MAX_POINTS * clampf(performance, 0.0, 1.0) * difficulty * streak_multiplier()
		score += last_points
		print("¡Minijuego superado! +", last_points, " Puntaje: ", score)
	else:
		last_points = 0.0
		streak = 0
		lives -= 1
		difficulty = maxf(MIN_DIFFICULTY, difficulty - 0.5)
		print("¡Fallaste! Vidas restantes: ", lives)

	# Pantalla de resultado: sube el puntaje o se rompe el corazón
	await show_result(won, last_points, performance >= 0.999)

	if lives <= 0:
		show_game_over()
		return

	# Al terminar todos los juegos de la ronda sube la dificultad.
	if pending_games.is_empty():
		difficulty += 1.0
		_refill_bag()
		print("¡Ronda completa! Dificultad: ", difficulty)
	start_roulette()

# ---------- Pantalla de resultado ----------

func _update_hud() -> void:
	vidas_label.text = str(shown_lives)
	puntaje_hud.text = "Puntaje: " + _fmt(shown_score)
	nivel_hud.text = "Nivel: " + _fmt(difficulty)

func _set_shown_score(v: float) -> void:
	shown_score = v
	_update_hud()
	# Mientras cuenta se muestran enteros, para que no parpadeen los decimales
	puntaje_hud.text = "Puntaje: " + str(int(v))

func _result_label(text: String, size: int, color: Color) -> Label:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(6, size / 8)
	ls.outline_color = Color(0.45, 0.07, 0.07, 1) if color.r > 0.9 and color.g > 0.7 else Color(0.2, 0.0, 0.0, 1)
	var l := Label.new()
	l.label_settings = ls
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_ui.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	return l

func _pop_node(node: Control, peak: float = 1.3) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(peak, peak), 0.1)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15)

func show_result(won: bool, points: float, perfect: bool) -> void:
	_show_only(transition_ui)
	carrusel.hide()
	controles.hide()
	nombre_label.text = ""
	_update_hud()
	if won:
		instruction_label.text = "¡PERFECTO!" if perfect else "¡BIEN HECHO!"
		await _anim_win(points)
	else:
		instruction_label.text = "¡FALLASTE!"
		await _anim_lose()
	await get_tree().create_timer(0.5).timeout

# "+20": aparece en el centro, viaja hasta el puntaje de abajo y se suma
func _anim_win(points: float) -> void:
	var lbl := _result_label("+" + _fmt(points), 130, Color(1, 0.85, 0.2))
	var center := size / 2.0
	lbl.position = center - lbl.size / 2.0
	lbl.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.1)
	await tw.finished

	# Desde la 2ª victoria seguida se muestra la racha bajo el puntaje
	var racha: Label = null
	if streak >= 2:
		var mult := streak_multiplier()
		var texto := "¡Racha de %d! x%s" % [streak, _fmt(mult)]
		if mult >= STREAK_MAX:
			texto += " (máx.)"
		racha = _result_label(texto, 44, Color(1, 0.55, 0.15))
		racha.position = Vector2(center.x - racha.size.x / 2.0, lbl.position.y + lbl.size.y + 6)
		_pop_node(racha, 1.3)
	await get_tree().create_timer(0.8 if racha else 0.6).timeout
	if racha:
		create_tween().tween_property(racha, "modulate:a", 0.0, 0.3)

	var target := puntaje_hud.global_position + puntaje_hud.size / 2.0 - lbl.size / 2.0
	var fly := create_tween().set_parallel(true)
	fly.tween_property(lbl, "global_position", target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(lbl, "scale", Vector2(0.3, 0.3), 0.6).set_ease(Tween.EASE_IN)
	await fly.finished
	lbl.queue_free()
	if racha:
		racha.queue_free()

	# La suma sube de a poco hasta el puntaje nuevo
	var from := shown_score
	var count := create_tween()
	count.tween_method(_set_shown_score, from, score, 0.6)
	_pop_node(puntaje_hud, 1.2)
	await count.finished
	shown_score = score
	_update_hud()

# El corazón se rompe en dos y el "-1" sube sobre las vidas desvaneciéndose
func _anim_lose() -> void:
	var heart_size := Vector2(15, 13) * 16.0
	var pos := size / 2.0 - heart_size / 2.0
	var make := func(tex: Texture2D) -> TextureRect:
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = heart_size
		r.position = pos
		r.pivot_offset = Vector2(heart_size.x / 2.0, heart_size.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_ui.add_child(r)
		return r
	var heart: TextureRect = make.call(HEART_FULL)
	# Latido y temblor antes de romperse
	var shake := create_tween()
	for i in range(6):
		shake.tween_property(heart, "position:x", pos.x + (10 if i % 2 == 0 else -10), 0.05)
	shake.tween_property(heart, "position:x", pos.x, 0.05)
	await shake.finished
	heart.queue_free()

	var left: TextureRect = make.call(HEART_LEFT)
	var right: TextureRect = make.call(HEART_RIGHT)
	var br := create_tween().set_parallel(true)
	br.tween_property(left, "position", pos + Vector2(-110, 150), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	br.tween_property(left, "rotation", -0.6, 0.9)
	br.tween_property(left, "modulate:a", 0.0, 0.9).set_delay(0.3)
	br.tween_property(right, "position", pos + Vector2(110, 150), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	br.tween_property(right, "rotation", 0.6, 0.9)
	br.tween_property(right, "modulate:a", 0.0, 0.9).set_delay(0.3)
	await get_tree().create_timer(0.5).timeout

	# "-1" sobre el número de vidas: sube y se vuelve transparente
	var minus := _result_label("-1", 90, Color(1, 0.3, 0.3))
	minus.global_position = vidas_label.global_position + vidas_label.size / 2.0 - minus.size / 2.0 - Vector2(0, 50)
	var start_y := minus.position.y
	var up := create_tween().set_parallel(true)
	up.tween_property(minus, "position:y", start_y - 90.0, 1.0).set_ease(Tween.EASE_OUT)
	up.tween_property(minus, "modulate:a", 0.0, 1.0).set_delay(0.2)
	shown_lives = lives
	_update_hud()
	_pop_node(vidas_label, 1.4)
	_pop_node(heart_icon, 0.7)
	await up.finished
	minus.queue_free()
	left.queue_free()
	right.queue_free()

# Multiplicador de la racha actual: 1 victoria = x1.0, 2 = x1.1, 3 = x1.2 ... hasta x1.5
func streak_multiplier() -> float:
	return minf(STREAK_MAX, 1.0 + STREAK_STEP * maxi(0, streak - 1))

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
