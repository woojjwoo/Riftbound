extends Node2D

## Brief impact flash when a projectile hits something.

var timer: float = 0.0
var duration: float = 0.15
var hit_color: Color = Color(0.3, 0.8, 1.0)

func setup(color: Color = Color(0.3, 0.8, 1.0)) -> void:
	hit_color = color

func _process(delta: float) -> void:
	timer += delta
	if timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := timer / duration
	var ease_t := 1.0 - pow(1.0 - t, 2.0)

	# Expanding ring
	var radius := 6.0 + 14.0 * ease_t
	var alpha := 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0, TAU, 12, Color(hit_color.r, hit_color.g, hit_color.b, alpha * 0.8), 2.0)

	# Inner flash
	draw_circle(Vector2.ZERO, radius * 0.4 * (1.0 - t), Color(1.0, 1.0, 1.0, alpha * 0.6))

	# Sparks
	for i in range(4):
		var angle := float(i) / 4.0 * TAU + t * 3.0
		var dist := radius * 0.8
		var pos := Vector2(cos(angle), sin(angle)) * dist
		draw_circle(pos, 1.5 * (1.0 - t), Color(hit_color.r, hit_color.g, hit_color.b, alpha * 0.5))
