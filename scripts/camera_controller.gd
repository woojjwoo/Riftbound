extends Camera2D

## Smooth follow + screen shake + dynamic zoom.
## Intensity varies by event:
##   - Small (2-3): enemy hit
##   - Medium (5-6): enemy kill
##   - Large (8-10): boss kill, level up
##   - Extra large (12+): boss entrance

var shake_intensity: float = 0.0
var shake_decay: float = 5.0

# Dynamic zoom
var target_zoom: Vector2 = Vector2(1.2, 1.2)
var default_zoom: Vector2 = Vector2(1.2, 1.2)
var boss_zoom: Vector2 = Vector2(1.0, 1.0)  # Zoom out for boss fights
var death_zoom: Vector2 = Vector2(1.6, 1.6)  # Zoom in on death
var zoom_speed: float = 2.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	zoom = default_zoom
	target_zoom = default_zoom
	Game.shake_camera.connect(_on_shake)
	Game.process_changed.connect(_on_process_changed)

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

	# Smooth zoom transitions
	zoom = zoom.lerp(target_zoom, zoom_speed * delta)

func _on_shake(intensity: float) -> void:
	# Always use the stronger shake — don't let small shakes override big ones
	shake_intensity = max(shake_intensity, intensity)

func _on_process_changed(new_process: Game.GameProcess) -> void:
	match new_process:
		Game.GameProcess.BOSS_FIGHT:
			target_zoom = boss_zoom
		Game.GameProcess.GAME_OVER:
			target_zoom = death_zoom
		Game.GameProcess.VICTORY:
			# Brief zoom in on victory, then back to normal
			target_zoom = Vector2(1.4, 1.4)
			var tween := create_tween()
			tween.tween_callback(func(): target_zoom = default_zoom).set_delay(1.5)
		_:
			target_zoom = default_zoom
