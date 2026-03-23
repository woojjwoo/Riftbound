extends Node2D

## Floating damage number that rises and fades out.

var rise_speed: float = 40.0
var lifetime: float = 0.7
var timer: float = 0.0
var damage_text: String = ""
var text_color: Color = Color.WHITE
var font_size: int = 10
var drift_x: float = 0.0
var punch_scale: float = 1.0
var base_scale: float = 1.0

func setup(amount: float, col: Color = Color.WHITE) -> void:
	if amount <= 0:
		damage_text = "BLOCKED"
		font_size = 8
	else:
		damage_text = str(int(amount))
	text_color = col
	# Wider horizontal random offset to prevent vertical stacking
	drift_x = randf_range(-25, 25)
	position += Vector2(randf_range(-8, 8), -12)
	# Scale size and punch by damage amount for visceral feedback
	if amount >= 50:
		font_size = 18
		base_scale = 1.6
		punch_scale = 2.2
		rise_speed = 55.0
		lifetime = 0.9
	elif amount >= 20:
		font_size = 14
		base_scale = 1.3
		punch_scale = 1.8
		rise_speed = 45.0
		lifetime = 0.8
	elif amount >= 10:
		font_size = 12
		base_scale = 1.1
		punch_scale = 1.6
	else:
		punch_scale = 1.4
	# Spawn punch: scale up then back down
	var tween := create_tween()
	tween.tween_property(self, "punch_scale", 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _process(delta: float) -> void:
	timer += delta
	position.y -= rise_speed * delta
	# Horizontal drift: ease out over lifetime
	position.x += drift_x * delta * (1.0 - timer / lifetime)
	modulate.a = 1.0 - (timer / lifetime)
	scale = Vector2.ONE * base_scale * punch_scale
	if timer >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-16, 0), damage_text, HORIZONTAL_ALIGNMENT_CENTER, 32, font_size, text_color)
