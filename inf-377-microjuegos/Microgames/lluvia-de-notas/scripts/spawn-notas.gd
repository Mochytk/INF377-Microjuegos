extends Node2D

const cienn = preload("res://Microgames/lluvia-de-notas/scenes/cien.tscn")
const ceroo = preload("res://Microgames/lluvia-de-notas/scenes/cero.tscn")

var random = RandomNumberGenerator.new()
var valid = true

func _ready() -> void:
	random.randomize()
	await get_tree().create_timer(3.0).timeout
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

		await get_tree().create_timer(5.0).timeout
	


func _on_cero_colision_cero() -> void:
	valid = false
	get_tree().change_scene_to_file("res://Microgames/lluvia-de-notas/scenes/game_over.tscn")
	print("perdiste")
