extends VBoxContainer

@export var time_entry_scene: PackedScene

func fetch_best_times() -> void:
	var best_scores: Array = await ProgressStore.get_level_top5_named(GameState.current_level)
	# (optional) clear previous entries
	for child in get_children():
		if child.is_in_group("time_entry"):
			child.queue_free()

	if best_scores.is_empty() or time_entry_scene == null:
		return

	for row in best_scores:
		var display: String = str(row.get("display_name", ""))
		var best_ms: int = int(row.get("best_ms", -1))

		var entry := time_entry_scene.instantiate()
		entry.display_name = display
		entry.time_ms = best_ms
		add_child(entry)
