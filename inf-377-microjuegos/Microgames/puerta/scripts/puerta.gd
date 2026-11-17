extends Node2D

var correct_door: int
var game_finished:= false
var fin_pasillo := INF   # x desde la que el jugador ya pasó la última puerta

func _ready() -> void:
	# Nivel 1: más lento y con más tiempo. Con la dificultad avanza más rápido y el tiempo baja.
	var core = get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	# Sobre el nivel 7 la dificultad sigue creciendo sin tope: cada nivel extra apura todo un 8 % más
	var apuro := 1.0 + 0.08 * maxf(0.0, d - 7.0)
	$CharacterBody2D.speed = minf(2000.0, 1300.0 + 100.0 * level) * apuro
	$Timer.wait_time = maxf(5.0, 9.0 - 0.4 * level) / apuro

	correct_door = randi_range(1 , 6)
	print("Puerta correcta", correct_door)
	
	$UI/InstructionLabel.text = "¡Entra a la Sala " + str(correct_door) + "!"
	_limitar_pasillo()
	$Timer.start()

# El jugador avanza solo y, si no entraba a ninguna puerta, seguía de largo hasta salir del
# escenario: la pantalla quedaba gris hasta que se acababa el tiempo. Ahora pierde al pasar la
# última puerta, y la cámara no muestra nada fuera de los fondos.
func _limitar_pasillo() -> void:
	var fin := -INF
	var escenario := Rect2()
	var primero := true
	for nodo in get_children():
		if nodo is Area2D and nodo.is_in_group("doors"):
			var cs: CollisionShape2D = nodo.get_node("CollisionShape2D")
			fin = maxf(fin, cs.global_position.x + (cs.shape as RectangleShape2D).size.x * absf(cs.global_scale.x) / 2.0)
		var sprites: Array = []
		if nodo is Sprite2D:
			sprites.append(nodo)
		elif nodo is Area2D:
			sprites.append(nodo.get_node("Sprite2D"))
		for sp in sprites:
			var r: Rect2 = sp.get_global_transform() * sp.get_rect()
			escenario = r if primero else escenario.merge(r)
			primero = false
	fin_pasillo = fin + 150.0
	var cam: Camera2D = $CharacterBody2D/Camera2D
	cam.limit_left = int(escenario.position.x)
	cam.limit_right = int(escenario.end.x)
	cam.limit_top = int(escenario.position.y)
	cam.limit_bottom = int(escenario.end.y)

func _process(delta: float) -> void:
	if game_finished:
		return
	if $CharacterBody2D.global_position.x > fin_pasillo:
		$UI/InstructionLabel.text = "¡Te pasaste de la sala!"
		Sonido.play("error")
		lose_game()

func win_game():
	if game_finished:
		return
	game_finished = true
	$Timer.stop()
	$CharacterBody2D.show_win_sprite()
	print("Ganaste!")
	
	# Pausa breve para ver la animación, luego avisar al Core
	await get_tree().create_timer(1.0).timeout
	get_parent().end_microgame(true)

func lose_game():
	if game_finished:
		return
	game_finished = true
	$Timer.stop()
	$CharacterBody2D.show_lose_sprite()
	print("Perdiste")
	
	# Pausa breve para ver la animación, luego avisar al Core
	await get_tree().create_timer(1.0).timeout
	get_parent().end_microgame(false)


func _on_timer_timeout() -> void:
	if game_finished:
		return
	
	lose_game()
