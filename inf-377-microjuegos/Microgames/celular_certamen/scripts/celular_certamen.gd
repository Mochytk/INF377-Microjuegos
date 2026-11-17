extends Control
## ¿De quién es el celular?: en pleno certamen vibra un celular dentro de una mochila. Hay que
## encontrar la mochila que tiembla y hacer clic en ella antes de que el profe se dé cuenta.
## Clic en la mochila equivocada resta tiempo.

const A := "res://Microgames/celular_certamen/assets/"
const PENALIZACION := 1.0
const ESCALA := 4.0
const SALTO_COL := 52.0          # separación entre puestos en pixeles del fondo
const SALTO_FILA := 32.0
const FILA_Y := 60.0
const CENTRO_X := 124.0
# filas x columnas según la cantidad de puestos
const GRILLAS := {6: Vector2i(2, 3), 8: Vector2i(2, 4), 9: Vector2i(3, 3), 12: Vector2i(3, 4), 15: Vector2i(3, 5)}

@onready var puestos: Control = $Puestos
@onready var profe: TextureRect = $Profe
@onready var duda: Label = $Duda
@onready var celular: TextureRect = $Celular
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 7.0
var elapsed := 0.0
var mochilas: Array = []        # TextureRect de cada mochila
var bases: Array = []           # posición original de cada mochila
var lineas: Array = []          # rayitas de vibración de la mochila correcta
var correcta := 0
var amplitud := 7.0
var pulso_on := 999.0           # segundos vibrando
var pulso_off := 0.0            # segundos en silencio
var con_rayitas := true
var distractores := false
var proximo_distractor := 1.5

func _ready() -> void:
	# Nivel 1: 6 mochilas y vibra todo el rato con rayitas. Al subir: hasta 15 mochilas, vibra a
	# ratos y más suave, y otros estudiantes acomodan su mochila para despistar.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n: int = [6, 8, 9, 12, 12, 15, 15][int(level)]
	if level < 2.0:
		amplitud = 7.0
	elif level < 4.0:
		amplitud = 5.0; pulso_on = 0.7; pulso_off = 0.5
	else:
		amplitud = 4.0; pulso_on = 0.5; pulso_off = 0.7
	con_rayitas = level < 3.0
	distractores = level >= 2.0
	time_limit = maxf(4.5, 7.0 - 0.4 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_armar_sala(n)
	correcta = randi() % n
	if con_rayitas:
		for k in range(4):
			var l := ColorRect.new()
			l.color = Color(0.1, 0.1, 0.1)
			l.size = Vector2(6, 34 if k % 2 == 0 else 22)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			puestos.add_child(l)
			lineas.append(l)
	playing = true

func _armar_sala(n: int) -> void:
	var g: Vector2i = GRILLAS[n]
	for i in range(n):
		var fila := i / g.y
		var col := i % g.y
		var x := CENTRO_X + (col - (g.y - 1) / 2.0) * SALTO_COL
		var y := FILA_Y + fila * SALTO_FILA + (0.0 if g.x == 3 else SALTO_FILA / 2.0)
		var pupitre := TextureRect.new()
		pupitre.texture = load(A + "pupitre_%d.png" % ((i + fila) % 4))
		pupitre.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pupitre.position = Vector2(x, y) * ESCALA
		pupitre.size = Vector2(26, 24) * ESCALA
		pupitre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puestos.add_child(pupitre)
		var m := TextureRect.new()
		m.texture = load(A + "mochila_%d.png" % ((col * 2 + fila * 3) % 5))
		m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		m.position = Vector2(x - 17.0, y + 5.0) * ESCALA
		m.size = Vector2(16, 18) * ESCALA
		m.pivot_offset = m.size / 2.0
		m.mouse_filter = Control.MOUSE_FILTER_STOP
		m.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		m.gui_input.connect(_on_mochila.bind(i))
		puestos.add_child(m)
		mochilas.append(m)
		bases.append(m.position)

func _vibrando() -> bool:
	if pulso_off <= 0.0:
		return true
	return fmod(elapsed, pulso_on + pulso_off) < pulso_on

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	var ratio := elapsed / time_limit
	duda.text = "?" if ratio < 0.4 else ("??" if ratio < 0.75 else "?!")
	var m: TextureRect = mochilas[correcta]
	var vibra := _vibrando()
	if vibra:
		m.position = bases[correcta] + Vector2(sin(elapsed * 75.0) * amplitud, cos(elapsed * 57.0) * amplitud * 0.4)
		m.rotation = sin(elapsed * 63.0) * 0.06
	else:
		m.position = bases[correcta]
		m.rotation = 0.0
	for k in range(lineas.size()):
		var l: ColorRect = lineas[k]
		l.visible = vibra and fmod(elapsed, 0.2) < 0.13
		# dos rayitas a cada lado: la de adentro más larga
		var izq := k < 2
		var x := -14.0 - 12.0 * (k % 2) if izq else m.size.x + 8.0 + 12.0 * (k % 2)
		l.position = bases[correcta] + Vector2(x, 18.0 + 6.0 * (k % 2))
	if distractores:
		proximo_distractor -= delta
		if proximo_distractor <= 0.0:
			proximo_distractor = randf_range(0.7, 1.4)
			_acomodar_otra()
	if elapsed >= time_limit:
		_finish(false)

# Otro estudiante acomoda su mochila: se mueve una vez, lento, para despistar
func _acomodar_otra() -> void:
	var i := randi() % mochilas.size()
	if i == correcta or mochilas[i].modulate != Color.WHITE:
		return
	var m: TextureRect = mochilas[i]
	var t := create_tween()
	t.tween_property(m, "rotation", 0.25 * (1.0 if randf() < 0.5 else -1.0), 0.15)
	t.tween_property(m, "rotation", 0.0, 0.2)

func _on_mochila(event: InputEvent, i: int) -> void:
	if not playing or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if i == correcta:
		_finish(true)
		return
	var m: TextureRect = mochilas[i]
	if m.modulate != Color.WHITE:
		return
	m.modulate = Color(0.55, 0.55, 0.55)
	elapsed += PENALIZACION
	mensaje.text = "¡Esa no es! El profe se está dando cuenta..."

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	for l in lineas:
		l.hide()
	var m: TextureRect = mochilas[correcta]
	var core = get_parent()
	fin.show()
	if won:
		m.position = bases[correcta]
		m.rotation = 0.0
		fin.text = "¡Celular silenciado!"
		mensaje.text = "El profe no se dio cuenta"
		duda.text = ""
		# el celular sale de la mochila
		celular.show()
		celular.position = m.position + Vector2(8, -10)
		celular.scale = Vector2(0.3, 0.3)
		var t := create_tween().set_parallel()
		t.tween_property(celular, "position:y", m.position.y - 90.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(celular, "scale", Vector2.ONE, 0.25)
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡¿De quién es ese celular?!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Era la mochila que temblaba"
		duda.text = "!!"
		m.modulate = Color(1.0, 0.6, 0.6)
		# el profe camina hacia la mochila
		create_tween().tween_property(profe, "position", Vector2(clampf(m.position.x + 80.0, 0.0, 1040.0), maxf(0.0, m.position.y - 150.0)), 0.6)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
