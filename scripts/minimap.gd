extends Control

## Corner minimap showing player, rifts, boss, thralls, enemies, and portal.
## Drawn procedurally in the top-right corner of the screen.

const MAP_SIZE: float = 120.0
const MAP_MARGIN: float = 10.0
const MAP_SCALE: float = 0.06  # World units → minimap pixels
const BG_COLOR := Color(0.02, 0.01, 0.04, 0.6)
const BORDER_COLOR := Color(0.4, 0.3, 0.6, 0.5)

var player: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return

	var screen_size := get_viewport_rect().size
	var map_x := screen_size.x - MAP_SIZE - MAP_MARGIN
	var map_y := MAP_MARGIN
	var map_center := Vector2(map_x + MAP_SIZE * 0.5, map_y + MAP_SIZE * 0.5)
	var half := MAP_SIZE * 0.5

	# Background
	draw_rect(Rect2(map_x, map_y, MAP_SIZE, MAP_SIZE), BG_COLOR)
	draw_rect(Rect2(map_x, map_y, MAP_SIZE, MAP_SIZE), BORDER_COLOR, false, 1.0)

	var player_pos := player.global_position

	# Helper: world position to minimap position (clamped to map bounds)
	# Returns Vector2 minimap position and bool whether it's within the map
	var _to_map := func(world_pos: Vector2) -> Vector2:
		var offset := (world_pos - player_pos) * MAP_SCALE
		offset.x = clampf(offset.x, -half + 2, half - 2)
		offset.y = clampf(offset.y, -half + 2, half - 2)
		return map_center + offset

	# Draw rifts (diamond shapes)
	for rift in get_tree().get_nodes_in_group("rifts"):
		if not is_instance_valid(rift):
			continue
		var mp: Vector2 = _to_map.call(rift.global_position)
		var rift_color := Color(0.6, 0.2, 0.9, 0.9)
		if rift.get("is_active"):
			rift_color = Color(0.9, 0.3, 1.0, 1.0)
		_draw_diamond(mp, 3.5, rift_color)

	# Draw enemies (red dots)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dying"):
			continue
		var mp: Vector2 = _to_map.call(enemy.global_position)
		var enemy_color := Color(0.9, 0.2, 0.2, 0.6)
		if enemy.is_in_group("boss"):
			# Boss: larger, brighter
			draw_circle(mp, 4.0, Color(1.0, 0.2, 0.1, 0.9))
		else:
			draw_circle(mp, 1.5, enemy_color)

	# Draw thralls (cyan dots)
	for thrall in get_tree().get_nodes_in_group("thralls"):
		if not is_instance_valid(thrall):
			continue
		var mp: Vector2 = _to_map.call(thrall.global_position)
		draw_circle(mp, 2.0, Color(0.3, 0.8, 1.0, 0.8))

	# Draw portal (golden diamond)
	for portal in get_tree().get_nodes_in_group("portals"):
		if not is_instance_valid(portal):
			continue
		var mp: Vector2 = _to_map.call(portal.global_position)
		_draw_diamond(mp, 4.0, Color(1.0, 0.85, 0.2, 0.9))

	# Draw world events (green triangles)
	for event in get_tree().get_nodes_in_group("world_events"):
		if not is_instance_valid(event):
			continue
		if event.get("interacted"):
			continue
		var mp: Vector2 = _to_map.call(event.global_position)
		_draw_triangle(mp, 3.0, Color(0.3, 1.0, 0.5, 0.8))

	# Draw environmental hazards (orange dots)
	for hazard in get_tree().get_nodes_in_group("hazards"):
		if not is_instance_valid(hazard):
			continue
		var mp: Vector2 = _to_map.call(hazard.global_position)
		draw_circle(mp, 1.5, Color(1.0, 0.5, 0.1, 0.4))

	# Draw elite enemies with special marker
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dying"):
			continue
		if enemy.get("is_elite"):
			var mp: Vector2 = _to_map.call(enemy.global_position)
			draw_circle(mp, 2.5, Color(1.0, 0.8, 0.2, 0.7))

	# Draw player (white dot, always center)
	draw_circle(map_center, 2.5, Color(1.0, 1.0, 1.0, 0.9))

	# Cardinal direction indicator
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(map_center.x - 2, map_y + 10), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 0.6, 0.4))

func _draw_diamond(center: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size * 0.7, 0),
		center + Vector2(0, size),
		center + Vector2(-size * 0.7, 0),
	])
	draw_colored_polygon(pts, color)

func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size * 0.87, size * 0.5),
		center + Vector2(-size * 0.87, size * 0.5),
	])
	draw_colored_polygon(pts, color)
