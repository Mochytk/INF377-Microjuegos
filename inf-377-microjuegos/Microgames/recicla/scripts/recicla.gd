extends Control
## Recicla en el campus: los residuos caen sobre el punto limpio y hay que mandarlos al
## contenedor correcto antes de que toquen las tapas: ← papel (azul), ↓ plástico (amarillo),
## → orgánico (café). Equivocarse o dejar que caiga al suelo cuenta como error.

const A := "res://Microgames/recicla/assets/"
const PAPEL := 0
const PLASTICO := 1
const ORGANICO := 2
const RESIDUOS := [
	["hoja", "Hoja de cuaderno", PAPEL], ["diario", "Diario", PAPEL], ["caja", "Caja de cartón", PAPEL],
	["botella", "Botella", PLASTICO], ["vaso", "Vaso plástico", PLASTICO], ["yogurt", "Envase de yogurt", PLASTICO],
	["platano", "Cáscara de plátano", ORGANICO], ["manzana", "Manzana mordida", ORGANICO], ["lechuga", "Hoja de lechuga", ORGANICO],
]
const Y_INICIO := 190.0
const Y_TAPA := 330.0        # cuando el residuo llega aquí, choca con la tapa
const CENTRO_X := 576.0

@onready var contenedores: Array = [$Contenedores/Papel, $Contenedores/Plastico, $Contenedores/Organico]
@onready var residuo: TextureRect = $Residuo
@onready var nombre_residuo: Label = $NombreResiduo
@onready var mensaje: Label = $Mensaje
@onready var contador: Label = $Contador
@onready var errores_label: Label = $Errores
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 12.0
var elapsed := 0.0
var cola: Array = []           # residuos que faltan, cada uno [archivo, nombre, tipo]
var actual: Array = []
var cayendo := false
var caida := 0.0               # 0..1 del recorrido del residuo actual
var tiempo_caida := 2.3
var total := 5
var hechos := 0
var errores := 0
var max_errores := 3
var texturas := {}
var suma_reaccion := 0.0       # suma de la parte de la caída que pasó antes de clasificar

func _ready() -> void:
	# Nivel 1: 4 residuos que caen lento y se aceptan 2 errores. Al subir: hasta 7 residuos, más
	# rápidos y desde el nivel 4 solo 1 error.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	total = 4 + int(level / 2.0)
	tiempo_caida = maxf(0.95, 2.3 - 0.22 * level) / apuro
	max_errores = 3 if level < 3.0 else 2
	# El ritmo lo marca la caída; el tiempo total es solo un tope de seguridad
	time_limit = total * (tiempo_caida + 0.5) + 1.5
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	for r in RESIDUOS:
		texturas[r[0]] = load(A + "res_%s.png" % r[0])
	# mezcla sin repetir el mismo residuo dos veces seguidas
	while cola.size() < total:
		var r: Array = RESIDUOS.pick_random()
		if cola.is_empty() or cola[-1][0] != r[0]:
			cola.append(r)
	_actualizar_textos()
	playing = true
	_siguiente()

func _actualizar_textos() -> void:
	contador.text = "Residuos: %d / %d" % [hechos, total]
	errores_label.text = "Errores: %d / %d" % [errores, max_errores]

func _siguiente() -> void:
	if not playing:
		return
	if cola.is_empty():
		_finish(true)
		return
	actual = cola.pop_front()
	residuo.texture = texturas[actual[0]]
	nombre_residuo.text = actual[1]
	residuo.rotation = 0.0
	residuo.scale = Vector2.ONE
	residuo.modulate.a = 1.0
	residuo.position = Vector2(CENTRO_X - 40.0, Y_INICIO)
	nombre_residuo.modulate.a = 1.0
	caida = 0.0
	cayendo = true

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if cayendo:
		caida += delta / tiempo_caida
		residuo.position.y = lerpf(Y_INICIO, Y_TAPA, caida)
		nombre_residuo.position.y = residuo.position.y + 24.0
		residuo.rotation = sin(caida * 9.0) * 0.15
		if caida >= 1.0:
			_al_suelo()
	if elapsed >= time_limit:
		_finish(false)

func _unhandled_input(event: InputEvent) -> void:
	if not playing or not cayendo:
		return
	var destino := -1
	if event.is_action_pressed("ui_left"):
		destino = PAPEL
	elif event.is_action_pressed("ui_down"):
		destino = PLASTICO
	elif event.is_action_pressed("ui_right"):
		destino = ORGANICO
	if destino < 0:
		return
	get_viewport().set_input_as_handled()
	_lanzar(destino)

# El residuo vuela en arco hasta el contenedor elegido y la tapa se abre
func _lanzar(destino: int) -> void:
	cayendo = false
	suma_reaccion += caida
	nombre_residuo.modulate.a = 0.0
	var bin: Control = contenedores[destino]
	var tapa: TextureRect = bin.get_node("Tapa")
	var bien: bool = destino == actual[2]
	var objetivo := bin.position + Vector2(56, -10)
	var t := create_tween()
	t.tween_property(tapa, "rotation", -1.2, 0.08)
	var desde := residuo.position
	t.tween_method(func(k: float):
		residuo.position = desde.lerp(objetivo, k) + Vector2(0, -90.0 * sin(k * PI))
		residuo.rotation = k * 4.0, 0.0, 1.0, 0.22)
	t.tween_property(residuo, "scale", Vector2(0.3, 0.3), 0.08)
	t.tween_callback(func(): residuo.modulate.a = 0.0)
	t.tween_property(tapa, "rotation", 0.0, 0.1)
	await t.finished
	if not playing:
		return
	if bien:
		hechos += 1
		var b := create_tween()
		b.tween_property(bin, "scale", Vector2(1.08, 0.92), 0.06)
		b.tween_property(bin, "scale", Vector2.ONE, 0.1)
	else:
		_error("¡%s no va en %s!" % [actual[1], bin.get_node("Nombre").text])
		var s := create_tween()
		bin.modulate = Color(1, 0.5, 0.5)
		for k in range(3):
			s.tween_property(bin, "position:x", bin.position.x + 8.0, 0.04)
			s.tween_property(bin, "position:x", bin.position.x - 8.0, 0.04)
		s.tween_property(bin, "position:x", bin.position.x, 0.04)
		s.tween_callback(func(): bin.modulate = Color.WHITE)
	_actualizar_textos()
	await get_tree().create_timer(0.12).timeout
	_siguiente()

# Nadie lo clasificó: rebota en la tapa del medio y queda en el suelo
func _al_suelo() -> void:
	cayendo = false
	nombre_residuo.modulate.a = 0.0
	_error("¡Quedó en el suelo!")
	_actualizar_textos()
	var t := create_tween()
	var lado := -1.0 if randf() < 0.5 else 1.0
	t.set_parallel()
	t.tween_property(residuo, "position", residuo.position + Vector2(lado * 360.0, 230.0), 0.4)
	t.tween_property(residuo, "rotation", lado * 3.0, 0.4)
	t.chain().tween_property(residuo, "modulate:a", 0.0, 0.15)
	await t.finished
	_siguiente()

func _error(texto: String) -> void:
	errores += 1
	mensaje.text = texto
	if errores >= max_errores:
		_finish(false)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	cayendo = false
	_actualizar_textos()
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Punto limpio impecable!"
		mensaje.text = "Separaste %d de %d" % [hechos, total]
		# Rendimiento: qué tan pronto se clasificó cada residuo (antes de un 30 % de la caída es
		# perfecto) y cuántos errores hubo
		var reaccion := suma_reaccion / maxf(1.0, hechos + errores)
		var perf := 1.0 - 0.75 * maxf(0.0, reaccion - 0.3) - 0.15 * errores
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, clampf(perf, 0.25, 1.0))
	else:
		fin.text = "¡Quedó todo revuelto!" if errores >= max_errores else "¡Se acabó el tiempo!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
