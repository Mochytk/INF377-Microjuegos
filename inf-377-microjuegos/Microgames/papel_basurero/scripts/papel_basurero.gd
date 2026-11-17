extends Control
## Papel al basurero: arrastras hacia atrás (como una honda) y sueltas para lanzar una bola de
## papel al basurero. El viento que entra por la ventana desvía el tiro: las cortinas y el
## letrero muestran hacia dónde sopla. Hay que encestar antes de que termine el tiempo.

const GRAVEDAD := 1500.0
const FUERZA := 6.0             # velocidad por pixel arrastrado
const VEL_MAX := 1250.0
const EMPUJE_VIENTO := 420.0    # aceleración horizontal con viento 1.0
const RADIO := 20.0
const SALIDA := Vector2(228, 424)
const PISO := 600.0
const ANCHO_BASURERO := 128.0
const BOCA := Vector2(14, 114)  # parte abierta del basurero (relativa a su borde izquierdo)

@onready var bola: TextureRect = $Bola
@onready var basurero: TextureRect = $Basurero
@onready var cortinas: Array = [$CortinaIzq, $CortinaDer]
@onready var viento_label: Label = $Viento
@onready var flecha: Line2D = $Flecha
@onready var trayectoria: Node2D = $Trayectoria
@onready var mensaje: Label = $Mensaje
@onready var contador: Label = $Contador
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 8.0
var elapsed := 0.0
var level := 0.0
var necesarios := 1
var encestes := 0
var lanzamientos := 0
var viento := 0.0
var viento_max := 0.0
var listo := false              # hay una bola esperando en el pupitre
var apuntando := false
var volando := false
var inicio_arrastre := Vector2.ZERO
var mouse := Vector2.ZERO
var pos := SALIDA
var vel := Vector2.ZERO
var borde_x := 760.0            # borde izquierdo del basurero
var borde_y := 476.0            # altura de la boca
var preview := 0.9              # segundos de trayectoria que se dibujan
var preview_con_viento := true
var anim := 0.0

func _ready() -> void:
	# Nivel 1: sin viento, basurero cerca, 1 enceste y trayectoria completa. Al subir: viento más
	# fuerte, basurero más lejos, 2 encestes y menos ayuda en la trayectoria.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	level = clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	necesarios = 1 if level < 2.0 else 2
	viento_max = 0.0 if level < 1.0 else minf(0.85, 0.3 + 0.1 * level)
	borde_x = 700.0 + 35.0 * level + randf_range(-30.0, 30.0)
	basurero.position.x = borde_x
	borde_y = basurero.position.y + 12.0
	preview = 0.9 if level < 2.0 else (0.45 if level < 4.0 else 0.25)
	preview_con_viento = level < 2.0
	# tiempo para apuntar con calma y fallar un par de veces
	time_limit = (7.0 + 3.5 * (necesarios - 1) + 0.2 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_actualizar_contador()
	playing = true
	_nueva_bola()

func _actualizar_contador() -> void:
	contador.text = "Encestes: %d / %d" % [encestes, necesarios]

func _nueva_bola() -> void:
	pos = SALIDA
	vel = Vector2.ZERO
	bola.position = pos - bola.size / 2.0
	bola.scale = Vector2.ONE
	bola.rotation = 0.0
	bola.modulate.a = 1.0
	volando = false
	listo = true
	# el viento cambia en cada lanzamiento
	viento = randf_range(-viento_max, viento_max)
	if viento_max > 0.0 and absf(viento) < viento_max * 0.35:
		viento = viento_max * 0.35 * (1.0 if randf() < 0.5 else -1.0)
	if viento_max == 0.0 or absf(viento) < 0.05:
		viento_label.text = "Sin viento"
	else:
		var flechas := "→" if absf(viento) < 0.45 else ("→→" if absf(viento) < 0.8 else "→→→")
		if viento < 0.0:
			flechas = flechas.replace("→", "←")
		viento_label.text = "Viento %s" % flechas

func _process(delta: float) -> void:
	anim += delta
	# las cortinas se inclinan hacia donde sopla el viento y flamean
	for i in range(cortinas.size()):
		cortinas[i].rotation = -viento * 0.35 + sin(anim * (5.0 + 3.0 * absf(viento)) + i) * 0.04 * (0.3 + absf(viento))
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if volando:
		_volar(delta)
	if elapsed >= time_limit:
		_finish(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		if apuntando:
			_dibujar_mira()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		if event.pressed and playing and listo:
			apuntando = true
			inicio_arrastre = mouse
			_dibujar_mira()
		elif not event.pressed and apuntando:
			apuntando = false
			_limpiar_mira()
			var v := _velocidad_lanzamiento()
			if v.length() > 150.0 and playing:
				_lanzar(v)

# Como una honda: la bola sale en sentido contrario al arrastre
func _velocidad_lanzamiento() -> Vector2:
	var v := (inicio_arrastre - mouse) * FUERZA
	return v.limit_length(VEL_MAX)

func _dibujar_mira() -> void:
	var v := _velocidad_lanzamiento()
	flecha.points = PackedVector2Array([SALIDA, SALIDA + v * 0.12])
	for c in trayectoria.get_children():
		c.queue_free()
	var p := SALIDA
	var vv := v
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < preview:
		vv.y += GRAVEDAD * dt
		if preview_con_viento:
			vv.x += viento * EMPUJE_VIENTO * dt
		p += vv * dt
		t += dt
		var punto := ColorRect.new()
		punto.size = Vector2(8, 8)
		punto.position = p - Vector2(4, 4)
		punto.color = Color(1, 1, 1, 0.9 - 0.6 * t / preview)
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trayectoria.add_child(punto)

func _limpiar_mira() -> void:
	flecha.points = PackedVector2Array()
	for c in trayectoria.get_children():
		c.queue_free()

func _lanzar(v: Vector2) -> void:
	listo = false
	volando = true
	lanzamientos += 1
	vel = v
	pos = SALIDA

func _volar(delta: float) -> void:
	# pasos chicos para que la bola no atraviese el borde del basurero
	var pasos := 4
	var dt := delta / pasos
	for _k in range(pasos):
		var antes := pos
		vel.y += GRAVEDAD * dt
		vel.x += viento * EMPUJE_VIENTO * dt
		pos += vel * dt
		var izq := borde_x
		var der := borde_x + ANCHO_BASURERO
		# cruza la altura de la boca bajando
		if antes.y < borde_y and pos.y >= borde_y and vel.y > 0.0:
			if pos.x >= izq + BOCA.x + RADIO * 0.4 and pos.x <= izq + BOCA.y - RADIO * 0.4:
				_adentro()
				return
			elif pos.x > izq - RADIO and pos.x < der + RADIO:
				# pega en el borde y rebota hacia afuera
				var lado := -1.0 if pos.x < izq + ANCHO_BASURERO / 2.0 else 1.0
				vel = Vector2(lado * maxf(120.0, absf(vel.x) * 0.5), -absf(vel.y) * 0.4)
				pos.y = borde_y - 1.0
				mensaje.text = "¡Pegó en el borde!"
		# choca con el costado del basurero
		if pos.y > borde_y and pos.x > izq - RADIO and pos.x < der + RADIO and not (antes.x > izq - RADIO and antes.x < der + RADIO):
			vel.x = -vel.x * 0.4
			pos.x = antes.x
		if pos.y >= PISO - RADIO or pos.x < -60.0 or pos.x > 1220.0:
			_afuera()
			return
	bola.position = pos - bola.size / 2.0
	bola.rotation += vel.x * delta * 0.01

func _adentro() -> void:
	volando = false
	encestes += 1
	_actualizar_contador()
	mensaje.text = "¡Adentro!"
	var t := create_tween()
	var centro := Vector2(borde_x + ANCHO_BASURERO / 2.0, borde_y + 30.0)
	t.tween_property(bola, "position", centro - bola.size / 2.0, 0.12)
	t.parallel().tween_property(bola, "scale", Vector2(0.6, 0.6), 0.12)
	t.tween_callback(func(): bola.modulate.a = 0.0)
	t.tween_property(basurero, "scale", Vector2(1.1, 0.9), 0.06)
	t.tween_property(basurero, "scale", Vector2.ONE, 0.1)
	await t.finished
	if encestes >= necesarios:
		_finish(true)
	elif playing:
		await get_tree().create_timer(0.15).timeout
		if playing:
			_nueva_bola()

func _afuera() -> void:
	volando = false
	mensaje.text = "¡Afuera! Prueba de nuevo"
	pos.y = minf(pos.y, PISO - RADIO)
	bola.position = pos - bola.size / 2.0
	var t := create_tween()
	t.tween_property(bola, "modulate:a", 0.0, 0.25)
	await t.finished
	if playing:
		_nueva_bola()

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	apuntando = false
	listo = false
	_limpiar_mira()
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Encestaste!" if necesarios == 1 else "¡%d de %d!" % [encestes, necesarios]
		mensaje.text = "¡Como un profesional!" if lanzamientos == necesarios else "Lo lograste en %d intentos" % lanzamientos
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se acabó el tiempo!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Encestaste %d de %d" % [encestes, necesarios]
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
