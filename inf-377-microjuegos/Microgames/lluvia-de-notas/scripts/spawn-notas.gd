extends Node2D

const cienn = preload("res://Microgames/lluvia-de-notas/scenes/cien.tscn")
const ceroo = preload("res://Microgames/lluvia-de-notas/scenes/cero.tscn")
var random = RandomNumberGenerator.new()
var valid = true
var game_ended = true
func _ready() -> void:
	random.randomize()
	# Eliminamos el retraso de 3 segundos para que inicie de inmediato
	spawn()

func GetRandomPos() -> Vector2:
	var x = random.randf_range(-150, 150)
	return Vector2(x, -70)

func spawn():
	while valid:
		var i = random.randi_range(0, 1)
		if i == 0:
			var cero_spawn = ceroo.instantiate()
			cero_spawn.position = GetRandomPos()
			cero_spawn.colision_cero.connect(_on_cero_colision_cero)
			add_child(cero_spawn)
		else:
			var cien_spawn = cienn.instantiate()
			cien_spawn.position = GetRandomPos()
			add_child(cien_spawn)
			
		# Reducido de 5.0 a 0.5 segundos para que sea un desafío rápido
		await get_tree().create_timer(0.5).timeout 

func _on_cero_colision_cero() -> void:
	valid = false
	game_ended = false
	# Avisamos de la derrota a la escena principal
	get_parent().game_over()



# Esta función la llamará el spawner si chocamos
func game_over() -> void:
	if not game_ended:
		game_ended = true
		get_parent().end_microgame(false)
