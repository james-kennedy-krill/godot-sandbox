extends CharacterBody2D
signal character_moved(pos: Vector2)

@export var step: int = 16
@export var padding: float = 16.0
@export var initial_delay: float = 0.20   # time before repeating starts
@export var repeat_interval: float = 0.08 # time between repeated steps

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var sweep: ShapeCast2D = $Sweep


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
	var step_size: float = float(step)
	if Input.is_action_pressed("sprint"):
		audio.pitch_scale = 1.5
		step_size *= 2.0
	else:
		audio.pitch_scale = 1.0

	# Compute target within padded viewport
	var vp: Vector2 = get_viewport_rect().size
	var desired_target: Vector2 = position + dir * step_size
	var target: Vector2 = Vector2(
		clamp(desired_target.x, padding, vp.x - padding),
		clamp(desired_target.y, padding, vp.y - padding)
	)
	var motion: Vector2 = target - position
	if motion == Vector2.ZERO:
		return

	# Oversweep half a step beyond the actual move
	var half_step_vec: Vector2 = dir * (step_size * 0.5)
	var extended_motion: Vector2 = motion + half_step_vec

	# --- Sweep along extended path to find candidate goals ---
	sweep.target_position = extended_motion
	sweep.collide_with_areas = true
	sweep.force_shapecast_update()

	if sweep.is_colliding():
		var seen := {}  # Dictionary used as a set of instance_ids
		for i in range(sweep.get_collision_count()):
			var a := sweep.get_collider(i)
			if a is Area2D:
				var id := a.get_instance_id()
				if seen.has(id):
					continue
				seen[id] = true

				if a.has_method("will_fit_body_at"):
					var fits_at_target: bool = a.will_fit_body_at(self, target)
					var fits_past: bool   = a.will_fit_body_at(self, target + half_step_vec)
					if fits_at_target or fits_past:
						a.call_deferred("_trigger_collect", self)

	# Move AFTER we’ve processed
	position += motion
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

func _collect_goals_from_sweep() -> void:
	for i in range(sweep.get_collision_count()):
		var collider := sweep.get_collider(i)
		if collider is Area2D:
			# Either via group membership:
			if collider.is_in_group("Goal"):
				collider.call_deferred("trigger_collect", self)
			# Or by script/type check, e.g. if collider has a method:
			# if collider.has_method("trigger_collect"):
			#     collider.call_deferred("trigger_collect", self)
