extends Control
## Calienta el almuerzo: el microondas va calentando el pote y una aguja avanza por la barra.
## Hay que apretar ESPACIO para sacarlo cuando la aguja está en la zona verde: antes queda
## frío y, si se llega al final, el pote explota. Mientras más al centro del verde, más puntaje.

const TEX_VAPOR := preload("res://Microgames/calienta_almuerzo/assets/vapor.png")
const ANCHO_BARRA := 800.0

@onready var calor: ColorRect = $Calor
@onready var pote: Sprite2D = $Pote
@onready var vapores: Node2D = $Vapores
@onready var explosion: Sprite2D = $Explosion
@onready var visor: Label = $Visor
@onready var frio: ColorRect = $Barra/Frio
@onready var perfecto: ColorRect = $Barra/Perfecto
@onready var quemado: ColorRect = $Barra/Quemado
@onready var aguja: ColorRect = $Barra/Aguja
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin

var playing := false
var t := 0.0
var duracion := 4.0          # segundos que tarda la aguja en recorrer la barra
var centro := 0.65           # centro de la zona verde (0 a 1)
var ancho := 0.22            # ancho de la zona verde (0 a 1)
var acelera := 1.0           # >1: la aguja parte lenta y termina rápida
var p := 0.0                 # posición de la aguja (0 a 1)
var vapor_clock := 0.0

func _ready() -> void:
	# Nivel 1: zona verde ancha y aguja lenta. Al subir: zona más angosta, aguja más rápida
	# y que acelera hacia el final.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	ancho = maxf(0.09, 0.22 - 0.02 * level)
	duracion = maxf(2.2, 4.0 - 0.3 * level) / apuro
	acelera = 1.0 + 0.1 * level
	centro = randf_range(0.5, 0.8)
	frio.size.x = (centro - ancho / 2.0) * ANCHO_BARRA
	perfecto.position.x = frio.size.x
	perfecto.size.x = ancho * ANCHO_BARRA
	quemado.position.x = perfecto.position.x + perfecto.size.x
	quemado.size.x = ANCHO_BARRA - quemado.position.x
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	p = pow(clampf(t / duracion, 0.0, 1.0), acelera)
	aguja.position.x = p * ANCHO_BARRA - 5.0
	visor.text = "0:%02d" % int(ceil((1.0 - p) * 30.0))
	# el pote se va calentando: brillo naranja, gira un poco y echa vapor
	calor.color.a = p * 0.55
	pote.position.x = 490.0 + sin(t * 3.0) * 26.0
	vapor_clock += delta
	if p > 0.35 and vapor_clock > lerpf(0.35, 0.08, p):
		vapor_clock = 0.0
		_steam()
	if Input.is_action_just_pressed("ui_accept"):
		_stop()
	elif p >= 1.0:
		_finish(false, "explota")

func _steam() -> void:
	var v := Sprite2D.new()
	v.texture = TEX_VAPOR
	v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.scale = Vector2(4, 4)
	v.position = pote.position + Vector2(randf_range(-40, 40), -40)
	vapores.add_child(v)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(v, "position:y", v.position.y - 70.0, 0.6)
	tw.tween_property(v, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(v.queue_free)

func _stop() -> void:
	var dist := absf(p - centro)
	if dist <= ancho / 2.0:
		_finish(true, "")
	elif p < centro:
		_finish(false, "frio")
	else:
		_finish(false, "quemado")

func _finish(won: bool, motivo: String) -> void:
	if not playing:
		return
	playing = false
	var core = get_parent()
	fin.show()
	if won:
		# en el centro de la zona verde vale 1; en el borde, 0.5
		var perf := lerpf(1.0, 0.5, clampf(absf(p - centro) / (ancho / 2.0), 0.0, 1.0))
		fin.text = "¡En su punto!" if perf > 0.8 else "¡Almuerzo caliente!"
		mensaje.text = "¡Listo!"
		calor.color.a = 0.0
		var tw := create_tween()
		tw.tween_property(pote, "scale", Vector2(5, 5), 0.12)
		tw.tween_property(pote, "scale", Vector2(4, 4), 0.12)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, perf)
		return
	fin.label_settings = fin.label_settings.duplicate()
	fin.label_settings.font_color = Color(1, 0.4, 0.35)
	if motivo == "frio":
		fin.text = "¡Quedó frío!"
		calor.color = Color(0.3, 0.6, 1.0, 0.35)
	elif motivo == "quemado":
		fin.text = "¡Se recalentó!"
		calor.color.a = 0.7
	else:
		fin.text = "¡Explotó el pote!"
		pote.hide()
		explosion.show()
		explosion.scale = Vector2(2, 2)
		create_tween().tween_property(explosion, "scale", Vector2(7, 7), 0.15)
	await get_tree().create_timer(1.1).timeout
	core.end_microgame(false)
