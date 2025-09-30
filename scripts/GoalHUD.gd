extends Control

@export var square_size: int = 8
@export var gap: int = 4
@export var border_thickness: int = 1
@export var border_color: Color = Color(1, 1, 1, 1)
@export var fitted_color: Color = Color(0.2, 1.0, 0.3, 1.0)
@export var margin: Vector2i = Vector2i(8, 8)  # top-left offset

var _total: int = 0
var _collected: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.goal_progress_changed.connect(_on_progress)
	_on_progress(GameState.total_goals, GameState.collected_goals)

func _on_progress(total: int, collected: int) -> void:
	_total = max(0, total)
	_collected = clamp(collected, 0, _total)
	queue_redraw()  # Godot 4.x replacement for update()

func _get_minimum_size() -> Vector2:
	var count: int = _total
	var w: int = (count * square_size) + (max(0, count - 1) * gap)
	var h: int = square_size
	return Vector2(float(w), float(h))

const COLS := 10

func _draw() -> void:
	var start: Vector2 = Vector2(float(margin.x), float(margin.y))

	for i in range(_total):
		var col: int = i % COLS
		var row: int = int(i / COLS)   # number of full rows before this item

		var x: float = start.x + float(col) * (square_size + gap)
		var y: float = start.y + float(row) * (square_size + gap)

		var rect_size := Vector2(float(square_size), float(square_size))
		var rect := Rect2(Vector2(x, y), rect_size)

		# Fill collected ones
		if i < _collected:
			draw_rect(rect, fitted_color, true)

		# Border
		draw_rect(rect, border_color, false, float(border_thickness))
