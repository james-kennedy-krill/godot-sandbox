extends Control

@onready var has_progress_h_box: VBoxContainer = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox
@onready var start_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/StartBtn
@onready var continue_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox/ContinueBtn
@onready var restart_btn: Button = $Panel/CenterContainer/VBoxContainer/Control/HasProgressHBox/RestartBtn
@onready var sign_out_btn: Button = $Panel/CenterContainer/VBoxContainer/SignOutBtn


func _ready() -> void:
	has_progress_h_box.visible = false
	start_btn.visible = false
	
	sign_out_btn.pressed.connect(_on_signout_pressed)
	
	if await ProgressStore.has_progress():
		has_progress_h_box.visible = true
		continue_btn.grab_focus()
		continue_btn.pressed.connect(_on_continue_pressed)
		restart_btn.pressed.connect(_on_restart_pressed)
	else:
		start_btn.visible = true
		start_btn.grab_focus()
		start_btn.pressed.connect(_on_start_pressed)
		
func _on_continue_pressed() -> void:
	var prog: Dictionary = await ProgressStore.load_progress()
	var last := int(prog.get("last_level", 1))
	GameState.load_level(last)
	SceneManager.go_to("res://scenes/Main.tscn")

func _on_restart_pressed() -> void:
	ProgressStore.reset_progress()
	SceneManager.go_to("res://scenes/Main.tscn")
	
func _on_start_pressed() -> void:
	SceneManager.go_to("res://scenes/Main.tscn")

func _on_signout_pressed() -> void:
	SupabaseAuth.sign_out()
	SceneManager.go_to("res://scenes/Login.tscn")
