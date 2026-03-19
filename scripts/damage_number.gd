extends Node2D

## Floating damage number that rises and fades out.

var rise_speed: float = 40.0
var lifetime: float = 0.7
var timer: float = 0.0
var damage_text: String = ""
var text_color: Color = Color.WHITE
var font_size: int = 10

func setup(amount: float, col: Color = Color.WHITE) -> void:
	if amount <= 0:
		damage_text = "BLOCKED"
		font_size = 8
	else:
		damage_text = str(int(amount))
	text_color = col
	position += Vector2(randf_range(-8, 8), -12)
	if amount >= 20:
		font_size = 14
		scale = Vector2(1.2, 1.2)

func _process(delta: float) -> void:
	timer += delta
	position.y -= rise_speed * delta
	modulate.a = 1.0 - (timer / lifetime)
	if timer >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-16, 0), damage_text, HORIZONTAL_ALIGNMENT_CENTER, 32, font_size, text_color)
