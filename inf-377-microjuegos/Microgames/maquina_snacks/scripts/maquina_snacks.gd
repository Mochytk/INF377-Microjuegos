extends Control
## Máquina de snacks: el snack quedó atascado. Cada clic en la máquina es un golpe que lo
## suelta un poco, pero después de cada golpe la máquina queda tambaleándose: si se vuelve a
## golpear antes de que se calme (luz roja), suena una alarma. Con todas las alarmas, llega
## el guardia y se pierde.

const A := "res://Microgames/maquina_snacks/assets/"
const TEX_LUZ_OFF := preload(A + "luz_off.png")
const TEX_LUZ_ON := preload(A + "luz_on.png")

@onready var maquina: TextureRect = $Maquina
@onready var snack: TextureRect = $Maquina/Snack
@onready var alarma_box: HBoxContainer = $Alarma
@onready var listo: Label = $Listo
@onready var golpes_label: Label = $Golpes
@onready var rojo: ColorRect = $Rojo
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var necesarios := 5
var golpes := 0
var alarmas := 0
var max_alarmas := 3
var calma := 0.45           # segundos que la máquina tarda en calmarse tras un golpe
var tambaleo := 0.0         # tiempo restante de tambaleo
var time_limit := 6.0
var elapsed := 0.0
var luces: Array = []

func _ready() -> void:
	# Nivel 1: 5 golpes, la máquina se calma rápido y se toleran 2 errores. Al subir: más
	# golpes, se calma más lento, menos tiempo de sobra y desde el nivel 4 solo 1 error.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	necesarios = 5 + int(level / 1.5)
	calma = 0.45 + 0.03 * level
	max_alarmas = 3 if level < 3.0 else 2
	time_limit = (necesarios * (calma + 0.3) + 1.2) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	for i in range(max_alarmas):
		var l := TextureRect.new()
		l.texture = TEX_LUZ_OFF
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		l.custom_minimum_size = Vector2(48, 48)
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alarma_box.add_child(l)
		luces.append(l)
	maquina.gui_input.connect(_on_machine_input)
	_update_labels()
	playing = true

func _update_labels() -> void:
	golpes_label.text = "Golpes: %d / %d" % [golpes, necesarios]
	if tambaleo > 0.0:
		listo.text = "● Espera..."
		listo.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	else:
		listo.text = "● ¡Golpea!"
		listo.add_theme_color_override("font_color", Color(0.35, 1, 0.5))

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if tambaleo > 0.0:
		tambaleo = maxf(0.0, tambaleo - delta)
		maquina.rotation_degrees = sin(tambaleo * 40.0) * 4.0 * (tambaleo / calma)
		if tambaleo == 0.0:
			maquina.rotation_degrees = 0.0
	rojo.color.a = maxf(0.0, rojo.color.a - delta * 1.5)
	_update_labels()
	if elapsed >= time_limit:
		_finish(false, "tiempo")

func _on_machine_input(event: InputEvent) -> void:
	if not playing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if tambaleo > 0.0:
		# golpe demasiado seguido: alarma
		luces[alarmas].texture = TEX_LUZ_ON
		alarmas += 1
		rojo.color.a = 0.35
		mensaje.text = "¡Muy rápido! ¡Bip bip bip!"
		if alarmas >= max_alarmas:
			_finish(false, "alarma")
		return
	golpes += 1
	tambaleo = calma
	mensaje.text = "¡PAF!"
	# el snack se suelta de a poco: baja y se inclina
	var avance := float(golpes) / necesarios
	var tw := create_tween().set_parallel(true)
	tw.tween_property(snack, "rotation", deg_to_rad(28.0 * avance), 0.15)
	tw.tween_property(snack, "position:y", 132.0 + 22.0 * avance, 0.15)
	if golpes >= necesarios:
		_finish(true, "")

func _finish(won: bool, motivo: String) -> void:
	if not playing:
		return
	playing = false
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Snack liberado!"
		mensaje.text = "¡Por fin!"
		var cae := create_tween()
		cae.tween_property(snack, "position:y", 352.0, 0.35).set_ease(Tween.EASE_IN)
		cae.tween_property(snack, "rotation", deg_to_rad(90.0), 0.1)
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		var perf: float = clampf(core.time_performance(used_ratio) - 0.15 * alarmas, 0.1, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, perf)
		return
	fin.label_settings = fin.label_settings.duplicate()
	fin.label_settings.font_color = Color(1, 0.4, 0.35)
	if motivo == "alarma":
		fin.text = "¡Sonó la alarma! Llegó el guardia"
		for i in range(6):
			rojo.color.a = 0.5 if i % 2 == 0 else 0.0
			await get_tree().create_timer(0.12).timeout
	else:
		fin.text = "¡El snack sigue atascado!"
	await get_tree().create_timer(0.9).timeout
	core.end_microgame(false)
