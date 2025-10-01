# GameState.gd (autoload)
extends Node
signal goal_progress_changed(total: int, collected: int)
signal level_won
signal pause

const GAME_START_GOAL_COUNT := 3  # the goals at level 1 (start)
const GAME_START_LEVEL := 1       # the level the game starts at
const LEVEL_GOAL_INCREASE := 1     # how many more goals to add at each new level

var _total_goals: int = 0         # the total goals for this level
var _collected_goals: int = 0     # the total collected goals for this level

var level_goal_count: int = GAME_START_GOAL_COUNT
var current_level: int = GAME_START_LEVEL

const SAVE_PATH := "user://progress.cfg"

var total_goals: int:
	get: return _total_goals
	set(value):
		_total_goals = max(0, value)
		_collected_goals = min(_collected_goals, _total_goals) # clamp collected to new max
		emit_signal("goal_progress_changed", _total_goals, _collected_goals)

var collected_goals: int:
	get: return _collected_goals
	set(value):
		_collected_goals = clamp(value, 0, _total_goals)
		emit_signal("goal_progress_changed", _total_goals, _collected_goals)

func _has_event(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and ev is InputEventJoypadButton and e.button_index == ev.button_index:
			return true
		if e is InputEventJoypadMotion and ev is InputEventJoypadMotion and e.axis == ev.axis and sign(e.axis_value) == sign(ev.axis_value):
			return true
	return false

func _ready() -> void:
	_ensure_gamepad_actions()
	
func _input(event: InputEvent) -> void:
	if event and event.is_action_pressed("pause"):
		emit_signal("pause")

# Helper to add a JoypadButton if missing
func add_btn(action: String, btn: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)

# Helper to add a JoypadMotion (left stick) if missing
func add_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value   # -1.0 or +1.0
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)

func _ensure_gamepad_actions() -> void:
	# Ensure the actions exist
	for a in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)

	# Common buttons (Godot 4 has JOY_BUTTON_A/B/X/Y constants)
	add_btn("ui_accept", JOY_BUTTON_A)       # Xbox A / Switch B / PlayStation Cross
	add_btn("ui_cancel", JOY_BUTTON_B)

	# DPAD for navigation
	add_btn("ui_up", JOY_BUTTON_DPAD_UP)
	add_btn("ui_down", JOY_BUTTON_DPAD_DOWN)
	add_btn("ui_left", JOY_BUTTON_DPAD_LEFT)
	add_btn("ui_right", JOY_BUTTON_DPAD_RIGHT)

	# Left stick for navigation (optional but nice)
	add_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	add_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	add_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	add_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)

func reset_goals(total: int = level_goal_count) -> void:
	total_goals = total      # uses setter → emits signal
	collected_goals = 0      # uses setter → emits signal

func goal_collected() -> void:
	collected_goals = _collected_goals + 1
	if _collected_goals >= _total_goals and _total_goals > 0:
		emit_signal("level_won")
		
func next_level() -> void:
	level_goal_count += LEVEL_GOAL_INCREASE
	current_level += 1
	reset_goals()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level_goal_count", level_goal_count)
	cfg.set_value("progress", "current_level", current_level)
	cfg.save(SAVE_PATH)
	
func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level_goal_count = cfg.get_value("progress", "level_goal_count", GAME_START_GOAL_COUNT)
		current_level = cfg.get_value("progress", "current_level", GAME_START_LEVEL)
		
func reset_progress() -> void:
	current_level = 1
	level_goal_count = GAME_START_GOAL_COUNT
	reset_goals(GAME_START_GOAL_COUNT)
		
func has_progress() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK
