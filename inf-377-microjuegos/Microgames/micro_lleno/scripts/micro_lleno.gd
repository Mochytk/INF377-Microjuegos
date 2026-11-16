extends Control
## Micro lleno: la micro llega repleta y la puerta está tapada de gente. Hay que hacer clic en
## cada pasajero para que se corra hacia adentro y así poder subir antes de que cierre la puerta.
## Los que llevan mochilón necesitan dos clics.

const A := "res://Microgames/micro_lleno/assets/"
const TEX_PASAJEROS := [preload(A + "pasajero_0.png"), preload(A + "pasajero_1.png"), preload(A + "pasajero_2.png"), preload(A + "pasajero_3.png"), preload(A + "pasajero_4.png"), preload(A + "pasajero_5.png")]
const TEX_GRANDES := [preload(A + "pasajero_grande_0.png"), preload(A + "pasajero_grande_1.png")]
const ESCALA := 6.0
# Puestos dentro de la puerta: 4 columnas x 2 filas (posición de los pies)
const COLS_X := [420.0, 524.0, 628.0, 732.0]
const FILAS_Y := [330.0, 470.0]

@onready var bus: Control = $Bus
@onready var gente: Control = $Bus/Gente
@onready var puerta_izq: TextureRect = $Bus/PuertaIzq
@onready var puerta_der: TextureRect = $Bus/PuertaDer
@onready var jugador: Sprite2D = $Jugador
@onready var globo: Label = $Globo
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var quedan := 0
var toques := {}             # pasajero -> clics que le faltan
var time_limit := 6.0
var elapsed := 0.0

func _ready() -> void:
	# Nivel 1: 4 pasajeros de un clic. Al subir: hasta 8 pasajeros, algunos con mochilón (2 clics) y menos tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(8, 4 + int(level * 0.7))
	var dobles := mini(3, int(level / 2.0))
	var puestos: Array = []
	for f in range(2):
		for c in range(4):
			puestos.append(Vector2(COLS_X[c], FILAS_Y[f]))
	puestos.shuffle()
	puestos = puestos.slice(0, n)
	puestos.sort_custom(func(a, b): return a.y < b.y)    # los de atrás se dibujan primero
	var total_toques := 0
	for i in range(n):
		var grande := i < dobles
		var p := TextureRect.new()
		p.texture = TEX_GRANDES.pick_random() if grande else TEX_PASAJEROS.pick_random()
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.size = Vector2(p.texture.get_width(), p.texture.get_height()) * ESCALA
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.pivot_offset = Vector2(p.size.x / 2.0, p.size.y)
		gente.add_child(p)
		toques[p] = 2 if grande else 1
		total_toques += toques[p]
		p.gui_input.connect(_on_passenger_input.bind(p))
	# los grandes quedan repartidos al azar entre los puestos
	var hijos := gente.get_children()
	var orden: Array = puestos.duplicate()
	orden.shuffle()
	for i in range(n):
		hijos[i].position = orden[i] - hijos[i].pivot_offset
	for h in hijos:
		h.z_index = 1 if h.position.y + h.size.y > 400.0 else 0
	quedan = n
	time_limit = (2.8 + maxf(0.6, 1.0 - 0.06 * level) * total_toques) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if elapsed >= time_limit:
		_finish(false)

func _on_passenger_input(event: InputEvent, p: TextureRect) -> void:
	if not playing or not toques.has(p):
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	toques[p] -= 1
	_say(p, "¡Permiso!" if toques[p] <= 0 else "¡Ya voy!")
	if toques[p] > 0:
		# le falta un clic: se queja y tiembla
		var base := p.position.x
		var tw := create_tween()
		tw.tween_property(p, "position:x", base + 10.0, 0.05)
		tw.tween_property(p, "position:x", base - 10.0, 0.05)
		tw.tween_property(p, "position:x", base, 0.05)
		return
	toques.erase(p)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quedan -= 1
	# se corre hacia adentro, por el lado más cercano
	var lado := -1.0 if p.position.x + p.size.x / 2.0 < 576.0 else 1.0
	var tw := create_tween()
	tw.tween_property(p, "position:x", p.position.x + lado * 330.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.hide)
	if quedan <= 0:
		_finish(true)

func _say(p: TextureRect, texto: String) -> void:
	globo.text = texto
	globo.position = p.global_position + Vector2(p.size.x / 2.0 - 80.0, -30.0)
	globo.show()
	globo.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(globo, "modulate:a", 0.0, 0.3).set_delay(0.35)

func _close_doors(t: float) -> Tween:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(puerta_izq, "position:x", 368.0, t)
	tw.tween_property(puerta_der, "position:x", 576.0, t)
	return tw

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var core = get_parent()
	if won:
		mensaje.text = "¡Hay espacio! Sube"
		var sube := create_tween().set_parallel(true)
		sube.tween_property(jugador, "position", Vector2(576, 500), 0.45)
		sube.tween_property(jugador, "scale", Vector2(5, 5), 0.45)
		await sube.finished
		jugador.reparent(gente)
		await _close_doors(0.3).finished
		fin.text = "¡Subiste a la micro!"
		fin.show()
		create_tween().tween_property(bus, "position:x", -1300.0, 0.9).set_ease(Tween.EASE_IN).set_delay(0.3)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		mensaje.text = "¡Se cerró la puerta!"
		await _close_doors(0.2).finished
		fin.text = "¡Se fue la micro!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		fin.show()
		create_tween().tween_property(bus, "position:x", -1300.0, 0.9).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
