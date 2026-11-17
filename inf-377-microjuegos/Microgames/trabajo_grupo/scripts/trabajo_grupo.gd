extends Control
## Trabajo en grupo: en el chat del grupo van llegando mensajes. Algunos son tareas ("Yo hago
## la introducción") y hay que hacer clic en ellos para anotarlas; el resto son memes y
## mensajes que no aportan, y hay que ignorarlos. Gana al anotar todas las tareas pedidas.

const A := "res://Microgames/trabajo_grupo/assets/"
# Stickers de memes (para quitar uno, basta borrar su línea)
const MEMES := [
	preload(A + "meme_bonk.png"),
	preload(A + "meme_trollface.png"),
	preload(A + "meme_awesome.png"),
	preload(A + "meme_moai.png"),
	preload(A + "meme_doge.png"),
	preload(A + "meme_nyan.png"),
	preload(A + "meme_deal_with_it.png"),
	preload(A + "meme_poker_face.png"),
	preload(A + "meme_stonks.png"),
	preload(A + "meme_banana.png"),
]
const TAREAS := ["Yo hago la introducción", "Yo armo el PPT", "Yo escribo las conclusiones", "Yo hago los gráficos",
	"Yo reviso la ortografía", "Yo subo el informe", "Yo hago el marco teórico", "Yo imprimo el informe",
	"Yo edito el video", "Yo presento mañana", "Yo hago la bibliografía", "Yo junto todo en el Drive"]
const RELLENO := ["jajajaja", "¿sale carrete el viernes?", "¿alguien tiene los apuntes?", "me quedé dormido",
	"¿qué había que hacer?", "x2", "F", "¿para cuándo era?", "ya po, mañana lo vemos"]
const GENTE := [["Cami", Color("#c2185b")], ["Mati", Color("#1565c0")], ["Sofi", Color("#6a1b9a")], ["Benja", Color("#2e7d32")], ["Vale", Color("#d84315")], ["Nico", Color("#00838f")]]
const PENALIZACION := 0.8     # segundos que se pierden al hacer clic en algo que no es tarea
const MAX_MENSAJES := 7

@onready var chat: Panel = $Telefono/Chat
@onready var lista: VBoxContainer = $Telefono/Chat/Lista
@onready var cuenta: Label = $Cuenta
@onready var error_label: Label = $Error
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var meta := 3                 # tareas que hay que anotar
var anotadas := 0
var errores := 0
var intervalo := 0.8
var proximo := 0.2
var sin_tarea := 0            # mensajes seguidos que no fueron tarea
var time_limit := 7.5
var elapsed := 0.0
var mensajes: Array = []      # {nodo, es_tarea, hecho}
var tareas_restantes: Array = []

func _ready() -> void:
	# Nivel 1: 3 tareas y mensajes con calma. Al subir: más tareas (hasta 6) y mensajes más seguidos.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	meta = mini(6, 3 + int(level / 2.0))
	intervalo = maxf(0.55, 0.85 - 0.05 * level) / apuro
	time_limit = 2.5 + meta * intervalo * 2.3
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	tareas_restantes = TAREAS.duplicate()
	tareas_restantes.shuffle()
	_update_count()
	playing = true

func _update_count() -> void:
	cuenta.text = "Tareas\n%d / %d" % [anotadas, meta]

func _process(delta: float) -> void:
	# el chat queda pegado abajo, como en una app de mensajes
	var objetivo_y := chat.size.y - lista.size.y - 10.0
	lista.position.y = lerpf(lista.position.y, objetivo_y, clampf(delta * 14.0, 0.0, 1.0))
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	proximo -= delta
	if proximo <= 0.0:
		proximo = intervalo
		_new_message()
	if elapsed >= time_limit:
		_finish(false)

func _new_message() -> void:
	Sonido.play("pop", -10.0, 1.3)
	# al menos una tarea cada 3 mensajes, y nunca dos seguidas imposibles de distinguir
	var es_tarea := sin_tarea >= 2 or randf() < 0.5
	if tareas_restantes.is_empty():
		es_tarea = false
	sin_tarea = 0 if es_tarea else sin_tarea + 1
	var persona: Array = GENTE.pick_random()
	var burbuja := PanelContainer.new()
	burbuja.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	burbuja.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	burbuja.add_theme_stylebox_override("panel", _bubble_style(Color.WHITE))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	burbuja.add_child(vb)
	var nombre := Label.new()
	nombre.text = persona[0]
	nombre.add_theme_font_size_override("font_size", 17)
	nombre.add_theme_color_override("font_color", persona[1])
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nombre)
	if es_tarea or randf() < 0.4:
		var texto := Label.new()
		texto.text = tareas_restantes.pop_back() if es_tarea else RELLENO.pick_random()
		texto.add_theme_font_size_override("font_size", 23)
		texto.add_theme_color_override("font_color", Color(0.07, 0.07, 0.09))
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(texto)
	else:
		var sticker := TextureRect.new()
		sticker.texture = MEMES.pick_random()
		sticker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sticker.custom_minimum_size = Vector2(96, 96)
		sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sticker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(sticker)
	var m := {"nodo": burbuja, "es_tarea": es_tarea, "hecho": false}
	burbuja.gui_input.connect(_on_bubble_input.bind(m))
	burbuja.mouse_entered.connect(func(): if playing and not m["hecho"]: burbuja.modulate = Color(0.92, 0.96, 1.0))
	burbuja.mouse_exited.connect(func(): burbuja.modulate = Color.WHITE)
	lista.add_child(burbuja)
	mensajes.append(m)
	# los mensajes viejos salen del chat
	while mensajes.size() > MAX_MENSAJES:
		var viejo: Dictionary = mensajes.pop_front()
		viejo["nodo"].queue_free()

func _bubble_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.corner_radius_top_left = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	return sb

func _on_bubble_input(event: InputEvent, m: Dictionary) -> void:
	if not playing or m["hecho"]:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	m["hecho"] = true
	var burbuja: PanelContainer = m["nodo"]
	if m["es_tarea"]:
		anotadas += 1
		Sonido.play("acierto")
		burbuja.add_theme_stylebox_override("panel", _bubble_style(Color(0.82, 0.97, 0.78)))
		var ok := Label.new()
		ok.text = "✓ Anotado"
		ok.add_theme_font_size_override("font_size", 17)
		ok.add_theme_color_override("font_color", Color(0.1, 0.5, 0.2))
		burbuja.get_child(0).add_child(ok)
		_update_count()
		if anotadas >= meta:
			_finish(true)
	else:
		errores += 1
		Sonido.play("error")
		elapsed += PENALIZACION
		burbuja.add_theme_stylebox_override("panel", _bubble_style(Color(1.0, 0.8, 0.8)))
		error_label.show()
		error_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(error_label, "modulate:a", 0.0, 0.4).set_delay(0.5)
		tw.tween_callback(error_label.hide)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	var core = get_parent()
	if won:
		cuenta.text = "¡Trabajo\nrepartido!"
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		var perf: float = clampf(core.time_performance(used_ratio) - 0.15 * errores, 0.1, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, perf)
	else:
		cuenta.text = "¡Nadie hizo\nnada!"
		cuenta.label_settings = cuenta.label_settings.duplicate()
		cuenta.label_settings.font_color = Color(1, 0.4, 0.35)
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
