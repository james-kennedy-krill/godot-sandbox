extends VBoxContainer

@export var next_scene_path: String = "res://scenes/start_screen.tscn"

@onready var picker: InitialsPicker = $InitialsPicker
@onready var save_btn: Button = $SaveBtn
@onready var status: Label = $StatusLabel

func _ready() -> void:
	picker.initials_changed.connect(func(txt): status.text = "Preview: %s" % txt)
	save_btn.pressed.connect(_on_save)

func _on_save() -> void:
	var new_name: String = picker.get_initials()
	status.text = "Saving %s..." % new_name
	var ok := await set_user_names(new_name)
	status.text = "Saved!" if ok else "Save failed."
	if ok:
		await get_tree().create_timer(0.05).timeout
		SceneManager.go_to(next_scene_path)

# Uses your SupabaseAuth authed_request to PATCH user metadata
func _update_display_name(new_name: String) -> bool:
	var url := "%s/auth/v1/user" % SupabaseAuth.supabase_url
	var payload := { "data": { "display_name": new_name } }
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_PATCH, payload)
	if resp.success and typeof(resp.json) == TYPE_DICTIONARY:
		SupabaseAuth.user = resp.json
		SupabaseAuth._save_session()
		return true
	return false

# Update both display_name + full_name (dashboard + app)
func set_user_names(new_name: String) -> bool:
	var url := "%s/auth/v1/user" % SupabaseAuth.supabase_url
	var payload := { "data": { "display_name": new_name, "full_name": new_name } }

	# MUST be PUT for GoTrue /auth/v1/user
	var resp := await SupabaseAuth.authed_request(
		url,
		HTTPClient.METHOD_PUT,
		payload
	)

	if resp.success:
		# Usually returns the updated user JSON; if not, fetch it.
		if typeof(resp.json) == TYPE_DICTIONARY:
			SupabaseAuth.user = resp.json
		else:
			var r2 := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET)
			if r2.success and typeof(r2.json) == TYPE_DICTIONARY:
				SupabaseAuth.user = r2.json
		SupabaseAuth._save_session()
		return true

	push_warning("Display name update failed: %s (%s)" % [resp.code, resp.text])
	return false
