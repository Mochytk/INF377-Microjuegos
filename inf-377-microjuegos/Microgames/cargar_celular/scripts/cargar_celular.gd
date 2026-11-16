extends Control
## Cargar el celular: queda 1 % de batería y hay un solo enchufe, al otro lado de la sala.
## Se toma el cargador con un clic y sigue al mouse: hay que llevarlo hasta el enchufe pasando
## entre las filas de pupitres. Si toca un pupitre, el cable se enreda y vuelve al inicio.

const A := "res://Microgames/cargar_celular/assets/"
const TEX_PUPITRE := preload(A + "pupitre.png")
const TEX_CARGANDO := preload(A + "celular_cargando.png")
const TEX_APAGADO := preload(A + "celular_apagado.png")
const INICIO := Vector2(150, 328)        # donde descansa el cargador, junto al celular
const CELULAR := Vector2(76, 328)
const ENCHUFE := Vector2(1090, 328)      # enchufe de la pared derecha
const PISO := Rect2(20, 96, 1060, 540)   # zona por donde puede moverse el cargador
const ANCHO_FILA := 112.0                # ancho de una fila de pupitres
const RADIO := 16.0                      # tamaño del cargador para los choques

@onready var pupitres: Control = $Pupitres
@onready var cable: Line2D = $Cable
@onready var celular: Sprite2D = $Celular
@onready var enchufe: Sprite2D = $Enchufe
@onready var bateria: Label = $Bateria
@onready var aqui: Label = $Aqui
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var agarrado := false
var mouse := Vector2.ZERO
var obstaculos: Array = []       # Rect2 de cada fila de pupitres
var pasos: Array = []            # centro del paso libre de cada fila (para pruebas y ayudas)
var rastro: Array = []           # puntos por donde pasó el cable
var tropiezos := 0
var time_limit := 9.5
var elapsed := 0.0
var volviendo := false

func _ready() -> void:
	# Nivel 1: 2 filas de pupitres con pasos anchos. Al subir: hasta 4 filas, pasos más angostos y menos tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	var filas := mini(4, 2 + int(level / 2.0))
	var paso := maxf(100.0, 170.0 - 12.0 * level)
	time_limit = maxf(7.0, 9.5 - 0.4 * level)
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	var arriba := randf() < 0.5       # la primera fila deja el paso arriba o abajo; luego se alternan
	for i in range(filas):
		var cx := lerpf(300.0, 900.0, float(i) / maxf(1.0, filas - 1.0)) if filas > 1 else 600.0
		var r: Rect2
		if arriba:
			r = Rect2(cx - ANCHO_FILA / 2.0, PISO.position.y + paso, ANCHO_FILA, PISO.size.y - paso + 12.0)
			pasos.append(Vector2(cx, PISO.position.y + paso / 2.0))
		else:
			r = Rect2(cx - ANCHO_FILA / 2.0, PISO.position.y, ANCHO_FILA, PISO.size.y - paso)
			pasos.append(Vector2(cx, PISO.end.y - paso / 2.0))
		obstaculos.append(r)
		# fila de pupitres dibujada con el sprite repetido
		var t := TextureRect.new()
		t.texture = TEX_PUPITRE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.stretch_mode = TextureRect.STRETCH_TILE
		t.scale = Vector2(4, 4)
		t.position = r.position
		t.size = r.size / 4.0
		t.clip_contents = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pupitres.add_child(t)
		arriba = not arriba
	var bounce := create_tween().set_loops()
	bounce.tween_property(aqui, "position:y", 242.0, 0.35)
	bounce.tween_property(aqui, "position:y", 250.0, 0.35)
	_reset_cable()
	playing = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		# un clic cerca del cargador lo toma; desde ahí sigue al mouse sin mantener apretado
		if playing and not agarrado and not volviendo and mouse.distance_to(enchufe.position) < 70.0:
			agarrado = true
			mensaje.text = "¡Llévalo al enchufe sin tocar los pupitres!"

func _blocked(p: Vector2) -> bool:
	for r in obstaculos:
		if r.grow(RADIO).has_point(p):
			return true
	return false

func _reset_cable() -> void:
	rastro = [CELULAR + Vector2(20, 0)]
	_draw_cable()

func _draw_cable() -> void:
	cable.clear_points()
	for p in rastro:
		cable.add_point(p)
	cable.add_point(enchufe.position)

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	bateria.visible = int(elapsed * 3.0) % 2 == 0
	if agarrado:
		# avanza hacia el mouse revisando el camino de a poco, para no atravesar pupitres
		var destino := Vector2(clampf(mouse.x, PISO.position.x, PISO.end.x + 20.0), clampf(mouse.y, PISO.position.y, PISO.end.y))
		var desde := enchufe.position
		var tramo := destino - desde
		var n := maxi(1, int(tramo.length() / 8.0))
		for i in range(1, n + 1):
			var p := desde + tramo * (float(i) / n)
			if _blocked(p):
				_tangle()
				return
			enchufe.position = p
			if rastro.is_empty() or p.distance_to(rastro[-1]) > 18.0:
				rastro.append(p)
		_draw_cable()
		if enchufe.position.distance_to(ENCHUFE) < 46.0:
			_finish(true)
			return
	if elapsed >= time_limit:
		_finish(false)

# El cable tocó un pupitre: se suelta y vuelve al inicio
func _tangle() -> void:
	tropiezos += 1
	agarrado = false
	volviendo = true
	mensaje.text = "¡Se enredó el cable! Haz clic en el cargador de nuevo"
	enchufe.modulate = Color(1, 0.5, 0.5)
	rastro = [CELULAR + Vector2(20, 0)]
	var tw := create_tween()
	tw.tween_method(func(p: Vector2):
		enchufe.position = p
		_draw_cable(), enchufe.position, INICIO, 0.3)
	tw.tween_callback(func():
		enchufe.modulate = Color.WHITE
		volviendo = false)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	agarrado = false
	aqui.hide()
	bateria.show()
	var core = get_parent()
	fin.show()
	if won:
		enchufe.position = ENCHUFE - Vector2(24, 0)
		_draw_cable()
		celular.texture = TEX_CARGANDO
		bateria.text = "Cargando"
		bateria.label_settings = bateria.label_settings.duplicate()
		bateria.label_settings.font_color = Color(0.35, 1, 0.5)
		fin.text = "¡Celular cargando!"
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		var perf: float = clampf(core.time_performance(used_ratio) - 0.15 * tropiezos, 0.1, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, perf)
	else:
		celular.texture = TEX_APAGADO
		bateria.text = "0%"
		fin.text = "¡Se apagó el celular!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
