extends Label

## Inspector options
@export var autostart: bool = false
@export var update_interval_ms: int = 50  # UI refresh rate (20 FPS)


func _ready() -> void:
	Stopwatch.autostart = autostart
	Stopwatch.update_interval_ms = update_interval_ms
	Stopwatch.update_label.connect(_update_label)


func _update_label(ms: int) -> void:
	text = Stopwatch.format_time_ms(ms)
