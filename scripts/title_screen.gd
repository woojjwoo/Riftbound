extends Node2D

## Title screen with animated rift visual. Click or press key to start.
## Shows world select and shop access.

var time: float = 0.0
var started: bool = false
var selected_world: int = 0

func _ready() -> void:
	Audio.start_music()
	selected_world = mini(SaveData.highest_world_unlocked, WorldData.get_world_count() - 1)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if started:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				selected_world = max(0, selected_world - 1)
			KEY_RIGHT, KEY_D:
				selected_world = min(SaveData.highest_world_unlocked, selected_world + 1)
				selected_world = mini(selected_world, WorldData.get_world_count() - 1)
			KEY_TAB:
				_open_shop()
			KEY_ENTER, KEY_SPACE:
				_start_game()
			_:
				pass

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport_rect().size
		var cx := vp.x / 2.0
		var my := event.position.y
		var mx := event.position.x

		# Shop button region
		if my > vp.y * 0.78 and my < vp.y * 0.78 + 30 and mx > cx - 60 and mx < cx + 60:
			_open_shop()
			return

		# World select arrows
		if my > vp.y * 0.55 and my < vp.y * 0.55 + 30:
			if mx < cx - 60:
				selected_world = max(0, selected_world - 1)
				return
			elif mx > cx + 60:
				selected_world = min(SaveData.highest_world_unlocked, selected_world + 1)
				selected_world = mini(selected_world, WorldData.get_world_count() - 1)
				return

		_start_game()

func _start_game() -> void:
	started = true
	Game.current_world = selected_world
	Audio.play_phase_change()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _open_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var center := Vector2(cx, cy)

	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.02, 0.07))

	# Floating particles
	for i in range(30):
		var seed_val := float(i) * 137.5
		var px := cx + sin(time * 0.3 + seed_val) * 300.0
		var py := cy + cos(time * 0.4 + seed_val * 0.7) * 200.0
		var p_alpha := 0.15 + 0.1 * sin(time * 0.8 + seed_val)
		draw_circle(Vector2(px, py), 1.5, Color(0.5, 0.2, 0.8, p_alpha))

	# Selected world color for rift
	var world_config := WorldData.get_config(selected_world)
	var rc: Color = world_config.get("rift_color", Color(0.6, 0.2, 0.9))

	# Rift visual — swirling arcs
	for i in range(5):
		var angle_offset := time * (0.8 + float(i) * 0.3)
		var radius := 50.0 + float(i) * 18.0
		var alpha := 0.35 - float(i) * 0.05
		draw_arc(center, radius, angle_offset, angle_offset + PI * 1.5, 24,
			Color(rc.r, rc.g, rc.b, alpha), 2.5)
	for i in range(3):
		var angle_offset := -time * (1.0 + float(i) * 0.5)
		var radius := 35.0 + float(i) * 15.0
		draw_arc(center, radius, angle_offset, angle_offset + PI, 16,
			Color(rc.r * 1.2, rc.g * 0.8, rc.b * 0.8, 0.2), 1.5)

	# Core glow
	var pulse := 0.6 + 0.4 * sin(time * 2.0)
	draw_circle(center, 25.0, Color(rc.r * 0.7, rc.g * 0.5, rc.b * 0.8, 0.15 * pulse))
	draw_circle(center, 12.0, Color(rc.r, rc.g, rc.b, 0.35 * pulse))
	draw_circle(center, 5.0, Color(1.0, 0.8, 1.0, 0.5 * pulse))

	# Title
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(cx - 90, cy - 130), "RIFTBOUND",
		HORIZONTAL_ALIGNMENT_CENTER, 180, 36, Color(0.85, 0.65, 1.0))

	# Subtitle
	draw_string(font, Vector2(cx - 80, cy - 100), "A Necromancer's Tale",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.5, 0.35, 0.65))

	# World selector
	var world_name: String = world_config.get("name", "Unknown")
	var world_sub: String = world_config.get("subtitle", "")
	var sel_y := cy + 80

	# Arrows
	if selected_world > 0:
		draw_string(font, Vector2(cx - 120, sel_y), "<",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color(0.7, 0.6, 0.9))
	if selected_world < SaveData.highest_world_unlocked and selected_world < WorldData.get_world_count() - 1:
		draw_string(font, Vector2(cx + 100, sel_y), ">",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color(0.7, 0.6, 0.9))

	# World name
	draw_string(font, Vector2(cx - 90, sel_y), "World %d: %s" % [selected_world + 1, world_name],
		HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(rc.r, rc.g, rc.b))
	draw_string(font, Vector2(cx - 80, sel_y + 18), world_sub,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 9, Color(0.5, 0.4, 0.6))

	# Player stats
	var stats_y := sel_y + 45
	draw_string(font, Vector2(cx - 100, stats_y), "Level %d  |  Coins: %d  |  Worlds: %d/%d" % [
		SaveData.player_level, SaveData.coins, SaveData.worlds_completed.size(), WorldData.get_world_count()],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color(0.5, 0.45, 0.6))

	# Click to start
	var blink := 0.4 + 0.6 * sin(time * 3.0)
	draw_string(font, Vector2(cx - 60, cy + 160), "Click to Begin",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.7, 0.5, 0.9, blink))

	# Shop button
	var shop_y := cy + 190
	draw_rect(Rect2(cx - 60, shop_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, shop_y - 15, 120, 30), Color(1.0, 0.85, 0.3, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 30, shop_y + 5), "TAB: Shop",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 0.9, 0.4))

	# Controls preview
	draw_string(font, Vector2(cx - 120, cy + 240), "A/D: Select World  |  WASD: Move  |  LMB: Attack",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 8, Color(0.4, 0.3, 0.5, 0.6))
	draw_string(font, Vector2(cx - 120, cy + 255), "RMB: Command Thralls  |  SPACE: Dash  |  R: Recall",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 8, Color(0.4, 0.3, 0.5, 0.6))
