extends Control
## El proyector: el notebook no da imagen y hay varios cables enredados entre la mesa y el
## panel de entradas. Hay que seguir con la vista el cable que sale del notebook (amarillo) y
## hacer clic en la entrada del panel donde termina. Un clic equivocado resta tiempo.

const PENALIZACION := 1.2
const ORIGEN_X := 252.0              # borde derecho del notebook
const DESTINO_X := 930.0             # entradas del panel
const COLORES := [Color("#2b2d31"), Color("#e63946"), Color("#3a7bd5"), Color("#2ecc71"), Color("#9b5de5"), Color("#f4f4f4"), Color("#ff8c1a")]

@onready var cables: Node2D = $Cables
@onready var puertos: Control = $Puertos
@onready var mensaje: Label = $Mensaje
@onready var sin_senal: Label = $SinSenal
@onready var pantalla: ColorRect = $Pantalla
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 8.0
var elapsed := 0.0
var correcto := 0                    # índice del puerto donde termina el cable del notebook
var botones: Array = []

func _ready() -> void:
	# Nivel 1: 3 cables, cada uno de un color y el del notebook amarillo entero. Al subir: hasta
	# 6 cables y más vueltas; desde el nivel 5 los cables son todos negros y solo la punta del
	# cable del notebook es amarilla: hay que seguirlo con la vista.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(6, 3 + int(level / 2.0))
	var vueltas := 1 if level < 3.0 else 2         # cuántas curvas hace cada cable
	var mismo_color := level >= 4.0
	time_limit = maxf(5.0, 8.0 - 0.35 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit

	# orígenes en la mesa (a la izquierda) y destinos en el panel (a la derecha), en orden al azar
	var ys_destino: Array = []
	for i in range(n):
		ys_destino.append(lerpf(110.0, 560.0, (i + 0.5) / n))
	var destinos: Array = range(n)
	destinos.shuffle()
	var cable_notebook := randi() % n
	var colores: Array = COLORES.duplicate()
	colores.shuffle()
	for i in range(n):
		var es_notebook := i == cable_notebook
		var color: Color = Color("#ffd23f") if es_notebook else (Color("#2b2d31") if mismo_color else colores[i % colores.size()])
		var cuerpo: Color = Color("#2b2d31") if mismo_color else color
		# los demás cables vienen desde abajo de la mesa (de otros equipos)
		var origen := Vector2(ORIGEN_X, 330.0) if es_notebook else Vector2(300.0 + 36.0 * i, 660.0)
		_make_cable(origen, Vector2(DESTINO_X, ys_destino[destinos[i]]), vueltas, color, cuerpo, es_notebook)
		if es_notebook:
			correcto = destinos[i]
	for j in range(n):
		botones.append(_make_port(j, ys_destino[j]))
	playing = true

# Un cable es una curva que zigzaguea entre el origen y el destino
func _make_cable(a: Vector2, b: Vector2, vueltas: int, punta: Color, cuerpo: Color, es_notebook: bool) -> void:
	var curva := Curve2D.new()
	curva.add_point(a, Vector2.ZERO, Vector2(80, 0) if es_notebook else Vector2(0, -120))
	var pasos := vueltas * 2
	# asas proporcionales al tramo: curvas suaves, sin rulos
	var asa := Vector2((b.x - 160.0 - a.x) / pasos * 0.45, 0.0)
	for k in range(1, pasos):
		var x := lerpf(a.x + 60.0, b.x - 160.0, float(k) / pasos)
		# se alejan de la recta hacia el destino, pero sin hacer nudos imposibles
		var y := clampf(lerpf(a.y, b.y, float(k) / pasos) + randf_range(-230.0, 230.0), 110.0, 600.0)
		curva.add_point(Vector2(x, y), -asa, asa)
	curva.add_point(b, Vector2(-100, 0), Vector2.ZERO)
	var pts := curva.tessellate(5, 3)
	var sombra := Line2D.new()
	sombra.points = pts
	sombra.width = 16.0
	sombra.default_color = Color(0, 0, 0, 0.85)
	sombra.joint_mode = Line2D.LINE_JOINT_ROUND
	cables.add_child(sombra)
	var linea := Line2D.new()
	linea.points = pts
	linea.width = 10.0
	linea.default_color = cuerpo
	linea.joint_mode = Line2D.LINE_JOINT_ROUND
	cables.add_child(linea)
	if es_notebook:
		# punta amarilla en el notebook (el resto del cable puede ser igual a los demás)
		var p := Line2D.new()
		var tramo: PackedVector2Array = []
		for q in pts:
			if q.x > a.x + 70.0:
				break
			tramo.append(q)
		p.points = tramo
		p.width = 10.0
		p.default_color = punta
		cables.add_child(p)
	# enchufe al final (en el panel)
	var enchufe := ColorRect.new()
	enchufe.color = Color(0.55, 0.57, 0.6)
	enchufe.size = Vector2(26, 22)
	enchufe.position = b - Vector2(26, 11)
	enchufe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puertos.add_child(enchufe)

func _make_port(j: int, y: float) -> Button:
	var b := Button.new()
	b.text = str(j + 1)
	b.position = Vector2(DESTINO_X + 8.0, y - 24.0)
	b.size = Vector2(150, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 26)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0.05, 0.05, 0.08))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.82, 0.25)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.05, 0.05, 0.08)
	sb.set_corner_radius_all(8)
	var hov := sb.duplicate(); hov.bg_color = Color(1.0, 0.92, 0.6)
	var dis := sb.duplicate(); dis.bg_color = Color(0.85, 0.5, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("disabled", dis)
	b.text = "HDMI %d" % (j + 1)
	b.pressed.connect(_on_port.bind(j, b))
	add_child(b)
	return b

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	sin_senal.modulate.a = 0.5 + 0.5 * sin(elapsed * 6.0)
	if elapsed >= time_limit:
		_finish(false)

func _on_port(j: int, b: Button) -> void:
	if not playing:
		return
	if j == correcto:
		_finish(true)
	else:
		b.disabled = true
		elapsed += PENALIZACION
		mensaje.text = "¡HDMI %d no es! Sigue el cable amarillo" % (j + 1)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	for b in botones:
		b.disabled = true
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Proyectando!"
		mensaje.text = "Ya se ve la presentación"
		sin_senal.text = "Proyectando..."
		sin_senal.modulate.a = 1.0
		# la presentación aparece sobre los cables
		pantalla.show()
		pantalla.modulate.a = 0.0
		var titulo := Label.new()
		titulo.text = "INF377 · Presentación final\n\nReMechón!"
		titulo.add_theme_font_size_override("font_size", 34)
		titulo.add_theme_color_override("font_color", Color(0.1, 0.25, 0.5))
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		titulo.size = pantalla.size
		pantalla.add_child(titulo)
		create_tween().tween_property(pantalla, "modulate:a", 1.0, 0.3)
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se acabó el tiempo de la presentación!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Era HDMI %d" % (correcto + 1)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
