extends Node2D

## Arise extraction visual effect. Expanding ring that fades out.
## Enhanced with multiple rings and particle burst.

var duration: float = 0.8
var max_scale: float = 3.0
var timer: float = 0.0

func _ready() -> void:
	scale = Vector2.ZERO
	modulate = Color(0.2, 0.8, 1.0, 1.0)  # teal/cyan glow
	# Screen shake on extraction
	Game.request_shake(5.0)

func _process(delta: float) -> void:
	timer += delta
	var t := timer / duration

	if t >= 1.0:
		queue_free()
		return

	# Expand with ease-out
	var ease_t := 1.0 - pow(1.0 - t, 3.0)
	scale = Vector2.ONE * lerp(0.0, max_scale, ease_t)

	# Fade out
	modulate.a = lerp(1.0, 0.0, t)

	queue_redraw()

func _draw() -> void:
	# Draw extra burst particles
	var t := timer / duration
	var num_particles := 8
	for i in range(num_particles):
		var angle := float(i) / float(num_particles) * TAU
		var dist := 10.0 + 30.0 * t
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var alpha := 1.0 - t
		var radius := 2.0 * (1.0 - t)
		draw_circle(pos, radius, Color(0.4, 1.0, 0.9, alpha))
