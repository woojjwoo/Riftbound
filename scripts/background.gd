extends Node2D

## Draws a subtle ground grid pattern that follows the camera.
## Creates a dark fantasy ground feel.

var grid_size: float = 40.0
var grid_color := Color(0.15, 0.12, 0.18, 0.3)
var bg_color := Color(0.08, 0.06, 0.1, 1.0)
var accent_color := Color(0.2, 0.15, 0.25, 0.15)

# How many cells to draw beyond the viewport
var padding: int = 3

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
			# Only draw some intersections for visual interest
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
