extends Control
## Despertador: suena la alarma y hay que apagarla varias veces seguidas. Los botones cambian
## de lugar en cada alarma y al lado siempre hay uno de POSPONER: tocarlo hace perder tiempo
## y puntaje. Si se acaba el tiempo, te quedaste dormido.

const TEX_DESPIERTO := preload("res://Microgames/despertador/assets/pieza_despierto.png")
const PENALIZACION := 0.8      # segundos que se pierden al posponer
const SEÑUELOS := ["POSPONER", "5 MIN MÁS", "DORMIR"]

@onready var fondo: TextureRect = $Fondo
@onready var zzz: Label = $Zzz
@onready var telefono: Panel = $Telefono
@onready var alarma_label: Label = $Telefono/Pantalla/Alarma
@onready var hora_label: Label = $Telefono/Pantalla/Hora
@onready var botones: Control = $Telefono/Pantalla/Botones
@onready var mensaje: Label = $Mensaje
@onready var error_label: Label = $Error
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var total := 3               # alarmas que hay que apagar
var apagadas := 0
var pospuestas := 0
var n_botones := 2
var alto_boton := 110.0
var time_limit := 6.5
var elapsed := 0.0
var ring_tween: Tween

func _ready() -> void:
	# Nivel 1: 3 alarmas y 2 botones grandes. Al subir: más alarmas, un tercer botón señuelo,
	# botones más chicos y menos tiempo por alarma.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	total = mini(6, 3 + int(level / 2.0))
	n_botones = 3 if level >= 2.0 else 2
	alto_boton = 110.0 if level < 4.0 else 80.0
	time_limit = 1.5 + maxf(1.0, 1.7 - 0.1 * level) * total
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_next_alarm()
	playing = true

func _style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(5)
	s.border_color = Color(0.03, 0.03, 0.05)
	s.set_corner_radius_all(14)
	return s

func _next_alarm() -> void:
	for b in botones.get_children():
		b.queue_free()
	alarma_label.text = "ALARMA %d de %d" % [apagadas + 1, total]
	hora_label.text = "07:%02d" % (apagadas * 5 + pospuestas * 5)
	# Botones en orden al azar: uno APAGAR y el resto señuelos
	var textos: Array = ["APAGAR"]
	var señuelos: Array = SEÑUELOS.duplicate()
	if n_botones == 2:
		señuelos = ["POSPONER"]
	señuelos.shuffle()
	for i in range(n_botones - 1):
		textos.append(señuelos[i])
	textos.shuffle()
	var sep := 14.0
	var y0 := (284.0 - (alto_boton * n_botones + sep * (n_botones - 1))) / 2.0
	for i in range(textos.size()):
		var b := Button.new()
		b.text = textos[i]
		b.position = Vector2(20, y0 + i * (alto_boton + sep))
		b.size = Vector2(320, alto_boton)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 34)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color(0.03, 0.03, 0.05))
		# Mismo color para todos los botones: hay que leer, no guiarse por el color
		var st := _style(Color(1.0, 0.82, 0.25))
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, st)
		b.pressed.connect(_on_button.bind(textos[i] == "APAGAR"))
		botones.add_child(b)
	# El teléfono vibra mientras suena
	if ring_tween:
		ring_tween.kill()
	ring_tween = create_tween().set_loops()
	ring_tween.tween_property(telefono, "rotation_degrees", 2.0, 0.06)
	ring_tween.tween_property(telefono, "rotation_degrees", -2.0, 0.06)

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	zzz.position.y = 310.0 + sin(elapsed * 3.0) * 6.0
	if elapsed >= time_limit:
		_finish(false)

func _on_button(es_apagar: bool) -> void:
	if not playing:
		return
	if es_apagar:
		apagadas += 1
		if apagadas >= total:
			_finish(true)
		else:
			_next_alarm()
	else:
		# Pospuso: pierde tiempo, puntaje y la alarma vuelve a sonar
		pospuestas += 1
		elapsed += PENALIZACION
		error_label.show()
		error_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(error_label, "modulate:a", 0.0, 0.5).set_delay(0.5)
		tw.tween_callback(error_label.hide)
		_next_alarm()

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	if ring_tween:
		ring_tween.kill()
	telefono.rotation_degrees = 0.0
	for b in botones.get_children():
		b.queue_free()
	var core = get_parent()
	if won:
		mensaje.text = "¡Despertaste! A clases"
		alarma_label.text = "¡Buenos días!"
		zzz.hide()
		fondo.texture = TEX_DESPIERTO
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		var perf: float = clampf(core.time_performance(used_ratio) - 0.25 * pospuestas, 0.1, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, perf)
	else:
		mensaje.text = "¡Te quedaste dormido! Llegaste tarde"
		alarma_label.text = "Alarma pospuesta..."
		hora_label.text = "09:40"
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
