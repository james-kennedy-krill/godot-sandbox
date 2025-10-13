# Goal.gd
extends Area2D
signal collected(body: Node2D)

@onready var mesh2d: MeshInstance2D = $MeshInstance2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var sfx: AudioStreamPlayer2D = $SFX

# ---- Visual / shader params ----
@export var fitted_color: Color = Color(0.2, 1.0, 0.3, 1.0)  # interior fill when fitted
@export var border_on_fit_glow: float = 3.0                  # optional extra glow punch

# ---- Animation tuning ----
@export var pop_scale: float = 1.15      # brief grow amount
@export var pop_time: float = 0.12
@export var collapse_time: float = 0.18
@export var fade_time: float = 0.16

# ---- State ----
var _collected: bool = false
var _pending_frees: int = 0  # gate counter; when it reaches 0 we free

func _ready() -> void:
	monitoring = true
	monitorable = true

	# Ensure unique material per instance so color/glow edits don't leak to others
	var sm: ShaderMaterial = mesh2d.material as ShaderMaterial
	if sm != null:
		mesh2d.material = (sm.duplicate() as ShaderMaterial)

func _physics_process(_delta: float) -> void:
	if _collected:
		return

	var bodies: Array = get_overlapping_bodies()
	for b in bodies:
		if (b is CharacterBody2D or b is StaticBody2D):
			var body_node: Node2D = b
			if _is_body_fully_inside(body_node):
				_trigger_collect(body_node)
				break

func _trigger_collect(body: Node2D) -> void:
	if _collected:
		return                # <-- guard: already counted
	_collected = true
	GameState.goal_collected()
	emit_signal("collected", body)

	# Stop interactions
	monitoring = false
	if col != null:
		col.disabled = true

	# Flip shader to "fitted" look
	var sm: ShaderMaterial = mesh2d.material as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter("fitted", 1.0)
		sm.set_shader_parameter("fitted_color", fitted_color)
		if _has_shader_param(sm, &"glow_strength"):
			sm.set_shader_parameter("glow_strength", border_on_fit_glow)

	# --- Start gate: we'll wait for tween, and optionally for SFX ---
	_begin_free_gate(1)  # always wait for animation tween

	# Pop → snap animation (scale); separate fade runs in parallel after the pop
	var tw: Tween = create_tween()
	tw.set_parallel(false)
	tw.tween_property(self, "scale", Vector2(pop_scale, pop_scale), pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ZERO, collapse_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.finished.connect(_mark_gate_done)

	var fade: Tween = create_tween()
	fade.set_parallel(false)
	fade.tween_interval(pop_time)
	fade.tween_property(self, "modulate:a", 0.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# SFX: if present, also wait for it to finish (finished won't fire on looping clips)
	if sfx != null and sfx.stream != null:
		_add_free_gate(1)
		sfx.stop()
		sfx.play()
		sfx.finished.connect(_mark_gate_done)

# ---------------- Gate helpers ----------------
func _begin_free_gate(count: int) -> void:
	_pending_frees = count

func _add_free_gate(count: int) -> void:
	_pending_frees += count

func _mark_gate_done() -> void:
	_pending_frees -= 1
	if _pending_frees <= 0:
		queue_free()

# ---------------- Shader uniform presence check ----------------
# Checks if the ShaderMaterial exposes a given uniform (by property name)
func _has_shader_param(mat: ShaderMaterial, pname: StringName) -> bool:
	var target: String = "shader_param/" + String(pname)
	var props: Array = mat.get_property_list()  # Array<Dictionary>
	for prop in props:
		if prop.has("name") and String(prop["name"]) == target:
			return true
	return false

# ---------------- Full-fit check (RectangleShape2D) ----------------
func _is_body_fully_inside(body: Node2D) -> bool:
	var area_cs: CollisionShape2D = $CollisionShape2D
	if area_cs == null:
		return false
	var area_rect: RectangleShape2D = area_cs.shape as RectangleShape2D
	if area_rect == null:
		return false

	var body_cs: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_cs == null:
		return false
	var body_rect: RectangleShape2D = body_cs.shape as RectangleShape2D
	if body_rect == null:
		return false

	var half_area: Vector2 = area_rect.size * 0.5
	var half_body: Vector2 = body_rect.size * 0.5

	# Transform body corners into this Area's local space
	var to_area: Transform2D = global_transform.affine_inverse() * body.global_transform
	var corners: Array[Vector2] = [
		Vector2(-half_body.x, -half_body.y),
		Vector2( half_body.x, -half_body.y),
		Vector2( half_body.x,  half_body.y),
		Vector2(-half_body.x,  half_body.y),
	]
	for c in corners:
		var p: Vector2 = to_area * c
		if absf(p.x) > half_area.x or absf(p.y) > half_area.y:
			return false
	return true

# Will the given body fully fit inside this Area if the body were at at_global_pos?
func will_fit_body_at(body: Node2D, at_global_pos: Vector2) -> bool:
	var area_cs: CollisionShape2D = $CollisionShape2D
	if area_cs == null:
		return false
	var area_rect: RectangleShape2D = area_cs.shape as RectangleShape2D
	if area_rect == null:
		return false

	var body_cs: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_cs == null:
		return false
	var body_rect: RectangleShape2D = body_cs.shape as RectangleShape2D
	if body_rect == null:
		return false

	var half_area: Vector2 = area_rect.size * 0.5
	var half_body: Vector2 = body_rect.size * 0.5

	# Pretend the body is at at_global_pos (keep its basis)
	var body_xf: Transform2D = body.global_transform
	body_xf.origin = at_global_pos

	var to_area: Transform2D = global_transform.affine_inverse() * body_xf
	var corners: Array[Vector2] = [
		Vector2(-half_body.x, -half_body.y),
		Vector2( half_body.x, -half_body.y),
		Vector2( half_body.x,  half_body.y),
		Vector2(-half_body.x,  half_body.y),
	]
	for c in corners:
		var p: Vector2 = to_area * c
		if absf(p.x) > half_area.x or absf(p.y) > half_area.y:
			return false
	return true
