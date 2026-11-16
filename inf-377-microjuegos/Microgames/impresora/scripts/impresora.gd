extends Control
## Impresora de la biblioteca: la impresora falla (atasco y/o sin papel) y hay que seguir
## los pasos haciendo clic en sus partes para imprimir el informe antes de la entrega.

const TEX_TAPA_CERRADA := preload("res://Microgames/impresora/assets/tapa_cerrada.png")
const TEX_BANDEJA_CERRADA := preload("res://Microgames/impresora/assets/bandeja_cerrada.png")
const TEX_BANDEJA_ABIERTA := preload("res://Microgames/impresora/assets/bandeja_abierta.png")
const TEX_BANDEJA_PAPEL := preload("res://Microgames/impresora/assets/bandeja_abierta_papel.png")
const PENALIZACION := 0.6   # segundos que se pierden al hacer clic en la parte equivocada

const ATASCO := [["tapa", "Abre la tapa"], ["hoja", "Saca la hoja atascada"], ["tapa", "Cierra la tapa"]]
const SIN_PAPEL := [["bandeja", "Abre la bandeja de papel"], ["resma", "Pon papel en la bandeja"], ["bandeja", "Cierra la bandeja"]]
const IMPRIMIR := [["boton", "Presiona imprimir (botón verde)"]]

@onready var tapa: TextureRect = $Tapa
@onready var tapa_abierta: TextureRect = $TapaAbierta
@onready var hoja: TextureRect = $Hoja
@onready var bandeja: TextureRect = $Bandeja
@onready var boton: TextureRect = $Boton
@onready var resma: TextureRect = $Resma
@onready var pantalla: Label = $Pantalla
@onready var pasos_box: VBoxContainer = $Lista/VBox/Pasos
@onready var mensaje: Label = $Mensaje
@onready var error_label: Label = $Error
@onready var hoja_impresa: TextureRect = $Salida/HojaImpresa
@onready var timer_bar: ProgressBar = $ProgressBar

var pasos: Array = []
var paso := 0
var playing := false
var time_limit := 9.0
var elapsed := 0.0
var tapa_open := false
var bandeja_open := false
var papel := false

func _ready() -> void:
	# Nivel 1: un solo problema (4 pasos). Desde el nivel 3 (dificultad 3): atasco y sin papel (7 pasos).
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var problemas: Array = [ATASCO, SIN_PAPEL]
	problemas.shuffle()
	if level < 2.0:
		problemas = [problemas[0]]
	for p in problemas:
		pasos.append_array(p)
	pasos.append_array(IMPRIMIR)
	time_limit = maxf(pasos.size() * 1.6, pasos.size() * 2.3 - 0.3 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	hoja.visible = false
	papel = not problemas.has(SIN_PAPEL)
	pantalla.text = "ATASCO" if problemas[0] == ATASCO else "SIN PAPEL"
	for part in [tapa, tapa_abierta, hoja, bandeja, boton, resma]:
		part.gui_input.connect(_on_part_input.bind(part))
		part.mouse_entered.connect(func(): part.modulate = Color(1.2, 1.2, 1.2))
		part.mouse_exited.connect(func(): part.modulate = Color.WHITE)
	_build_list()
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if elapsed >= time_limit:
		_finish(false)

func _build_list() -> void:
	for c in pasos_box.get_children():
		c.queue_free()
	for i in range(pasos.size()):
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		if i < paso:
			l.text = "  ✓ " + pasos[i][1]
			l.add_theme_color_override("font_color", Color(0.45, 1, 0.55))
		elif i == paso:
			l.text = "▶ " + pasos[i][1]
			l.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		else:
			l.text = "  • " + pasos[i][1]
			l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		pasos_box.add_child(l)

func _part_name(part: TextureRect) -> String:
	if part == tapa or part == tapa_abierta: return "tapa"
	if part == hoja: return "hoja"
	if part == bandeja: return "bandeja"
	if part == boton: return "boton"
	return "resma"

func _on_part_input(event: InputEvent, part: TextureRect) -> void:
	if not playing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var nombre := _part_name(part)
	if nombre == pasos[paso][0]:
		_apply(nombre)
		paso += 1
		_build_list()
		if paso >= pasos.size():
			_finish(true)
	else:
		_wrong()

# Cambia la impresora según el paso realizado
func _apply(nombre: String) -> void:
	match nombre:
		"tapa":
			tapa_open = not tapa_open
			tapa.visible = not tapa_open
			tapa_abierta.visible = tapa_open
		"hoja":
			var tw := create_tween().set_parallel(true)
			tw.tween_property(hoja, "position:y", hoja.position.y - 60, 0.25)
			tw.tween_property(hoja, "modulate:a", 0.0, 0.25)
			tw.chain().tween_callback(hoja.hide)
			pantalla.text = "LISTO" if papel else "SIN PAPEL"
		"bandeja":
			bandeja_open = not bandeja_open
			if bandeja_open:
				bandeja.texture = TEX_BANDEJA_PAPEL if papel else TEX_BANDEJA_ABIERTA
				bandeja.position = Vector2(456, 400)
				bandeja.size = Vector2(240, 88)
			else:
				bandeja.texture = TEX_BANDEJA_CERRADA
				bandeja.position = Vector2(472, 400)
				bandeja.size = Vector2(208, 48)
				if papel and not hoja.visible:
					pantalla.text = "LISTO"
		"resma":
			papel = true
			bandeja.texture = TEX_BANDEJA_PAPEL
			var tw := create_tween()
			tw.tween_property(resma, "position:y", resma.position.y - 10, 0.08)
			tw.tween_property(resma, "position:y", resma.position.y, 0.08)
		"boton":
			pantalla.text = "IMPRIMIENDO"
	# Al abrir la tapa con atasco aparece la hoja arrugada
	if nombre == "tapa" and tapa_open and pasos[paso][0] == "tapa" and paso + 1 < pasos.size() and pasos[paso + 1][0] == "hoja":
		hoja.modulate.a = 1.0
		hoja.show()

func _wrong() -> void:
	elapsed += PENALIZACION
	error_label.show()
	error_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(error_label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(error_label.hide)
	var cuerpo: Control = $Cuerpo
	var base: float = cuerpo.position.x
	var sh := create_tween()
	for i in range(4):
		sh.tween_property(cuerpo, "position:x", base + (6.0 if i % 2 == 0 else -6.0), 0.04)
	sh.tween_property(cuerpo, "position:x", base, 0.04)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	if won:
		mensaje.text = "¡Informe impreso!"
		var tw := create_tween()
		tw.tween_property(hoja_impresa, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
		pantalla.text = "LISTO"
	else:
		mensaje.text = "¡Se acabó el plazo de entrega!"
		pantalla.text = "ERROR"
	await get_tree().create_timer(0.9).timeout
	var core = get_parent()
	if won:
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		core.end_microgame(false)
