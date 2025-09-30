extends Control

@onready var has_progress_h_box: HBoxContainer = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox
@onready var start_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/StartBtn
@onready var continue_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox/ContinueBtn
@onready var restart_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox/RestartBtn


func _ready() -> void:
	has_progress_h_box.visible = false
	start_btn.visible = false
	
	if GameState.has_progress():
		has_progress_h_box.visible = true
		continue_btn.grab_focus()
		continue_btn.pressed.connect(_on_continue_pressed)
		restart_btn.pressed.connect(_on_restart_pressed)
	else:
		start_btn.visible = true
		start_btn.grab_focus()
		start_btn.pressed.connect(_on_start_pressed)
		
func _on_continue_pressed() -> void:
	GameState.load_progress()
	SceneManager.go_to("res://scenes/Main.tscn")

func _on_restart_pressed() -> void:
	GameState.reset_progress()
	SceneManager.go_to("res://scenes/Main.tscn")
	
func _on_start_pressed() -> void:
	SceneManager.go_to("res://scenes/Main.tscn")
