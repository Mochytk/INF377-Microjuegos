extends Control
## Carrusel de microjuegos: se ven 3 iconos (anterior, actual, siguiente), el del centro
## va enmarcado en rojo y la fila se desliza hacia la izquierda hasta caer en el elegido.

const SPACING := 300.0
const CENTER_SCALE := 1.3
const SIDE_SCALE := 0.85

@onready var items: Array[Control] = [$IconSimon, $IconPuerta, $IconLluvia, $IconMicroondas, $IconEnviarTarea, $IconBandeja, $IconImpresora, $IconWifi, $IconNoTeDuermas, $IconPizarron, $IconFirmaLista, $IconFilaCasino, $IconDespertador, $IconMicroLleno, $IconBicicletero]
@onready var marco: Control = $Marco

var current: int = 0 # índice del juego que está en el centro

func _ready() -> void:
	_layout(0.0)

# Coloca los iconos. `offset` = cuántos puestos se ha deslizado la fila desde `current`.
func _layout(offset: float) -> void:
	var n := items.size()
	var center := size / 2.0
	for i in range(n):
		# Posición relativa al centro, dando la vuelta (con n=4: de -1.5 a 2.5).
		var r := wrapf(float(i - current) - offset, -1.5, n - 1.5)
		var a := absf(r)
		var s := lerpf(CENTER_SCALE, SIDE_SCALE, clampf(a, 0.0, 1.0))
		items[i].scale = Vector2(s, s)
		items[i].position = Vector2(center.x + r * SPACING, center.y) - items[i].pivot_offset
		if a <= 1.0:
			items[i].modulate.a = lerpf(1.0, 0.85, a)
		else:
			items[i].modulate.a = lerpf(0.85, 0.0, clampf((a - 1.0) / 0.5, 0.0, 1.0))
		items[i].z_index = 1 if a < 0.5 else 0
	marco.position = center - marco.pivot_offset

func spin_to(target: int) -> void:
	var n := items.size()
	# Siempre gira entre 8 y 12 puestos, sin importar cuántos juegos haya: con muchos juegos,
	# dar vueltas completas hacía el giro demasiado largo. Parte desde un punto que deja al
	# elegido a esa distancia (el carrusel estaba oculto, así que el salto no se ve).
	var steps := randi_range(8, 12)
	current = posmod(target - steps, n)
	_layout(0.0)
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
