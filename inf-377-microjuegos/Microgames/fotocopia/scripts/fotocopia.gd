extends Control
## Fotocopia a tiempo: la fotocopiadora va lanzando las hojas del apunte y hay que atraparlas
## con la carpeta (se mueve con el mouse) antes de que caigan al suelo. Si se pierden
## demasiadas, se pierde. El puntaje es la proporción de hojas atrapadas.

const A := "res://Microgames/fotocopia/assets/"
const TEX_HOJA := preload(A + "hoja.png")
const TEX_ARRUGADA := preload(A + "hoja_arrugada.png")
const SALIDA := Vector2(552, 300)      # ranura de la fotocopiadora
const GRAVEDAD := 620.0
const CARPETA_Y := 596.0
const ATRAPA_Y := 572.0                # altura a la que la carpeta atrapa
const MEDIO_CARPETA := 98.0            # medio ancho de la carpeta (con un poco de margen)
const PISO_Y := 628.0

@onready var fotocopiadora: Sprite2D = $Fotocopiadora
@onready var hojas_nodo: Node2D = $Hojas
@onready var piso: Node2D = $Piso
@onready var carpeta: Sprite2D = $Carpeta
@onready var mensaje: Label = $Mensaje
@onready var cuenta: Label = $Cuenta
@onready var fin: Label = $Fin

var playing := false
var total := 6                # hojas que saca la fotocopiadora
var lanzadas := 0
var atrapadas := 0
var perdidas := 0
var max_perdidas := 3         # al perder esta cantidad de hojas, se pierde el juego
var intervalo := 0.9
var dispersion := 200.0       # velocidad horizontal máxima de las hojas
var proxima := 0.5
var hojas: Array = []         # {nodo, vel, giro}
var mouse_x := 576.0

func _ready() -> void:
	# Nivel 1: 6 hojas con calma y poca dispersión. Al subir: más hojas, más seguidas y más abiertas.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	total = 6 + int(level)
	intervalo = maxf(0.55, 0.9 - 0.06 * level) / apuro
	dispersion = (200.0 + 30.0 * level) * apuro
	max_perdidas = 2 + int(total / 6.0)
	_update_count()
	playing = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_x = event.position.x

func _update_count() -> void:
	cuenta.text = "Hojas: %d / %d\nPerdidas: %d / %d" % [atrapadas, total, perdidas, max_perdidas]

func _process(delta: float) -> void:
	carpeta.position.x = lerpf(carpeta.position.x, clampf(mouse_x, 90.0, 1062.0), clampf(delta * 25.0, 0.0, 1.0))
	if not playing:
		return
	proxima -= delta
	if proxima <= 0.0 and lanzadas < total:
		proxima = intervalo
		_launch()
	for h in hojas.duplicate():
		var nodo: Sprite2D = h["nodo"]
		var antes := nodo.position.y
		h["vel"].y += GRAVEDAD * delta
		nodo.position += h["vel"] * delta
		nodo.position.x = clampf(nodo.position.x, 40.0, 1112.0)
		nodo.rotation += h["giro"] * delta
		# la carpeta atrapa la hoja cuando viene cayendo y pasa por su altura
		if h["vel"].y > 0.0 and antes < ATRAPA_Y and nodo.position.y >= ATRAPA_Y and absf(nodo.position.x - carpeta.position.x) <= MEDIO_CARPETA:
			_caught(h)
		elif nodo.position.y >= PISO_Y:
			_missed(h)
	if not playing:
		return
	if lanzadas >= total and hojas.is_empty():
		_finish(true)

func _launch() -> void:
	lanzadas += 1
	var s := Sprite2D.new()
	s.texture = TEX_HOJA
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(2, 2)
	s.position = SALIDA
	hojas_nodo.add_child(s)
	hojas.append({"nodo": s, "vel": Vector2(randf_range(-dispersion, dispersion), randf_range(-440.0, -380.0)), "giro": randf_range(-3.0, 3.0)})
	# la fotocopiadora da un saltito al sacar cada hoja
	var tw := create_tween()
	tw.tween_property(fotocopiadora, "position:y", 312.0, 0.05)
	tw.tween_property(fotocopiadora, "position:y", 318.0, 0.08)

func _caught(h: Dictionary) -> void:
	hojas.erase(h)
	atrapadas += 1
	Sonido.play("papel")
	_update_count()
	var nodo: Sprite2D = h["nodo"]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nodo, "position", Vector2(carpeta.position.x, CARPETA_Y - 6.0), 0.1)
	tw.tween_property(nodo, "scale", Vector2(0.6, 0.6), 0.1)
	tw.chain().tween_callback(nodo.queue_free)
	var pop := create_tween()
	pop.tween_property(carpeta, "scale", Vector2(4.5, 4.5), 0.06)
	pop.tween_property(carpeta, "scale", Vector2(4, 4), 0.08)

func _missed(h: Dictionary) -> void:
	hojas.erase(h)
	perdidas += 1
	Sonido.play("error", -6.0)
	_update_count()
	var nodo: Sprite2D = h["nodo"]
	nodo.reparent(piso)
	nodo.texture = TEX_ARRUGADA
	nodo.scale = Vector2(4, 4)
	nodo.rotation = 0.0
	nodo.position.y = PISO_Y
	if perdidas >= max_perdidas:
		_finish(false)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Apunte completo!" if perdidas == 0 else "¡Apunte listo!"
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, float(atrapadas) / total)
	else:
		fin.text = "¡Se te cayó el apunte!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
