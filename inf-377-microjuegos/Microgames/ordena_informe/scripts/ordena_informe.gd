extends Control
## Ordena el informe: las hojas del informe quedaron repartidas por el escritorio. Hay que
## hacer clic en ellas en orden, de la 1 a la última, para ir juntándolas en la carpeta antes
## de la entrega. Clic en la hoja equivocada resta tiempo.

const A := "res://Microgames/ordena_informe/assets/"
const PENALIZACION := 0.7
const TAM_HOJA := Vector2(120, 160)
const CARPETA := Vector2(960, 470)

@onready var hojas_nodo: Control = $Hojas
@onready var carpeta: Label = $Carpeta
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 6.0
var elapsed := 0.0
var hojas: Array = []          # TextureRect por número de hoja (índice 0 = hoja 1)
var siguiente := 0
var errores := 0

func _ready() -> void:
	# Nivel 1: 5 hojas casi derechas con el número grande. Al subir: hasta 10 hojas, más
	# giradas, y desde el nivel 4 el número va chico en una esquina distinta en cada hoja.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(10, 5 + int(level * 0.85))
	var giro := 0.08 + 0.05 * level
	var numero_chico := level >= 3.0
	time_limit = (2.5 + n * 0.75) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_repartir(n, giro, numero_chico)
	_actualizar_carpeta()
	playing = true

# Las hojas quedan en una grilla con desorden, para que se pisen un poco pero se vean todas
func _repartir(n: int, giro: float, numero_chico: bool) -> void:
	var cols := 5 if n > 6 else 3
	var filas := ceili(float(n) / cols)
	var celdas: Array = []
	for f in range(filas):
		for c in range(cols):
			celdas.append(Vector2(c, f))
	celdas.shuffle()
	var ancho := 820.0 / cols
	var alto := 420.0 / filas
	var orden_z: Array = range(n)
	orden_z.shuffle()
	var tex := load(A + "hoja.png")
	hojas.resize(n)
	for k in orden_z:
		var celda: Vector2 = celdas[k]
		var h := TextureRect.new()
		h.texture = tex
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.size = TAM_HOJA
		h.pivot_offset = TAM_HOJA / 2.0
		var centro := Vector2(70.0 + ancho * (celda.x + 0.5), 110.0 + alto * (celda.y + 0.5))
		centro += Vector2(randf_range(-ancho * 0.18, ancho * 0.18), randf_range(-alto * 0.12, alto * 0.12))
		h.position = centro - TAM_HOJA / 2.0
		h.rotation = randf_range(-giro, giro)
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		h.gui_input.connect(_on_hoja.bind(k))
		var num := Label.new()
		num.text = str(k + 1)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.add_theme_color_override("font_color", Color(0.75, 0.12, 0.12))
		if numero_chico:
			num.add_theme_font_size_override("font_size", 30)
			var esquinas := [Vector2(8, 4), Vector2(78, 4), Vector2(8, 118), Vector2(78, 118)]
			num.position = esquinas.pick_random()
		else:
			num.add_theme_font_size_override("font_size", 56)
			num.position = Vector2(36, 60)
			num.size = Vector2(48, 70)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(num)
		hojas_nodo.add_child(h)
		hojas[k] = h

func _actualizar_carpeta() -> void:
	carpeta.text = "INFORME\n%d / %d" % [siguiente, hojas.size()]

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if elapsed >= time_limit:
		_finish(false)

func _on_hoja(event: InputEvent, k: int) -> void:
	if not playing or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var h: TextureRect = hojas[k]
	accept_event()
	if k == siguiente:
		siguiente += 1
		Sonido.play("papel")
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hojas_nodo.move_child(h, -1)
		var t := create_tween().set_parallel()
		t.tween_property(h, "position", CARPETA + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.2).set_trans(Tween.TRANS_QUAD)
		t.tween_property(h, "rotation", randf_range(-0.06, 0.06), 0.2)
		t.tween_property(h, "scale", Vector2(0.55, 0.55), 0.2)
		_actualizar_carpeta()
		if siguiente >= hojas.size():
			_finish(true)
	else:
		errores += 1
		Sonido.play("error")
		elapsed += PENALIZACION
		mensaje.text = "¡Esa es la %d! Busca la hoja %d" % [k + 1, siguiente + 1]
		var x := h.position.x
		var t := create_tween()
		h.modulate = Color(1, 0.7, 0.7)
		t.tween_property(h, "position:x", x + 10.0, 0.04)
		t.tween_property(h, "position:x", x - 10.0, 0.04)
		t.tween_property(h, "position:x", x, 0.04)
		t.tween_callback(func(): h.modulate = Color.WHITE)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	for h in hojas:
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Informe en orden!"
		mensaje.text = "Listo para entregar"
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se acabó el plazo de entrega!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Te faltaron %d hojas" % (hojas.size() - siguiente)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
