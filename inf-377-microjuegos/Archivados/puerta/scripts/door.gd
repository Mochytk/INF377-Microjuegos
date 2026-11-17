extends Area2D

@export var door_number: int = 1

func _ready() -> void:
	_add_sign()

# Cartel "SALA n" en la pared, a la izquierda de la puerta
func _add_sign() -> void:
	var placa := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.98, 0.96)
	sb.set_border_width_all(10)
	sb.border_color = Color.BLACK
	sb.set_corner_radius_all(6)
	placa.add_theme_stylebox_override("panel", sb)
	placa.position = Vector2(769, -400)
	placa.size = Vector2(260, 190)
	placa.z_index = 1
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(placa)
	var titulo := Label.new()
	titulo.text = "SALA"
	titulo.add_theme_font_size_override("font_size", 46)
	titulo.add_theme_color_override("font_color", Color.BLACK)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(0, 8)
	titulo.size = Vector2(260, 56)
	placa.add_child(titulo)
	var numero := Label.new()
	numero.text = str(door_number)
	numero.add_theme_font_size_override("font_size", 104)
	numero.add_theme_color_override("font_color", Color(0.1, 0.2, 0.75))
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.position = Vector2(0, 52)
	numero.size = Vector2(260, 130)
	placa.add_child(numero)
