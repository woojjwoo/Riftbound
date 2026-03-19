extends Node2D

## Visual marker at thrall command position. Shows count of thralls heading here.

var lifetime: float = 0.0
const MAX_LIFETIME: float = 4.0

func _process(delta: float) -> void:
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := lifetime / MAX_LIFETIME
	var alpha := 1.0 - t
	var pulse := 0.5 + 0.5 * sin(lifetime * 6.0)

	# Ring
	draw_arc(Vector2.ZERO, 10.0 + pulse * 3.0, 0, TAU, 12, Color(0.4, 0.8, 1.0, alpha * 0.5), 1.5)
	# Center dot
	draw_circle(Vector2.ZERO, 3.0, Color(0.4, 0.8, 1.0, alpha * pulse))
	# Flag pole
	draw_line(Vector2(0, 0), Vector2(0, -14), Color(0.4, 0.8, 1.0, alpha * 0.6), 1.0)
	# Flag
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14), Vector2(8, -11), Vector2(0, -8)
	]), Color(0.4, 0.8, 1.0, alpha * 0.4))

	# Count thralls heading here
	var count := 0
	for thrall in get_tree().get_nodes_in_group("thralls"):
		if thrall.get("mode") == 1:  # ThrallMode.COMMANDED = 1
			count += 1
	if count > 0:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-4, -20), "x%d" % count,
			HORIZONTAL_ALIGNMENT_CENTER, 16, 8, Color(0.4, 0.8, 1.0, alpha))
