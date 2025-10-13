extends IProgressBackend
class_name LocalProgressBackend

const FILE := "user://progress.cfg"

func save_run(level_id: int, ms: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	var key := str(level_id)
	var best := int(cfg.get_value("best", key, -1))
	if best == -1 or ms < best:
		cfg.set_value("best", key, ms)
	cfg.save(FILE)

func get_my_best(level_id: int) -> int:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	return int(cfg.get_value("best", str(level_id), -1))

func get_level_top5(level_id: int) -> Array:
	# Local mode: no global board; synthesize from local best.
	var best := get_my_best(level_id)
	return [] if best == -1 else [ { "level_id": level_id, "user_id": "local", "best_ms": best } ]

# --- PROGRESS API ---

func save_progress(last_level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("progress", "last_level", last_level)
	cfg.set_value("progress", "played", true)
	cfg.save(FILE)

func load_progress() -> Dictionary:
	var cfg := ConfigFile.new()
	var ok := cfg.load(FILE)
	if ok != OK:
		return {}
	var level := int(cfg.get_value("progress", "last_level", -1))
	var played := bool(cfg.get_value("progress", "played", false))
	return {} if level == -1 else { "last_level": level, "played": played }

func has_progress() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return false
	return cfg.has_section_key("progress", "last_level")

func reset_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		# wipe just the progress keys (keep your PBs in [best])
		if cfg.has_section("progress"):
			cfg.erase_section("progress")
		cfg.save(FILE)
