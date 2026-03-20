extends CanvasLayer

## Equipment crafting screen. Combine 3 items of same rarity into 1 of next rarity.
## Accessed from the title screen.

signal closed

var cursor: int = 0
var scroll_offset: int = 0
const VISIBLE_ROWS: int = 10
var time: float = 0.0
var selected_items: Array[int] = []  # indices into inventory
var craft_result: Dictionary = {}
var result_timer: float = 0.0
var result_text: String = ""

var draw_node: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "CraftDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _process(delta: float) -> void:
	time += delta
	if result_timer > 0.0:
		result_timer -= delta
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var inv := SaveData.inventory
		match event.keycode:
			KEY_ESCAPE, KEY_G:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				cursor = max(0, cursor - 1)
				if cursor < scroll_offset:
					scroll_offset = cursor
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				cursor = min(inv.size() - 1, cursor + 1)
				if cursor >= scroll_offset + VISIBLE_ROWS:
					scroll_offset = cursor - VISIBLE_ROWS + 1
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				if cursor >= 0 and cursor < inv.size():
					_toggle_selection(cursor)
					Audio.play_ui_click()
			KEY_C:
				_try_craft()
		get_viewport().set_input_as_handled()

func _toggle_selection(idx: int) -> void:
	if idx in selected_items:
		selected_items.erase(idx)
	elif selected_items.size() < 3:
		selected_items.append(idx)

func _try_craft() -> void:
	if selected_items.size() != 3:
		result_text = "Select exactly 3 items"
		result_timer = 2.0
		return

	var inv := SaveData.inventory
	var items: Array[Dictionary] = []
	for idx in selected_items:
		if idx >= 0 and idx < inv.size():
			items.append(inv[idx])

	if items.size() != 3:
		return

	# Check same rarity
	var rarity: int = items[0]["rarity"]
	for item in items:
		if item["rarity"] != rarity:
			result_text = "All 3 items must be same rarity"
			result_timer = 2.0
			return

	if rarity >= Equipment.Rarity.LEGENDARY:
		result_text = "Cannot craft beyond Legendary"
		result_timer = 2.0
		return

	# Check cost
	var cost := Equipment.get_craft_cost(rarity)
	if SaveData.coins < cost:
		result_text = "Need %d coins (have %d)" % [cost, SaveData.coins]
		result_timer = 2.0
		return

	# Craft!
	SaveData.coins -= cost
	var result := Equipment.craft_upgrade(items)
	if result.is_empty():
		result_text = "Crafting failed"
		result_timer = 2.0
		return

	# Remove selected items from inventory (reverse order to keep indices valid)
	var sorted_indices := selected_items.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	for idx in sorted_indices:
		if idx < inv.size():
			inv.remove_at(idx)

	# Add crafted item
	SaveData.add_to_inventory(result)
	selected_items = []
	cursor = 0
	scroll_offset = 0

	var rarity_name := Equipment.get_rarity_name(result["rarity"])
	result_text = "Crafted: %s (%s)" % [result["name"], rarity_name]
	result_timer = 3.0
	Audio.play_ui_confirm()
	SaveData.save_game()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 60, 40), "CRAFTING",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(1.0, 0.85, 0.4))

	# Instructions
	draw_node.draw_string(font, Vector2(cx - 160, 60), "Combine 3 items of same rarity → 1 item of next rarity",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.5, 0.4, 0.6))

	draw_node.draw_string(font, Vector2(cx - 100, 75), "Coins: %d" % SaveData.coins,
		HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color(1.0, 0.9, 0.4))

	var inv := SaveData.inventory

	if inv.is_empty():
		draw_node.draw_string(font, Vector2(cx - 80, 120), "No items in inventory.",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.4, 0.35, 0.5))
		draw_node.draw_string(font, Vector2(cx - 80, vp.y - 20), "ESC: Close",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))
		return

	# Column headers
	var header_y := 92.0
	var col_sel := 40.0
	var col_name := 70.0
	var col_rarity := 220.0
	var col_slot := 310.0
	var col_level := 400.0
	var header_color := Color(0.6, 0.5, 0.75)

	draw_node.draw_string(font, Vector2(col_sel, header_y), "Sel", HORIZONTAL_ALIGNMENT_LEFT, 25, 9, header_color)
	draw_node.draw_string(font, Vector2(col_name, header_y), "Name", HORIZONTAL_ALIGNMENT_LEFT, 120, 9, header_color)
	draw_node.draw_string(font, Vector2(col_rarity, header_y), "Rarity", HORIZONTAL_ALIGNMENT_LEFT, 70, 9, header_color)
	draw_node.draw_string(font, Vector2(col_slot, header_y), "Slot", HORIZONTAL_ALIGNMENT_LEFT, 70, 9, header_color)
	draw_node.draw_string(font, Vector2(col_level, header_y), "Level", HORIZONTAL_ALIGNMENT_LEFT, 50, 9, header_color)

	draw_node.draw_line(Vector2(30, header_y + 5), Vector2(vp.x - 30, header_y + 5), Color(0.3, 0.25, 0.4, 0.5), 1.0)

	# Item rows
	var row_y := header_y + 22.0
	var row_h := 24.0

	for i in range(scroll_offset, mini(scroll_offset + VISIBLE_ROWS, inv.size())):
		var item: Dictionary = inv[i]
		var y := row_y + float(i - scroll_offset) * row_h
		var is_cursor := (i == cursor)
		var is_selected := i in selected_items

		if is_cursor:
			draw_node.draw_rect(Rect2(30, y - 12, vp.x - 60, row_h - 2), Color(0.3, 0.2, 0.5, 0.3))

		# Selection marker
		var sel_text := "[X]" if is_selected else "[ ]"
		var sel_color := Color(1.0, 0.9, 0.3) if is_selected else Color(0.4, 0.35, 0.5)
		draw_node.draw_string(font, Vector2(col_sel, y), sel_text, HORIZONTAL_ALIGNMENT_LEFT, 25, 10, sel_color)

		# Name
		var rarity_color := Equipment.get_rarity_color(item["rarity"])
		draw_node.draw_string(font, Vector2(col_name, y), item.get("name", "Unknown"),
			HORIZONTAL_ALIGNMENT_LEFT, 140, 10, rarity_color)

		# Rarity
		draw_node.draw_string(font, Vector2(col_rarity, y), Equipment.get_rarity_name(item["rarity"]),
			HORIZONTAL_ALIGNMENT_LEFT, 70, 10, rarity_color)

		# Slot
		draw_node.draw_string(font, Vector2(col_slot, y), Equipment.get_slot_name(item["slot"]),
			HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color(0.6, 0.55, 0.7))

		# Level
		draw_node.draw_string(font, Vector2(col_level, y), "+%d" % item.get("level", 0),
			HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(0.6, 0.5, 0.8))

	# Selected items summary
	var summary_y := vp.y - 80.0
	draw_node.draw_line(Vector2(30, summary_y - 10), Vector2(vp.x - 30, summary_y - 10), Color(0.3, 0.25, 0.4, 0.5), 1.0)

	if selected_items.size() > 0:
		var sel_text := "Selected: %d/3" % selected_items.size()
		draw_node.draw_string(font, Vector2(40, summary_y), sel_text,
			HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.7, 0.6, 0.9))

		if selected_items.size() == 3:
			var first_rarity: int = inv[selected_items[0]]["rarity"]
			var cost := Equipment.get_craft_cost(first_rarity)
			var can_craft := SaveData.coins >= cost
			var cost_color := Color(0.3, 1.0, 0.4) if can_craft else Color(1.0, 0.3, 0.3)
			draw_node.draw_string(font, Vector2(160, summary_y), "Cost: %d coins" % cost,
				HORIZONTAL_ALIGNMENT_LEFT, 120, 11, cost_color)
			draw_node.draw_string(font, Vector2(300, summary_y), "C: Craft!",
				HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color(1.0, 0.85, 0.3))

	# Result text
	if result_timer > 0.0 and not result_text.is_empty():
		var alpha := minf(result_timer, 1.0)
		draw_node.draw_string(font, Vector2(cx - 100, summary_y + 20), result_text,
			HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(1.0, 0.9, 0.4, alpha))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 160, vp.y - 20), "W/S: Navigate  |  ENTER: Select  |  C: Craft  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.4, 0.35, 0.55))
