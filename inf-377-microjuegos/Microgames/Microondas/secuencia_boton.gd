extends CanvasLayer

@onready var buttonBox: HBoxContainer = %buttonBox
@onready var timeLabel: Label = %timeLabel
@onready var successLabel: Label = %successLabel
@onready var timer: Timer = %Timer

var ButtonSelection = [
	{"action": "ui_down", "icon": preload("res://assets/down.png")},
	{"action": "ui_left", "icon": preload("res://assets/left.png")},
	{"action": "ui_right", "icon": preload("res://assets/right.png")},
	{"action": "ui_up", "icon": preload("res://assets/up.png")},
]

var ActionSequence = []
var SequenceIndex = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	successLabel.hide()
	_set_random_sequence()
	timer.start()

func _set_random_sequence() -> void:
	for node in buttonBox.get_children():
		var RandomPick = ButtonSelection.pick_random()
		node.texture = RandomPick.icon
		ActionSequence.append(RandomPick.action)

func _input(event: InputEvent) -> void:
	if not timer.time_left: return
	if not event is InputEventKey or not event.is_pressed(): return
	
	if Input.is_action_just_pressed(ActionSequence[SequenceIndex]):
		_next_index()
	else:
		_reset_all()

func _next_index() -> void:
	buttonBox.get_child(SequenceIndex).modulate.a = 0
	
	SequenceIndex += 1
	
	if SequenceIndex >= ActionSequence.size():
		timer.paused = true
		_on_timer_timeout()

func _reset_all() -> void:
	SequenceIndex = 0
	
	for node in buttonBox.get_children():
		node.modulate.a = 1

signal finished(success: bool)

func _on_timer_timeout() -> void:
	var success = timer.time_left
	
	_update_success_label(success)
	
	get_tree().paused = false
	
	finished.emit(success)

func _update_success_label(success: bool) -> void:
	successLabel.show()
	
	if success:
		successLabel.text = "EXITO"
		successLabel.add_theme_color_override("font_color", Color.GREEN)
	else:
		successLabel.text = "FAIL"
		successLabel.add_theme_color_override("font_color", Color.RED)

func _process(delta: float) -> void:
	var remainingTime = snapped(timer.time_left, 0.01)
	timeLabel.text = str(remainingTime)
