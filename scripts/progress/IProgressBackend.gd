extends RefCounted
class_name IProgressBackend

func save_run(level_id: int, ms: int) -> void:        push_error("Not implemented")
func get_my_best(level_id: int) -> int:                push_error("Not implemented"); return -1
func get_level_top5(level_id: int) -> Array:           push_error("Not implemented"); return []
func save_progress(last_level: int) -> void: pass
func load_progress() -> Dictionary: return {}
func has_progress() -> bool: return false
func reset_progress() -> void: pass
