extends Control
## Firma la lista: la hoja de asistencia pasa por tu mesa y el ayudante se la va llevando.
## Hay que encontrar tu nombre y hacer clic en su fila para firmar antes de que se la lleven.

const NOMBRES := ["Camila", "Matías", "Sofía", "Benjamín", "Valentina", "Diego", "Javiera", "Tomás", "Antonia", "Nicolás", "Catalina", "Felipe", "Fernanda", "Ignacio", "Constanza", "Sebastián"]
const APELLIDOS := ["Rojas", "Muñoz", "Soto", "Contreras", "Silva", "Sepúlveda", "Morales", "Fuentes", "Araya", "Castillo", "Vargas", "Tapia", "Reyes", "Espinoza", "Pizarro", "Carrasco"]
const ALTO_FILA := 38.0
const PENALIZACION := 1.0     # segundos que se pierden al firmar en la fila de otro
const X_INICIO := 150.0
const X_FIN := 1170.0         # fuera de la pantalla

@onready var hoja: PanelContainer = $Hoja
@onready var filas_box: VBoxContainer = $Hoja/VBox/Filas
@onready var mano: Sprite2D = $Hoja/Mano
@onready var mensaje: Label = $Mensaje
@onready var nombre_label: Label = $Nombre
@onready var error_label: Label = $Error
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 8.0
var elapsed := 0.0
var mi_fila := 0
var filas: Array = []         # paneles de cada fila
var base_y := 96.0

func _ready() -> void:
	# Nivel 1: 6 nombres y 8 s. Al subir: más nombres (hasta 12), nombres parecidos al tuyo y menos tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := 6 + int(level)
	time_limit = maxf(5.5, 8.0 - 0.4 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	var nombres := _make_names(n, int(level))
	mi_fila = nombres.find(_propio)
	nombre_label.text = _propio.to_upper()
	for i in range(n):
		filas.append(_make_row(i, nombres[i], i != mi_fila and randf() < 0.45))
	# Centra la hoja verticalmente según su alto
	var alto := 92.0 + ALTO_FILA * n
	base_y = clampf(84.0 + (560.0 - alto) / 2.0, 84.0, 300.0)
	hoja.position = Vector2(X_INICIO, base_y)
	hoja.size = Vector2(540, alto)
	mano.position = Vector2(566, alto / 2.0)
	playing = true

# n nombres distintos; con nivel alto, algunos comparten nombre o apellido con el del jugador
func _make_names(n: int, parecidos: int) -> Array:
	var usados := {}
	var lista: Array = []
	var propio_n: String = NOMBRES.pick_random()
	var propio_a: String = APELLIDOS.pick_random()
	lista.append(propio_n + " " + propio_a)
	usados[lista[0]] = true
	var k := mini(parecidos, n - 1)
	while lista.size() < n:
		var nom: String = NOMBRES.pick_random()
		var ape: String = APELLIDOS.pick_random()
		if lista.size() <= k:
			if lista.size() % 2 == 1: nom = propio_n
			else: ape = propio_a
		elif nom == propio_n or ape == propio_a:
			continue   # fuera de los "parecidos" a propósito, nadie más comparte tu nombre ni tu apellido
		var full := nom + " " + ape
		if not usados.has(full):
			usados[full] = true
			lista.append(full)
	# el propio se ubica en una fila al azar entre los demás
	_propio = lista.pop_front()
	lista.shuffle()
	lista.insert(randi() % n, _propio)
	return lista

var _propio := ""

func _make_row(i: int, nombre: String, firmada: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ALTO_FILA)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0) if i % 2 else Color(0.93, 0.95, 0.98, 1)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.7, 0.72, 0.76)
	sb.content_margin_left = 6
	row.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var num := Label.new()
	num.text = "%2d." % (i + 1)
	num.custom_minimum_size = Vector2(34, 0)
	var nom := Label.new()
	nom.text = nombre
	nom.custom_minimum_size = Vector2(270, 0)
	for l in [num, nom]:
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.14))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(l)
	var firma := Control.new()
	firma.name = "Firma"
	firma.custom_minimum_size = Vector2(170, ALTO_FILA - 4)
	firma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(firma)
	var linea := ColorRect.new()
	linea.color = Color(0.45, 0.47, 0.52)
	linea.position = Vector2(0, ALTO_FILA - 10)
	linea.size = Vector2(170, 2)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	firma.add_child(linea)
	if firmada:
		firma.add_child(_scribble(Color(0.25, 0.3, 0.45), 1.0))
	row.gui_input.connect(_on_row_input.bind(i))
	row.mouse_entered.connect(func(): if playing: row.modulate = Color(1.0, 0.97, 0.75))
	row.mouse_exited.connect(func(): row.modulate = Color.WHITE)
	filas_box.add_child(row)
	return row

# Garabato de firma hecho con una línea
func _scribble(color: Color, completo: float) -> Line2D:
	var l := Line2D.new()
	l.width = 2.5
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	var x := 8.0
	var pts := int(14 * completo)
	for k in range(pts):
		l.add_point(Vector2(x, (ALTO_FILA - 14) * 0.5 + randf_range(-9, 9)))
		x += randf_range(6, 13)
	return l

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	var p := clampf(elapsed / time_limit, 0.0, 1.0)
	# El ayudante se va llevando la hoja: parte lento y acelera
	hoja.position = Vector2(lerpf(X_INICIO, X_FIN, pow(p, 1.6)), base_y + sin(elapsed * 2.2) * 5.0)
	if elapsed >= time_limit:
		_finish(false)

func _on_row_input(event: InputEvent, i: int) -> void:
	if not playing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if i == mi_fila:
		_finish(true)
		Sonido.play("acierto")
	else:
		elapsed += PENALIZACION
		Sonido.play("error")
		filas[i].modulate = Color(1, 0.6, 0.6)
		error_label.show()
		error_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(error_label, "modulate:a", 0.0, 0.5).set_delay(0.4)
		tw.parallel().tween_property(filas[i], "modulate", Color.WHITE, 0.5).set_delay(0.4)
		tw.tween_callback(error_label.hide)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var core = get_parent()
	if won:
		mensaje.text = "¡Firmado! Quedaste presente"
		var fila: PanelContainer = filas[mi_fila]
		fila.modulate = Color(0.8, 1.0, 0.8)
		var firma: Control = fila.get_child(0).get_node("Firma")
		# la firma se dibuja de a poco
		var linea := _scribble(Color(0.1, 0.25, 0.85), 1.0)
		var puntos := linea.points
		linea.clear_points()
		firma.add_child(linea)
		for pt in puntos:
			linea.add_point(pt)
			await get_tree().create_timer(0.03).timeout
		await get_tree().create_timer(0.7).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		mensaje.text = "¡Se llevaron la lista! Quedaste ausente"
		nombre_label.hide()
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
