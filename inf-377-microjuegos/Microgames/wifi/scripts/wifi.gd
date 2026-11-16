extends Control
## Wi-Fi de la U: recorrer el campus buscando señal. Las barras suben al acercarse al
## punto con Wi-Fi; hay que quedarse quieto donde haya señal para que cargue el Aula.
## Gana si la página carga antes de que se acabe el tiempo.

const A := "res://Microgames/wifi/assets/"
const TEX_EST := {
	"abajo": [preload(A + "est_abajo_0.png"), preload(A + "est_abajo_1.png")],
	"arriba": [preload(A + "est_arriba_0.png"), preload(A + "est_arriba_1.png")],
	"lado": [preload(A + "est_lado_0.png"), preload(A + "est_lado_1.png")],
}
const TEX_WIFI := [preload(A + "wifi_0.png"), preload(A + "wifi_1.png"), preload(A + "wifi_2.png"), preload(A + "wifi_3.png"), preload(A + "wifi_4.png")]

const SPEED := 300.0
const LOAD_TIME := 2.2                       # segundos para cargar con señal completa
const RATE := [0.0, 0.12, 0.3, 0.6, 1.0]     # velocidad de carga según las barras
const RING := [0.0, 3.4, 2.4, 1.6, 1.0]      # barras según distancia (en radios): <1 = 4 barras ... <3.4 = 1 barra

# Edificios y calle (no se puede caminar), en píxeles de pantalla
const OBSTACLES := [
	Rect2(240, 0, 668, 264),      # edificio principal
	Rect2(88, 0, 152, 138),       # ala poniente
	Rect2(928, 0, 224, 474),      # edificio oriente
	Rect2(784, 472, 368, 176),    # edificios sur-oriente
	Rect2(0, 0, 92, 648),         # avenida
]
# Lugares del campus donde puede estar el Wi-Fi
const SPOTS := [
	Vector2(160, 250), Vector2(160, 560), Vector2(336, 328), Vector2(640, 304),
	Vector2(856, 368), Vector2(480, 560), Vector2(704, 424), Vector2(400, 448),
]

@onready var jugador: Sprite2D = $Jugador
@onready var senal: Sprite2D = $Jugador/Senal
@onready var anillo: Sprite2D = $Anillo
@onready var mensaje: Label = $Mensaje
@onready var icono: TextureRect = $Telefono/Margen/Pantalla/VBox/Fila/Icono
@onready var porcentaje: Label = $Telefono/Margen/Pantalla/VBox/Fila/Porcentaje
@onready var carga: ProgressBar = $Telefono/Margen/Pantalla/VBox/Carga
@onready var estado: Label = $Telefono/Margen/Pantalla/VBox/Estado
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var hotspot := Vector2.ZERO
var radio := 120.0
var progreso := 0.0
var caidas: Array = []           # porcentajes de carga en los que el Wi-Fi se cae y cambia de lugar
var time_limit := 13.0
var elapsed := 0.0
var barras := 0
var moviendo := false
var walk_clock := 0.0
var mirando := "abajo"

func _ready() -> void:
	# Nivel 1: zona de señal grande y fija. Al subir, la zona se achica y el Wi-Fi se cae 1 o 2 veces.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	radio = maxf(85.0, 120.0 - 6.0 * level)
	if level >= 4.0:
		caidas = [0.35, 0.7]
	elif level >= 2.0:
		caidas = [0.5]
	time_limit = (13.0 + 3.5 * caidas.size() - 0.4 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	hotspot = _pick_spot(240.0)
	anillo.scale = Vector2.ONE * (radio * 2.0 / 48.0)
	playing = true

func _pick_spot(min_dist: float) -> Vector2:
	var options: Array = []
	for s in SPOTS:
		if s.distance_to(jugador.position) >= min_dist and s != hotspot:
			options.append(s)
	return options.pick_random() if not options.is_empty() else SPOTS.pick_random()

func _blocked(p: Vector2) -> bool:
	if p.x < 100.0 or p.x > 1144.0 or p.y < 24.0 or p.y > 644.0:
		return true
	for r in OBSTACLES:
		if r.grow(6.0).has_point(p):
			return true
	return false

func bars_at(p: Vector2) -> int:
	var dist := p.distance_to(hotspot) / radio
	for b in [4, 3, 2, 1]:
		if dist < RING[b]:
			return b
	return 0

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)

	# Movimiento con flechas o WASD; se revisa cada eje por separado para deslizarse por las paredes
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	moviendo = dir.length() > 0.1
	if moviendo:
		var step := dir.normalized() * SPEED * delta
		if not _blocked(jugador.position + Vector2(step.x, 0)):
			jugador.position.x += step.x
		if not _blocked(jugador.position + Vector2(0, step.y)):
			jugador.position.y += step.y
		if absf(dir.x) > absf(dir.y):
			mirando = "lado"
			jugador.flip_h = dir.x < 0
		else:
			mirando = "abajo" if dir.y > 0 else "arriba"
			jugador.flip_h = false
		walk_clock += delta
	jugador.texture = TEX_EST[mirando][int(walk_clock / 0.14) % 2 if moviendo else 0]

	# Señal y carga: solo carga estando quieto
	barras = bars_at(jugador.position)
	senal.texture = TEX_WIFI[barras]
	icono.texture = TEX_WIFI[barras]
	anillo.visible = barras == 4
	anillo.position = hotspot
	anillo.rotation += delta * 1.5
	if barras == 0:
		estado.text = "Sin señal..."
	elif moviendo:
		estado.text = "Señal débil: acércate más" if barras < 3 else "Buena señal: ¡quédate quieto!"
	else:
		estado.text = ("Cargando lento" if barras < 3 else "Cargando") + ".".repeat(1 + int(elapsed * 3.0) % 3)
		progreso = minf(1.0, progreso + RATE[barras] / LOAD_TIME * delta)
	carga.value = progreso
	porcentaje.text = "%d%%" % int(progreso * 100.0)

	if not caidas.is_empty() and progreso >= caidas[0]:
		caidas.pop_front()
		_wifi_down()
	if progreso >= 1.0:
		_finish(true)
	elif elapsed >= time_limit:
		_finish(false)

# El Wi-Fi se cae y aparece en otro lugar del campus
func _wifi_down() -> void:
	hotspot = _pick_spot(320.0)
	mensaje.text = "¡Se cayó el Wi-Fi! Busca señal de nuevo"
	mensaje.modulate = Color(1, 0.45, 0.4)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func():
		if playing:
			mensaje.text = "¡Busca señal y quédate quieto para cargar el Aula!"
			mensaje.modulate = Color.WHITE)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	anillo.hide()
	mensaje.modulate = Color.WHITE
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	if won:
		mensaje.text = "¡Página cargada!"
		estado.text = "✓ Listo"
		var tw := create_tween()
		tw.tween_property(jugador, "position:y", jugador.position.y - 20, 0.1)
		tw.tween_property(jugador, "position:y", jugador.position.y, 0.1)
	else:
		mensaje.text = "¡No alcanzó a cargar!"
		estado.text = "✗ Tiempo de espera agotado"
		senal.texture = TEX_WIFI[0]
		icono.texture = TEX_WIFI[0]
	await get_tree().create_timer(1.0).timeout
	var core = get_parent()
	if won:
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		core.end_microgame(false)
