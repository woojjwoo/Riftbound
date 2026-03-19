extends Node2D

## Draws a themed ground grid pattern that follows the camera.
## Colors adapt to the current world.

var grid_size: float = 40.0
var grid_color := Color(0.15, 0.12, 0.18, 0.3)
var bg_color := Color(0.08, 0.06, 0.1, 1.0)
var accent_color := Color(0.2, 0.15, 0.25, 0.15)

# How many cells to draw beyond the viewport
var padding: int = 3

func _ready() -> void:
	_apply_world_theme()

func _apply_world_theme() -> void:
	var config := Game.get_world_config()
	bg_color = config.get("bg_color", bg_color)
	grid_color = config.get("grid_color", grid_color)
	accent_color = config.get("accent_color", accent_color)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var zoom := camera.zoom
	var cam_pos := camera.global_position
	var viewport_size := get_viewport_rect().size / zoom

	# Background fill (large rect)
	var bg_rect := Rect2(cam_pos - viewport_size, viewport_size * 2.0)
	draw_rect(bg_rect, bg_color)

	# Grid lines
	var start_x := snapped(cam_pos.x - viewport_size.x, grid_size) - grid_size * padding
	var end_x := cam_pos.x + viewport_size.x + grid_size * padding
	var start_y := snapped(cam_pos.y - viewport_size.y, grid_size) - grid_size * padding
	var end_y := cam_pos.y + viewport_size.y + grid_size * padding

	# Vertical lines
	var x := start_x
	while x <= end_x:
		draw_line(Vector2(x, start_y), Vector2(x, end_y), grid_color, 1.0)
		x += grid_size

	# Horizontal lines
	var y := start_y
	while y <= end_y:
		draw_line(Vector2(start_x, y), Vector2(end_x, y), grid_color, 1.0)
		y += grid_size

	# Accent diamonds at grid intersections (sparse)
	x = start_x
	while x <= end_x:
		y = start_y
		while y <= end_y:
			var hash_val := int(x * 73.0 + y * 137.0) % 7
			if hash_val == 0:
				var diamond_size := 3.0
				var pts := PackedVector2Array([
					Vector2(x, y - diamond_size),
					Vector2(x + diamond_size, y),
					Vector2(x, y + diamond_size),
					Vector2(x - diamond_size, y),
				])
				draw_colored_polygon(pts, accent_color)
			y += grid_size
		x += grid_size

	# World-specific environmental decoration
	var world_id := Game.current_world
	x = start_x
	while x <= end_x:
		y = start_y
		while y <= end_y:
			var hash_val := int(x * 31.0 + y * 97.0) % 13
			if hash_val == 0:
				_draw_world_detail(Vector2(x, y), world_id)
			y += grid_size
		x += grid_size

func _draw_world_detail(pos: Vector2, world_id: int) -> void:
	match world_id:
		1:  # Desert — sand dunes
			draw_circle(pos, 5.0, Color(0.4, 0.3, 0.15, 0.08))
			draw_circle(pos + Vector2(3, 2), 3.0, Color(0.5, 0.35, 0.1, 0.06))
		2:  # Ice — snowflakes
			for i in range(3):
				var a := float(i) / 3.0 * PI
				var p1 := pos + Vector2(cos(a), sin(a)) * 4.0
				var p2 := pos - Vector2(cos(a), sin(a)) * 4.0
				draw_line(p1, p2, Color(0.5, 0.7, 1.0, 0.08), 1.0)
		3:  # Swamp — puddles
			draw_circle(pos, 6.0, Color(0.2, 0.4, 0.15, 0.06))
			draw_circle(pos + Vector2(2, -1), 3.0, Color(0.3, 0.5, 0.1, 0.05))
		4:  # Void — void cracks
			draw_line(pos, pos + Vector2(8, 3), Color(0.5, 0.2, 0.8, 0.08), 1.0)
			draw_line(pos, pos + Vector2(-5, 6), Color(0.4, 0.1, 0.7, 0.06), 1.0)
		5:  # Space — stars
			draw_circle(pos, 1.5, Color(1.0, 1.0, 0.8, 0.12))
			if int(pos.x * 17.0 + pos.y * 41.0) % 3 == 0:
				draw_circle(pos, 2.5, Color(0.8, 0.9, 1.0, 0.08))
