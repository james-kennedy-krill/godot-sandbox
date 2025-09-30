extends CharacterBody2D
signal character_moved(pos: Vector2)

@export var step: int = 16
@export var padding: float = 16.0
@export var initial_delay: float = 0.20   # time before repeating starts
@export var repeat_interval: float = 0.08 # time between repeated steps

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _time_to_next: float = 0.0
var _repeating: bool = false
var _last_dir: Vector2 = Vector2.ZERO

func move_character_to(target: Vector2) -> void:
	global_position = target

func _physics_process(delta: float) -> void:
	var dir := _read_dir()

	if dir == Vector2.ZERO:
		_repeating = false
		_time_to_next = 0.0
		_last_dir = Vector2.ZERO
		return

	var just_pressed := Input.is_action_just_pressed("move_up") \
		|| Input.is_action_just_pressed("move_down") \
		|| Input.is_action_just_pressed("move_left") \
		|| Input.is_action_just_pressed("move_right")

	# Start or change direction: step immediately, then start repeat timer
	if just_pressed or dir != _last_dir or not _repeating:
		_step_once(dir)
		_last_dir = dir
		_time_to_next = initial_delay
		_repeating = true
	else:
		_time_to_next -= delta
		if _time_to_next <= 0.0:
			_step_once(dir)
			_time_to_next = repeat_interval

func _step_once(dir: Vector2) -> void:
	# Check if Shift is held → double the step distance
	var step_size := float(step)
	if Input.is_action_pressed("sprint"):
		audio.pitch_scale = 1.5
		step_size *= 2.0

	position += dir * step_size
	#audio.play()
	#audio.pitch_scale = 1.0

	# Clamp to viewport padded rect
	var vp := get_viewport_rect().size
	position.x = clamp(position.x, padding, vp.x - padding)
	position.y = clamp(position.y, padding, vp.y - padding)
	
	emit_signal("character_moved", position)

func _read_dir() -> Vector2:
	# Deterministic priority (U, D, L, R). Change if you prefer another priority.
	if Input.is_action_pressed("move_up"):
		return Vector2(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2(1, 0)
	return Vector2.ZERO
