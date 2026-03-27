extends Node2D

## Explosion visual effect. Expanding ring + particles.

var duration: float = 0.5
var timer: float = 0.0
var max_radius: float = 80.0

func _process(delta: float) -> void:
	timer += delta
	if timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := timer / duration
	var ease_t := 1.0 - pow(1.0 - t, 3.0)
	var alpha := 1.0 - t

	# Expanding ring
	var radius := max_radius * ease_t
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.5, 0.1, alpha * 0.8), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.6, 0, TAU, 16, Color(1.0, 0.8, 0.2, alpha * 0.5), 2.0)

	# Inner glow
	draw_circle(Vector2.ZERO, radius * 0.3 * (1.0 - t), Color(1.0, 0.9, 0.4, alpha))

	# Particles flying outward
	for i in range(12):
		var angle := float(i) / 12.0 * TAU + t * 2.0
		var dist := radius * (0.4 + 0.6 * t)
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var p_radius := 2.0 * (1.0 - t)
		draw_circle(pos, p_radius, Color(1.0, 0.6, 0.2, alpha * 0.7))
