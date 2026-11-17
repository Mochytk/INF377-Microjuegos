extends Control
## ¡Presente!: el profe pasa la lista en voz alta, por apellidos. Hay que apretar ESPACIO
## solo cuando diga tu nombre. Si respondes a otro nombre es un error; si dejas pasar el tuyo,
## quedas ausente.

const A := "res://Microgames/presente/assets/"
const TEX_PROFE := [preload(A + "profe_0.png"), preload(A + "profe_1.png")]
const MAX_ERRORES := 2
# apellidos del jugador y otros que suenan parecido
const PARECIDOS_1 := {"Rojas": ["Rozas", "Rosas", "Ojeda"], "Muñoz": ["Núñez", "Muñiz", "Ibáñez"], "Castro": ["Castillo", "Carrasco", "Cáceres"],
	"Pérez": ["Peña", "Paredes", "Pereira"], "Silva": ["Sierra", "Salvo", "Silvestre"], "Torres": ["Toro", "Tapia", "Torrejón"]}
const PARECIDOS_2 := {"Soto": ["Sotomayor", "Sotelo", "Toro"], "Fuentes": ["Puentes", "Fuenzalida", "Funes"], "Morales": ["Moraga", "Mora", "Morel"],
	"Vargas": ["Vergara", "Varas", "Varela"], "Reyes": ["Reinoso", "Ríos", "Rey"], "Díaz": ["Daza", "Díez", "Ruiz"]}
const OTROS := ["González", "Contreras", "Sepúlveda", "Rodríguez", "López", "Hernández", "Araya", "Flores", "Espinoza",
	"Valenzuela", "Gutiérrez", "Pizarro", "Álvarez", "Vásquez", "Sánchez", "Fernández", "Ramírez", "Gómez", "Cortés",
	"Herrera", "Jara", "Rivera", "Figueroa", "Navarro", "Bravo", "Cárdenas", "Riquelme", "Lagos", "Bustos", "Olivares"]

@onready var profe: TextureRect = $Profe
@onready var globo: Panel = $Globo
@onready var nombre_label: Label = $Globo/Nombre
@onready var tu_label: Label = $Tu
@onready var brazo: TextureRect = $Brazo
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 8.0
var elapsed := 0.0
var lista: Array = []          # nombres que va a decir el profe
var mio := ""
var pos_mia := 0
var actual := -1
var intervalo := 1.4
var desde_nombre := 0.0        # tiempo desde que dijo el nombre actual
var respondido := false        # ya se respondió al nombre actual
var errores := 0
var reaccion := 0.0

func _ready() -> void:
	# Nivel 1: 5 nombres muy distintos al tuyo, con calma. Al subir: lista más larga y rápida,
	# desde el nivel 3 nombres que comparten un apellido contigo y desde el nivel 5 apellidos
	# que suenan casi igual (Rojas / Rozas, Soto / Sotomayor).
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var largo := mini(10, 5 + int(level * 0.8))
	intervalo = maxf(0.95, 1.45 - 0.08 * level) / apuro
	var a1: String = PARECIDOS_1.keys().pick_random()
	var a2: String = PARECIDOS_2.keys().pick_random()
	mio = "%s %s" % [a1, a2]
	tu_label.text = "Tú eres: %s" % mio.to_upper()
	pos_mia = randi_range(2, largo - 1)
	while lista.size() < largo:
		if lista.size() == pos_mia:
			lista.append(mio)
			continue
		var otro := _señuelo(a1, a2, level)
		if otro != mio and not lista.has(otro):
			lista.append(otro)
	time_limit = largo * intervalo + 0.3
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	playing = true
	_siguiente_nombre()

func _señuelo(a1: String, a2: String, level: float) -> String:
	var r := randf()
	var x: String = OTROS.pick_random()
	var y: String = OTROS.pick_random()
	while y == x:
		y = OTROS.pick_random()
	if level >= 4.0 and r < 0.45:
		# suena casi igual: cambia uno de los dos apellidos por uno parecido
		return ("%s %s" % [PARECIDOS_1[a1].pick_random(), a2]) if randf() < 0.5 else ("%s %s" % [a1, PARECIDOS_2[a2].pick_random()])
	if level >= 2.0 and r < 0.75:
		# comparte un apellido contigo
		return ("%s %s" % [a1, y]) if randf() < 0.5 else ("%s %s" % [x, a2])
	return "%s %s" % [x, y]

func _siguiente_nombre() -> void:
	actual += 1
	if actual >= lista.size():
		return
	desde_nombre = 0.0
	respondido = false
	nombre_label.text = "¿%s?" % lista[actual]
	globo.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(globo, "scale", Vector2.ONE, 0.1)

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	desde_nombre += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	# el profe mueve la boca mientras dice el nombre
	profe.texture = TEX_PROFE[1 if desde_nombre < 0.4 and int(desde_nombre / 0.1) % 2 == 0 else 0]
	if desde_nombre >= intervalo:
		if actual == pos_mia and not respondido:
			_finish(false, "¡Te pusieron ausente!")
			return
		_siguiente_nombre()

func _unhandled_input(event: InputEvent) -> void:
	if not playing or not event.is_action_pressed("ui_accept") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_levantar_mano()
	if respondido:
		return
	respondido = true
	if actual == pos_mia:
		reaccion = desde_nombre
		_finish(true, "")
	else:
		errores += 1
		mensaje.text = "¡Ese no eres tú! Era %s" % lista[actual]
		if errores >= MAX_ERRORES:
			_finish(false, "¡El profe te retó por desordenado!")

func _levantar_mano() -> void:
	var t := create_tween()
	t.tween_property(brazo, "position:y", 430.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	t.tween_property(brazo, "position:y", 660.0, 0.15)

func _finish(won: bool, texto: String) -> void:
	if not playing:
		return
	playing = false
	profe.texture = TEX_PROFE[0]
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Presente!"
		mensaje.text = "El profe te marcó presente"
		# rendimiento: responder rápido a tu nombre y sin equivocarte
		var perf := 1.0 - 0.7 * maxf(0.0, reaccion - 0.35) / intervalo - 0.2 * errores
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, clampf(perf, 0.25, 1.0))
	else:
		fin.text = texto
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		if texto.begins_with("¡Te pusieron"):
			mensaje.text = "El profe dijo %s y no respondiste" % mio
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
