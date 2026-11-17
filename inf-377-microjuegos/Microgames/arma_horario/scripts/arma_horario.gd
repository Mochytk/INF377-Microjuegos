extends Control
## Arma el horario: cada ramo tiene sus días fijos (por ejemplo Lun y Mié) y hay que
## arrastrarlo a un bloque del horario donde no choque con otro ramo ni con lo que ya está
## ocupado. Soltarlo donde hay tope resta tiempo y el ramo vuelve a la lista. Los ramos ya
## puestos se pueden volver a tomar para moverlos.

const DIAS := ["Lun", "Mar", "Mié", "Jue", "Vie"]
const BLOQUES := ["1-2", "3-4", "5-6", "7-8"]
const GRILLA_X := 400.0
const GRILLA_Y := 140.0
const ANCHO_COL := 140.0
const ALTO_FILA := 104.0
const TARJETA := Vector2(280, 80)
const PENALIZACION := 1.0
const RAMOS := [["Cálculo", Color("#e63946")], ["Física", Color("#2f6fd6")], ["Programación", Color("#2e9e5b")],
	["Química", Color("#f2a03d")], ["Inglés", Color("#8e5bd6")], ["Ed. Física", Color("#e05a9a")]]
const OCUPADOS := ["Ayudantía", "Trabajo", "Almuerzo", "Taller", "Deporte"]
const PATRONES_2 := [[0, 2], [1, 3], [2, 4], [0, 3], [1, 4]]
const PATRONES_1 := [[0], [2], [4], [1], [3]]
const PATRONES_3 := [[0, 2, 4]]

@onready var grilla_nodo: Control = $Grilla
@onready var vista: Control = $Vista
@onready var tarjetas_nodo: Control = $Tarjetas
@onready var mensaje: Label = $Mensaje
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 10.0
var elapsed := 0.0
var ramos: Array = []          # {nombre, color, dias, solucion, fila (-1 si no está puesto), tarjeta, celdas}
var grilla: Array = []         # [fila][día] -> "" libre, "#" ocupado, o índice del ramo (int)
var arrastrando := -1
var agarre := Vector2.ZERO
var errores := 0

func _ready() -> void:
	# Nivel 1: 3 ramos y pocos bloques ocupados. Al subir: hasta 5 ramos, más bloques ocupados
	# y desde el nivel 4 aparecen ramos de tres días (Lun, Mié y Vie).
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var n := mini(5, 3 + int(level / 2.0))
	var ocupados := 2 + int(level)
	time_limit = (4.0 + 2.0 * n) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	_generar(n, ocupados, level >= 3.0)
	_dibujar_grilla()
	_crear_tarjetas()
	playing = true

# Primero se arma una solución válida y después se ocupan bloques que no la estorban,
# así siempre hay al menos una forma de armar el horario.
func _generar(n: int, ocupados: int, con_tres: bool) -> void:
	grilla.clear()
	for f in range(BLOQUES.size()):
		var fila: Array = []
		fila.resize(DIAS.size())
		fila.fill("")
		grilla.append(fila)
	var solucion := []
	for f in range(BLOQUES.size()):
		solucion.append([false, false, false, false, false])
	var nombres: Array = RAMOS.duplicate()
	nombres.shuffle()
	var i := 0
	var intentos := 0
	while ramos.size() < n and intentos < 500:
		intentos += 1
		var patrones: Array = PATRONES_2.duplicate()
		if randf() < 0.25:
			patrones = PATRONES_1.duplicate()
		elif con_tres and randf() < 0.35:
			patrones = PATRONES_3.duplicate()
		var dias: Array = patrones.pick_random()
		var fila := randi() % BLOQUES.size()
		var libre := true
		for dd in dias:
			if solucion[fila][dd]:
				libre = false
		if not libre:
			continue
		for dd in dias:
			solucion[fila][dd] = true
		ramos.append({"nombre": nombres[i][0], "color": nombres[i][1], "dias": dias, "solucion": fila, "fila": -1, "tarjeta": null, "celdas": []})
		i += 1
	# bloques ocupados que no tocan la solución
	var libres: Array = []
	for f in range(BLOQUES.size()):
		for dd in range(DIAS.size()):
			if not solucion[f][dd]:
				libres.append(Vector2i(f, dd))
	libres.shuffle()
	for k in range(mini(ocupados, libres.size())):
		var c: Vector2i = libres[k]
		grilla[c.x][c.y] = "#"

func _celda_rect(fila: int, dia: int) -> Rect2:
	return Rect2(GRILLA_X + dia * ANCHO_COL + 3.0, GRILLA_Y + fila * ALTO_FILA + 3.0, ANCHO_COL - 6.0, ALTO_FILA - 6.0)

func _texto(t: String, tam: int, color: Color, rect: Rect2, padre: Control) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = rect.position
	l.size = rect.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(l)
	return l

func _dibujar_grilla() -> void:
	var oscuro := Color(0.15, 0.15, 0.2)
	for dd in range(DIAS.size()):
		_texto(DIAS[dd], 24, oscuro, Rect2(GRILLA_X + dd * ANCHO_COL, GRILLA_Y - 44.0, ANCHO_COL, 40.0), grilla_nodo)
	for f in range(BLOQUES.size()):
		_texto(BLOQUES[f], 22, oscuro, Rect2(GRILLA_X - 70.0, GRILLA_Y + f * ALTO_FILA, 66.0, ALTO_FILA), grilla_nodo)
		for dd in range(DIAS.size()):
			var r := _celda_rect(f, dd)
			var c := ColorRect.new()
			c.position = r.position
			c.size = r.size
			c.color = Color(0.93, 0.94, 0.96) if grilla[f][dd] != "#" else Color(0.62, 0.64, 0.68)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grilla_nodo.add_child(c)
			if grilla[f][dd] == "#":
				_texto(OCUPADOS[(f * 5 + dd) % OCUPADOS.size()], 18, Color(0.2, 0.2, 0.24), r, grilla_nodo)

func _posicion_bandeja(i: int) -> Vector2:
	return Vector2(28, 132 + i * 92)

func _crear_tarjetas() -> void:
	for i in range(ramos.size()):
		var r: Dictionary = ramos[i]
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = r["color"]
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.08, 0.08, 0.1)
		p.add_theme_stylebox_override("panel", sb)
		p.size = TARJETA
		p.position = _posicion_bandeja(i)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tarjetas_nodo.add_child(p)
		var dias: Array = []
		for dd in r["dias"]:
			dias.append(DIAS[dd])
		_texto(r["nombre"], 26, Color.WHITE, Rect2(0, 4, TARJETA.x, 40), p)
		_texto(" · ".join(dias), 22, Color(1, 1, 1, 0.9), Rect2(0, 40, TARJETA.x, 34), p)
		r["tarjeta"] = p

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	if elapsed >= time_limit:
		_finish(false)

func _fila_bajo(pos: Vector2) -> int:
	if pos.x < GRILLA_X - 70.0 or pos.x > GRILLA_X + ANCHO_COL * DIAS.size() or pos.y < GRILLA_Y or pos.y > GRILLA_Y + ALTO_FILA * BLOQUES.size():
		return -1
	return int((pos.y - GRILLA_Y) / ALTO_FILA)

# Con qué choca el ramo i si se pone en la fila: "" si cabe
func _choque(i: int, fila: int) -> String:
	for dd in ramos[i]["dias"]:
		var v = grilla[fila][dd]
		if typeof(v) == TYPE_STRING and v == "#":
			return OCUPADOS[(fila * 5 + dd) % OCUPADOS.size()]
		if typeof(v) == TYPE_INT and v != i:
			return ramos[v]["nombre"]
	return ""

func _input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tomar(event.position)
		elif arrastrando >= 0:
			_soltar(event.position)
	elif event is InputEventMouseMotion and arrastrando >= 0:
		var t: Panel = ramos[arrastrando]["tarjeta"]
		t.position = event.position - agarre
		_mostrar_vista(event.position)

func _tomar(pos: Vector2) -> void:
	for i in range(ramos.size()):
		var r: Dictionary = ramos[i]
		var t: Panel = r["tarjeta"]
		var en_tarjeta: bool = r["fila"] < 0 and Rect2(t.position, t.size).has_point(pos)
		var en_celda := false
		if r["fila"] >= 0:
			for dd in r["dias"]:
				if _celda_rect(r["fila"], dd).has_point(pos):
					en_celda = true
		if en_tarjeta or en_celda:
			if en_celda:
				_quitar(i)
				t.position = pos - TARJETA / 2.0
				t.show()
			arrastrando = i
			agarre = pos - t.position
			tarjetas_nodo.move_child(t, -1)
			t.scale = Vector2(1.05, 1.05)
			_mostrar_vista(pos)
			return

func _mostrar_vista(pos: Vector2) -> void:
	for c in vista.get_children():
		c.queue_free()
	var fila := _fila_bajo(pos)
	if fila < 0:
		return
	var choca := _choque(arrastrando, fila) != ""
	for dd in ramos[arrastrando]["dias"]:
		var r := _celda_rect(fila, dd)
		var c := ColorRect.new()
		c.position = r.position
		c.size = r.size
		c.color = Color(0.9, 0.2, 0.2, 0.4) if choca else Color(0.2, 0.8, 0.35, 0.45)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vista.add_child(c)

func _soltar(pos: Vector2) -> void:
	var i := arrastrando
	arrastrando = -1
	for c in vista.get_children():
		c.queue_free()
	var t: Panel = ramos[i]["tarjeta"]
	t.scale = Vector2.ONE
	var fila := _fila_bajo(pos)
	if fila < 0:
		_volver(i)
		return
	var con := _choque(i, fila)
	if con != "":
		errores += 1
		elapsed += PENALIZACION
		mensaje.text = "¡Tope de horario con %s!" % con
		_volver(i)
		return
	_poner(i, fila)
	mensaje.text = "¡%s inscrito!" % ramos[i]["nombre"]
	for r in ramos:
		if r["fila"] < 0:
			return
	_finish(true)

func _volver(i: int) -> void:
	var t: Panel = ramos[i]["tarjeta"]
	create_tween().tween_property(t, "position", _posicion_bandeja(i), 0.15)

func _poner(i: int, fila: int) -> void:
	var r: Dictionary = ramos[i]
	r["fila"] = fila
	r["tarjeta"].hide()
	for dd in r["dias"]:
		grilla[fila][dd] = i
		var rect := _celda_rect(fila, dd)
		var c := ColorRect.new()
		c.position = rect.position
		c.size = rect.size
		c.color = r["color"]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grilla_nodo.add_child(c)
		_texto(r["nombre"], 20, Color.WHITE, Rect2(Vector2.ZERO, rect.size), c)
		r["celdas"].append(c)
		c.scale = Vector2(0.8, 0.8)
		c.pivot_offset = rect.size / 2.0
		create_tween().tween_property(c, "scale", Vector2.ONE, 0.1)

func _quitar(i: int) -> void:
	var r: Dictionary = ramos[i]
	for dd in r["dias"]:
		grilla[r["fila"]][dd] = ""
	for c in r["celdas"]:
		c.queue_free()
	r["celdas"].clear()
	r["fila"] = -1

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	arrastrando = -1
	for c in vista.get_children():
		c.queue_free()
	var core = get_parent()
	fin.show()
	if won:
		fin.text = "¡Horario sin topes!"
		mensaje.text = "Semestre armado"
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Se cerró la inscripción!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		var faltan := 0
		for r in ramos:
			if r["fila"] < 0:
				faltan += 1
		mensaje.text = "Te faltaron %d ramos" % faltan
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
