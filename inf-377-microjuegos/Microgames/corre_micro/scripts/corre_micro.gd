extends Control
## Corre a la micro: la micro está en el paradero y va a partir. Hay que alternar ← y →
## rápido para que el estudiante corra hasta la puerta antes de que se cierre. Apretar la
## misma flecha dos veces seguidas no avanza (hay que alternar).

const A := "res://Microgames/corre_micro/assets/"
const TEX_JUGADOR := [preload(A + "jugador_0.png"), preload(A + "jugador_1.png")]
const TEX_HUMO := preload(A + "humo.png")
const START_X := 110.0
const PUERTA_X := 760.0        # puerta trasera de la micro

@onready var micro: Sprite2D = $Micro
@onready var humo_nodo: Node2D = $Humo
@onready var jugador: Sprite2D = $Jugador
@onready var izq: TextureRect = $Izq
@onready var der: TextureRect = $Der
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var paso := 26.0               # píxeles que avanza cada flecha alternada
var time_limit := 6.0
var elapsed := 0.0
var siguiente := ""            # flecha que toca ("" = cualquiera al empezar)
var pasos := 0
var humo_clock := 0.0

func _ready() -> void:
	# Nivel 1: 25 pulsaciones en 6.5 s (menos de 4 por segundo). Al subir: hay que apretar
	# más veces (paso más corto) y hay menos tiempo; en el nivel 7, unas 6 por segundo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	paso = maxf(20.0, 26.0 - 1.0 * level)
	time_limit = maxf(5.3, 6.5 - 0.2 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_mark_next()
	playing = true

func _mark_next() -> void:
	izq.modulate = Color(1, 1, 1, 1.0 if siguiente != "ui_right" else 0.35)
	der.modulate = Color(1, 1, 1, 1.0 if siguiente != "ui_left" else 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if not playing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var accion := ""
	if event.is_action("ui_left"): accion = "ui_left"
	elif event.is_action("ui_right"): accion = "ui_right"
	if accion == "":
		return
	get_viewport().set_input_as_handled()
	var flecha := izq if accion == "ui_left" else der
	if siguiente != "" and accion != siguiente:
		# misma flecha dos veces: tropieza un poquito y no avanza
		flecha.scale = Vector2(0.85, 0.85)
		create_tween().tween_property(flecha, "scale", Vector2.ONE, 0.1)
		return
	pasos += 1
	Sonido.play("paso", 0.0, randf_range(0.9, 1.15))
	siguiente = "ui_right" if accion == "ui_left" else "ui_left"
	jugador.position.x = minf(PUERTA_X, jugador.position.x + paso)
	jugador.texture = TEX_JUGADOR[pasos % 2]
	jugador.offset.y = -38.0 if pasos % 2 == 0 else -36.0
	flecha.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(flecha, "scale", Vector2.ONE, 0.08)
	_mark_next()
	if jugador.position.x >= PUERTA_X:
		_finish(true)

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	# la micro tirita con el motor andando y echa humo, cada vez más al final
	micro.position.y = 470.0 + (1.0 if int(elapsed * 20.0) % 2 == 0 else 0.0)
	humo_clock += delta
	if humo_clock > lerpf(0.35, 0.1, elapsed / time_limit):
		humo_clock = 0.0
		_smoke()
	if elapsed >= time_limit:
		_finish(false)

func _smoke() -> void:
	var h := Sprite2D.new()
	h.texture = TEX_HUMO
	h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.scale = Vector2(4, 4)
	h.position = micro.position + Vector2(-200, 60)
	humo_nodo.add_child(h)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(h, "position", h.position + Vector2(-80, -40), 0.7)
	tw.tween_property(h, "modulate:a", 0.0, 0.7)
	tw.tween_property(h, "scale", Vector2(7, 7), 0.7)
	tw.chain().tween_callback(h.queue_free)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var core = get_parent()
	fin.show()
	izq.hide()
	der.hide()
	if won:
		fin.text = "¡Alcanzaste la micro!"
		mensaje.text = "¡Uf! Justo a tiempo"
		var sube := create_tween().set_parallel(true)
		sube.tween_property(jugador, "position", Vector2(PUERTA_X + 26.0, 456.0), 0.2)
		sube.tween_property(jugador, "modulate:a", 0.0, 0.35).set_delay(0.15)
		await sube.finished
		create_tween().tween_property(micro, "position:x", 1500.0, 0.9).set_ease(Tween.EASE_IN)
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se fue la micro!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		create_tween().tween_property(micro, "position:x", 1500.0, 1.0).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
