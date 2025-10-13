extends Control

@export var next_scene_path: String = "res://scenes/start_screen.tscn"

@onready var email_input: LineEdit      = %EmailInput
@onready var password_input: LineEdit   = %PasswordInput
@onready var login_btn: Button          = %LoginBtn
@onready var play_as_guest_btn: Button = %PlayAsGuestBtn
@onready var logout_btn: Button         = %LogoutBtn
@onready var status_label: Label        = %StatusLabel
@onready var title_label: Label         = %TitleLabel
@onready var display_name_container: VBoxContainer = $CenterContainer/DisplayNameContainer
@onready var sign_in_container: VBoxContainer = $CenterContainer/SignInContainer


func _ready() -> void:
	_wire_ui()
	await _attempt_auto_login()

func _wire_ui() -> void:
	login_btn.pressed.connect(_on_login_pressed)
	play_as_guest_btn.pressed.connect(_on_play_as_guest_pressed)
	logout_btn.pressed.connect(_on_logout_pressed)
	password_input.text_submitted.connect(func(_t): login_btn.emit_signal("pressed"))
	email_input.text_submitted.connect(func(_t): password_input.grab_focus())

func _set_ui_busy(busy: bool) -> void:
	login_btn.disabled = busy
	play_as_guest_btn.disabled = busy
	logout_btn.disabled = busy
	email_input.editable = not busy
	password_input.editable = not busy
	status_label.text = "Working..." if busy else status_label.text

func _show_authed_ui() -> void:
	var uname := ""
	if typeof(SupabaseAuth.user) == TYPE_DICTIONARY:
		uname = str(SupabaseAuth.user.get("email", ""))
	title_label.text = "Welcome"
	status_label.text = "Signed in as %s" % uname
	logout_btn.visible = true
	login_btn.visible = false
	play_as_guest_btn.visible = false
	email_input.visible = false
	password_input.visible = false

func _show_login_ui() -> void:
	title_label.text = "Sign In"
	status_label.text = ""
	logout_btn.visible = false
	login_btn.visible = true
	play_as_guest_btn.visible = true
	email_input.visible = true
	password_input.visible = true
	email_input.grab_focus()

# Try to reuse a saved session and continue
func _attempt_auto_login() -> void:
	_set_ui_busy(true)
	var ok := await SupabaseAuth.ensure_fresh_token()
	_set_ui_busy(false)
	if ok:
		_show_authed_ui()
		_go_next()
	else:
		_show_login_ui()

func _on_login_pressed() -> void:
	var email := email_input.text.strip_edges()
	var pw := password_input.text
	if email == "" or pw == "":
		status_label.text = "Please enter email and password."
		return

	_set_ui_busy(true)
	status_label.text = "Signing in..."
	var ok := await SupabaseAuth.sign_in(email, pw)
	_set_ui_busy(false)

	if ok:
		_show_authed_ui()
		_go_next()
	else:
		status_label.text = "Login failed. Check credentials and network."

func _on_logout_pressed() -> void:
	_set_ui_busy(true)
	SupabaseAuth.sign_out(true) # remote=true to invalidate server-side
	_set_ui_busy(false)
	_show_login_ui()
	status_label.text = "Signed out."

func _on_play_as_guest_pressed() -> void:
	SceneManager.go_to(next_scene_path)

func _go_next() -> void:
	var display_name = SupabaseAuth.get_display_name()
	if display_name == "":
		_show_display_name_form()
	else:
		# Small delay so the UI can update before switching
		await get_tree().create_timer(0.05).timeout
		SceneManager.go_to(next_scene_path)


func _show_display_name_form() -> void:
	sign_in_container.visible = false
	display_name_container.visible = true
