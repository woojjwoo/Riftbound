extends Node2D

## Poison pool left behind by poisoner enemies. Damages player/thralls standing in it.

var radius: float = 20.0
var damage: float = 3.0
var duration: float = 4.0
var elapsed: float = 0.0
var damage_timer: float = 0.0
var damage_interval: float = 0.5

func setup(p_radius: float, p_damage: float, p_duration: float) -> void:
	radius = p_radius
	damage = p_damage
	duration = p_duration

func _process(delta: float) -> void:
	elapsed += delta
	damage_timer -= delta

	if elapsed >= duration:
		queue_free()
		return

	# Damage targets standing in the pool
	if damage_timer <= 0.0:
		damage_timer = damage_interval
		_damage_targets()

	queue_redraw()

func _damage_targets() -> void:
	var targets: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("player"):
		targets.append(node)
	for node in get_tree().get_nodes_in_group("thralls"):
		targets.append(node)

	for target in targets:
		var dist := global_position.distance_to(target.global_position)
		if dist <= radius and target.has_method("take_damage"):
			target.take_damage(damage)

func _draw() -> void:
	var fade := 1.0 - (elapsed / duration)
	var pulse := 0.7 + 0.3 * sin(elapsed * 5.0)

	# Outer pool
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.8, 0.1, 0.2 * fade * pulse))
	# Inner pool
	draw_circle(Vector2.ZERO, radius * 0.6, Color(0.3, 0.9, 0.15, 0.3 * fade * pulse))
	# Bubbles
	for i in range(5):
		var angle := float(i) / 5.0 * TAU + elapsed * 1.5
		var dist := radius * (0.3 + 0.3 * sin(elapsed * 2.0 + float(i)))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var bubble_size := 2.0 * (0.5 + 0.5 * sin(elapsed * 3.0 + float(i) * 1.3))
		draw_circle(pos, bubble_size, Color(0.4, 1.0, 0.2, 0.4 * fade))
