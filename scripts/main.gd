extends Node2D

@export var goal_scene: PackedScene
@export var grid: int = 32
@export var half_cell: int = 16
#@export var cell_size := Vector2(32, 32)
#@export var grid_origin := Vector2(640.0, 480.0)
@export var winSound: AudioStream

@onready var player: Node2D = $Character
@onready var win_overlay: Control = $WinOverlay/Root
@onready var pause_overlay: Control = $PauseOverlay/Root
@onready var stopwatch: Stopwatch = $UI/Stopwatch


var rng := RandomNumberGenerator.new()
var _character_moved := false

func _ready() -> void:
	_setup_level()
	GameState.level_won.connect(func(): 
		stopwatch.stop()
		var level_time = stopwatch.get_time_ms()
		ProgressStore.set_best_time_if_better(str(GameState.current_level), level_time)
		var best_time = ProgressStore.get_best_time(str(GameState.current_level))
		stopwatch.reset_timer()
		GameState.next_level()
		GameState.save_progress()
		win_overlay.level_time = level_time
		win_overlay.best_time = best_time
		win_overlay.play_from_world(player.global_position)
		if winSound:
			var asp: AudioStreamPlayer = AudioStreamPlayer.new()
			asp.stream = winSound
			add_child(asp)
			asp.play()
			asp.finished.connect(func(): asp.queue_free())
	)
	win_overlay.restart_requested.connect(_setup_level)
	
	GameState.pause.connect(func(): 
		GameState.save_progress()
		pause_overlay.play_from_world(player.global_position)
	)
	
	player.character_moved.connect(func(_pos): 
		if not _character_moved:
			stopwatch.start()
			_character_moved = true
		)

func _setup_level() -> void:
	_character_moved = false
	var goal_count: int = GameState.level_goal_count
	rng.randomize()

	var vp: Vector2 = get_viewport_rect().size  # (1280, 960)
	# No integer division here: multiply by 0.5 and round to ints.
	var center: Vector2i = Vector2i(roundi(vp.x * 0.5), roundi(vp.y * 0.5))  # (640, 480)

	# Do float division explicitly, then floor to int — no “INTEGER_DIVISION” warning.
	var max_kx: int = floori((float(center.x) - float(half_cell)) / float(grid))
	var max_ky: int = floori((float(center.y) - float(half_cell)) / float(grid))

	var offsets: Array[Vector2i] = []
	for ky in range(-max_ky, max_ky + 1):
		for kx in range(-max_kx, max_kx + 1):
			if kx == 0 and ky == 0:
				continue
			offsets.append(Vector2i(kx, ky))

	offsets.shuffle()

	var placed := 0
	var idx := 0
	while placed < min(goal_count, offsets.size()):
		var o: Vector2i = offsets[idx]; idx += 1

		var pos_center := Vector2(
			float(center.x) + float(o.x * grid),
			float(center.y) + float(o.y * grid)
		)

		var inst: Node2D = goal_scene.instantiate() as Node2D
		inst.position = pos_center
		add_child(inst)

		placed += 1
		
	# After you compute the final list of spawn cells:
	GameState.reset_goals(goal_count)  # or goal_count actually placed
	
	
	
	
# If we want to move the square by clicking - seems like cheating
#func snap_to_grid(world_pos: Vector2) -> Vector2:
	#var p := world_pos - grid_origin
	#var cell := Vector2i(floor(p.x / cell_size.x), floor(p.y / cell_size.y))
	#return Vector2(cell) * cell_size + grid_origin + cell_size * 0.5


#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#var click_position: Vector2 = event.position
		#var snapped_position := snap_to_grid(click_position)
		#player.move_character_to(snapped_position)
