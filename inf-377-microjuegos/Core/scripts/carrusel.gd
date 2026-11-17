extends Control
## Carrusel de microjuegos: muestra solo los juegos de la bolsa (4). Se ven 3 iconos
## (anterior, actual, siguiente), el del centro va enmarcado en rojo y la fila se desliza
## hacia la izquierda hasta caer en el elegido. El juego ya jugado se cambia por uno nuevo.

const SPACING := 300.0
const CENTER_SCALE := 1.3
const SIDE_SCALE := 0.85

# Iconos de todos los juegos, en el mismo orden que `microgames` en core.gd
@onready var icons: Array[Control] = [$IconSimon, $IconPuerta, $IconLluvia, $IconMicroondas, $IconEnviarTarea, $IconBandeja, $IconImpresora, $IconWifi, $IconNoTeDuermas, $IconPizarron, $IconFirmaLista, $IconFilaCasino, $IconDespertador, $IconMicroLleno, $IconBicicletero, $IconTomaRamos, $IconTrabajoGrupo, $IconFotocopia, $IconParaguas, $IconCargarCelular, $IconCalientaAlmuerzo, $IconCalculadora, $IconChatEscondidas, $IconCorreMicro, $IconMaquinaSnacks, $IconProyector, $IconBorraPizarra, $IconRecicla, $IconPapelBasurero, $IconCelularCertamen, $IconArmaCompleto, $IconHojaRespuestas, $IconArmaHorario, $IconOrdenaInforme]
@onready var marco: Control = $Marco

var slots: Array[int] = []   # juegos que están en el carrusel (índice de juego por puesto)
var current: int = 0         # puesto que está en el centro

func _ready() -> void:
	_layout(0.0)

# Define qué juegos se muestran. Los demás iconos quedan ocultos.
func set_games(games: Array) -> void:
	slots.assign(games)
	current = 0
	for i in range(icons.size()):
		icons[i].visible = slots.has(i)
	_layout(0.0)

# Coloca los iconos. `offset` = cuántos puestos se ha deslizado la fila desde `current`.
func _layout(offset: float) -> void:
	var n := slots.size()
	var center := size / 2.0
	for i in range(n):
		var icon := icons[slots[i]]
		# Posición relativa al centro, dando la vuelta (con n=4: de -1.5 a 2.5).
		var r := wrapf(float(i - current) - offset, -1.5, n - 1.5)
		var a := absf(r)
		var s := lerpf(CENTER_SCALE, SIDE_SCALE, clampf(a, 0.0, 1.0))
		icon.scale = Vector2(s, s)
		icon.position = Vector2(center.x + r * SPACING, center.y) - icon.pivot_offset
		if a <= 1.0:
			icon.modulate.a = lerpf(1.0, 0.85, a)
		else:
			icon.modulate.a = lerpf(0.85, 0.0, clampf((a - 1.0) / 0.5, 0.0, 1.0))
		icon.z_index = 1 if a < 0.5 else 0
	marco.position = center - marco.pivot_offset

# El juego del puesto `slot` (recién jugado) sale del carrusel y entra `new_game` en su lugar.
func replace_game(slot: int, new_game: int) -> void:
	current = slot
	_layout(0.0)
	var viejo := icons[slots[slot]]
	var sale := create_tween().set_parallel(true)
	sale.tween_property(viejo, "scale", Vector2(0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	sale.tween_property(viejo, "modulate:a", 0.0, 0.25)
	await sale.finished
	viejo.hide()
	slots[slot] = new_game
	var nuevo := icons[new_game]
	nuevo.show()
	_layout(0.0)
	nuevo.scale = Vector2(0.1, 0.1)
	var entra := create_tween()
	entra.tween_property(nuevo, "scale", Vector2(CENTER_SCALE, CENTER_SCALE), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entra.finished
	await get_tree().create_timer(0.5).timeout

# Gira hasta dejar el puesto `slot` en el centro (una o dos vueltas completas más lo que falte).
func spin_to(slot: int) -> void:
	var n := slots.size()
	var steps := randi_range(1, 2) * n + posmod(slot - current, n)
	var step_time := 0.08
	for s in range(steps):
		var tween := create_tween()
		tween.tween_method(_layout, 0.0, 1.0, step_time)
		await tween.finished
		current = (current + 1) % n
		_layout(0.0)
		step_time += 0.32 / steps # va frenando poco a poco
	await _flash_marco()

func _flash_marco() -> void:
	for i in range(3):
		marco.modulate.a = 0.0
		await get_tree().create_timer(0.1).timeout
		marco.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
