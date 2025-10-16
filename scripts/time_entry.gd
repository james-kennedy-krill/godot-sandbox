extends HBoxContainer

@onready var name_label: Label = %Name
@onready var time_label: Label = %Time

var _display_name := "" 
var _time_ms := -1

@export var display_name: String:
	set(v):
		_display_name = v
		if is_node_ready():
			name_label.text = v

@export var time_ms: int:
	set(v):
		_time_ms = v
		if is_node_ready():
			time_label.text = Stopwatch.format_time_ms(v)

func _ready() -> void:
	# apply values assigned before ready
	display_name = _display_name
	time_ms = _time_ms
