extends Node

const CONFIG_PATH: String = "user://records.cfg"
const SECTION_LEVELS: String = "levels"
const SECTION_META: String = "meta"
const FILE_VERSION: int = 1

func _ensure_file_initialized() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		# Fresh file
		cfg.set_value(SECTION_META, "file_version", FILE_VERSION)
		cfg.save(CONFIG_PATH)

func get_best_time(level_id: String) -> int:
	# Returns -1 if no time is stored
	_ensure_file_initialized()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		return -1
	var v = cfg.get_value(SECTION_LEVELS, level_id, -1)
	return int(v)

func set_best_time_if_better(level_id: String, time_ms: int) -> void:
	# Only updates if it's an improvement (smaller time)
	_ensure_file_initialized()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		# If the file can't be read, start fresh
		cfg = ConfigFile.new()
		cfg.set_value(SECTION_META, "file_version", FILE_VERSION)
	var prev: int = int(cfg.get_value(SECTION_LEVELS, level_id, -1))
	if prev < 0 or time_ms < prev:
		cfg.set_value(SECTION_LEVELS, level_id, time_ms)
		cfg.save(CONFIG_PATH)

func set_best_time(level_id: String, time_ms: int) -> void:
	# Unconditional write
	_ensure_file_initialized()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		cfg = ConfigFile.new()
		cfg.set_value(SECTION_META, "file_version", FILE_VERSION)
	cfg.set_value(SECTION_LEVELS, level_id, time_ms)
	cfg.save(CONFIG_PATH)

func get_all_best_times() -> Dictionary:
	_ensure_file_initialized()
	var out: Dictionary = {}
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		return out
	var keys: PackedStringArray = cfg.get_section_keys(SECTION_LEVELS)
	for k in keys:
		out[k] = int(cfg.get_value(SECTION_LEVELS, k, -1))
	return out

func clear_level(level_id: String) -> void:
	_ensure_file_initialized()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	if cfg.has_section_key(SECTION_LEVELS, level_id):
		cfg.erase_section_key(SECTION_LEVELS, level_id)
		cfg.save(CONFIG_PATH)


func format_time_ms(ms: int) -> String:
	var total_cs: int = int(ms / 10.0)      # centiseconds
	var cs: int = total_cs % 100
	var total_s: int = int(ms / 1000.0)     # seconds
	var s: int = total_s % 60
	var m: int = int(total_s / 60.0) % 60
	var h: int = int(total_s / 3600.0)
	if h > 0:
		return "%02d:%02d:%02d.%02d" % [h, m, s, cs]
	return "%02d:%02d.%02d" % [m, s, cs]
