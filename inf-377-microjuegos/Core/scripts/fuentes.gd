extends Node
## Autoload "Fuentes": agrega DejaVu Sans como respaldo de la fuente por defecto.
## En la versión web Godot no puede usar las fuentes del sistema, y la fuente que trae no tiene
## flechas (← → ↓), ✓, ✗, ▶, ▼, ● ni otros símbolos: se veían como cuadros con números. Con el
## respaldo, el texto se sigue viendo con la fuente de siempre y solo esos símbolos salen de DejaVu.

const RESPALDO := preload("res://Core/assets/fuentes/DejaVuSans.ttf")

func _enter_tree() -> void:
	var fuente: Font = ThemeDB.fallback_font
	if fuente == null or fuente.fallbacks.has(RESPALDO):
		return
	var lista := fuente.fallbacks.duplicate()
	lista.append(RESPALDO)
	fuente.fallbacks = lista
