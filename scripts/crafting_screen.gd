extends CanvasLayer

## Equipment crafting + enchanting screen.
## Craft mode: Combine 3 items of same rarity into 1 of next rarity.
## Enchant mode: Add/reroll enchantments on equipped or inventory items.

signal closed

enum Mode { CRAFT, ENCHANT }
var mode: Mode = Mode.CRAFT

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
		var list_size: int = SaveData.inventory.size() if mode == Mode.CRAFT else _get_enchant_items().size()
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
				cursor = min(list_size - 1, cursor + 1)
				if cursor >= scroll_offset + VISIBLE_ROWS:
					scroll_offset = cursor - VISIBLE_ROWS + 1
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				if mode == Mode.CRAFT:
					if cursor >= 0 and cursor < list_size:
						_toggle_selection(cursor)
						Audio.play_ui_click()
				elif mode == Mode.ENCHANT:
					_try_enchant()
			KEY_C:
				if mode == Mode.CRAFT:
					_try_craft()
			KEY_E:
				if mode == Mode.ENCHANT:
					_try_enchant()
				else:
					mode = Mode.ENCHANT
					selected_items = []
					cursor = 0
					scroll_offset = 0
					Audio.play_ui_click()
			KEY_TAB:
				mode = Mode.CRAFT if mode == Mode.ENCHANT else Mode.ENCHANT
				selected_items = []
				cursor = 0
				scroll_offset = 0
				Audio.play_ui_click()
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

func _try_enchant() -> void:
	# Enchant the currently selected equipped item
	var all_items := _get_enchant_items()
	if cursor < 0 or cursor >= all_items.size():
		result_text = "Select an item to enchant"
		result_timer = 2.0
		return

	var item: Dictionary = all_items[cursor]["item"]
	if item.is_empty():
		return

	var cost := Equipment.get_enchant_cost(item["rarity"])
	if SaveData.coins < cost:
		result_text = "Need %d coins (have %d)" % [cost, SaveData.coins]
		result_timer = 2.0
		return

	SaveData.coins -= cost
	var key: String
	if item.has("enchant"):
		key = Equipment.reroll_enchant(item)
		result_text = "Rerolled: %s" % Equipment.get_enchant_info(key).get("name", key)
	else:
		key = Equipment.enchant_item(item)
		result_text = "Enchanted: %s" % Equipment.get_enchant_info(key).get("name", key)
	result_timer = 3.0
	Audio.play_ui_confirm()
	SaveData.equipment_changed.emit()
	SaveData.save_game()

func _get_enchant_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	# Show equipped items first, then inventory
	for i in range(6):
		if not SaveData.equipped[i].is_empty():
			items.append({"item": SaveData.equipped[i], "source": "equipped", "index": i})
	for i in range(SaveData.inventory.size()):
		items.append({"item": SaveData.inventory[i], "source": "inventory", "index": i})
	return items

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Mode tabs
	var craft_col = Color(1.0, 0.85, 0.4) if mode == Mode.CRAFT else Color(0.4, 0.35, 0.5)
	var enchant_col = Color(0.6, 0.3, 1.0) if mode == Mode.ENCHANT else Color(0.4, 0.35, 0.5)
	draw_node.draw_string(font, Vector2(cx - 100, 30), "CRAFT", HORIZONTAL_ALIGNMENT_LEFT, 60, 14, craft_col)
	draw_node.draw_string(font, Vector2(cx - 30, 30), "|", HORIZONTAL_ALIGNMENT_LEFT, 10, 14, Color(0.3, 0.25, 0.4))
	draw_node.draw_string(font, Vector2(cx - 10, 30), "ENCHANT", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, enchant_col)
	draw_node.draw_string(font, Vector2(cx + 80, 30), "(TAB)", HORIZONTAL_ALIGNMENT_LEFT, 40, 9, Color(0.35, 0.3, 0.45))

	draw_node.draw_string(font, Vector2(cx - 100, 50), "Coins: %d" % SaveData.coins,
		HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color(1.0, 0.9, 0.4))

	if mode == Mode.CRAFT:
		_draw_craft_mode(vp, cx, font)
	else:
		_draw_enchant_mode(vp, cx, font)

	# Result text
	var summary_y := vp.y - 80.0
	if result_timer > 0.0 and not result_text.is_empty():
		var alpha := minf(result_timer, 1.0)
		draw_node.draw_string(font, Vector2(cx - 120, summary_y + 20), result_text,
			HORIZONTAL_ALIGNMENT_CENTER, 240, 12, Color(1.0, 0.9, 0.4, alpha))

func _draw_craft_mode(vp: Vector2, cx: float, font: Font) -> void:
	# Instructions
	draw_node.draw_string(font, Vector2(cx - 160, 68), "Combine 3 items of same rarity -> 1 of next rarity",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.5, 0.4, 0.6))

	var inv := SaveData.inventory

	if inv.is_empty():
		draw_node.draw_string(font, Vector2(cx - 80, 120), "No items in inventory.",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.4, 0.35, 0.5))
		draw_node.draw_string(font, Vector2(cx - 80, vp.y - 20), "ESC: Close",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))
		return

	# Column headers
	var header_y := 85.0
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
		var sel_text = "[X]" if is_selected else "[ ]"
		var sel_color = Color(1.0, 0.9, 0.3) if is_selected else Color(0.4, 0.35, 0.5)
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
			var cost_color = Color(0.3, 1.0, 0.4) if can_craft else Color(1.0, 0.3, 0.3)
			draw_node.draw_string(font, Vector2(160, summary_y), "Cost: %d coins" % cost,
				HORIZONTAL_ALIGNMENT_LEFT, 120, 11, cost_color)
			draw_node.draw_string(font, Vector2(300, summary_y), "C: Craft!",
				HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color(1.0, 0.85, 0.3))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 160, vp.y - 20), "W/S: Navigate  |  ENTER: Select  |  C: Craft  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.4, 0.35, 0.55))

func _draw_enchant_mode(vp: Vector2, cx: float, font: Font) -> void:
	# Instructions
	draw_node.draw_string(font, Vector2(cx - 140, 68), "Add or reroll enchantments on your equipment",
		HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.5, 0.4, 0.6))

	var all_items := _get_enchant_items()

	if all_items.is_empty():
		draw_node.draw_string(font, Vector2(cx - 80, 120), "No items to enchant.",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.4, 0.35, 0.5))
		draw_node.draw_string(font, Vector2(cx - 80, vp.y - 20), "ESC: Close",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))
		return

	# Column headers
	var header_y := 85.0
	var col_src := 40.0
	var col_name := 90.0
	var col_rarity := 220.0
	var col_slot := 300.0
	var col_enchant := 370.0
	var header_color := Color(0.6, 0.5, 0.75)

	draw_node.draw_string(font, Vector2(col_src, header_y), "Source", HORIZONTAL_ALIGNMENT_LEFT, 45, 9, header_color)
	draw_node.draw_string(font, Vector2(col_name, header_y), "Name", HORIZONTAL_ALIGNMENT_LEFT, 120, 9, header_color)
	draw_node.draw_string(font, Vector2(col_rarity, header_y), "Rarity", HORIZONTAL_ALIGNMENT_LEFT, 70, 9, header_color)
	draw_node.draw_string(font, Vector2(col_slot, header_y), "Slot", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, header_color)
	draw_node.draw_string(font, Vector2(col_enchant, header_y), "Enchant", HORIZONTAL_ALIGNMENT_LEFT, 90, 9, header_color)

	draw_node.draw_line(Vector2(30, header_y + 5), Vector2(vp.x - 30, header_y + 5), Color(0.3, 0.25, 0.4, 0.5), 1.0)

	# Item rows
	var row_y := header_y + 22.0
	var row_h := 24.0

	for i in range(scroll_offset, mini(scroll_offset + VISIBLE_ROWS, all_items.size())):
		var entry: Dictionary = all_items[i]
		var item: Dictionary = entry["item"]
		var y := row_y + float(i - scroll_offset) * row_h
		var is_cursor := (i == cursor)

		if is_cursor:
			draw_node.draw_rect(Rect2(30, y - 12, vp.x - 60, row_h - 2), Color(0.3, 0.2, 0.5, 0.3))

		# Source label
		var src_text = "EQP" if entry["source"] == "equipped" else "INV"
		var src_color = Color(0.3, 0.8, 0.5) if entry["source"] == "equipped" else Color(0.5, 0.45, 0.6)
		draw_node.draw_string(font, Vector2(col_src, y), src_text, HORIZONTAL_ALIGNMENT_LEFT, 40, 10, src_color)

		# Name
		var rarity_color := Equipment.get_rarity_color(item["rarity"])
		draw_node.draw_string(font, Vector2(col_name, y), item.get("name", "Unknown"),
			HORIZONTAL_ALIGNMENT_LEFT, 120, 10, rarity_color)

		# Rarity
		draw_node.draw_string(font, Vector2(col_rarity, y), Equipment.get_rarity_name(item["rarity"]),
			HORIZONTAL_ALIGNMENT_LEFT, 70, 10, rarity_color)

		# Slot
		draw_node.draw_string(font, Vector2(col_slot, y), Equipment.get_slot_name(item["slot"]),
			HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.6, 0.55, 0.7))

		# Enchantment status
		if item.has("enchant"):
			var info := Equipment.get_enchant_info(item["enchant"])
			var ench_name: String = info.get("name", item["enchant"])
			var ench_color: Color = info.get("color", Color(0.6, 0.3, 1.0))
			draw_node.draw_string(font, Vector2(col_enchant, y), ench_name,
				HORIZONTAL_ALIGNMENT_LEFT, 90, 10, ench_color)
		else:
			draw_node.draw_string(font, Vector2(col_enchant, y), "None",
				HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color(0.35, 0.3, 0.45))

	# Selected item details
	var summary_y := vp.y - 80.0
	draw_node.draw_line(Vector2(30, summary_y - 10), Vector2(vp.x - 30, summary_y - 10), Color(0.3, 0.25, 0.4, 0.5), 1.0)

	if cursor >= 0 and cursor < all_items.size():
		var item: Dictionary = all_items[cursor]["item"]
		var cost := Equipment.get_enchant_cost(item["rarity"])
		var can_afford := SaveData.coins >= cost
		var cost_color = Color(0.3, 1.0, 0.4) if can_afford else Color(1.0, 0.3, 0.3)
		var action_text = "Reroll" if item.has("enchant") else "Enchant"
		draw_node.draw_string(font, Vector2(40, summary_y), "%s Cost: %d coins" % [action_text, cost],
			HORIZONTAL_ALIGNMENT_LEFT, 180, 11, cost_color)
		draw_node.draw_string(font, Vector2(240, summary_y), "ENTER/E: %s" % action_text,
			HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color(0.6, 0.3, 1.0))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 160, vp.y - 20), "W/S: Navigate  |  ENTER: Enchant  |  TAB: Craft  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.4, 0.35, 0.55))
