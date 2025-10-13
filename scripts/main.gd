extends Node2D

@export var goal_scene: PackedScene
@export var grid: int = 32
@export var half_cell: int = 16
@export var TOP_MARGIN: int = 120      # pixels to skip from top
@export var BOTTOM_MARGIN: int = 180   # pixels to skip from bottom

@onready var player: Node2D = $Character
@onready var win_overlay: Control = $WinOverlay/Root
@onready var pause_overlay: Control = $PauseOverlay/Root
@onready var stopwatch: Label = %Stopwatch
@onready var best_time_label: Label = %BestTime
@onready var clock_instructions: Label = %ClockInstructions
@onready var initials_label: Label = %InitialsLabel
@onready var level_name_label: Label = %LevelNameLabel
@onready var personal_best_label: Label = %PersonalBestLabel

const DEFAULT_TIME_LABEL = "--:--.--"

var rng := RandomNumberGenerator.new()
var _character_moved := false
var level_best_time: int

func _ready() -> void:
	_setup_ui()
	_setup_level()
	GameState.level_won.connect(func(): 
		# Stop the stopwatch
		Stopwatch.stop()
		# get the time
		var level_time = Stopwatch.get_time_ms()
		await ProgressStore.save_run(GameState.current_level, level_time)
		
		# save the time if its the best
		#ProgressStore.set_best_time_if_better(str(GameState.current_level), level_time)
		
		# get the best time (saved)
		#var best_time = ProgressStore.get_best_time(str(GameState.current_level))
		
			
		# now reset the stopwatch ad level, and save progress
		win_overlay.level_time = level_time
		win_overlay.best_time = level_best_time
		win_overlay.play_from_world(player.global_position)
		clock_instructions.visible = true
	)
	win_overlay.restart_requested.connect(_setup_level)
	
	GameState.pause.connect(func(): 
		clock_instructions.visible = true
		_character_moved = false
		Stopwatch.stop()
		ProgressStore.save_progress(GameState.current_level)
		pause_overlay.play_from_world(player.global_position)
	)
	GameState.unpause.connect(func():
		pause_overlay.unpause()
	)
	
	player.character_moved.connect(func(_pos): 
		if not _character_moved:
			clock_instructions.visible = false
			Stopwatch.start()
			_character_moved = true
		)

func _setup_level() -> void:
	personal_best_label.text = "LOADING"
	best_time_label.text = "LOADING"
	_character_moved = false
	Stopwatch.reset_timer()
	var goal_count: int = GameState.level_goal_count
	rng.randomize()

	# Viewport + play area
	var vp: Vector2i = Vector2i(get_viewport_rect().size)  # e.g. (1280,960)
	var play_top: int = clamp(TOP_MARGIN, 0, vp.y)
	var play_bottom: int = clamp(vp.y - BOTTOM_MARGIN, 0, vp.y)
	if play_bottom <= play_top:
		push_warning("Play area height is <= 0. Adjust TOP_MARGIN/BOTTOM_MARGIN.")
		return
	var play_height: int = play_bottom - play_top

	# Center the grid within the play area vertically; horizontally use full width
	var center: Vector2i = Vector2i(
		roundi(vp.x * 0.5),
		play_top + roundi(float(play_height) * 0.5)
	)

	# Horizontal radius (symmetric left/right)
	var max_kx_left: int  = floori((float(center.x) - float(half_cell)) / float(grid))
	var max_kx_right: int = floori(((float(vp.x) - float(center.x)) - float(half_cell)) / float(grid))

	# Vertical radius (asymmetric: up limited by play_top, down limited by play_bottom)
	var max_ky_up: int    = floori(((float(center.y) - float(play_top)) - float(half_cell)) / float(grid))
	var max_ky_down: int  = floori(((float(play_bottom) - float(center.y)) - float(half_cell)) / float(grid))

	# Build all candidate cell offsets inside the play area
	var offsets: Array[Vector2i] = []
	for ky in range(-max_ky_up, max_ky_down + 1):
		for kx in range(-max_kx_left, max_kx_right + 1):
			if kx == 0 and ky == 0:
				continue
			offsets.append(Vector2i(kx, ky))

	offsets.shuffle()

	var placed: int = 0
	var idx: int = 0
	var max_to_place: int = min(goal_count, offsets.size())
	
	# (Optional) last-guard: skip any cell that would clip margins due to rounding
	var min_y: float = float(play_top) + float(half_cell)
	var max_y: float = float(play_bottom) - float(half_cell)

	while placed < max_to_place and idx < offsets.size():
		var o: Vector2i = offsets[idx]; idx += 1

		var pos_center := Vector2(
			float(center.x) + float(o.x * grid),
			float(center.y) + float(o.y * grid)
		)

		# Last-guard check (usually redundant with the computed ranges)
		if pos_center.y < min_y or pos_center.y > max_y:
			continue

		var inst: Node2D = goal_scene.instantiate() as Node2D
		inst.position = pos_center
		add_child(inst)
		placed += 1

	# bookkeeping
	GameState.reset_goals(placed)  # use placed in case fewer fit than requested
	level_name_label.text = "Level %d" % GameState.current_level
	
	# Fetch best time for level from all users, also gets top 5 times
	var level_best_times = await ProgressStore.get_level_top5(GameState.current_level)
	if level_best_times and level_best_times.size() > 0:
		var best_time: Dictionary = level_best_times[0]
		level_best_time = best_time.get("best_ms")
		var best_time_str = Stopwatch.format_time_ms(level_best_time)
		best_time_label.text = best_time_str
	else:
		best_time_label.text = DEFAULT_TIME_LABEL
		level_best_time = 0
		
	
	# Fetch best time for current authed user
	var my_best_time = await ProgressStore.get_my_best(GameState.current_level)
	if my_best_time > 0:
		var my_best_time_str = Stopwatch.format_time_ms(my_best_time)
		personal_best_label.text = my_best_time_str
	else:
		personal_best_label.text = DEFAULT_TIME_LABEL
	GameState.start_level()
	
func _setup_ui() -> void:
	win_overlay.get_parent().visible = true
	pause_overlay.get_parent().visible = true
	
	var display_name = SupabaseAuth.get_display_name()
	initials_label.text = display_name if display_name != "" else "GUEST"
	
