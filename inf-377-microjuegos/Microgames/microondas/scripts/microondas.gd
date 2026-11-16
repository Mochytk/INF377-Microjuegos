extends Control
## Microondas: carrera contra otro estudiante por el único microondas libre del casino.
## Cada flecha correcta acerca al jugador; el rival avanza solo con el tiempo.
## Si completas la secuencia llegas primero; si se acaba el tiempo, te lo gana el rival.

const ARROWS := [
	{"action": "ui_up", "icon": preload("res://Microgames/microondas/assets/up.png")},
	{"action": "ui_down", "icon": preload("res://Microgames/microondas/assets/down.png")},
	{"action": "ui_left", "icon": preload("res://Microgames/microondas/assets/left.png")},
	{"action": "ui_right", "icon": preload("res://Microgames/microondas/assets/right.png")},
]
const TEX_JUGADOR := [preload("res://Microgames/microondas/assets/jugador_0.png"), preload("res://Microgames/microondas/assets/jugador_1.png")]
const TEX_RIVAL := [preload("res://Microgames/microondas/assets/rival_0.png"), preload("res://Microgames/microondas/assets/rival_1.png")]
const MW_OPEN := preload("res://Microgames/microondas/assets/microondas_open.png")
const MW_ON := preload("res://Microgames/microondas/assets/microondas_on.png")

# Posiciones de los pies: salida abajo y llegada frente al microondas libre
const JUGADOR_SALIDA := Vector2(144, 496)
const JUGADOR_META := Vector2(536, 368)
const RIVAL_SALIDA := Vector2(1008, 496)
const RIVAL_META := Vector2(616, 368)
const MW_INTERIOR := Vector2(562, 176)

@onready var jugador: Sprite2D = $Jugador
@onready var rival: Sprite2D = $Rival
@onready var microondas: Sprite2D = $MicroondasLibre
@onready var libre: Label = $Libre
@onready var mensaje: Label = $Mensaje
@onready var flechas: HBoxContainer = $Barra/Flechas
@onready var timer_bar: ProgressBar = $ProgressBar

var sequence: Array = []      # acciones (ui_up, ...)
var index := 0
var playing := false
var time_limit := 7.0
var elapsed := 0.0
var walk_clock := 0.0
var last_pos := {}

func _ready() -> void:
	# Nivel 1: 3 flechas y 7 s. Cada 2 niveles se agrega una flecha (máx. 5) y baja el tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var count := 3 + int(level / 2.0)
	time_limit = maxf(4.0, 7.0 - 0.3 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	for i in range(count):
		var pick: Dictionary = ARROWS.pick_random()
		sequence.append(pick["action"])
		var r := TextureRect.new()
		r.texture = pick["icon"]
		r.custom_minimum_size = Vector2(96, 96)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.pivot_offset = Vector2(48, 48)
		flechas.add_child(r)
	_mark_current()

	var bounce := create_tween().set_loops()
	bounce.tween_property(libre, "position:y", libre.position.y - 8, 0.35)
	bounce.tween_property(libre, "position:y", libre.position.y, 0.35)
	playing = true

func _process(delta: float) -> void:
	_animate_walk(delta)
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	# El rival avanza solo: llega justo cuando se acaba el tiempo
	rival.position = RIVAL_SALIDA.lerp(RIVAL_META, clampf(elapsed / time_limit, 0.0, 1.0))
	if elapsed >= time_limit:
		_finish(false)

func _unhandled_input(event: InputEvent) -> void:
	if not playing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var pressed_action := ""
	for a in ARROWS:
		if event.is_action(a["action"]):
			pressed_action = a["action"]
	if pressed_action == "":
		return   # otras teclas no cuentan
	get_viewport().set_input_as_handled()
	if pressed_action == sequence[index]:
		flechas.get_child(index).modulate.a = 0.2
		index += 1
		_move_player()
		if index >= sequence.size():
			_finish(true)
		else:
			_mark_current()
	else:
		# Error: se reinicia la secuencia y el jugador vuelve a la salida
		index = 0
		for f in flechas.get_children():
			f.modulate.a = 1.0
		_mark_current()
		_move_player()

func _mark_current() -> void:
	for i in range(flechas.get_child_count()):
		flechas.get_child(i).scale = Vector2.ONE * (1.15 if i == index else 1.0)

func _move_player() -> void:
	var target := JUGADOR_SALIDA.lerp(JUGADOR_META, float(index) / sequence.size())
	create_tween().tween_property(jugador, "position", target, 0.18)

# Alterna los dos cuadros de caminar mientras el personaje se mueve
func _animate_walk(delta: float) -> void:
	walk_clock += delta
	for pair in [[jugador, TEX_JUGADOR], [rival, TEX_RIVAL]]:
		var s: Sprite2D = pair[0]
		var moving: bool = last_pos.get(s, s.position) != s.position
		s.texture = pair[1][int(walk_clock / 0.12) % 2] if moving else pair[1][0]
		last_pos[s] = s.position

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var winner: Sprite2D = jugador if won else rival
	var loser: Sprite2D = rival if won else jugador
	mensaje.text = "¡Llegaste primero!" if won else "¡Te ganaron el microondas!"
	libre.hide()

	# El ganador termina de llegar
	var meta := JUGADOR_META if won else RIVAL_META
	var t := create_tween()
	t.tween_property(winner, "position", meta, 0.2)
	await t.finished
	await _put_food_in(winner)

	# Celebración del ganador y el perdedor niega con la cabeza
	var hop := create_tween()
	hop.tween_property(winner, "position:y", meta.y - 24, 0.12)
	hop.tween_property(winner, "position:y", meta.y, 0.12)
	for i in range(4):
		loser.flip_h = not loser.flip_h
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(0.6).timeout

	var core = get_parent()
	if won:
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		core.end_microgame(false)

# Abre el microondas, mete el pote y lo enciende
func _put_food_in(who: Sprite2D) -> void:
	microondas.texture = MW_OPEN
	var pop := create_tween()
	pop.tween_property(microondas, "scale", Vector2(4.3, 4.3), 0.08)
	pop.tween_property(microondas, "scale", Vector2(4, 4), 0.08)
	await get_tree().create_timer(0.3).timeout

	var pote: Sprite2D = who.get_node("Pote")
	var move := create_tween().set_parallel(true)
	move.tween_property(pote, "global_position", MW_INTERIOR, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(pote, "scale", Vector2(0.85, 0.85), 0.45)
	await move.finished
	pote.hide()
	await get_tree().create_timer(0.2).timeout

	microondas.texture = MW_ON
	var close := create_tween()
	close.tween_property(microondas, "scale", Vector2(4.3, 4.3), 0.08)
	close.tween_property(microondas, "scale", Vector2(4, 4), 0.08)
	await get_tree().create_timer(0.4).timeout
