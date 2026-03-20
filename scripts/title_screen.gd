extends Node2D

## Title screen with animated rift visual. Click or press key to start.
## Shows world select and shop access.

var time: float = 0.0
var started: bool = false
var selected_world: int = 0

func _ready() -> void:
	Audio.start_music(0)  # Title screen uses Dark Realm music
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
				Audio.play_ui_click()
			KEY_RIGHT, KEY_D:
				selected_world = min(SaveData.highest_world_unlocked, selected_world + 1)
				selected_world = mini(selected_world, WorldData.get_world_count() - 1)
				Audio.play_ui_click()
			KEY_TAB:
				Audio.play_ui_click()
				_open_shop()
			KEY_Q:
				_open_sanctum()
			KEY_B:
				_open_bestiary()
			KEY_I:
				_open_achievements()
			KEY_C:
				_open_challenges()
			KEY_H:
				_open_run_history()
			KEY_G:
				_open_crafting()
			KEY_O:
				_open_settings()
			KEY_ENTER, KEY_SPACE:
				_start_game()
			_:
				pass

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport_rect().size
		var cx := vp.x / 2.0
		var my := event.position.y
		var mx := event.position.x

		var cy := vp.y / 2.0

		# Shop button region (drawn at cy + 185)
		var shop_btn_y := cy + 185 - 15
		if my > shop_btn_y and my < shop_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_shop()
			return

		# Sanctum button region (drawn at cy + 223)
		var sanctum_btn_y := cy + 223 - 15
		if my > sanctum_btn_y and my < sanctum_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_sanctum()
			return

		# Achievements button region (drawn at cy + 261)
		var ach_btn_y := cy + 261 - 15
		if my > ach_btn_y and my < ach_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_achievements()
			return

		# Bestiary button region (drawn at cy + 299)
		var bestiary_btn_y := cy + 299 - 15
		if my > bestiary_btn_y and my < bestiary_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_bestiary()
			return

		# Crafting button region (drawn at cy + 337)
		var craft_btn_y := cy + 337 - 15
		if my > craft_btn_y and my < craft_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_crafting()
			return

		# Settings button region (drawn at cy + 375)
		var settings_btn_y := cy + 375 - 15
		if my > settings_btn_y and my < settings_btn_y + 30 and mx > cx - 60 and mx < cx + 60:
			_open_settings()
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

func _open_sanctum() -> void:
	get_tree().change_scene_to_file("res://scenes/sanctum_screen.tscn")

func _open_achievements() -> void:
	get_tree().change_scene_to_file("res://scenes/achievement_screen.tscn")

func _open_run_history() -> void:
	var history := CanvasLayer.new()
	history.set_script(preload("res://scripts/run_history_screen.gd"))
	history.closed.connect(func(): history.queue_free())
	add_child(history)

func _open_challenges() -> void:
	var challenge := CanvasLayer.new()
	challenge.set_script(preload("res://scripts/challenge_screen.gd"))
	challenge.closed.connect(func(): challenge.queue_free())
	add_child(challenge)

func _open_crafting() -> void:
	var crafting := CanvasLayer.new()
	crafting.set_script(preload("res://scripts/crafting_screen.gd"))
	crafting.closed.connect(func(): crafting.queue_free())
	add_child(crafting)

func _open_bestiary() -> void:
	var bestiary := CanvasLayer.new()
	bestiary.set_script(preload("res://scripts/bestiary_screen.gd"))
	bestiary.closed.connect(func(): bestiary.queue_free())
	add_child(bestiary)

func _open_settings() -> void:
	var settings := CanvasLayer.new()
	settings.set_script(preload("res://scripts/settings_screen.gd"))
	settings.setup("res://scenes/title_screen.tscn")
	add_child(settings)

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
	var subtitle := "A Necromancer's Tale"
	if SaveData.ng_plus_cycle > 0:
		subtitle = "New Game+ %d" % SaveData.ng_plus_cycle
	draw_string(font, Vector2(cx - 80, cy - 100), subtitle,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.5, 0.35, 0.65) if SaveData.ng_plus_cycle == 0 else Color(1.0, 0.6, 0.2))

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
		HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color(0.5, 0.4, 0.6))

	# Player stats
	var stats_y := sel_y + 45
	draw_string(font, Vector2(cx - 110, stats_y), "Level %d  |  Coins: %d  |  Worlds: %d/%d" % [
		SaveData.player_level, SaveData.coins, SaveData.worlds_completed.size(), WorldData.get_world_count()],
		HORIZONTAL_ALIGNMENT_CENTER, 220, 11, Color(0.5, 0.45, 0.6))

	# Soul Essence display
	var essence_pulse := 0.7 + 0.3 * sin(time * 2.0)
	var essence_color := Color(0.5 * essence_pulse, 0.25 * essence_pulse, 0.9 * essence_pulse)
	draw_string(font, Vector2(cx - 90, stats_y + 18), "Soul Essence: %d" % Meta.soul_essence,
		HORIZONTAL_ALIGNMENT_CENTER, 180, 11, essence_color)

	# Click to start
	var blink := 0.4 + 0.6 * sin(time * 3.0)
	draw_string(font, Vector2(cx - 60, cy + 160), "Click to Begin",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.7, 0.5, 0.9, blink))

	# Shop button
	var shop_y := cy + 185
	draw_rect(Rect2(cx - 60, shop_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, shop_y - 15, 120, 30), Color(1.0, 0.85, 0.3, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 30, shop_y + 5), "TAB: Shop",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 0.9, 0.4))

	# Sanctum button (below shop)
	var sanctum_y := shop_y + 38
	var sanctum_pulse := 0.4 + 0.15 * sin(time * 2.5)
	draw_rect(Rect2(cx - 60, sanctum_y - 15, 120, 30), Color(0.08, 0.03, 0.14, 0.8))
	draw_rect(Rect2(cx - 60, sanctum_y - 15, 120, 30), Color(0.6, 0.3, 1.0, sanctum_pulse), false, 1.0)
	draw_string(font, Vector2(cx - 35, sanctum_y + 5), "Q: Sanctum",
		HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.6, 0.35, 1.0))

	# Achievements button (below sanctum)
	var ach_y := sanctum_y + 38
	var ach_progress := "%d/%d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()]
	draw_rect(Rect2(cx - 60, ach_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, ach_y - 15, 120, 30), Color(0.6, 0.4, 1.0, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 55, ach_y + 5), "I: Achievements %s" % ach_progress,
		HORIZONTAL_ALIGNMENT_CENTER, 110, 11, Color(0.7, 0.6, 0.9))

	# Bestiary button (below achievements)
	var bestiary_y := ach_y + 38
	draw_rect(Rect2(cx - 60, bestiary_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, bestiary_y - 15, 120, 30), Color(0.8, 0.5, 0.3, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 30, bestiary_y + 5), "B: Bestiary",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(0.8, 0.6, 0.4))

	# Challenge button (below bestiary)
	var challenge_y := bestiary_y + 38
	var chal_count := Challenges.get_active_count()
	var chal_label := "C: Challenges" if chal_count == 0 else "C: Challenges (%d)" % chal_count
	draw_rect(Rect2(cx - 60, challenge_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, challenge_y - 15, 120, 30), Color(1.0, 0.5, 0.3, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 50, challenge_y + 5), chal_label,
		HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color(1.0, 0.6, 0.3))

	# Run History button (below challenges)
	var history_y := challenge_y + 38
	var history_count := SaveData.run_history.size()
	draw_rect(Rect2(cx - 60, history_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, history_y - 15, 120, 30), Color(0.5, 0.7, 0.9, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 50, history_y + 5), "H: History (%d)" % history_count,
		HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color(0.5, 0.7, 0.9))

	# Crafting button (below history)
	var craft_y := history_y + 38
	draw_rect(Rect2(cx - 60, craft_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, craft_y - 15, 120, 30), Color(1.0, 0.85, 0.4, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 30, craft_y + 5), "G: Crafting",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 0.85, 0.4))

	# Settings button (below crafting)
	var settings_y := craft_y + 38
	draw_rect(Rect2(cx - 60, settings_y - 15, 120, 30), Color(0.12, 0.08, 0.18, 0.8))
	draw_rect(Rect2(cx - 60, settings_y - 15, 120, 30), Color(0.6, 0.6, 0.7, 0.4), false, 1.0)
	draw_string(font, Vector2(cx - 30, settings_y + 5), "O: Settings",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(0.6, 0.6, 0.7))

	# Controls preview
	draw_string(font, Vector2(cx - 140, cy + 328), "A/D: Select World  |  WASD: Move  |  LMB: Attack",
		HORIZONTAL_ALIGNMENT_CENTER, 280, 11, Color(0.5, 0.4, 0.6, 0.7))
	draw_string(font, Vector2(cx - 140, cy + 346), "RMB: Command Thralls  |  SPACE: Dash  |  R: Recall",
		HORIZONTAL_ALIGNMENT_CENTER, 280, 11, Color(0.5, 0.4, 0.6, 0.7))
