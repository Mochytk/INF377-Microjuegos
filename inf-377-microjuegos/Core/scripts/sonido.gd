extends Node
## Gestor de sonido (autoload "Sonido"). Cualquier escena puede hacer:
##     Sonido.play("acierto")            efecto de sonido
##     Sonido.play("golpe", -6.0, 1.2)   con volumen (dB) y tono distintos
##     Sonido.musica("musica_menu")      música en loop (si ya suena, no la reinicia)
##     Sonido.parar_musica()
## Los .wav están en Core/assets/sonidos y se generan con herramientas/generar_sonidos.py.
## La opción de silencio se guarda en user://ajustes.cfg.

const RUTA := "res://Core/assets/sonidos/%s.wav"
const AJUSTES := "user://ajustes.cfg"
const VOCES := 12
const VOLUMEN_MUSICA := -13.0

var silenciado := false
var _cache := {}
var _voces: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _musica: AudioStreamPlayer
var _ultimo := {}      # para que un mismo sonido no se apile demasiado seguido

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(VOCES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voces.append(p)
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = VOLUMEN_MUSICA
	add_child(_musica)
	var cfg := ConfigFile.new()
	if cfg.load(AJUSTES) == OK:
		silenciado = cfg.get_value("audio", "silencio", false)
	AudioServer.set_bus_mute(0, silenciado)

func _stream(nombre: String) -> AudioStream:
	if not _cache.has(nombre):
		var ruta := RUTA % nombre
		_cache[nombre] = load(ruta) if ResourceLoader.exists(ruta) else null
		if _cache[nombre] == null:
			push_warning("Sonido no encontrado: " + nombre)
	return _cache[nombre]

## Reproduce un efecto. `separacion` evita repetir el mismo sonido antes de esos segundos.
func play(nombre: String, volumen_db := 0.0, tono := 1.0, separacion := 0.03) -> void:
	var s := _stream(nombre)
	if s == null:
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if _ultimo.has(nombre) and ahora - _ultimo[nombre] < separacion:
		return
	_ultimo[nombre] = ahora
	# usa una voz libre; si están todas ocupadas, la más antigua
	var p: AudioStreamPlayer = null
	for i in range(VOCES):
		var v := _voces[(_siguiente + i) % VOCES]
		if not v.playing:
			p = v
			break
	if p == null:
		p = _voces[_siguiente]
	_siguiente = (_siguiente + 1) % VOCES
	p.stream = s
	p.volume_db = volumen_db
	p.pitch_scale = tono
	p.play()

func musica(nombre: String) -> void:
	var s := _stream(nombre)
	if s == null:
		return
	if _musica.stream == s and _musica.playing:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_musica.stream = s
	_musica.play()

func parar_musica() -> void:
	_musica.stop()

func alternar_silencio() -> bool:
	silenciado = not silenciado
	AudioServer.set_bus_mute(0, silenciado)
	var cfg := ConfigFile.new()
	cfg.load(AJUSTES)
	cfg.set_value("audio", "silencio", silenciado)
	cfg.save(AJUSTES)
	return silenciado
