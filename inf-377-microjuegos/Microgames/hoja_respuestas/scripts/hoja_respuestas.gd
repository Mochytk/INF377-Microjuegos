extends Control
## Hoja de respuestas: en el borrador están tus respuestas (1. B, 2. D, ...) y hay que pasarlas
## a la hoja de alternativas rellenando la burbuja correcta de cada pregunta antes de que el
## profe recoja las pruebas. Una burbuja equivocada resta tiempo.

const LETRAS := ["A", "B", "C", "D", "E"]
const PENALIZACION := 0.8
const HOJA_X := 464.0
const FILA_Y0 := 116.0
const ALTO_HOJA := 490.0

@onready var borrador: Control = $Borrador
@onready var filas: Control = $Filas
@onready var profe: TextureRect = $Profe
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 6.0
var elapsed := 0.0
var respuestas: Array = []      # índice de la letra correcta por pregunta
var marcadas: Array = []        # true si la pregunta ya está rellena
var burbujas: Array = []        # [pregunta][letra] -> Button
var estilos := {}
var errores := 0

func _ready() -> void:
	# Nivel 1: 4 preguntas y el borrador en orden. Al subir: hasta 8 preguntas, y desde el
	# nivel 4 el borrador está desordenado (hay que buscar cada número).
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(8, 4 + int(level * 0.7))
	var desordenado := level >= 3.0
	time_limit = (3.5 + n * (1.0 if not desordenado else 1.2)) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	for i in range(n):
		var r := randi() % 5
		# nunca tres respuestas iguales seguidas
		while i >= 2 and r == respuestas[i - 1] and r == respuestas[i - 2]:
			r = randi() % 5
		respuestas.append(r)
		marcadas.append(false)
	_crear_estilos()
	_armar_borrador(n, desordenado)
	_armar_hoja(n)
	playing = true

func _crear_estilos() -> void:
	var colores := {"vacia": [Color.WHITE, Color(0.55, 0.6, 0.68)], "llena": [Color(0.08, 0.08, 0.1), Color(0.08, 0.08, 0.1)],
		"mal": [Color(0.95, 0.35, 0.35), Color(0.7, 0.1, 0.1)], "hover": [Color(0.9, 0.94, 1.0), Color(0.3, 0.45, 0.7)]}
	for k in colores:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colores[k][0]
		sb.border_color = colores[k][1]
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(40)
		estilos[k] = sb

func _armar_borrador(n: int, desordenado: bool) -> void:
	var orden: Array = range(n)
	if desordenado:
		orden.shuffle()
	var alto := minf(52.0, 470.0 / n)
	for k in range(n):
		var i: int = orden[k]
		var l := Label.new()
		l.text = "%d.  %s" % [i + 1, LETRAS[respuestas[i]]]
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", Color(0.25, 0.27, 0.33))
		l.position = Vector2(100, 126 + k * alto)
		l.rotation = randf_range(-0.04, 0.04)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		borrador.add_child(l)

func _armar_hoja(n: int) -> void:
	var alto := minf(58.0, ALTO_HOJA / n)
	var lado := minf(44.0, alto - 8.0)
	for i in range(n):
		var y := FILA_Y0 + i * alto + (alto - lado) / 2.0
		var num := Label.new()
		num.text = "%d." % (i + 1)
		num.add_theme_font_size_override("font_size", 28)
		num.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		num.position = Vector2(HOJA_X + 30, y + lado / 2.0 - 20.0)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filas.add_child(num)
		var fila: Array = []
		for c in range(5):
			var b := Button.new()
			b.text = LETRAS[c]
			b.position = Vector2(HOJA_X + 110 + c * 100, y)
			b.size = Vector2(lado, lado)
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.add_theme_font_size_override("font_size", int(lado * 0.5))
			b.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
			b.add_theme_color_override("font_hover_color", Color(0.2, 0.3, 0.5))
			b.add_theme_color_override("font_pressed_color", Color(0.2, 0.3, 0.5))
			b.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.8))
			_pintar(b, "vacia")
			b.add_theme_stylebox_override("hover", estilos["hover"])
			b.add_theme_stylebox_override("pressed", estilos["hover"])
			b.pressed.connect(_on_burbuja.bind(i, c, b))
			filas.add_child(b)
			fila.append(b)
		burbujas.append(fila)

func _pintar(b: Button, estilo: String) -> void:
	b.add_theme_stylebox_override("normal", estilos[estilo])
	b.add_theme_stylebox_override("disabled", estilos[estilo])

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if elapsed > time_limit * 0.7 and mensaje.text.begins_with("¡Pasa"):
		mensaje.text = "¡El profe ya viene a recoger las pruebas!"
	if elapsed >= time_limit:
		_finish(false)

func _on_burbuja(i: int, c: int, b: Button) -> void:
	if not playing or marcadas[i]:
		return
	if c == respuestas[i]:
		marcadas[i] = true
		for otra in burbujas[i]:
			otra.disabled = true
		_pintar(b, "llena")
		b.add_theme_color_override("font_disabled_color", Color.WHITE)
		if not marcadas.has(false):
			_finish(true)
	else:
		errores += 1
		elapsed += PENALIZACION
		mensaje.text = "¡La %d no era %s! Revisa el borrador" % [i + 1, LETRAS[c]]
		_pintar(b, "mal")
		await get_tree().create_timer(0.35).timeout
		if not marcadas[i]:
			_pintar(b, "vacia")

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	for fila in burbujas:
		for b in fila:
			b.disabled = true
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Hoja lista!"
		mensaje.text = "Entregaste a tiempo" if errores == 0 else "Entregaste con %d borrón(es)" % errores
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se acabó el tiempo, entreguen!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Te faltaron %d respuestas" % marcadas.count(false)
		profe.show()
		create_tween().tween_property(profe, "position:x", 1010.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
