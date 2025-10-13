extends Node

var backend: IProgressBackend

func _ready() -> void:
	_pick_backend()
	# If you emit signals on sign-in/out, listen and swap:
	SupabaseAuth.signed_in.connect(refresh_backend)
	SupabaseAuth.signed_out.connect(refresh_backend)

func _pick_backend() -> void:
	var use_cloud := false
	use_cloud = await SupabaseAuth.ensure_fresh_token()
	backend = SupabaseProgressBackend.new() if use_cloud else LocalProgressBackend.new()
	print(backend)

# ---- Public API (thin forwarders) ----
func save_run(level_id: int, ms: int) -> void:
	await backend.save_run(level_id, ms)

func get_my_best(level_id: int) -> int:
	return await backend.get_my_best(level_id)

func get_level_top5(level_id: int) -> Array:
	return await backend.get_level_top5(level_id)

# Optionally call this after explicit login/logout to re-select backend
func refresh_backend() -> void:
	_pick_backend()
	
# --- Public Progress API ---

func save_progress(last_level: int) -> void:
	if backend == null: _pick_backend()
	await backend.save_progress(last_level)

func load_progress() -> Dictionary:
	if backend == null: _pick_backend()
	return await backend.load_progress()

func has_progress() -> bool:
	if backend == null: _pick_backend()
	return await backend.has_progress()

func reset_progress() -> void:
	if backend == null: _pick_backend()
	await backend.reset_progress()
