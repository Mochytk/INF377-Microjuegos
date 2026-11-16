extends Control
## Toma de ramos: se abre la inscripción y los cupos se acaban en segundos. Hay que encontrar
## el ramo que falta (sigla y nombre) y hacer clic en él antes de que sus cupos lleguen a 0.
## Los demás ramos son señuelos, algunos con siglas y nombres muy parecidos.

const FAMILIAS := [
	[["INF-377", "Diseño de Videojuegos"], ["INF-337", "Diseño de Software"], ["INF-373", "Diseño de Interfaces"], ["INF-277", "Diseño de Algoritmos"]],
	[["MAT-021", "Matemáticas I"], ["MAT-022", "Matemáticas II"], ["MAT-023", "Matemáticas III"], ["MAT-024", "Matemáticas IV"]],
	[["FIS-110", "Física General I"], ["FIS-120", "Física General II"], ["FIS-130", "Física General III"], ["FIS-140", "Física General IV"]],
	[["INF-134", "Estructuras de Datos"], ["INF-143", "Estructuras Discretas"], ["INF-314", "Estructuras de Compiladores"], ["INF-341", "Estructuras de Redes"]],
	[["INF-239", "Bases de Datos"], ["INF-293", "Bases de Señales"], ["INF-329", "Bases de la Computación"], ["INF-392", "Bases de la IA"]],
]
const PENALIZACION := 1.0     # segundos que se pierden al inscribir otro ramo
const CUPOS_INICIALES := 12

@onready var ramo_label: Label = $Ramo
@onready var grid: GridContainer = $Grid
@onready var aviso: Label = $Aviso
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 7.0
var elapsed := 0.0
var objetivo: Array = []          # [sigla, nombre]
var tarjetas: Array = []          # {panel, cupos_label, ramo, ritmo, es_objetivo}
var recarga_pendiente := false    # en niveles altos la página se "actualiza" y reordena los ramos

func _ready() -> void:
	# Nivel 1: 4 ramos distintos y 7.5 s. Al subir: hasta 8 ramos, más señuelos parecidos, menos
	# tiempo y, desde el nivel 4, la página se reordena una vez.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := 4 if level < 2.0 else (6 if level < 5.0 else 8)
	var parecidos := mini(3, int(level))
	time_limit = maxf(5.0, 7.5 - 0.4 * level) / apuro
	recarga_pendiente = level >= 3.0
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	grid.columns = 2 if n == 4 else (3 if n == 6 else 4)

	var familias: Array = FAMILIAS.duplicate(true)
	familias.shuffle()
	var propia: Array = familias.pop_front()
	propia.shuffle()
	objetivo = propia.pop_front()
	var ramos: Array = [objetivo]
	for i in range(parecidos):
		ramos.append(propia.pop_front())
	# el resto: de otras familias, de a uno por familia
	var k := 0
	while ramos.size() < n:
		var f: Array = familias[k % familias.size()]
		ramos.append(f[(k / familias.size()) % f.size()])
		k += 1
	ramos.shuffle()
	ramo_label.text = "%s · %s" % [objetivo[0], objetivo[1]]
	for r in ramos:
		tarjetas.append(_make_card(r))
	playing = true

func _make_card(ramo: Array) -> Dictionary:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1)))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var textos := [[ramo[0], 30, Color(0.1, 0.25, 0.5)], [ramo[1], 21, Color(0.15, 0.15, 0.2)], ["", 21, Color(0.1, 0.5, 0.25)]]
	var labels: Array = []
	for t in textos:
		var l := Label.new()
		l.text = t[0]
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_color", t[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		labels.append(l)
	var card := {"panel": p, "cupos": labels[2], "ramo": ramo, "es_objetivo": ramo == objetivo,
		"ritmo": randf_range(0.25, 0.7), "inicio": randi_range(8, 16)}
	p.gui_input.connect(_on_card_input.bind(card))
	p.mouse_entered.connect(func(): if playing: p.modulate = Color(0.9, 0.95, 1.0))
	p.mouse_exited.connect(func(): p.modulate = Color.WHITE)
	grid.add_child(p)
	return card

func _card_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(4)
	sb.border_color = Color(0.1, 0.25, 0.5)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	var restante := clampf(1.0 - elapsed / time_limit, 0.0, 1.0)
	for c in tarjetas:
		var cupos: int
		if c["es_objetivo"]:
			cupos = int(ceil(restante * CUPOS_INICIALES))      # llega a 0 justo al acabarse el tiempo
		else:
			cupos = maxi(1, int(c["inicio"] - elapsed * c["ritmo"] * 2.0))
		c["cupos"].text = "Cupos: %d" % cupos
		c["cupos"].add_theme_color_override("font_color", Color(0.8, 0.15, 0.15) if cupos <= 3 else Color(0.1, 0.5, 0.25))
	if recarga_pendiente and elapsed >= time_limit * 0.45:
		recarga_pendiente = false
		_reload_page()
	if elapsed >= time_limit:
		_finish(false, null)

# La página se "actualiza": los ramos cambian de lugar
func _reload_page() -> void:
	var orden: Array = grid.get_children()
	orden.shuffle()
	for i in range(orden.size()):
		grid.move_child(orden[i], i)
	aviso.text = "La página se actualizó..."
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func(): if playing: aviso.text = "")

func _on_card_input(event: InputEvent, card: Dictionary) -> void:
	if not playing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if card["es_objetivo"]:
		_finish(true, card)
		return
	elapsed += PENALIZACION
	aviso.text = "¡Ese no es tu ramo! (%s)" % card["ramo"][0]
	card["panel"].add_theme_stylebox_override("panel", _card_style(Color(1, 0.8, 0.8)))
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		card["panel"].add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1)))
		if playing: aviso.text = "")

func _finish(won: bool, card) -> void:
	if not playing:
		return
	playing = false
	var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
	var core = get_parent()
	if won:
		card["panel"].add_theme_stylebox_override("panel", _card_style(Color(0.75, 1.0, 0.8)))
		card["cupos"].text = "INSCRITO ✓"
		aviso.add_theme_color_override("font_color", Color(0.1, 0.5, 0.25))
		aviso.text = "¡Ramo inscrito!"
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		for c in tarjetas:
			if c["es_objetivo"]:
				c["cupos"].text = "SIN CUPOS"
				c["panel"].add_theme_stylebox_override("panel", _card_style(Color(0.85, 0.85, 0.88)))
		aviso.text = "¡Sin cupos! Quedaste en lista de espera"
		await get_tree().create_timer(1.1).timeout
		core.end_microgame(false)
