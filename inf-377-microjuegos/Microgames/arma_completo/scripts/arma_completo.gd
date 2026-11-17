extends Control
## Arma el completo: el pan con vienesa corre de lado a lado por el mesón y arriba cuelga la
## cuchara con el ingrediente que toca. Con ESPACIO se suelta: tiene que caer encima del pan.
## Un italiano lleva tomate, palta y mayo, en ese orden. Si cae en el mesón, es un error.

const A := "res://Microgames/arma_completo/assets/"
const INGREDIENTES := ["tomate", "palta", "mayo"]
const NOMBRES := ["Tomate", "Palta", "Mayo"]
const CENTRO_X := 576.0          # donde cae el ingrediente
const PAN_MIN_X := 220.0         # borde izquierdo del pan en sus extremos
const PAN_MAX_X := 760.0
const ANCHO_PAN := 176.0
const PAN_Y := 388.0
const PORCION_Y := 136.0
const GRAVEDAD := 2200.0

@onready var pan: TextureRect = $Pan
@onready var porcion: TextureRect = $Porcion
@onready var cuchara: TextureRect = $Cuchara
@onready var manchas: Control = $Manchas
@onready var guia: ColorRect = $Guia
@onready var menu: Label = $Menu
@onready var mensaje: Label = $Mensaje
@onready var errores_label: Label = $Errores
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 10.0
var elapsed := 0.0
var level := 0.0
var velocidad := 280.0
var vel_base := 280.0
var dir := 1.0
var tolerancia := 64.0
var completos := 1
var hechos := 0                  # completos terminados
var paso := 0                    # ingrediente que toca (0 tomate, 1 palta, 2 mayo)
var errores := 0
var max_errores := 3
var cayendo := false
var cambiando := false           # el completo listo se va y llega otro pan
var vel_caida := 0.0
var capas: Array = []
var texturas := {}
var ideal := 4.0                 # tiempo de alguien que suelta bien en cada pasada

func _ready() -> void:
	# Nivel 1: el pan va lento, hay una guía que marca dónde cae y basta un italiano. Al subir:
	# el pan va más rápido (y desde el nivel 5 cambia de velocidad), hay menos margen, se
	# piden 2 italianos y se tolera un error menos.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	level = clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	vel_base = (320.0 + 35.0 * level) * apuro
	velocidad = vel_base
	tolerancia = 64.0 - 5.0 * level
	completos = 1 if level < 3.0 else 2
	max_errores = 3 if level < 3.0 else 2
	guia.visible = level < 2.0
	var pasada := (PAN_MAX_X - PAN_MIN_X) / vel_base
	ideal = 3 * completos * pasada * 0.85 + (completos - 1) * 0.8
	time_limit = 3 * completos * (pasada * 0.6 + 0.7) + 2.5 + (completos - 1) * 1.2
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	for n in INGREDIENTES:
		texturas["porcion_" + n] = load(A + "porcion_%s.png" % n)
		texturas["capa_" + n] = load(A + "capa_%s.png" % n)
		texturas["mancha_" + n] = load(A + "mancha_%s.png" % n)
	pan.position.x = PAN_MIN_X + randf() * (PAN_MAX_X - PAN_MIN_X)
	dir = 1.0 if randf() < 0.5 else -1.0
	_preparar_porcion()
	_actualizar_textos()
	playing = true

func _actualizar_textos() -> void:
	var lineas := ["ITALIANO" + ("  %d/%d" % [hechos + 1, completos] if completos > 1 else "")]
	for i in range(3):
		lineas.append(("✓ " if i < paso else ("▶ " if i == paso else "   ")) + NOMBRES[i])
	menu.text = "\n".join(lineas)
	errores_label.text = "Errores: %d / %d" % [errores, max_errores]

func _preparar_porcion() -> void:
	porcion.texture = texturas["porcion_" + INGREDIENTES[paso]]
	porcion.position = Vector2(CENTRO_X - porcion.size.x / 2.0, PORCION_Y)
	porcion.modulate.a = 1.0
	cuchara.rotation = 0.0
	cayendo = false

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if not cambiando:
		_mover_pan(delta)
	if cayendo:
		_caer(delta)
	if elapsed >= time_limit:
		_finish(false)

func _mover_pan(delta: float) -> void:
	var antes := pan.position.x
	pan.position.x += dir * velocidad * delta
	if pan.position.x > PAN_MAX_X or pan.position.x < PAN_MIN_X:
		pan.position.x = clampf(pan.position.x, PAN_MIN_X, PAN_MAX_X)
		dir = -dir
		# desde el nivel 5 el cocinero cambia el ritmo en cada vuelta
		if level >= 4.0:
			velocidad = vel_base * randf_range(0.75, 1.25)
	var dx := pan.position.x - antes
	for c in capas:
		c.position.x += dx

func _unhandled_input(event: InputEvent) -> void:
	if not playing or cayendo or cambiando:
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		cayendo = true
		vel_caida = 0.0
		var t := create_tween()
		t.tween_property(cuchara, "rotation", 0.5, 0.06)
		t.tween_property(cuchara, "rotation", 0.0, 0.15)

func _altura_pila() -> float:
	# parte de arriba de la última capa (o de la vienesa)
	return PAN_Y + 4.0 - 16.0 * capas.size()

func _caer(delta: float) -> void:
	vel_caida += GRAVEDAD * delta
	porcion.position.y += vel_caida * delta
	var abajo := porcion.position.y + porcion.size.y
	var centro_pan := pan.position.x + ANCHO_PAN / 2.0
	if abajo >= _altura_pila() + 20.0:
		var sobre_pan := absf(CENTRO_X - centro_pan) <= tolerancia
		if sobre_pan:
			_agregar_capa()
		elif abajo >= PAN_Y + 60.0:
			_manchar()

func _agregar_capa() -> void:
	cayendo = false
	porcion.modulate.a = 0.0
	var c := TextureRect.new()
	c.texture = texturas["capa_" + INGREDIENTES[paso]]
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.size = Vector2(160, 28)
	c.position = Vector2(pan.position.x + 8.0, PAN_Y - 4.0 - 16.0 * capas.size())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	move_child(c, pan.get_index() + 1)
	capas.append(c)
	var t := create_tween()
	c.scale = Vector2(1.0, 0.4)
	c.pivot_offset = Vector2(80, 28)
	t.tween_property(c, "scale", Vector2.ONE, 0.1)
	paso += 1
	mensaje.text = ["", "¡Bien! Ahora la palta", "¡Eso! Falta la mayo", ""][paso]
	if paso >= 3:
		_completo_listo()
	else:
		_actualizar_textos()
		_preparar_porcion()

func _completo_listo() -> void:
	hechos += 1
	paso = 0
	if hechos >= completos:
		_actualizar_textos()
		_finish(true)
		return
	# el italiano listo se va por la derecha y entra un pan nuevo por la izquierda
	cambiando = true
	mensaje.text = "¡Un italiano listo! Va el otro"
	var t := create_tween().set_parallel()
	t.tween_property(pan, "position:x", 1200.0, 0.4)
	for c in capas:
		t.tween_property(c, "position:x", c.position.x + (1200.0 - pan.position.x), 0.4)
	await t.finished
	for c in capas:
		c.queue_free()
	capas.clear()
	if not playing:
		return
	pan.position.x = PAN_MIN_X - 260.0
	dir = 1.0
	var t2 := create_tween()
	t2.tween_property(pan, "position:x", PAN_MIN_X, 0.3)
	await t2.finished
	cambiando = false
	_actualizar_textos()
	_preparar_porcion()

# El ingrediente cae al mesón
func _manchar() -> void:
	cayendo = false
	var m := TextureRect.new()
	m.texture = texturas["mancha_" + INGREDIENTES[paso]]
	m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	m.size = Vector2(96, 24)
	m.position = Vector2(CENTRO_X - 48.0, 428.0)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	manchas.add_child(m)
	porcion.modulate.a = 0.0
	errores += 1
	mensaje.text = "¡Cayó al mesón! Espera que pase el pan"
	_actualizar_textos()
	if errores >= max_errores:
		_finish(false)
		return
	await get_tree().create_timer(0.25).timeout
	if playing:
		_preparar_porcion()

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	cayendo = false
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Italiano listo!" if completos == 1 else "¡Dos italianos listos!"
		mensaje.text = "¡Buen provecho!"
		# el ritmo lo pone el pan: se compara con el tiempo de alguien que acierta en cada pasada
		var perf := 1.25 - 0.5 * elapsed / ideal - 0.12 * errores
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, clampf(perf, 0.25, 1.0))
	else:
		fin.text = "¡Quedó todo en el mesón!" if errores >= max_errores else "¡Se acabó el tiempo!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
