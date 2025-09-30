# WinOverlay.gd
extends Control
signal unpause_requested

@onready var flash: ColorRect = $Flash
@onready var ui: CenterContainer = $UI
@onready var continue_btn: Button = $UI/VBoxContainer/ContinueBtn
@onready var main_menu_btn: Button = $UI/VBoxContainer/MainMenuBtn
@onready var quit_btn: Button = $UI/VBoxContainer/QuitBtn

@export var grow_time: float = 0.25
@export var feather: float = 12.0
@export var ui_fade_time: float = 0.20


var _mat: ShaderMaterial

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = flash.material as ShaderMaterial
	if _mat == null:
		push_warning("WinOverlay: Flash is missing a ShaderMaterial.")
	continue_btn.pressed.connect(_unpause)
	main_menu_btn.pressed.connect(func(): SceneManager.go_to("res://scenes/start_screen.tscn"))
	quit_btn.pressed.connect(func(): get_tree().quit())

func play_from_world(world_pos: Vector2) -> void:
	# Convert world → screen (canvas) using the viewport's canvas transform
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = ct * world_pos

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	ui.visible = false
	ui.modulate = Color(1, 1, 1, 0)

	# Prepare shader
	var vp: Vector2 = get_viewport_rect().size
	if _mat != null:
		_mat.set_shader_parameter("center_px", screen_pos)
		_mat.set_shader_parameter("radius", 0.0)
		_mat.set_shader_parameter("feather", feather)
		_mat.set_shader_parameter("viewport_size", vp)  # <-- set it here


	# Compute max radius to cover screen from that point (distance to corners)
	var corners: Array[Vector2] = [Vector2(0,0), Vector2(vp.x,0), Vector2(0,vp.y), Vector2(vp.x,vp.y)]
	var max_r: float = 0.0
	for c in corners:
		var d: float = screen_pos.distance_to(c)
		if d > max_r:
			max_r = d
	

	# Animate the wipe radius
	var tw: Tween = create_tween()
	tw.tween_method(func(v): if _mat != null: _mat.set_shader_parameter("radius", v),
		0.0, max_r, grow_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Show centered UI and fade it in
	ui.visible = true
	var tw2: Tween = create_tween()
	tw2.tween_property(ui, "modulate:a", 1.0, ui_fade_time)
	await tw2.finished
	continue_btn.grab_focus()

func _unpause() -> void:
	# 1) Fade the centered UI out (if visible)
	if ui.visible:
		var fade_out: Tween = create_tween()
		fade_out.tween_property(ui, "modulate:a", 0.0, ui_fade_time)
		await fade_out.finished
		ui.visible = false

	# 2) Animate the wipe radius back to 0 (reverse of play_from_world)
	if _mat != null:
		var start_radius: float = 0.0

		# Try to read the current radius, otherwise compute a safe starting radius
		var r: float = _mat.get_shader_parameter("radius")
		if typeof(r) == TYPE_FLOAT:
			start_radius = float(r)
		else:
			var vp: Vector2 = get_viewport_rect().size
			var center_any = _mat.get_shader_parameter("center_px")
			var center: Vector2 = center_any if typeof(center_any) == TYPE_VECTOR2 else vp * 0.5
			var corners: Array[Vector2] = [Vector2(0,0), Vector2(vp.x,0), Vector2(0,vp.y), Vector2(vp.x,vp.y)]
			for c in corners:
				var d: float = center.distance_to(c)
				if d > start_radius:
					start_radius = d

		var tw: Tween = create_tween()
		tw.tween_method(
			func(v: float) -> void:
				if _mat != null:
					_mat.set_shader_parameter("radius", v),
			start_radius, 0.0, grow_time
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await tw.finished

	# 3) Hide overlay and restore input behavior
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Optional: release any focused control so gameplay input resumes cleanly
	if get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_release_focus()

	emit_signal("unpause_requested")
