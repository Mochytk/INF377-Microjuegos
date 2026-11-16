extends Control
## Paraguas en el patio: empieza a llover camino a clases. El estudiante camina solo y el
## viento va cambiando la inclinación de la lluvia. Con ← → se inclina el paraguas: hay que
## apuntarlo hacia donde viene la lluvia. Si se moja demasiado, pierde.

const A := "res://Microgames/paraguas/assets/"
const TEX_CAMINA := [preload(A + "estudiante_camina_1.png"), preload(A + "estudiante_quieto.png"), preload(A + "estudiante_camina_2.png"), preload(A + "estudiante_quieto.png")]
const TEX_GOTA := preload(A + "gota.png")
const START_X := 100.0
const END_X := 1010.0
const WALK_TIME := 7.0
const VEL_PARAGUAS := 1.9        # cuánto se inclina por segundo con la tecla apretada
const MOJA := 0.8                # qué tan rápido se moja por unidad de desajuste

@onready var estudiante: Sprite2D = $Estudiante
@onready var lluvia: Node2D = $Lluvia
@onready var sombrilla: Sprite2D = $Sombrilla
@onready var salpicaduras: Node2D = $Salpicaduras
@onready var mensaje: Label = $Mensaje
@onready var medidor: ProgressBar = $Medidor
@onready var fin: Label = $Fin

var playing := false
var t := 0.0
var inclinacion := 0.0           # -1 = paraguas hacia la izquierda, 1 = hacia la derecha
var viento := 0.0                # -1 = la lluvia cae hacia la izquierda, 1 = hacia la derecha
var mojado := 0.0
var tolerancia := 0.38
var amplitud := 0.85
var rapidez := 1.0
var fase1 := 0.0
var fase2 := 0.0
var gota_clock := 0.0
var lado := 1.0                 # lado desde el que sopla el viento casi todo el tiempo
var lado_actual := 1.0
var cambia_lado := false         # en niveles altos el viento cambia de lado a mitad de camino

func _ready() -> void:
	# Nivel 1: el viento cambia lento y hay harto margen. Al subir: cambia más rápido y más fuerte, con menos margen.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	tolerancia = maxf(0.28, 0.38 - 0.02 * level)
	amplitud = minf(1.0, 0.85 + 0.03 * level)
	rapidez = (1.0 + 0.09 * level) * apuro
	fase1 = randf() * TAU
	fase2 = randf() * TAU
	lado = 1.0 if randf() < 0.5 else -1.0
	lado_actual = lado
	cambia_lado = level >= 2.0
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	var progreso := clampf(t / WALK_TIME, 0.0, 1.0)
	estudiante.position.x = lerpf(START_X, END_X, progreso)
	estudiante.texture = TEX_CAMINA[int(t / 0.14) % 4]

	# Viento: sopla sobre todo desde un lado (así, sin mover el paraguas uno se moja) y encima
	# lleva una mezcla de dos ondas para que no sea predecible
	if cambia_lado and t >= WALK_TIME * 0.5:
		cambia_lado = false
		lado = -lado
	lado_actual = lerpf(lado_actual, lado, clampf(2.5 * delta, 0.0, 1.0))
	viento = clampf(lado_actual * 0.55 + amplitud * 0.5 * (0.7 * sin(0.9 * rapidez * t + fase1) + 0.45 * sin(2.1 * rapidez * t + fase2)), -1.0, 1.0)
	lluvia.dir = viento

	inclinacion = clampf(inclinacion + Input.get_axis("ui_left", "ui_right") * VEL_PARAGUAS * delta, -1.0, 1.0)
	sombrilla.position = estudiante.position + Vector2(18.0 + inclinacion * 26.0, -84.0)
	sombrilla.rotation = inclinacion * 0.6

	# El paraguas debe apuntar hacia donde viene la lluvia: si cae hacia la derecha, viene de la izquierda
	var desajuste := absf(inclinacion - (-viento))
	var exceso := desajuste - tolerancia
	if exceso > 0.0:
		mojado = minf(1.0, mojado + exceso * MOJA * delta)
		_splash(delta)
	medidor.value = mojado
	estudiante.modulate = Color(0.75, 0.85, 1.0) if exceso > 0.0 else Color.WHITE

	if mojado >= 1.0:
		_finish(false)
	elif progreso >= 1.0:
		_finish(true)

# Gotas que salpican sobre el estudiante cuando la lluvia le llega
func _splash(delta: float) -> void:
	gota_clock += delta
	if gota_clock < 0.07:
		return
	gota_clock = 0.0
	var g := Sprite2D.new()
	g.texture = TEX_GOTA
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.scale = Vector2(3, 3)
	g.position = estudiante.position + Vector2(randf_range(-30, 40), randf_range(-140, -40))
	salpicaduras.add_child(g)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(g, "position", g.position + Vector2(randf_range(-20, 20), 40), 0.3)
	tw.tween_property(g, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(g.queue_free)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	estudiante.texture = TEX_CAMINA[1]
	var core = get_parent()
	fin.show()
	if won:
		estudiante.modulate = Color.WHITE
		fin.text = "¡Llegaste seco!" if mojado < 0.15 else "¡Llegaste a clases!"
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, clampf(1.0 - mojado, 0.1, 1.0))
	else:
		estudiante.modulate = Color(0.6, 0.75, 1.0)
		fin.text = "¡Quedaste empapado!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
