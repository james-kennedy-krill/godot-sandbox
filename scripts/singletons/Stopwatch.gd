extends Label

signal started()
signal stopped(elapsed_ms: int)
signal reset()
signal update_label(elapsed_ms: int)

## Inspector options
@export var autostart: bool = false
@export var update_interval_ms: int = 50  # UI refresh rate (20 FPS)

# Property with inline getter/setter
@export var initial_time_ms: int:
	get:
		return _initial_time_ms
	set(value):
		_initial_time_ms = max(value, 0)
		if not _running and _base_elapsed_ms == 0:
			_base_elapsed_ms = _initial_time_ms
			emit_signal("update_label", _base_elapsed_ms)

# backing field for the property
var _initial_time_ms: int = 0

## Internal state
var _running: bool = false
var _base_elapsed_ms: int = 0      # accumulated time before last start
var _last_start_tick_ms: int = 0   # Time.get_ticks_msec() at last start
var _accum_refresh_ms: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	emit_signal("update_label", _current_elapsed_ms())

	if autostart:
		start()

func _process(delta: float) -> void:
	if not _running:
		return
	_accum_refresh_ms += int(delta * 1000.0)
	if _accum_refresh_ms >= update_interval_ms:
		_accum_refresh_ms = 0
		emit_signal("update_label", _current_elapsed_ms())

# ——— Public API ———

func start() -> void:
	if _running:
		return
	_last_start_tick_ms = Time.get_ticks_msec()
	_running = true
	emit_signal("started")

func stop() -> void:
	if not _running:
		return
	var now_ms: int = Time.get_ticks_msec()
	_base_elapsed_ms += now_ms - _last_start_tick_ms
	_running = false
	emit_signal("update_label", _base_elapsed_ms)
	emit_signal("stopped", _base_elapsed_ms)

func reset_timer() -> void:
	_running = false
	_base_elapsed_ms = initial_time_ms
	_last_start_tick_ms = 0
	emit_signal("update_label", _base_elapsed_ms)
	emit_signal("reset")

func get_time_ms() -> int:
	return _current_elapsed_ms()

func set_time_ms(ms: int) -> void:
	_base_elapsed_ms = max(ms, 0)
	_last_start_tick_ms = Time.get_ticks_msec()
	emit_signal("update_label", _current_elapsed_ms())

func get_time_string() -> String:
	return format_time_ms(_current_elapsed_ms())

func to_dict() -> Dictionary:
	return {"elapsed_ms": get_time_ms()}

func from_dict(data: Dictionary) -> void:
	if data.has("elapsed_ms"):
		set_time_ms(int(data["elapsed_ms"]))

# ——— Internals ———

func _current_elapsed_ms() -> int:
	if _running:
		return _base_elapsed_ms + (Time.get_ticks_msec() - _last_start_tick_ms)
	return _base_elapsed_ms

func format_time_ms(ms: int) -> String:
	if ms == 0:
		return "00:00.00"
	var total_cs: int = int(ms / 10.0)      # centiseconds
	var cs: int = total_cs % 100
	var total_s: int = int(ms / 1000.0)     # seconds
	var s: int = total_s % 60
	var m: int = int(total_s / 60.0) % 60
	var h: int = int(total_s / 3600.0)
	if h > 0:
		return "%02d:%02d:%02d.%02d" % [h, m, s, cs]
	return "%02d:%02d.%02d" % [m, s, cs]
