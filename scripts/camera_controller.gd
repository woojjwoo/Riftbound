extends Camera2D

## Smooth follow + screen shake. Attach to Camera2D under Player.
## Intensity varies by event:
##   - Small (2-3): enemy hit
##   - Medium (5-6): enemy kill
##   - Large (8-10): boss kill, level up
##   - Extra large (12+): boss entrance

var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	Game.shake_camera.connect(_on_shake)

func _process(delta: float) -> void:
	if shake_intensity > 0.01:
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO
		shake_intensity = 0.0

func _on_shake(intensity: float) -> void:
	# Always use the stronger shake — don't let small shakes override big ones
	shake_intensity = max(shake_intensity, intensity)
