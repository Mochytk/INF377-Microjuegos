extends Control
## Bicicletero: queda un solo puesto libre y otro ciclista va hacia él. Hay que manejar la
## bici con las flechas (o WASD) y entrar al puesto LIBRE antes que el rival. Chocar con las
## bicis estacionadas o con la gente hace perder tiempo y puntaje.

const A := "res://Microgames/bicicletero/assets/"
const TEX_JUGADOR := [preload(A + "jugador_0.png"), preload(A + "jugador_1.png")]
const TEX_RIVAL := [preload(A + "rival_0.png"), preload(A + "rival_1.png")]
const TEX_BICIS := [preload(A + "bici_0.png"), preload(A + "bici_1.png"), preload(A + "bici_2.png"), preload(A + "bici_3.png"), preload(A + "bici_4.png")]
const TEX_BARRA := preload(A + "barra.png")
const TEX_PEATONES := [preload(A + "peaton_0.png"), preload(A + "peaton_1.png")]

const SPEED := 300.0
const RACK_Y := 196.0            # centro de las bicis estacionadas
const ENTRADA_Y := 292.0         # sobre esta línea se está dentro del bicicletero
const ESTACIONADO_Y := 216.0     # llegar hasta aquí dentro del puesto libre = estacionar
const CALLE_Y := 330.0           # carril por donde llega el rival
const ATURDIDO := 0.35           # segundos sin control tras un choque

@onready var rack: Node2D = $Rack
@onready var libre: Label = $Libre
@onready var peatones_nodo: Node2D = $Peatones
@onready var rival: Sprite2D = $Rival
@onready var jugador: Sprite2D = $Jugador
@onready var golpe: Label = $Golpe
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var ancho := 170.0               # ancho de cada puesto
var libre_x := 576.0
var medio := 60.0                # margen lateral permitido dentro del puesto libre
var rival_time := 9.5
var rival_start_x := -80.0
var elapsed := 0.0
var choques := 0
var aturdido := 0.0
var inmune := 0.0
var peatones: Array = []         # {nodo, vel}
var pedal := 0.0

func _ready() -> void:
	# Nivel 1: 5 puestos anchos, sin gente y el rival tarda 9.5 s. Al subir: más puestos y más
	# angostos, peatones cruzando y un rival más rápido.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(8, 5 + int(level / 2.0))
	ancho = minf(170.0, 960.0 / n)
	medio = ancho / 2.0 - 24.0
	rival_time = maxf(5.5, 9.5 - 0.65 * level) / apuro
	timer_bar.max_value = rival_time
	timer_bar.value = rival_time

	var x0 := 576.0 - n * ancho / 2.0 + ancho / 2.0
	var f := randi() % n
	libre_x = x0 + f * ancho
	for i in range(n + 1):       # líneas pintadas y barras entre puestos
		var lx := x0 - ancho / 2.0 + i * ancho
		var linea := ColorRect.new()
		linea.color = Color(0.91, 0.89, 0.75)
		linea.position = Vector2(lx - 2, 124)
		linea.size = Vector2(4, 148)
		rack.add_child(linea)
		var barra := Sprite2D.new()
		barra.texture = TEX_BARRA
		barra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		barra.scale = Vector2(4, 4)
		barra.position = Vector2(lx, 150)
		rack.add_child(barra)
	for i in range(n):
		if i == f:
			var zona := ColorRect.new()
			zona.color = Color(0.3, 1.0, 0.5, 0.28)
			zona.position = Vector2(libre_x - ancho / 2.0 + 4, 124)
			zona.size = Vector2(ancho - 8, 148)
			rack.add_child(zona)
			continue
		var b := Sprite2D.new()
		b.texture = TEX_BICIS.pick_random()
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.scale = Vector2(4, 4)
		b.position = Vector2(x0 + i * ancho + randf_range(-6, 6), RACK_Y + randf_range(-6, 6))
		b.rotation = randf_range(-0.08, 0.08)
		rack.add_child(b)
	libre.position = Vector2(libre_x - 80, 78)
	var bounce := create_tween().set_loops()
	bounce.tween_property(libre, "position:y", 70.0, 0.35)
	bounce.tween_property(libre, "position:y", 78.0, 0.35)

	# El jugador parte abajo, lejos del puesto libre; el rival llega desde el lado más lejano
	var sx := randf_range(140.0, 1010.0)
	while absf(sx - libre_x) < 260.0:
		sx = randf_range(140.0, 1010.0)
	jugador.position = Vector2(sx, 580)
	rival_start_x = -80.0 if libre_x > 576.0 else 1232.0
	rival.position = Vector2(rival_start_x, CALLE_Y)

	var n_peatones := 0 if level < 1.0 else (1 if level < 4.0 else 2)
	for i in range(n_peatones):
		var p := Sprite2D.new()
		p.texture = TEX_PEATONES[i % 2]
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.scale = Vector2(4, 4)
		p.position = Vector2(randf_range(200, 950), 420.0 + i * 90.0)
		peatones_nodo.add_child(p)
		peatones.append({"nodo": p, "vel": (110.0 + 15.0 * level) * apuro * (1 if randf() < 0.5 else -1)})
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, rival_time - elapsed)
	aturdido = maxf(0.0, aturdido - delta)
	inmune = maxf(0.0, inmune - delta)
	jugador.modulate.a = 0.5 if inmune > 0.0 and int(elapsed * 14.0) % 2 == 0 else 1.0

	_move_rival()
	_move_pedestrians(delta)
	if aturdido <= 0.0:
		_move_player(delta)
	if not playing:
		return
	if elapsed >= rival_time:
		_finish(false)

func _move_player(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var pos := jugador.position + dir * SPEED * delta
	pos.x = clampf(pos.x, 100.0, 1052.0)
	pos.y = minf(pos.y, 604.0)
	jugador.rotation = lerp_angle(jugador.rotation, dir.angle() + PI / 2.0, 0.3)
	pedal += delta
	jugador.texture = TEX_JUGADOR[int(pedal / 0.12) % 2]

	if pos.y < ENTRADA_Y:
		# Dentro del bicicletero solo cabe en el puesto libre
		var dentro: bool = jugador.position.y < ENTRADA_Y
		if not dentro and absf(pos.x - libre_x) > medio:
			_crash(Vector2(pos.x, ENTRADA_Y + 40.0), "¡Ese puesto está ocupado!")
			return
		pos.x = clampf(pos.x, libre_x - medio, libre_x + medio)
		if pos.y <= ESTACIONADO_Y:
			jugador.position = pos
			_finish(true)
			return
	jugador.position = pos

	for p in peatones:
		if inmune <= 0.0 and jugador.position.distance_to(p["nodo"].position) < 46.0:
			_crash(jugador.position + (jugador.position - p["nodo"].position).normalized() * 60.0, "¡Cuidado!")
			return

func _crash(rebote: Vector2, texto: String) -> void:
	Sonido.play("golpe", -2.0, 1.3)
	choques += 1
	aturdido = ATURDIDO
	inmune = 0.9
	rebote.x = clampf(rebote.x, 100.0, 1052.0)
	rebote.y = clampf(rebote.y, ENTRADA_Y + 10.0, 604.0)
	create_tween().tween_property(jugador, "position", rebote, 0.15)
	golpe.text = texto
	golpe.position = jugador.position + Vector2(-100, -90)
	golpe.show()
	golpe.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(golpe, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tw.tween_callback(golpe.hide)

# El rival va por el carril hasta quedar frente al puesto y luego entra; llega justo al acabarse el tiempo
func _move_rival() -> void:
	var p := clampf(elapsed / rival_time, 0.0, 1.0)
	if p < 0.8:
		rival.position = Vector2(lerpf(rival_start_x, libre_x, p / 0.8), CALLE_Y)
		rival.rotation = PI / 2.0 if libre_x > rival_start_x else -PI / 2.0
	else:
		rival.position = Vector2(libre_x, lerpf(CALLE_Y, RACK_Y, (p - 0.8) / 0.2))
		rival.rotation = 0.0
	rival.texture = TEX_RIVAL[int(elapsed / 0.12) % 2]

func _move_pedestrians(delta: float) -> void:
	for p in peatones:
		var nodo: Sprite2D = p["nodo"]
		nodo.position.x += p["vel"] * delta
		if nodo.position.x < 130.0 or nodo.position.x > 1020.0:
			p["vel"] = -p["vel"]
			nodo.position.x = clampf(nodo.position.x, 130.0, 1020.0)
		nodo.flip_h = p["vel"] < 0
		nodo.offset.y = -1.0 if int(elapsed / 0.18) % 2 == 0 else 0.0

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	libre.hide()
	jugador.modulate.a = 1.0
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Estacionado!"
		var tw := create_tween().set_parallel(true)
		tw.tween_property(jugador, "position", Vector2(libre_x, RACK_Y), 0.2)
		tw.tween_property(jugador, "rotation", 0.0, 0.2)
		# el rival frena y se queda mirando
		var base := rival.rotation
		var no := create_tween()
		for i in range(3):
			no.tween_property(rival, "rotation", base + 0.25, 0.1)
			no.tween_property(rival, "rotation", base - 0.25, 0.1)
		var used_ratio := clampf(elapsed / rival_time, 0.0, 1.0)
		var perf: float = clampf(core.time_performance(used_ratio) - 0.2 * choques, 0.1, 1.0)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(true, perf)
	else:
		fin.text = "¡Te ganaron el puesto!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		rival.position = Vector2(libre_x, RACK_Y)
		rival.rotation = 0.0
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
