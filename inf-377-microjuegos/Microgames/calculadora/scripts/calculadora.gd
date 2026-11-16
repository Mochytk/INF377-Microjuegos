extends Control
## Calculadora en el certamen: aparece una operación en la calculadora y tres resultados.
## Hay que hacer clic en el correcto antes de que el profe llegue a retirar la prueba.
## Equivocarse una vez resta tiempo; los resultados falsos son parecidos al verdadero.

const PENALIZACION := 1.2

@onready var pregunta: Label = $Pregunta
@onready var nota: Label = $Nota
@onready var pantalla: Label = $Pantalla
@onready var opciones: VBoxContainer = $Opciones
@onready var profe: Sprite2D = $Profe
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 7.0
var elapsed := 0.0
var correcta := 0
var botones: Array = []

func _ready() -> void:
	# Nivel 1: sumas y tablas fáciles, 3 opciones, 7 s. Al subir: restas, multiplicaciones más
	# grandes y operaciones combinadas, 4 opciones y menos tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	time_limit = maxf(4.5, 7.0 - 0.4 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	var op := _make_operation(int(level))
	pantalla.text = op[0]
	correcta = op[1]
	var n := 3 if level < 3.0 else 4
	var valores := _distractors(correcta, n, int(level))
	for v in valores:
		botones.append(_make_button(v))
	pregunta.text = "%d. Calcule: %s =" % [randi_range(1, 6), op[0]]
	playing = true

# Devuelve [texto, resultado] según el nivel
func _make_operation(level: int) -> Array:
	var tipo := randi() % (2 if level < 2 else (3 if level < 4 else 4))
	match tipo:
		0:
			var a := randi_range(12, 48 + 10 * level); var b := randi_range(11, 39 + 10 * level)
			return ["%d + %d" % [a, b], a + b]
		1:
			var a := randi_range(3, 9); var b := randi_range(3, 9 + level)
			return ["%d × %d" % [a, b], a * b]
		2:
			var a := randi_range(40, 99); var b := randi_range(12, a - 5)
			return ["%d − %d" % [a, b], a - b]
		_:
			var a := randi_range(2, 9); var b := randi_range(2, 9); var c := randi_range(3, 20)
			return ["%d × %d + %d" % [a, b, c], a * b + c]

# Resultados falsos parecidos: ±1, ±2, ±10 o con dígitos invertidos
func _distractors(valor: int, n: int, level: int) -> Array:
	var set := {valor: true}
	var lista: Array = [valor]
	var saltos: Array = [1, -1, 2, -2, 10, -10] if level >= 2 else [3, -4, 5, -6, 10, -10, 11]
	saltos.shuffle()
	for s in saltos:
		if lista.size() >= n:
			break
		var v: int = valor + s
		if v > 0 and not set.has(v):
			set[v] = true
			lista.append(v)
	if lista.size() < n and valor >= 10:
		var inv := int(str(valor).reverse())
		if not set.has(inv) and inv > 0:
			lista.append(inv)
	lista.shuffle()
	return lista

func _style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(5)
	sb.border_color = Color(0.05, 0.05, 0.08)
	sb.set_corner_radius_all(10)
	return sb

func _make_button(valor: int) -> Button:
	var b := Button.new()
	b.text = str(valor)
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 40)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0.05, 0.05, 0.08))
	b.add_theme_stylebox_override("normal", _style(Color(1.0, 0.82, 0.25)))
	b.add_theme_stylebox_override("hover", _style(Color(1.0, 0.92, 0.6)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.9, 0.65, 0.1)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.9, 0.55, 0.55)))
	b.pressed.connect(_on_answer.bind(b, valor))
	opciones.add_child(b)
	return b

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	# el profe va caminando hacia tu puesto
	profe.position.x = lerpf(-120.0, 560.0, clampf(elapsed / time_limit, 0.0, 1.0))
	profe.position.y = 470.0 + (6.0 if int(elapsed / 0.2) % 2 == 0 else 0.0)
	if elapsed >= time_limit:
		_finish(false)

func _on_answer(b: Button, valor: int) -> void:
	if not playing:
		return
	if valor == correcta:
		b.add_theme_stylebox_override("normal", _style(Color(0.55, 0.95, 0.6)))
		b.add_theme_stylebox_override("hover", _style(Color(0.55, 0.95, 0.6)))
		_finish(true)
	else:
		b.disabled = true
		elapsed += PENALIZACION
		mensaje.text = "¡%d no es! Revisa la cuenta" % valor

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	for b in botones:
		b.disabled = true
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var core = get_parent()
	fin.show()
	if won:
		# escala USM: de 0 a 100
		nota.text = "100"
		fin.text = "¡Correcto!"
		pregunta.text += " %d ✓" % correcta
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		nota.text = "0"
		fin.text = "¡Se acabó el tiempo!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Era %d" % correcta
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
