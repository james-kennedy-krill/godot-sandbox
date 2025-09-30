# SceneManager.gd — usage guide
#
# Basic change with fade:
#     SceneManager.go_to("res://scenes/MainMenu.tscn")
#
# Pass data into the next scene:
#     SceneManager.go_to("res://scenes/Level.tscn", {"level_id": 3})
#
# In Level.tscn's root script:
#     func set_scene_data(data: Dictionary) -> void:
#         if data.has("level_id"):
#             _load_level(int(data["level_id"]))
#
# Reload current scene:
#     SceneManager.reload()
#
# Preload to avoid hitching later:
#     SceneManager.preload_scenes([
#         "res://scenes/MainMenu.tscn",
#         "res://scenes/Level.tscn",
#         "res://scenes/Settings.tscn",
#     ])
#
# Adjust fade speed:
#     SceneManager.go_to("res://scenes/Level.tscn", {}, 0.4) # 0.4s fade


extends Node

signal scene_changed(new_scene: Node)

var current_scene: Node
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _cache: Dictionary = {} # path:String -> PackedScene
var fade_color: Color = Color(0, 0, 0, 1) # default to black

const DEFAULT_FADE_TIME: float = 0.25

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Defer overlay creation so the root finishes adding its own children first.
	call_deferred("_ensure_overlay_exists")


func _ready() -> void:
	current_scene = get_tree().current_scene

func go_to(path: String, data: Dictionary = {}, fade_time: float = DEFAULT_FADE_TIME) -> void:
	await _go_to_async(path, data, fade_time)

func reload(fade_time: float = DEFAULT_FADE_TIME) -> void:
	if current_scene == null:
		return
	var path: String = current_scene.scene_file_path
	await _go_to_async(path, {}, fade_time)

func preload_scenes(paths: Array) -> void:
	for p in paths:
		if typeof(p) == TYPE_STRING and not _cache.has(p):
			var res: Resource = ResourceLoader.load(p)
			if res is PackedScene:
				_cache[p] = res

func is_cached(path: String) -> bool:
	return _cache.has(path)

func get_current_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""

# --- internals ---

func _ensure_overlay_exists() -> void:
	if is_instance_valid(_fade_layer) and is_instance_valid(_fade_rect):
		return
	_build_fade_overlay()

func _build_fade_overlay() -> void:
	if is_instance_valid(_fade_layer):
		return
	var root: Window = get_tree().root
	if root == null:
		# Try again next frame if the root isn't ready yet.
		call_deferred("_build_fade_overlay")
		return

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 4096
	_fade_layer.name = "SceneManagerFade"

	# IMPORTANT: use deferred add to avoid "Parent node is busy" error
	root.call_deferred("add_child", _fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = fade_color
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Fullscreen anchors
	_fade_rect.anchor_left = 0.0
	_fade_rect.anchor_top = 0.0
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0

	# Also defer adding the ColorRect to the CanvasLayer
	_fade_layer.call_deferred("add_child", _fade_rect)


func _fade(to_opaque: bool, secs: float) -> void:
	_ensure_overlay_exists()
	# Wait one frame to guarantee the deferred add_childs are committed
	await get_tree().process_frame

	if secs <= 0.0:
		_fade_rect.modulate.a = 1.0 if to_opaque else 0.0
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_rect, "modulate:a", 1.0 if to_opaque else 0.0, secs)
	await tween.finished


func _load_packed(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var res: Resource = ResourceLoader.load(path)
	if res is PackedScene:
		return res
	push_error("SceneManager: Failed to load PackedScene: %s" % path)
	return null

func _instantiate_with_data(packed: PackedScene, data: Dictionary) -> Node:
	var node: Node = packed.instantiate()
	if node.has_method("set_scene_data"):
		node.call("set_scene_data", data)
	return node

func _swap_scene(new_scene: Node) -> void:
	var root: Window = get_tree().root
	root.add_child(new_scene)

	# Keep the fade layer above any other CanvasLayers
	_ensure_fade_on_top()

	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()

	get_tree().current_scene = new_scene
	current_scene = new_scene
	emit_signal("scene_changed", new_scene)




func _viewport_block_input(block: bool) -> void:
	var vp: Viewport = get_viewport()
	if vp:
		vp.gui_disable_input = block

func _go_to_async(path: String, data: Dictionary, fade_time: float) -> void:
	_ensure_overlay_exists()

	_viewport_block_input(true)
	await _fade(true, fade_time)

	var packed: PackedScene = _load_packed(path)
	if packed == null:
		await _fade(false, fade_time)
		_viewport_block_input(false)
		return

	var new_scene: Node = _instantiate_with_data(packed, data)
	_swap_scene(new_scene)

	await _fade(false, fade_time)
	_viewport_block_input(false)

# Optional: quick debug helper to force the overlay visible
func debug_show_overlay() -> void:
	_ensure_overlay_exists()
	_fade_rect.modulate.a = 0.6

func _ensure_fade_on_top() -> void:
	_ensure_overlay_exists()
	var max_layer: int = 0
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child != _fade_layer:
			var cl: CanvasLayer = child
			if cl.layer > max_layer:
				max_layer = cl.layer
	_fade_layer.layer = max_layer + 1
