extends Node2D

## Warning indicator shown before an enemy spawns at this location.

var duration: float = 0.6
var timer: float = 0.0
var max_radius: float = 18.0

func _process(delta: float) -> void:
	timer += delta
	if timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := timer / duration
	# Pulsing warning circle
	var pulse := 0.5 + 0.5 * sin(t * TAU * 4.0)
	var radius := max_radius * (0.5 + 0.5 * t)
	var alpha := (1.0 - t) * 0.7
	# Outer ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.3, 0.1, alpha * pulse), 2.0)
	# Inner fill
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.2, 0.0, alpha * 0.3 * pulse))
	# Cross marker
	var cross_size := 6.0
	draw_line(Vector2(-cross_size, 0), Vector2(cross_size, 0), Color(1.0, 0.4, 0.1, alpha), 1.5)
	draw_line(Vector2(0, -cross_size), Vector2(0, cross_size), Color(1.0, 0.4, 0.1, alpha), 1.5)
