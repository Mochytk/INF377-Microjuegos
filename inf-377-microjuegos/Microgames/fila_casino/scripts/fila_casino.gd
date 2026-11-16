extends Control
## Fila del casino: hay tres filas para el almuerzo y cada una avanza a distinta velocidad
## (rápida, normal o lenta), que va cambiando. Con ← → te cambias de fila, pero quedas al
## final de la nueva. Gana si te sirven antes de que se acabe el tiempo.

const A := "res://Microgames/fila_casino/assets/"
const TEX_PERSONAS := [preload(A + "persona_0.png"), preload(A + "persona_1.png"), preload(A + "persona_2.png"), preload(A + "persona_3.png"), preload(A + "persona_4.png"), preload(A + "persona_5.png")]
const TEX_JUGADOR := preload(A + "jugador.png")
const TEX_SIRVE := [preload(A + "sirve_0.png"), preload(A + "sirve_1.png")]
const TEX_BANDEJA := preload(A + "bandeja.png")

const LANES_X := [288.0, 576.0, 864.0]
const FRONT_Y := 262.0          # pies de la primera persona de la fila
const GAP := 56.0
const MAX_FILA := 6              # máximo de personas (sin contar al jugador) por fila
const ESTADOS := {
	"rapida": {"rate": 1.1, "texto": "RÁPIDA »»»", "color": Color(0.18, 0.8, 0.44)},
	"normal": {"rate": 0.6, "texto": "NORMAL »»", "color": Color(1.0, 0.82, 0.25)},
	"lenta": {"rate": 0.22, "texto": "LENTA »", "color": Color(0.9, 0.22, 0.27)},
}

@onready var gente: Node2D = $Gente
@onready var sirven: Node2D = $Sirven
@onready var letreros: Control = $Letreros
@onready var tu: Label = $Tu
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var lanes: Array = [[], [], []]      # sprites de cada fila, del primero al último
var estado: Array = ["normal", "lenta", "rapida"]
var acc: Array = [0.0, 0.0, 0.0]
var signs: Array = []
var servers: Array = []
var player: Sprite2D
var player_lane := 1
var playing := false
var time_limit := 10.0
var elapsed := 0.0
var cambio := 3.0                # cada cuánto cambian las velocidades
var cambio_t := 0.0
var llegada_t := 0.0

func _ready() -> void:
	# Nivel 1: 4 personas adelante, 10 s y cambios cada 3 s. Al subir: más gente y cambios más seguidos.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n0 := 4 + int(level / 3.0)              # 4 a 6 personas adelante
	cambio = maxf(2.2, 3.0 - 0.13 * level) / apuro
	time_limit = (10.0 + 1.2 * (n0 - 4)) / sqrt(apuro)   # las filas no avanzan más rápido, así que el tiempo baja más suave
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	# Partes en la fila del medio, que empieza lenta: conviene cambiarse
	estado = ["rapida", "lenta", "normal"] if randf() < 0.5 else ["normal", "lenta", "rapida"]
	for i in range(3):
		var s := Sprite2D.new()
		s.texture = TEX_SIRVE[0]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(4, 4)
		s.position = Vector2(LANES_X[i], 96)
		sirven.add_child(s)
		servers.append(s)
		signs.append(_make_sign(i))
		var n := n0 if i == player_lane else clampi(n0 + randi_range(-1, 1), 3, MAX_FILA)
		for k in range(n):
			lanes[i].append(_make_person(TEX_PERSONAS.pick_random()))
	player = _make_person(TEX_JUGADOR)
	lanes[player_lane].append(player)
	for i in range(3):
		_update_sign(i, false)
		_reposition(i, true)
	playing = true

func _make_person(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(4, 4)
	s.centered = false
	s.offset = Vector2(-7, -18)
	gente.add_child(s)
	return s

func _make_sign(i: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(LANES_X[i] - 95, 26)
	p.custom_minimum_size = Vector2(190, 40)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.pivot_offset = Vector2(95, 20)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	p.add_child(l)
	letreros.add_child(p)
	return p

func _update_sign(i: int, animar: bool) -> void:
	var info: Dictionary = ESTADOS[estado[i]]
	var sb := StyleBoxFlat.new()
	sb.bg_color = info["color"]
	sb.set_border_width_all(4)
	sb.border_color = Color(0.08, 0.08, 0.08)
	sb.set_corner_radius_all(8)
	signs[i].add_theme_stylebox_override("panel", sb)
	signs[i].get_child(0).text = info["texto"]
	if animar:
		signs[i].scale = Vector2(1.25, 1.25)
		create_tween().tween_property(signs[i], "scale", Vector2.ONE, 0.2)

# Ubica a cada persona según su puesto en la fila
func _reposition(i: int, inmediato := false) -> void:
	for k in range(lanes[i].size()):
		var s: Sprite2D = lanes[i][k]
		var target := Vector2(LANES_X[i], FRONT_Y + k * GAP)
		s.z_index = k
		if inmediato:
			s.position = target
		else:
			create_tween().tween_property(s, "position", target, 0.18)

func _process(delta: float) -> void:
	tu.position = player.position + Vector2(30, -56)
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)

	# Cambiarse de fila: quedas al final de la nueva
	var dir := 0
	if Input.is_action_just_pressed("ui_left"): dir = -1
	elif Input.is_action_just_pressed("ui_right"): dir = 1
	var destino := player_lane + dir
	if dir != 0 and destino >= 0 and destino <= 2:
		lanes[player_lane].erase(player)
		_reposition(player_lane)
		player_lane = destino
		lanes[player_lane].append(player)
		_reposition(player_lane)

	# Cada fila atiende según su velocidad
	for i in range(3):
		var rate: float = ESTADOS[estado[i]]["rate"]
		servers[i].texture = TEX_SIRVE[int(elapsed * rate * 4.0) % 2]
		acc[i] += rate * delta
		if acc[i] >= 1.0 and not lanes[i].is_empty():
			acc[i] -= 1.0
			if _serve(i):
				return

	# Las velocidades cambian cada cierto rato (siempre hay una rápida, una normal y una lenta)
	cambio_t += delta
	if cambio_t >= cambio:
		cambio_t = 0.0
		var nuevo: Array = estado.duplicate()
		while nuevo == estado:
			nuevo.shuffle()
		estado = nuevo
		for i in range(3):
			_update_sign(i, true)

	# Sigue llegando gente a las filas
	llegada_t += delta
	if llegada_t >= 1.5:
		llegada_t = 0.0
		var i := randi() % 3
		if lanes[i].size() < MAX_FILA:
			var s := _make_person(TEX_PERSONAS.pick_random())
			s.position = Vector2(LANES_X[i], 700)
			lanes[i].append(s)
			_reposition(i)

	if elapsed >= time_limit:
		_finish(false)

# Atiende al primero de la fila. Devuelve true si era el jugador.
func _serve(i: int) -> bool:
	var s: Sprite2D = lanes[i].pop_front()
	if s == player:
		_finish(true)
		return true
	var lado := -1.0 if i == 0 else 1.0
	if i == 1: lado = -1.0 if randf() < 0.5 else 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "position", s.position + Vector2(lado * 110, 30), 0.35)
	tw.tween_property(s, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(s.queue_free)
	_reposition(i)
	return false

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Almuerzo servido!"
		var b := Sprite2D.new()
		b.texture = TEX_BANDEJA
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(0, -22)
		player.add_child(b)
		var tw := create_tween()
		tw.tween_property(player, "position:y", player.position.y - 20, 0.1)
		tw.tween_property(player, "position:y", player.position.y, 0.1)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se acabó la comida!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
