extends Control
## Chat a escondidas: hay que escribir un mensaje en el celular durante la clase. Mientras se
## mantiene ESPACIO el celular sube y se escribe; al soltarlo se esconde bajo la mesa. El
## profesor avisa con un "!" y se da vuelta: si te ve con el celular arriba, te lo quita.

const A := "res://Microgames/chat_escondidas/assets/"
const TEX_ESPALDA := [preload(A + "profe_espalda_0.png"), preload(A + "profe_espalda_1.png")]
const TEX_FRENTE := [preload(A + "profe_frente_0.png"), preload(A + "profe_frente_1.png")]
const MENSAJES := [
	"¿alguien tiene los apuntes de ayer?",
	"guárdenme puesto en el casino",
	"¿salimos a comer completos después?",
	"el profe dijo que hay control el lunes",
	"¿alguien entendió algo de esta clase?",
	"voy a llegar tarde al lab, avísenle al ayudante",
	"¿quién se anota para el trabajo en grupo de Física?",
	"si alguien graba la clase me la pasa porfa",
]
const LETRAS_POR_SEG := 10.0
const MIRADA := 1.0        # segundos que el profe mira a la clase
const GRACIA := 0.15       # margen al darse vuelta para alcanzar a soltar
const Y_ARRIBA := 330.0    # celular a la vista
const Y_ABAJO := 560.0     # celular escondido bajo la mesa

@onready var profe: Sprite2D = $Profe
@onready var alerta: Label = $Alerta
@onready var celular: Control = $Celular
@onready var texto: Label = $Celular/Pantalla/Burbuja/Texto
@onready var mensaje_label: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var mensaje := ""
var escrito := 0.0
var t := 0.0
var time_limit := 9.0
var aviso := 0.8
var miradas: Array = []
var estado := "escribe"
var estado_t := 0.0
var escribiendo := false

func _ready() -> void:
	# Nivel 1: mensaje corto, aviso largo y 2 miradas. Al subir: mensajes más largos, aviso más
	# corto y hasta 4 miradas.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var opciones: Array = MENSAJES.duplicate()
	opciones.sort_custom(func(a, b): return a.length() < b.length())
	var desde := mini(int(level / 1.5), opciones.size() - 3)
	mensaje = opciones.slice(desde, desde + 3).pick_random()
	aviso = maxf(0.45, 0.8 - 0.05 * level) / apuro
	var n := mini(4, 2 + int(level / 2.0))
	var escribir := mensaje.length() / LETRAS_POR_SEG
	time_limit = (escribir + n * (aviso + MIRADA) + 3.0) / apuro
	for i in range(n):
		miradas.append((i + 1) * time_limit / (n + 1) + randf_range(-0.3, 0.3) - aviso)
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_update_text()
	celular.position.y = Y_ABAJO
	playing = true

func _update_text() -> void:
	var n := int(escrito)
	texto.text = mensaje.substr(0, n) + ("|" if int(t * 4.0) % 2 == 0 else " ")

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	timer_bar.value = maxf(0.0, time_limit - t)
	escribiendo = Input.is_action_pressed("ui_accept")
	# el celular sube mientras se escribe y baja al soltar
	var objetivo := Y_ARRIBA if escribiendo else Y_ABAJO
	celular.position.y = lerpf(celular.position.y, objetivo, clampf(delta * 18.0, 0.0, 1.0))
	if escribiendo:
		escrito = minf(mensaje.length(), escrito + LETRAS_POR_SEG * delta)
	_update_text()

	estado_t += delta
	match estado:
		"escribe":
			profe.texture = TEX_ESPALDA[int(t / 0.25) % 2]
			if not miradas.is_empty() and t >= miradas[0]:
				miradas.pop_front()
				_set_estado("aviso")
		"aviso":
			profe.texture = TEX_ESPALDA[0]
			if estado_t >= aviso:
				_set_estado("mira")
		"mira":
			profe.texture = TEX_FRENTE[int(t / 0.2) % 2]
			if estado_t >= GRACIA and escribiendo:
				_finish(false, "pillado")
				return
			if estado_t >= MIRADA:
				_set_estado("escribe")

	if escrito >= mensaje.length():
		_finish(true, "")
	elif t >= time_limit:
		_finish(false, "tiempo")

func _set_estado(nuevo: String) -> void:
	estado = nuevo
	estado_t = 0.0
	alerta.visible = nuevo == "aviso"
	if nuevo == "aviso":
		mensaje_label.text = "¡El profe se va a dar vuelta! Suelta ESPACIO"
	elif nuevo == "mira":
		mensaje_label.text = "Disimula..."
	else:
		mensaje_label.text = "Mantén ESPACIO para escribir. ¡Suéltalo si el profe mira!"

func _finish(won: bool, motivo: String) -> void:
	if not playing:
		return
	playing = false
	alerta.hide()
	var core = get_parent()
	fin.show()
	if won:
		texto.text = mensaje + "  ✓✓"
		fin.text = "¡Mensaje enviado!"
		celular.position.y = Y_ARRIBA
		var used_ratio := clampf(t / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
		return
	fin.label_settings = fin.label_settings.duplicate()
	fin.label_settings.font_color = Color(1, 0.4, 0.35)
	if motivo == "pillado":
		fin.text = "¡El profe te quitó el celular!"
		alerta.text = "!!"
		alerta.show()
		profe.texture = TEX_FRENTE[1]
		# el celular sale volando hacia el profe
		var tw := create_tween().set_parallel(true)
		tw.tween_property(celular, "position", Vector2(300, 120), 0.45).set_ease(Tween.EASE_IN)
		tw.tween_property(celular, "scale", Vector2(0.2, 0.2), 0.45)
	else:
		fin.text = "¡No alcanzaste a enviarlo!"
	await get_tree().create_timer(1.2).timeout
	core.end_microgame(false)
