extends Control
## Bandeja: llevar la bandeja del almuerzo por el casino hasta la mesa sin botar el jugo.
## La bandeja se ladea sola (y más cuando chocas con alguien); con el mouse la enderezas.
## Si se inclina demasiado, el jugo se derrama. Gana si llega a la mesa con jugo.

const TEX_EST := [preload("res://Microgames/bandeja/assets/estudiante_bandeja_0.png"), preload("res://Microgames/bandeja/assets/estudiante_bandeja_1.png")]
const TEX_GOTA := preload("res://Microgames/bandeja/assets/gota.png")
const START_X := 80.0
const END_X := 900.0
const WALK_TIME := 6.0
const MAX_CORRECCION := 45.0     # grados que el jugador puede corregir con el mouse
const MOUSE_RANGO := 350.0       # píxeles de mouse para la corrección máxima
const DERRAME := 1.0 / 8.0       # jugo perdido por grado de exceso por segundo
# Personas del fondo con las que se choca (x en pantalla) y sus globos "¡Permiso!"
const PERSONAS_X := [368.0, 664.0]

@onready var estudiante: Sprite2D = $Estudiante
@onready var pivot: Node2D = $BandejaPivot
@onready var vaso: Sprite2D = $BandejaPivot/Bandeja/Vaso
@onready var jugo_sprite: Sprite2D = $BandejaPivot/Bandeja/Vaso/Jugo
@onready var medidor: ProgressBar = $Panel/Medidor
@onready var mensaje: Label = $Mensaje
@onready var permiso: PanelContainer = $Permiso
@onready var gotas: Node2D = $Gotas

var playing := false
var t := 0.0
var jugo := 1.0
var amplitud := 12.0
var zona_segura := 10.0
var fase1 := 0.0
var fase2 := 0.0
var choques: Array = []          # posiciones x donde hay un choque, se sacan al pasar
var empujon := 0.0               # grados extra de un choque (suavizado)
var empujon_obj := 0.0           # valor al que tiende el empujón; decae con el tiempo
var mouse_inicio := 0.0
var mouse_x := 0.0
var angulo := 0.0
var gota_clock := 0.0

func _ready() -> void:
	# Nivel 1: vaivén suave y 2 choques. Con la dificultad crece el vaivén y hay más choques.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	amplitud = 18.0 + 1.5 * level
	zona_segura = 9.0
	fase1 = randf() * TAU
	fase2 = randf() * TAU
	choques = PERSONAS_X.duplicate()
	for i in range(int(level / 2.0)):
		choques.append(randf_range(START_X + 150.0, END_X - 80.0))
	choques.sort()
	mouse_inicio = get_viewport().get_mouse_position().x
	mouse_x = mouse_inicio
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	var progreso := clampf(t / WALK_TIME, 0.0, 1.0)
	estudiante.position.x = lerpf(START_X, END_X, progreso)
	estudiante.texture = TEX_EST[int(t / 0.15) % 2]

	# Choques al pasar junto a alguien
	if not choques.is_empty() and estudiante.position.x >= choques[0]:
		_chocar(choques.pop_front())
	empujon_obj *= exp(-2.5 * delta)
	empujon = lerpf(empujon, empujon_obj, clampf(8.0 * delta, 0.0, 1.0))

	# Inclinación = vaivén propio + choques + corrección del jugador (mouse)
	var vaiven := amplitud * (0.65 * sin(0.9 * t + fase1) + 0.35 * sin(1.9 * t + fase2))
	var correccion := clampf((mouse_x - mouse_inicio) / MOUSE_RANGO, -1.0, 1.0) * MAX_CORRECCION
	angulo = vaiven + empujon + correccion
	pivot.rotation_degrees = angulo
	# El vaso se desliza un poco hacia el lado bajo y el jugo se mueve dentro
	vaso.position.x = 56.0 + clampf(angulo, -30.0, 30.0) * 0.12
	jugo_sprite.position = Vector2(clampf(angulo * 0.12, -3.0, 3.0), 0)

	var exceso := absf(angulo) - zona_segura
	if exceso > 0.0:
		jugo = maxf(0.0, jugo - exceso * DERRAME * delta)
		_soltar_gotas(delta, exceso)
	jugo_sprite.scale = Vector2.ONE * (0.35 + 0.65 * jugo)
	medidor.value = jugo
	pivot.modulate = Color(1, 0.8, 0.8) if exceso > 0.0 else Color.WHITE

	if jugo <= 0.0:
		_finish(false)
	elif progreso >= 1.0:
		_finish(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_x = event.position.x

func _chocar(x: float) -> void:
	empujon_obj += 14.0 * (1.0 if randf() < 0.5 else -1.0)
	permiso.position = Vector2(x - 60.0, 196.0)
	permiso.show()
	permiso.scale = Vector2(0.5, 0.5)
	permiso.pivot_offset = permiso.size / 2.0
	var tw := create_tween()
	tw.tween_property(permiso, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.6)
	tw.tween_callback(permiso.hide)

# Gotas de jugo que saltan por el borde del vaso hacia el lado que se inclina
func _soltar_gotas(delta: float, exceso: float) -> void:
	gota_clock += delta
	if gota_clock < maxf(0.03, 0.12 - exceso * 0.01):
		return
	gota_clock = 0.0
	var g := Sprite2D.new()
	g.texture = TEX_GOTA
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.scale = Vector2(3, 3)
	g.global_position = vaso.global_position
	gotas.add_child(g)
	var lado := signf(angulo)
	var destino := g.global_position + Vector2(lado * randf_range(40, 90), randf_range(60, 130))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(g, "global_position", destino, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(g.queue_free)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	pivot.modulate = Color.WHITE
	if won:
		mensaje.text = "¡Llegaste a la mesa!"
		var tw := create_tween()
		tw.tween_property(pivot, "rotation_degrees", 0.0, 0.3)
		tw.tween_property(estudiante, "position:y", estudiante.position.y - 16, 0.1)
		tw.tween_property(estudiante, "position:y", estudiante.position.y, 0.1)
		await tw.finished
	else:
		mensaje.text = "¡Se te cayó el jugo!"
		var lado := signf(angulo) if angulo != 0.0 else 1.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(pivot, "rotation_degrees", lado * 35.0, 0.3)
		tw.tween_property(vaso, "position", vaso.position + Vector2(lado * 60, 20), 0.4)
		tw.tween_property(vaso, "modulate:a", 0.0, 0.4)
		await tw.finished
	await get_tree().create_timer(0.8).timeout
	var core = get_parent()
	if won:
		core.end_microgame(true, jugo)
	else:
		core.end_microgame(false)
