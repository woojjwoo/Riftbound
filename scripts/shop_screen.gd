extends Node2D

## Upgrade shop between runs. Spend coins on permanent upgrades.
## Accessible from title screen.

var time: float = 0.0
var selected_index: int = -1
var scroll_offset: int = 0
const VISIBLE_ITEMS: int = 5

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				Audio.play_ui_cancel()
				get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
			KEY_UP, KEY_W:
				selected_index = max(0, selected_index - 1)
				if selected_index < scroll_offset:
					scroll_offset = selected_index
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				selected_index = min(SaveData.SHOP_UPGRADES.size() - 1, selected_index + 1)
				if selected_index >= scroll_offset + VISIBLE_ITEMS:
					scroll_offset = selected_index - VISIBLE_ITEMS + 1
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				if selected_index >= 0:
					_try_buy(selected_index)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_offset = max(0, scroll_offset - 1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_offset = min(SaveData.SHOP_UPGRADES.size() - VISIBLE_ITEMS, scroll_offset + 1)
			scroll_offset = max(0, scroll_offset)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport_rect().size
		var start_y := 160.0
		var item_h := 60.0
		var mx: float = event.position.x
		var my: float = event.position.y
		if mx > vp.x * 0.15 and mx < vp.x * 0.85:
			for i in range(VISIBLE_ITEMS):
				var idx := scroll_offset + i
				if idx >= SaveData.SHOP_UPGRADES.size():
					break
				var y := start_y + float(i) * item_h
				if my >= y and my < y + item_h - 5:
					if selected_index == idx:
						_try_buy(idx)
					else:
						selected_index = idx
					break

		# Back button
		if my > get_viewport_rect().size.y - 60 and mx < 200:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _try_buy(index: int) -> void:
	if SaveData.buy_upgrade(index):
		Audio.play_ui_confirm()
		Audio.play_upgrade()
		Game.request_shake(3.0)
	else:
		Audio.play_ui_error()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.03, 0.08))

	# Floating particles
	for i in range(20):
		var seed_val := float(i) * 97.3
		var px := cx + sin(time * 0.2 + seed_val) * 400.0
		var py := vp.y / 2.0 + cos(time * 0.3 + seed_val * 0.6) * 300.0
		draw_circle(Vector2(px, py), 1.5, Color(0.4, 0.3, 0.6, 0.1))

	var font := ThemeDB.fallback_font

	# Title
	draw_string(font, Vector2(cx - 80, 40), "UPGRADE SHOP",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 28, Color(1.0, 0.85, 0.3))

	# Coins display
	var coin_text := "Coins: %d" % SaveData.coins
	draw_string(font, Vector2(cx - 60, 75), coin_text,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1.0, 0.9, 0.4))

	# Level display
	var level_text := "Level %d  (EXP: %d / %d)" % [SaveData.player_level, SaveData.exp_points, SaveData.exp_to_next_level]
	draw_string(font, Vector2(cx - 120, 100), level_text,
		HORIZONTAL_ALIGNMENT_CENTER, 240, 11, Color(0.5, 0.7, 1.0))

	# World progress
	var world_text := "Worlds Cleared: %d / %d" % [SaveData.worlds_completed.size(), WorldData.get_world_count()]
	draw_string(font, Vector2(cx - 80, 120), world_text,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.6, 0.5, 0.8))

	# Upgrade list
	var start_y := 160.0
	var item_h := 60.0
	var item_w := vp.x * 0.7
	var item_x := vp.x * 0.15

	for i in range(VISIBLE_ITEMS):
		var idx := scroll_offset + i
		if idx >= SaveData.SHOP_UPGRADES.size():
			break

		var upgrade := SaveData.SHOP_UPGRADES[idx]
		var y := start_y + float(i) * item_h
		var level: int = SaveData.shop_levels[idx]
		var max_level: int = upgrade["max_level"]
		var cost := SaveData.get_upgrade_cost(idx)
		var is_maxed := level >= max_level
		var can_afford := SaveData.coins >= cost and not is_maxed
		var is_selected := idx == selected_index

		# Background
		var bg_color := Color(0.12, 0.1, 0.18, 0.8) if not is_selected else Color(0.2, 0.15, 0.3, 0.9)
		draw_rect(Rect2(item_x, y, item_w, item_h - 5), bg_color)

		if is_selected:
			draw_rect(Rect2(item_x, y, item_w, item_h - 5), Color(0.6, 0.4, 1.0, 0.4), false, 2.0)

		# Name
		var name_color := Color(0.9, 0.85, 1.0) if can_afford else Color(0.5, 0.5, 0.5)
		draw_string(font, Vector2(item_x + 10, y + 18), upgrade["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 150, 14, name_color)

		# Description
		draw_string(font, Vector2(item_x + 10, y + 35), upgrade["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(0.6, 0.6, 0.7))

		# Level bar
		var bar_x := item_x + item_w * 0.45
		var bar_w := 100.0
		for j in range(max_level):
			var seg_x := bar_x + float(j) * (bar_w / float(max_level))
			var seg_w := bar_w / float(max_level) - 2
			var seg_color := Color(0.4, 0.8, 0.3) if j < level else Color(0.2, 0.2, 0.2, 0.5)
			draw_rect(Rect2(seg_x, y + 12, seg_w, 10), seg_color)

		# Level text
		var lvl_text := "%d/%d" % [level, max_level]
		draw_string(font, Vector2(bar_x + bar_w + 5, y + 22), lvl_text,
			HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(0.7, 0.7, 0.7))

		# Cost
		if is_maxed:
			draw_string(font, Vector2(item_x + item_w - 80, y + 35), "MAX",
				HORIZONTAL_ALIGNMENT_RIGHT, 70, 12, Color(0.4, 0.8, 0.3))
		else:
			var cost_color := Color(1.0, 0.9, 0.3) if can_afford else Color(0.8, 0.3, 0.3)
			draw_string(font, Vector2(item_x + item_w - 80, y + 35), "%d coins" % cost,
				HORIZONTAL_ALIGNMENT_RIGHT, 70, 10, cost_color)

	# Scroll indicators
	if scroll_offset > 0:
		draw_string(font, Vector2(cx - 10, 150), "^",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.7, 0.7, 0.7))
	if scroll_offset + VISIBLE_ITEMS < SaveData.SHOP_UPGRADES.size():
		draw_string(font, Vector2(cx - 10, start_y + VISIBLE_ITEMS * item_h + 10), "v",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.7, 0.7, 0.7))

	# Stats
	var stats_y := start_y + VISIBLE_ITEMS * item_h + 35
	draw_string(font, Vector2(cx - 120, stats_y), "Total Runs: %d  |  Total Kills: %d  |  Bosses: %d" % [
		SaveData.total_runs, SaveData.total_kills, SaveData.total_bosses_killed],
		HORIZONTAL_ALIGNMENT_CENTER, 240, 11, Color(0.5, 0.4, 0.6))

	# Back button
	var back_y := vp.y - 50
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.15, 0.1, 0.2, 0.8))
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.5, 0.3, 0.7, 0.5), false, 1.0)
	draw_string(font, Vector2(55, back_y + 22), "ESC: Back",
		HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.7, 0.6, 0.9))

	# Controls hint
	draw_string(font, Vector2(cx - 150, vp.y - 20), "W/S: Navigate  |  Enter/Double-Click: Buy  |  Scroll: Mouse Wheel  |  ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 300, 11, Color(0.5, 0.45, 0.6))
