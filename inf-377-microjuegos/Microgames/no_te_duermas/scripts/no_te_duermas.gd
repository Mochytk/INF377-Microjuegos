extends Control
## No te duermas en clase: los párpados se cierran solos y hay que apretar ESPACIO para
## mantenerlos abiertos hasta que termine la clase. El profesor se da vuelta cada cierto
## rato: si te ve con los ojos casi cerrados, te pilla. Si se cierran del todo, te dormiste.

const A := "res://Microgames/no_te_duermas/assets/"
const TEX_ESPALDA := [preload(A + "profe_espalda_0.png"), preload(A + "profe_espalda_1.png")]
const TEX_FRENTE := [preload(A + "profe_frente_0.png"), preload(A + "profe_frente_1.png")]

const DURACION := 8.0        # segundos que dura la clase
const ABRIR := 0.15          # cuánto se abren los ojos con cada ESPACIO
const UMBRAL := 0.4          # apertura mínima para que el profe no te pille (línea roja del medidor)
const BIEN_ABIERTOS := 0.6   # sobre esto cuenta como "atento" para el puntaje
const MIRADA := 1.0          # segundos que el profe mira a la clase
const GRACIA := 0.2          # margen al inicio de la mirada

@onready var profe: Sprite2D = $Profe
@onready var alerta: Label = $Alerta
@onready var sueno: ColorRect = $Sueno
@onready var parpado_arriba: ColorRect = $ParpadoArriba
@onready var parpado_abajo: ColorRect = $ParpadoAbajo
@onready var zzz: Label = $Zzz
@onready var mensaje: Label = $Mensaje
@onready var medidor: ProgressBar = $Medidor
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var t := 0.0
var apertura := 0.8          # 1 = ojos abiertos, 0 = cerrados
var cierre := 0.3            # velocidad a la que se cierran (por segundo)
var aviso := 0.7             # segundos de "!" antes de que el profe se dé vuelta
var miradas: Array = []      # momentos en que el profe se da vuelta
var estado := "escribe"      # escribe / aviso / mira
var estado_t := 0.0
var tiempo_atento := 0.0

func _ready() -> void:
	# Nivel 1: sueño suave y 2 miradas. Al subir, los ojos se cierran más rápido,
	# el aviso es más corto y el profe se da vuelta más veces (máx. 4).
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	cierre = (0.30 + 0.045 * level) * apuro
	aviso = maxf(0.45, 0.7 - 0.04 * level)
	var n := mini(4, 2 + int(level / 2.0))
	for i in range(n):
		miradas.append((i + 1) * DURACION / (n + 1) + randf_range(-0.35, 0.35) - 0.5)
	timer_bar.max_value = DURACION
	timer_bar.value = DURACION
	_update_eyes()
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	timer_bar.value = maxf(0.0, DURACION - t)

	# Los ojos se cierran solos (cada vez más rápido) y ESPACIO los abre
	apertura -= cierre * (1.0 + 0.3 * t / DURACION) * delta
	if Input.is_action_just_pressed("ui_accept"):
		apertura = minf(1.0, apertura + ABRIR)
	apertura = maxf(0.0, apertura)
	if apertura >= BIEN_ABIERTOS:
		tiempo_atento += delta
	_update_eyes()

	# Profesor: escribe -> aviso "!" -> mira a la clase -> vuelve a escribir
	estado_t += delta
	match estado:
		"escribe":
			profe.texture = TEX_ESPALDA[int(t / 0.25) % 2]
			if not miradas.is_empty() and t >= miradas[0] - aviso:
				miradas.pop_front()
				_set_estado("aviso")
		"aviso":
			profe.texture = TEX_ESPALDA[0]
			if estado_t >= aviso:
				_set_estado("mira")
		"mira":
			profe.texture = TEX_FRENTE[int(t / 0.2) % 2]
			if estado_t >= GRACIA and apertura < UMBRAL:
				_finish(false, "pillado")
				return
			if estado_t >= MIRADA:
				_set_estado("escribe")

	if apertura <= 0.0:
		_finish(false, "dormido")
	elif t >= DURACION:
		_finish(true, "")

func _set_estado(nuevo: String) -> void:
	estado = nuevo
	estado_t = 0.0
	alerta.visible = nuevo == "aviso"
	profe.flip_h = false
	if nuevo == "aviso":
		mensaje.text = "¡El profe se va a dar vuelta!"
	elif nuevo == "mira":
		mensaje.text = "¡Ojos abiertos!"
	else:
		mensaje.text = "¡No te duermas! Aprieta ESPACIO"

# Párpados: cada uno cubre hasta la mitad de la pantalla según qué tan cerrados estén los ojos
func _update_eyes() -> void:
	var cerrado := 1.0 - apertura
	var alto := size.y if size.y > 0.0 else 648.0
	parpado_arriba.size.y = alto * 0.5 * cerrado
	parpado_abajo.position.y = alto - alto * 0.5 * cerrado
	parpado_abajo.size.y = alto * 0.5 * cerrado
	sueno.color.a = clampf(cerrado * 0.6, 0.0, 0.6)
	medidor.value = apertura
	medidor.modulate = Color(0.35, 1, 0.5) if apertura >= UMBRAL else Color(1, 0.35, 0.3)
	zzz.visible = apertura < UMBRAL and playing

func _finish(won: bool, motivo: String) -> void:
	if not playing:
		return
	playing = false
	alerta.hide()
	zzz.hide()
	var core = get_parent()
	if won:
		mensaje.text = "¡Terminó la clase! Sobreviviste"
		profe.texture = TEX_FRENTE[0]
		var tw := create_tween()
		tw.tween_method(_set_apertura, apertura, 1.0, 0.3)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, clampf(tiempo_atento / DURACION, 0.25, 1.0))
		return
	if motivo == "pillado":
		mensaje.text = "¡El profe te pilló durmiendo!"
		profe.texture = TEX_FRENTE[1]
		alerta.text = "!!"
		alerta.show()
		var tw := create_tween()
		tw.tween_method(_set_apertura, apertura, 1.0, 0.15)   # despiertas de golpe
		tw.tween_property(profe, "scale", Vector2(4.6, 4.6), 0.2)
	else:
		mensaje.text = "¡Te quedaste dormido!"
		zzz.show()
		_set_apertura(0.0)
	await get_tree().create_timer(1.2).timeout
	core.end_microgame(false)

func _set_apertura(v: float) -> void:
	apertura = v
	var was := playing
	_update_eyes()
	zzz.visible = (not was) and v <= 0.0
