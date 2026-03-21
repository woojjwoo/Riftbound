extends Node2D

## Environmental hazard tile. Deals damage or applies effects to entities
## that step on it. Each world has a unique hazard type.

enum HazardType { LAVA, ICE_PATCH, POISON_FOG, GRAVITY_WELL, LIGHT_BEAM }

var hazard_type: HazardType = HazardType.LAVA
var radius: float = 30.0
var damage: float = 5.0
var duration: float = 8.0
var time_alive: float = 0.0
var _tick_timer: float = 0.0
var _draw_time: float = 0.0
const TICK_INTERVAL: float = 0.5

func setup(type: HazardType, rad: float = 30.0, dmg: float = 5.0, dur: float = 8.0) -> void:
	hazard_type = type
	radius = rad
	damage = dmg
	duration = dur

func _ready() -> void:
	add_to_group("hazards")

func _process(delta: float) -> void:
	time_alive += delta
	_tick_timer -= delta
	_draw_time += delta

	if duration > 0.0 and time_alive >= duration:
		_fade_out()
		return

	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		_apply_effects()

	queue_redraw()

func _apply_effects() -> void:
	# Affect player
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if global_position.distance_to(p.global_position) < radius:
			match hazard_type:
				HazardType.LAVA:
					if p.has_method("take_damage"):
						p.take_damage(damage, global_position)
				HazardType.ICE_PATCH:
					# Slow player
					if "move_speed" in p:
						var orig_speed: float = p.move_speed
						p.move_speed *= 0.5
						get_tree().create_timer(1.0).timeout.connect(func():
							if is_instance_valid(p):
								p.move_speed = orig_speed
						)
				HazardType.POISON_FOG:
					if p.has_method("take_damage"):
						p.take_damage(damage * 0.5, Vector2.ZERO)
				HazardType.GRAVITY_WELL:
					var pull_dir: Vector2 = p.global_position.direction_to(global_position)
					if "knockback_velocity" in p:
						p.knockback_velocity += pull_dir * 80.0
				HazardType.LIGHT_BEAM:
					if p.has_method("take_damage"):
						p.take_damage(damage * 1.5, global_position)

	# Affect thralls
	for thrall in get_tree().get_nodes_in_group("thralls"):
		if global_position.distance_to(thrall.global_position) < radius:
			match hazard_type:
				HazardType.LAVA:
					if thrall.has_method("take_damage"):
						thrall.take_damage(damage * 0.5)
				HazardType.POISON_FOG:
					if thrall.has_method("take_damage"):
						thrall.take_damage(damage * 0.3)
				HazardType.LIGHT_BEAM:
					if thrall.has_method("take_damage"):
						thrall.take_damage(damage * 0.8)

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var alpha_mult := 1.0
	if duration > 0.0 and time_alive > duration - 1.0:
		alpha_mult = maxf(0.0, (duration - time_alive))

	match hazard_type:
		HazardType.LAVA:
			_draw_lava(alpha_mult)
		HazardType.ICE_PATCH:
			_draw_ice(alpha_mult)
		HazardType.POISON_FOG:
			_draw_poison(alpha_mult)
		HazardType.GRAVITY_WELL:
			_draw_gravity(alpha_mult)
		HazardType.LIGHT_BEAM:
			_draw_light(alpha_mult)

func _draw_lava(alpha: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.8, 0.2, 0.0, 0.15 * alpha))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 0.4, 0.0, 0.2 * alpha))
	for i in range(5):
		var angle := float(i) / 5.0 * TAU + _draw_time * 0.5
		var r := radius * 0.5 + sin(_draw_time * 2.0 + float(i)) * 5.0
		var pos := Vector2(cos(angle), sin(angle)) * r
		draw_circle(pos, 3.0, Color(1.0, 0.6, 0.0, 0.4 * alpha))

func _draw_ice(alpha: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.6, 1.0, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color(0.5, 0.8, 1.0, 0.25 * alpha), 1.5)
	for i in range(6):
		var angle := float(i) / 6.0 * TAU
		var pos := Vector2(cos(angle), sin(angle)) * radius * 0.6
		draw_circle(pos, 2.0, Color(0.7, 0.9, 1.0, 0.3 * alpha))

func _draw_poison(alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_draw_time * 1.5)
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.6, 0.1, 0.1 * alpha * pulse))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.3, 0.8, 0.1, 0.15 * alpha))
	for i in range(4):
		var seed_val := float(i) * 47.3
		var fx := sin(_draw_time * 0.8 + seed_val) * radius * 0.5
		var fy := cos(_draw_time * 0.6 + seed_val) * radius * 0.5 - sin(_draw_time + seed_val) * 5.0
		draw_circle(Vector2(fx, fy), 2.5, Color(0.4, 0.9, 0.2, 0.25 * alpha))

func _draw_gravity(alpha: float) -> void:
	var pulse := 0.3 + 0.2 * sin(_draw_time * 3.0)
	draw_circle(Vector2.ZERO, radius, Color(0.5, 0.1, 0.8, 0.08 * alpha))
	for i in range(3):
		var r := radius * (0.3 + float(i) * 0.25) - fmod(_draw_time * 20.0, radius * 0.3)
		if r > 0:
			draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(0.6, 0.2, 1.0, (0.2 - float(i) * 0.05) * alpha), 1.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.8, 0.3, 1.0, pulse * alpha))

func _draw_light(alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_draw_time * 4.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.9, 0.4, 0.1 * alpha * pulse))
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 1.0, 0.8, 0.2 * alpha))
	for i in range(4):
		var angle := float(i) / 4.0 * TAU + _draw_time * 2.0
		var start := Vector2(cos(angle), sin(angle)) * 5.0
		var end := Vector2(cos(angle), sin(angle)) * radius * 0.8
		draw_line(start, end, Color(1.0, 0.9, 0.3, 0.2 * alpha * pulse), 1.5)
