extends Node2D

const cienn = preload("res://Microgames/lluvia_de_notas/scenes/cien.tscn")
const ceroo = preload("res://Microgames/lluvia_de_notas/scenes/cero.tscn")
var random = RandomNumberGenerator.new()
var valid = true
var game_ended = true

# Ajustes según dificultad. Nivel 1: cae poco, pocos ceros y con calma.
var spawn_interval := 0.8
var zero_chance := 0.35
var fall_gravity := 0.08

func _ready() -> void:
	random.randomize()
	var core = get_parent().get_parent()
	var d: float = core.difficulty if "difficulty" in core else 1.0
	var level := clampf(d - 1.0, 0.0, 6.0)
	spawn_interval = maxf(0.5, 0.8 - 0.05 * level)
	zero_chance = minf(0.5, 0.35 + 0.025 * level)
	fall_gravity = 0.08 + 0.01 * level
	# Eliminamos el retraso de 3 segundos para que inicie de inmediato
	spawn()

func GetRandomPos() -> Vector2:
	var x = random.randf_range(-150, 150)
	return Vector2(x, -70)

func spawn():
	while valid:
		if random.randf() < zero_chance:
			var cero_spawn = ceroo.instantiate()
			cero_spawn.position = GetRandomPos()
			cero_spawn.get_node("RigidBody2D").gravity_scale = fall_gravity
			cero_spawn.colision_cero.connect(_on_cero_colision_cero)
			add_child(cero_spawn)
		else:
			var cien_spawn = cienn.instantiate()
			cien_spawn.position = GetRandomPos()
			cien_spawn.get_node("RigidBody2D").gravity_scale = fall_gravity
			add_child(cien_spawn)
			
		await get_tree().create_timer(spawn_interval).timeout

func _on_cero_colision_cero() -> void:
	valid = false
	print("perdiste")
	game_ended = false
	# Avisamos de la derrota a la escena principal
	get_parent().game_over()



# Esta función la llamará el spawner si chocamos
func game_over() -> void:
	if not game_ended:
		game_ended = true
		get_parent().end_microgame(false)
