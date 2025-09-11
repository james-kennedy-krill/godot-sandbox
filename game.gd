extends Node2D

# ===== Spawn tuning =====
@export var star_outer_radius: float = 40.0
@export var star_inner_ratio: float = 0.5
@export var star_points: int = 5
@export var star_color: Color = Color(1.0, 0.85, 0.2, 1.0)

@export var spawn_interval: float = 1.0   # seconds between spawns while holding

# ===== Explosion + FX tuning =====
@export var star_lifetime: float = 5.0        # seconds before exploding
@export var countdown_last_secs: float = 3.0  # countdown duration (shows only for last N seconds)
@export var explode_lifetime: float = 0.6     # particle lifetime (s)
@export var fade_time: float = 0.35           # total pop+collapse time (s)
@export var explode_particles: int = 80

var _spawn_timer: float = 0.0
var _mouse_down: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if _mouse_down:
			_spawn_timer = 0.0

func _process(delta: float) -> void:
	if _mouse_down:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var world_pos: Vector2 = get_global_mouse_position()
			var local_pos: Vector2 = to_local(world_pos)
			spawn_star(local_pos)
			_spawn_timer = spawn_interval

# -------------------------
# Spawns a RigidBody2D star that self-destructs after star_lifetime
# -------------------------
func spawn_star(local_pos: Vector2) -> void:
	var body := RigidBody2D.new()
	body.position = local_pos
	body.linear_damp = 0.05
	body.angular_damp = 0.05
	add_child(body)

	# Visual star
	var poly := Polygon2D.new()
	var pts := make_star_points(star_points, star_outer_radius, star_outer_radius * star_inner_ratio, -PI/2.0)
	poly.polygon = pts
	poly.color = star_color
	poly.antialiased = true
	poly.z_index = 1000
	body.add_child(poly)

	# Collision (convex decomposition for dynamic body)
	var convexes: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(pts)
	for c: PackedVector2Array in convexes:
		var shape := ConvexPolygonShape2D.new()
		shape.points = c
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)

	# Schedule the countdown to appear only for the final N seconds
	var countdown_delay: float = max(0.0, star_lifetime - countdown_last_secs)
	if countdown_last_secs > 0.0 and countdown_delay >= 0.0:
		show_countdown_after(body, countdown_delay, countdown_last_secs, star_outer_radius * star_inner_ratio)

	# Schedule explosion
	explode_after(body, poly, star_lifetime)

# -------------------------
# Spawns a centered ticking countdown Node2D after `delay_s`
# -------------------------
func show_countdown_after(body: RigidBody2D, delay_s: float, duration_s: float, inner_radius: float) -> void:
	await get_tree().create_timer(delay_s).timeout
	if !is_instance_valid(body):
		return
	var cd := Countdown2D.new()
	cd.total_time = duration_s
	cd.font_size = int(max(8.0, inner_radius * 0.9))  # small enough to fit inside star center
	cd.modulate = Color(1, 1, 1, 1)
	cd.z_index = 1002
	body.add_child(cd)

# -------------------------
# After `delay_s`, burst particles, expand→collapse+fade, then remove the body
# -------------------------
func explode_after(body: RigidBody2D, poly: Polygon2D, delay_s: float) -> void:
	await get_tree().create_timer(delay_s).timeout
	if !is_instance_valid(body):
		return

	body.freeze = true
	for child in body.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true

	# Particle burst
	var particles := make_explosion_particles(star_color, explode_particles, explode_lifetime)
	body.add_child(particles)
	particles.emitting = true

	# === Snappier expand → collapse + fade ===
	var pop_up: float = fade_time * 0.45
	var hold: float = fade_time * 0.10
	var collapse: float = fade_time * 0.35

	# Scale tween (expand, brief hold, then collapse)
	var scale_tween := create_tween()
	scale_tween.tween_property(poly, "scale", Vector2.ONE * 1.35, pop_up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_interval(hold)
	scale_tween.tween_property(poly, "scale", Vector2.ZERO, collapse).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Opacity tween (start fading shortly after the pop begins)
	var fade_total: float = pop_up + hold + collapse
	var fade_delay: float = pop_up * 0.25
	var fade_duration: float = max(0.1, fade_total - fade_delay)
	var fade_tween := create_tween()
	fade_tween.tween_interval(fade_delay)
	fade_tween.tween_property(poly, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Also fade & shrink any countdown child
	for child in body.get_children():
		if child is Countdown2D:
			var c := child as Countdown2D
			var t := create_tween()
			t.tween_property(c, "scale", Vector2.ZERO, collapse).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(c, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Wait for both FX and particles to finish
	var wait_time: float = max(explode_lifetime, fade_total) + 0.05
	await get_tree().create_timer(wait_time).timeout
	if is_instance_valid(body):
		body.queue_free()

# -------------------------
# Build a simple star polygon
# -------------------------
func make_star_points(n_points: int, r_outer: float, r_inner: float, rotation_rad: float = -PI * 0.5) -> PackedVector2Array:
	n_points = max(2, n_points)
	r_inner = clamp(r_inner, 0.0, r_outer - 0.0001)

	var verts: Array[Vector2] = []
	var step: float = PI / float(n_points)  # alternate outer/inner
	for i in range(n_points * 2):
		var angle: float = rotation_rad + step * float(i)
		var r: float = r_outer if i % 2 == 0 else r_inner
		verts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return PackedVector2Array(verts)

# -------------------------
# Create a one-shot GPUParticles2D burst
# -------------------------
func make_explosion_particles(base_color: Color, amount: int, lifetime_s: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime_s
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = true
	p.z_index = 1001

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 260.0
	mat.gravity = Vector3(0, 600.0, 0)
	mat.damping_min = 0.8
	mat.damping_max = 1.2
	mat.scale_min = 0.4
	mat.scale_max = 0.9

	# Color ramp → Texture2D
	var ramp: Gradient = Gradient.new()
	ramp.add_point(0.0, base_color.lightened(0.2))
	ramp.add_point(0.5, Color(1.0, 0.55, 0.0, 0.9))
	ramp.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex

	p.process_material = mat
	return p

# =========================================================
# Countdown2D: draws a centered ticking number in world space
# =========================================================
class Countdown2D:
	extends Node2D

	@export var total_time: float = 3.0   # seconds to count down from
	@export var font_size: int = 18
	@export var tick_pulse_scale: float = 0.18  # how big the tick pulse gets

	var _time_left: float = 0.0
	var _last_whole: int = -1

	func _ready() -> void:
		_time_left = total_time
		set_process(true)

	func _process(delta: float) -> void:
		_time_left = max(0.0, _time_left - delta)
		# Ticking pulse: brief bump at each whole-second boundary
		var whole: int = int(ceil(_time_left))
		var frac: float = _time_left - floor(_time_left)  # [0..1)
		var pulse: float = 0.0
		# Strong pulse during first ~0.12s after the tick
		if frac > 0.88:
			var t: float = (frac - 0.88) / 0.12 # 0..1
			pulse = (1.0 - t) * tick_pulse_scale
		self.scale = Vector2.ONE * (1.0 + pulse)

		queue_redraw()

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		if font == null:
			return

		var num: int = int(ceil(_time_left))
		var text: String = str(num)

		# Measurements
		var ascent: float = font.get_ascent(font_size)
		var descent: float = font.get_descent(font_size)
		var width: float = font.get_string_size(text, font_size).x

		# Baseline-centered positioning:
		#   x centered via -width/2
		#   y centered via +(ascent - descent)/2  (baseline sits this far below center)
		var vertical_nudge: float = 0.0  # tweak to taste, e.g. 1.0 if you still want it a hair lower
		var pos: Vector2 = Vector2(-width * 0.5, (ascent - descent) * 0.5 + vertical_nudge)

		# Colors with external alpha respected
		var a: float = self.modulate.a
		var outline_col: Color = Color(0, 0, 0, 0.9 * a)
		var main_col: Color = Color(1, 1, 1, 1 * a)

		var align: int = HORIZONTAL_ALIGNMENT_LEFT
		var width_limit: float = -1.0

		# Outline + main text (order of args: font, position, text, align, width, size, modulate)
		draw_string(font, pos + Vector2(1, 0), text, align, width_limit, font_size, outline_col)
		draw_string(font, pos + Vector2(-1, 0), text, align, width_limit, font_size, outline_col)
		draw_string(font, pos + Vector2(0, 1), text, align, width_limit, font_size, outline_col)
		draw_string(font, pos + Vector2(0, -1), text, align, width_limit, font_size, outline_col)
		draw_string(font, pos, text, align, width_limit, font_size, main_col)
