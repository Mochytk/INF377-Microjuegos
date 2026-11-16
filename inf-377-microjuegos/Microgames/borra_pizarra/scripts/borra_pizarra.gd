extends Control
## Borra la pizarra: la clase anterior dejó la pizarra blanca escrita. Hay que mantener el clic
## y frotar con el borrador hasta dejarla limpia antes de que llegue el profe. Solo borra el
## borrador en movimiento; el plumón permanente (niveles altos) necesita varias pasadas.

const ESCALA := 4.0                          # cada pixel de la tinta se ve de 4x4
const ORIGEN := Vector2(96, 56)              # esquina de la superficie blanca en pantalla
const TAM := Vector2i(240, 110)              # tamaño de la tinta en pixeles reales
const BORRADOR := Vector2i(30, 16)           # superficie del borrador en pixeles de tinta
const DESGASTE := 0.08                       # tinta que se quita por paso (≈ 1 pasada)
const DUREZA_PERMANENTE := 3.0               # el permanente necesita ~3 veces más frotado
const NEGRO_PERMANENTE := Color("#0b0b10")
const META := 0.95                           # porcentaje limpio para ganar
const ESCRITURAS := [
	preload("res://Microgames/borra_pizarra/assets/escritura_0.png"),
	preload("res://Microgames/borra_pizarra/assets/escritura_1.png"),
	preload("res://Microgames/borra_pizarra/assets/escritura_2.png"),
]

@onready var tinta_rect: TextureRect = $Tinta
@onready var borrador: TextureRect = $Borrador
@onready var polvo: Control = $Polvo
@onready var profe: TextureRect = $Profe
@onready var mensaje: Label = $Mensaje
@onready var limpio_label: Label = $Limpio
@onready var fin: Label = $Fin
@onready var timer_bar: ProgressBar = $ProgressBar

var playing := false
var time_limit := 8.0
var elapsed := 0.0
var img: Image
var tex: ImageTexture
var tinta := PackedFloat32Array()       # 0..1 por pixel
var dureza := PackedFloat32Array()      # 1 normal, DUREZA_PERMANENTE permanente
var total := 0.0                         # tinta inicial (para el porcentaje)
var restante := 0.0
var base_color: PackedColorArray = []    # color original de cada pixel
var mouse := Vector2(576, 590)
var apretado := false
var cambio := false
var polvo_cd := 0.0

func _ready() -> void:
	# Nivel 1: 3 filas escritas y el dibujo. Al subir: hasta 6 filas, menos tiempo, y desde el
	# nivel 4 una o dos filas son de plumón permanente.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	var filas := mini(6, 3 + int(level / 2.0))
	var permanentes := 0 if level < 3.0 else (1 if level < 5.0 else 2)

	img = (ESCRITURAS.pick_random() as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var filas_perm: Array = range(filas)
	filas_perm.shuffle()
	filas_perm = filas_perm.slice(0, permanentes)
	# el plumón permanente se ve más grueso y negro: se engrosa la letra un pixel
	var fuente := img.duplicate()
	for y in range(TAM.y - 1):
		if not (int((y - 3) / 17.0) in filas_perm):
			continue
		for x in range(176):
			if fuente.get_pixel(x, y).a > 0.0:
				for q in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
					img.set_pixelv(q, NEGRO_PERMANENTE)
	tinta.resize(TAM.x * TAM.y)
	dureza.resize(TAM.x * TAM.y)
	base_color.resize(TAM.x * TAM.y)
	for y in range(TAM.y):
		var fila := int((y - 3) / 17.0)
		for x in range(TAM.x):
			var i := y * TAM.x + x
			var c := img.get_pixel(x, y)
			# las filas que no tocan en este nivel quedan en blanco (el dibujo de la derecha queda)
			if c.a > 0.0 and fila >= filas and x < 176:
				c.a = 0.0
			if c.a > 0.0 and fila in filas_perm and x < 176:
				dureza[i] = DUREZA_PERMANENTE
			else:
				dureza[i] = 1.0
			base_color[i] = c
			tinta[i] = 1.0 if c.a > 0.0 else 0.0
			total += tinta[i]
			img.set_pixel(x, y, c)
	restante = total
	tex = ImageTexture.create_from_image(img)
	tinta_rect.texture = tex

	if permanentes > 0:
		mensaje.text = "¡Alguien usó plumón permanente! Frota más fuerte"
	# Tiempo pensado para frotar fila por fila con calma, más un margen
	time_limit = (2.6 + 1.0 * filas + 1.4 * permanentes) * (1.0 - 0.04 * level) / apuro
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_mover_borrador()
	playing = true

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		apretado = event.pressed
		mouse = event.position
		_mover_borrador()
	elif event is InputEventMouseMotion:
		var anterior := mouse
		mouse = event.position
		apretado = apretado or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			apretado = false
		if playing and apretado:
			_frotar(anterior, mouse)
		_mover_borrador()

func _mover_borrador() -> void:
	borrador.position = mouse - borrador.size / 2.0 + (Vector2(0, 6) if apretado else Vector2.ZERO)

# Pasa el borrador desde a hasta b, de a un pixel de tinta por paso
func _frotar(a: Vector2, b: Vector2) -> void:
	var pasos := maxi(1, int(a.distance_to(b) / ESCALA))
	var quitado := 0.0
	for k in range(1, pasos + 1):
		var p := (a.lerp(b, float(k) / pasos) - ORIGEN) / ESCALA
		var x0 := int(p.x) - BORRADOR.x / 2
		var y0 := int(p.y) - BORRADOR.y / 2
		for y in range(maxi(0, y0), mini(TAM.y, y0 + BORRADOR.y)):
			for x in range(maxi(0, x0), mini(TAM.x, x0 + BORRADOR.x)):
				var i := y * TAM.x + x
				if tinta[i] <= 0.0:
					continue
				var antes := tinta[i]
				tinta[i] = maxf(0.0, antes - DESGASTE / dureza[i])
				quitado += antes - tinta[i]
				var c := base_color[i]
				c.a = tinta[i]
				img.set_pixel(x, y, c)
	if quitado > 0.0:
		restante -= quitado
		cambio = true
		if polvo_cd <= 0.0:
			polvo_cd = 0.05
			_soltar_polvo()

func _soltar_polvo() -> void:
	var r := ColorRect.new()
	r.color = Color(0.55, 0.6, 0.75, 0.8)
	r.size = Vector2(8, 8)
	r.position = mouse + Vector2(randf_range(-50, 50), 28)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polvo.add_child(r)
	var t := create_tween().set_parallel()
	t.tween_property(r, "position:y", r.position.y + randf_range(40, 80), 0.5)
	t.tween_property(r, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(r.queue_free)

func _process(delta: float) -> void:
	polvo_cd -= delta
	if cambio:
		cambio = false
		tex.update(img)
	if not playing:
		return
	elapsed += delta
	timer_bar.value = maxf(0.0, time_limit - elapsed)
	var limpio := 1.0 - restante / total
	limpio_label.text = "Limpio: %d %%" % int(floor(limpio * 100.0))
	if limpio >= META:
		_finish(true)
	elif elapsed >= time_limit:
		_finish(false)

func _finish(won: bool) -> void:
	if not playing:
		return
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var core = get_parent()
	fin.show()
	if won:
		# los restos que quedan se terminan de borrar solos y la pizarra brilla
		for i in range(tinta.size()):
			if tinta[i] > 0.0:
				var c := base_color[i]
				c.a = 0.0
				img.set_pixel(i % TAM.x, i / TAM.x, c)
		cambio = true
		limpio_label.text = "Limpio: 100 %"
		fin.text = "¡Pizarra impecable!"
		mensaje.text = "Justo a tiempo para la clase"
		for k in range(10):
			var brillo := ColorRect.new()
			brillo.color = Color(1, 1, 1)
			brillo.size = Vector2(12, 12)
			brillo.position = ORIGEN + Vector2(randf_range(40, 920), randf_range(30, 400))
			brillo.rotation = PI / 4.0
			brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			brillo.scale = Vector2.ZERO
			polvo.add_child(brillo)
			var t := create_tween()
			t.tween_interval(k * 0.05)
			t.tween_property(brillo, "scale", Vector2(1.6, 1.6), 0.18)
			t.tween_property(brillo, "scale", Vector2.ZERO, 0.25)
		var used_ratio := clampf(elapsed / time_limit, 0.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		core.end_microgame(true, core.time_performance(used_ratio))
	else:
		fin.text = "¡Llegó el profe y la pizarra sigue escrita!"
		fin.label_settings = fin.label_settings.duplicate()
		fin.label_settings.font_color = Color(1, 0.4, 0.35)
		mensaje.text = "Limpio: %d %% de %d %%" % [int((1.0 - restante / total) * 100.0), int(META * 100.0)]
		profe.show()
		create_tween().tween_property(profe, "position:x", 1000.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.2).timeout
		core.end_microgame(false)
