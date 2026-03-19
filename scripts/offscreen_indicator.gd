extends Control

## Draws arrows at screen edges pointing to off-screen rifts.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size / 2.0
	var cam_pos := camera.global_position
	var zoom := camera.zoom

	var rift_color: Color = Game.get_world_config().get("rift_color", Color(0.6, 0.2, 0.9))
	for rift in get_tree().get_nodes_in_group("rifts"):
		_draw_indicator(rift.global_position, cam_pos, zoom, viewport_size, screen_center,
			Color(rift_color.r, rift_color.g, rift_color.b, 0.9))

func _draw_indicator(world_pos: Vector2, cam_pos: Vector2, zoom: Vector2,
	viewport_size: Vector2, screen_center: Vector2, color: Color) -> void:
	var screen_pos := (world_pos - cam_pos) * zoom + screen_center
	var margin: float = 50.0

	# Check if on-screen
	if screen_pos.x >= margin and screen_pos.x <= viewport_size.x - margin and \
	   screen_pos.y >= margin and screen_pos.y <= viewport_size.y - margin:
		return

	# Clamp to screen edge
	var clamped := Vector2(
		clampf(screen_pos.x, margin, viewport_size.x - margin),
		clampf(screen_pos.y, margin, viewport_size.y - margin)
	)

	# Arrow pointing toward rift
	var dir := (screen_pos - screen_center).normalized()
	var arrow_size: float = 12.0
	var perp := Vector2(-dir.y, dir.x)
	var tip := clamped
	var base1 := clamped - dir * arrow_size * 1.5 + perp * arrow_size * 0.6
	var base2 := clamped - dir * arrow_size * 1.5 - perp * arrow_size * 0.6

	# Pulsing
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
	var c := color
	c.a *= pulse

	draw_colored_polygon(PackedVector2Array([tip, base1, base2]), c)

	# Glow
	draw_circle(clamped, 4.0, Color(c.r, c.g, c.b, c.a * 0.3))

	# Distance text
	var dist := cam_pos.distance_to(world_pos)
	var font := ThemeDB.fallback_font
	var label_offset := -dir * 20.0 + Vector2(-8, 4)
	draw_string(font, clamped + label_offset, "%dm" % int(dist / 10.0),
		HORIZONTAL_ALIGNMENT_CENTER, 30, 11, c)
