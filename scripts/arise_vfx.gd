extends Node2D

## Arise extraction visual effect. Expanding ring that fades out.

var duration: float = 0.8
var max_scale: float = 3.0
var timer: float = 0.0

func _ready() -> void:
	scale = Vector2.ZERO
	modulate = Color(0.2, 0.8, 1.0, 1.0)  # teal/cyan glow

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
