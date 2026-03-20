extends Node2D

## Achievement gallery screen. Shows all achievements in a scrollable list.
## Unlocked achievements are highlighted, locked ones are dimmed.
## Accessible from title screen via I key.

var time: float = 0.0
var scroll_offset: int = 0
var selected_index: int = 0
const VISIBLE_ITEMS: int = 7
const ITEM_HEIGHT: float = 70.0

# Category filter
var categories: Array[String] = ["all", "combat", "progression", "economy", "survival", "misc"]
var category_names: Array[String] = ["All", "Combat", "Progression", "Economy", "Survival", "Misc"]
var current_category: int = 0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var filtered := _get_filtered_achievements()
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
			KEY_UP, KEY_W:
				selected_index = maxi(0, selected_index - 1)
				if selected_index < scroll_offset:
					scroll_offset = selected_index
			KEY_DOWN, KEY_S:
				selected_index = mini(filtered.size() - 1, selected_index + 1)
				if selected_index >= scroll_offset + VISIBLE_ITEMS:
					scroll_offset = selected_index - VISIBLE_ITEMS + 1
			KEY_LEFT, KEY_A:
				current_category = (current_category - 1 + categories.size()) % categories.size()
				selected_index = 0
				scroll_offset = 0
			KEY_RIGHT, KEY_D:
				current_category = (current_category + 1) % categories.size()
				selected_index = 0
				scroll_offset = 0

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_offset = maxi(0, scroll_offset - 1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var filtered := _get_filtered_achievements()
			var max_scroll := maxi(0, filtered.size() - VISIBLE_ITEMS)
			scroll_offset = mini(max_scroll, scroll_offset + 1)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport_rect().size
		var mx := event.position.x
		var my := event.position.y

		# Category tabs
		if my >= 85.0 and my <= 115.0:
			var tab_w := vp.x * 0.7 / float(categories.size())
			var tab_start := vp.x * 0.15
			for i in range(categories.size()):
				var tx := tab_start + float(i) * tab_w
				if mx >= tx and mx < tx + tab_w:
					current_category = i
					selected_index = 0
					scroll_offset = 0
					return

		# Achievement items
		var start_y := 130.0
		var item_x := vp.x * 0.1
		var item_w := vp.x * 0.8
		for i in range(VISIBLE_ITEMS):
			var y := start_y + float(i) * ITEM_HEIGHT
			if mx >= item_x and mx < item_x + item_w and my >= y and my < y + ITEM_HEIGHT - 4:
				selected_index = scroll_offset + i
				return

		# Back button
		if my > vp.y - 60 and mx < 200:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _get_filtered_achievements() -> Array[Dictionary]:
	var all_defs := Achievements.get_all_defs()
	if current_category == 0:
		return all_defs
	var cat: String = categories[current_category]
	var filtered: Array[Dictionary] = []
	for def in all_defs:
		if def.get("category", "") == cat:
			filtered.append(def)
	return filtered

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.03, 0.08))

	# Floating particles
	for i in range(20):
		var seed_val := float(i) * 97.3
		var px := cx + sin(time * 0.2 + seed_val) * 400.0
		var py := vp.y / 2.0 + cos(time * 0.3 + seed_val * 0.6) * 300.0
		draw_circle(Vector2(px, py), 1.5, Color(0.4, 0.3, 0.6, 0.1))

	# Title
	draw_string(font, Vector2(cx - 100, 40), "ACHIEVEMENTS",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color(1.0, 0.85, 0.3))

	# Progress counter
	var progress_text := "%d / %d Unlocked" % [Achievements.get_unlocked_count(), Achievements.get_total_count()]
	draw_string(font, Vector2(cx - 60, 65), progress_text,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.7, 0.65, 0.85))

	# Category tabs
	var tab_w := vp.x * 0.7 / float(categories.size())
	var tab_start := vp.x * 0.15
	var tab_y := 85.0
	for i in range(categories.size()):
		var tx := tab_start + float(i) * tab_w
		var is_active := i == current_category
		var tab_bg := Color(0.2, 0.15, 0.3, 0.9) if is_active else Color(0.1, 0.08, 0.15, 0.6)
		draw_rect(Rect2(tx + 2, tab_y, tab_w - 4, 25), tab_bg)
		if is_active:
			draw_rect(Rect2(tx + 2, tab_y, tab_w - 4, 25), Color(1.0, 0.85, 0.3, 0.5), false, 1.5)
		var tab_color := Color(1.0, 0.9, 0.5) if is_active else Color(0.5, 0.45, 0.6)
		draw_string(font, Vector2(tx + 6, tab_y + 17), category_names[i],
			HORIZONTAL_ALIGNMENT_LEFT, int(tab_w - 12), 11, tab_color)

	# Achievement list
	var filtered := _get_filtered_achievements()
	var start_y := 130.0
	var item_x := vp.x * 0.1
	var item_w := vp.x * 0.8

	if filtered.is_empty():
		draw_string(font, Vector2(cx - 60, start_y + 60), "No achievements in this category",
			HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.4, 0.4, 0.5))
	else:
		for i in range(VISIBLE_ITEMS):
			var idx := scroll_offset + i
			if idx >= filtered.size():
				break
			var def: Dictionary = filtered[idx]
			var y := start_y + float(i) * ITEM_HEIGHT
			var is_unlocked := Achievements.is_unlocked(def["id"])
			var is_selected := idx == selected_index

			# Background
			var bg_color: Color
			if is_selected:
				bg_color = Color(0.2, 0.15, 0.3, 0.9)
			elif is_unlocked:
				bg_color = Color(0.12, 0.1, 0.18, 0.8)
			else:
				bg_color = Color(0.06, 0.05, 0.1, 0.6)
			draw_rect(Rect2(item_x, y, item_w, ITEM_HEIGHT - 4), bg_color)

			# Selection border
			if is_selected:
				var pulse := 0.3 + 0.1 * sin(time * 3.0)
				draw_rect(Rect2(item_x, y, item_w, ITEM_HEIGHT - 4),
					Color(0.6, 0.4, 1.0, pulse), false, 2.0)

			# Icon box
			var icon_x := item_x + 8.0
			var icon_y := y + 8.0
			var icon_size := ITEM_HEIGHT - 20.0
			var icon_bg := Color(0.15, 0.1, 0.25, 0.8) if is_unlocked else Color(0.08, 0.06, 0.12, 0.6)
			draw_rect(Rect2(icon_x, icon_y, icon_size, icon_size), icon_bg)
			var icon_border := Color(1.0, 0.85, 0.3, 0.6) if is_unlocked else Color(0.3, 0.25, 0.4, 0.4)
			draw_rect(Rect2(icon_x, icon_y, icon_size, icon_size), icon_border, false, 1.0)

			# Icon text
			var icon_text: String = def.get("icon", "?") if is_unlocked else "?"
			var icon_color := Color(1.0, 0.85, 0.3, 1.0) if is_unlocked else Color(0.3, 0.3, 0.4)
			draw_string(font, Vector2(icon_x + 4.0, icon_y + icon_size / 2.0 + 5.0),
				icon_text, HORIZONTAL_ALIGNMENT_LEFT, int(icon_size - 8), 12, icon_color)

			# Text area
			var text_x := icon_x + icon_size + 12.0
			var text_w := int(item_w - icon_size - 32.0)

			# Name
			var name_text: String = def["name"] if is_unlocked else "???"
			var name_color := Color(1.0, 0.85, 0.3) if is_unlocked else Color(0.4, 0.4, 0.5)
			draw_string(font, Vector2(text_x, y + 25.0), name_text,
				HORIZONTAL_ALIGNMENT_LEFT, text_w, 14, name_color)

			# Description
			var desc_text: String = def["desc"] if is_unlocked else "Locked"
			var desc_color := Color(0.7, 0.65, 0.85) if is_unlocked else Color(0.35, 0.35, 0.4)
			draw_string(font, Vector2(text_x, y + 45.0), desc_text,
				HORIZONTAL_ALIGNMENT_LEFT, text_w, 11, desc_color)

			# Unlocked indicator
			if is_unlocked:
				draw_string(font, Vector2(item_x + item_w - 80.0, y + 35.0), "UNLOCKED",
					HORIZONTAL_ALIGNMENT_RIGHT, 70, 10, Color(0.4, 0.8, 0.3, 0.8))

	# Scroll indicators
	if scroll_offset > 0:
		draw_string(font, Vector2(cx - 10, start_y - 5), "^",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.7, 0.7, 0.7))
	if scroll_offset + VISIBLE_ITEMS < filtered.size():
		draw_string(font, Vector2(cx - 10, start_y + VISIBLE_ITEMS * ITEM_HEIGHT + 10), "v",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.7, 0.7, 0.7))

	# Back button
	var back_y := vp.y - 50
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.15, 0.1, 0.2, 0.8))
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.5, 0.3, 0.7, 0.5), false, 1.0)
	draw_string(font, Vector2(55, back_y + 22), "ESC: Back",
		HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.7, 0.6, 0.9))

	# Controls hint
	draw_string(font, Vector2(cx - 180, vp.y - 20),
		"W/S: Navigate  |  A/D: Category  |  Scroll: Mouse Wheel  |  ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 360, 11, Color(0.5, 0.45, 0.6))
