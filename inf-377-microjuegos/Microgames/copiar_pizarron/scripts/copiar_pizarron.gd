extends Control
## Copiar el pizarrón: el profesor escribe una palabra y la borra al poco rato. Hay que
## tipearla en el teclado antes de que la borre. Se puede perder una palabra; con dos, se pierde.

const A := "res://Microgames/copiar_pizarron/assets/"
const TEX_ESPALDA := [preload(A + "profe_espalda_0.png"), preload(A + "profe_espalda_1.png")]
const TEX_FRENTE := preload(A + "profe_frente_0.png")
# Sin tildes ni ñ, para que funcione igual en cualquier teclado
const CORTAS := ["RAMO", "NOTA", "SALA", "BECA", "QUIZ", "PASE", "LAB", "TAREA", "CLASE", "PROFE", "LIBRO", "MALLA", "SIGLA", "MICRO", "TESIS"]
const LARGAS := ["CAMPUS", "CASINO", "EXAMEN", "APUNTE", "PRUEBA", "CONTROL", "INFORME", "CREDITO", "CERTAMEN", "AYUDANTIA", "FOTOCOPIA", "BIBLIOTECA"]
const MAX_FALLOS := 2

@onready var palabra_label: RichTextLabel = $Palabra
@onready var borrador: ProgressBar = $Borrador
@onready var profe: Sprite2D = $Profe
@onready var copiado: RichTextLabel = $Cuaderno/VBox/Copiado
@onready var mensaje: Label = $Mensaje

var palabras: Array = []
var actual := 0              # índice de la palabra en curso
var letra := 0               # letras ya tipeadas de la palabra
var tiempo_palabra := 3.0
var restante := 3.0
var seg_por_letra := 0.55
var tiempo_base := 1.3       # segundos fijos por palabra (para leerla)
var aciertos := 0
var puntos := 0.0            # suma del puntaje de cada palabra (0 a 1)
var fallos := 0
var resultados: Array = []   # true/false por palabra
var playing := false
var esperando := false       # pausa corta entre palabras
var anim := 0.0

func _ready() -> void:
	# Nivel 1: 3 palabras cortas y con calma. Al subir: más palabras, más largas y menos tiempo.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(5, 3 + int(level / 2.0))
	seg_por_letra = maxf(0.3, 0.6 - 0.05 * level) / apuro
	tiempo_base = maxf(0.8, 1.3 - 0.08 * level) / apuro
	var cortas: Array = CORTAS.duplicate(); cortas.shuffle()
	var largas: Array = LARGAS.duplicate(); largas.shuffle()
	var n_largas := clampi(int(level), 0, n)      # nivel 1: ninguna larga
	for i in range(n):
		palabras.append(largas.pop_back() if i >= n - n_largas else cortas.pop_back())
	_start_word()
	playing = true

func _start_word() -> void:
	letra = 0
	tiempo_palabra = tiempo_base + seg_por_letra * palabras[actual].length()
	restante = tiempo_palabra
	esperando = false
	palabra_label.modulate.a = 1.0
	mensaje.text = "¡Copia lo que escribe el profe antes de que lo borre!  (%d/%d)" % [actual + 1, palabras.size()]
	_draw_word()

func _draw_word() -> void:
	var w: String = palabras[actual]
	palabra_label.text = "[center][color=#7CFF9B]%s[/color]%s[/center]" % [w.substr(0, letra), w.substr(letra)]

func _draw_notebook() -> void:
	# espacio no separable entre la marca y la palabra, para que no queden en líneas distintas
	var parts: Array = []
	for i in range(resultados.size()):
		if resultados[i]:
			parts.append("[color=#1f8f4a]✓\u00a0%s[/color]" % palabras[i])
		else:
			parts.append("[color=#c0392b]✗\u00a0%s...[/color]" % palabras[i].substr(0, 2))
	if playing and not esperando and actual < palabras.size():
		parts.append(palabras[actual].substr(0, letra) + "_")
	copiado.text = "   ".join(parts)

func _process(delta: float) -> void:
	if not playing:
		return
	anim += delta
	profe.texture = TEX_ESPALDA[int(anim / 0.25) % 2]
	if esperando:
		return
	restante -= delta
	borrador.value = clampf(restante / tiempo_palabra, 0.0, 1.0)
	borrador.modulate = Color(1, 0.45, 0.4) if restante < tiempo_palabra * 0.3 else Color.WHITE
	_draw_notebook()
	if restante <= 0.0:
		_word_done(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not playing or esperando or not event.pressed or event.echo:
		return
	var ch := ""
	if event.unicode > 0:
		ch = String.chr(event.unicode).to_upper()
	elif event.keycode >= KEY_A and event.keycode <= KEY_Z:
		ch = OS.get_keycode_string(event.keycode)
	if ch.length() != 1 or ch < "A" or ch > "Z":
		return
	get_viewport().set_input_as_handled()
	var w: String = palabras[actual]
	if ch == w[letra]:
		letra += 1
		Sonido.play("tecla", -2.0, randf_range(0.9, 1.2))
		_draw_word()
		if letra >= w.length():
			_word_done(true)
	else:
		# letra equivocada: la palabra tiembla, sin otra penalización
		var base := palabra_label.position.x
		var tw := create_tween()
		tw.tween_property(palabra_label, "position:x", base + 10.0, 0.04)
		tw.tween_property(palabra_label, "position:x", base - 10.0, 0.04)
		tw.tween_property(palabra_label, "position:x", base, 0.04)

func _word_done(ok: bool) -> void:
	esperando = true
	resultados.append(ok)
	if ok:
		aciertos += 1
		Sonido.play("acierto")
		# Palabra copiada con 40% o más del tiempo de sobra vale 1; justo al final vale 0.5
		puntos += lerpf(0.5, 1.0, clampf(restante / tiempo_palabra / 0.4, 0.0, 1.0))
	else:
		fallos += 1
		Sonido.play("borrador", 0.0, 0.8)
		mensaje.text = "¡El profe la borró!"
		create_tween().tween_property(palabra_label, "modulate:a", 0.0, 0.3)   # se borra
	_draw_notebook()
	await get_tree().create_timer(0.45 if ok else 0.7).timeout
	if not playing:
		return
	if fallos >= MAX_FALLOS:
		_finish(false)
		return
	actual += 1
	if actual >= palabras.size():
		_finish(true)
	else:
		_start_word()

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	profe.texture = TEX_FRENTE
	borrador.hide()
	_draw_notebook()
	palabra_label.modulate.a = 1.0
	if won:
		mensaje.text = "¡Copiaste %d de %d!" % [aciertos, palabras.size()]
		palabra_label.text = "[center][color=#7CFF9B]¡BIEN![/color][/center]"
	else:
		mensaje.text = "¡Te quedaste sin materia!"
		palabra_label.text = "[center][color=#ff8a80]...[/color][/center]"
	await get_tree().create_timer(1.0).timeout
	var core = get_parent()
	if won:
		core.end_microgame(true, puntos / palabras.size())
	else:
		core.end_microgame(false)
