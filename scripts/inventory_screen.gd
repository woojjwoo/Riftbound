extends Node2D

## Inventory & Equipment management screen.
## Accessible from pause menu (TAB). Shows equipped items and inventory grid.
## Uses procedural drawing — no scene nodes.

var time: float = 0.0

# Navigation state
enum Focus { EQUIPMENT, INVENTORY }
var focus: Focus = Focus.EQUIPMENT
var equip_cursor: int = 0       # 0-5 for equipment slots
var inv_cursor: int = 0         # index into inventory array
var inv_scroll_offset: int = 0  # scroll offset for inventory grid

# Inventory grid layout
const INV_COLS: int = 5
const INV_VISIBLE_ROWS: int = 4

# Stat comparison — shown when hovering an inventory item
var compare_item: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_TAB:
				_close()
				return
			KEY_LEFT, KEY_A:
				if focus == Focus.INVENTORY:
					if inv_cursor % INV_COLS == 0:
						focus = Focus.EQUIPMENT
						equip_cursor = clampi(inv_cursor / INV_COLS, 0, 5)
					else:
						inv_cursor -= 1
						_clamp_inv_cursor()
			KEY_RIGHT, KEY_D:
				if focus == Focus.EQUIPMENT:
					focus = Focus.INVENTORY
					inv_cursor = clampi(equip_cursor * INV_COLS, 0, maxi(SaveData.inventory.size() - 1, 0))
					_clamp_inv_cursor()
				else:
					if (inv_cursor + 1) % INV_COLS != 0:
						inv_cursor += 1
						_clamp_inv_cursor()
			KEY_UP, KEY_W:
				if focus == Focus.EQUIPMENT:
					equip_cursor = maxi(0, equip_cursor - 1)
				else:
					inv_cursor -= INV_COLS
					if inv_cursor < 0:
						inv_cursor = 0
					_clamp_inv_cursor()
			KEY_DOWN, KEY_S:
				if focus == Focus.EQUIPMENT:
					equip_cursor = mini(5, equip_cursor + 1)
				else:
					inv_cursor += INV_COLS
					_clamp_inv_cursor()
			KEY_ENTER, KEY_SPACE:
				if focus == Focus.INVENTORY:
					_equip_selected()
			KEY_X:
				if focus == Focus.INVENTORY:
					_scrap_selected()

	# Mouse scroll for inventory
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inv_scroll_offset = maxi(0, inv_scroll_offset - 1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var max_scroll := _get_max_scroll()
			inv_scroll_offset = mini(max_scroll, inv_scroll_offset + 1)
			return

	# Mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	# Mouse motion for hover comparison
	if event is InputEventMouseMotion:
		_handle_hover(event.position)

func _clamp_inv_cursor() -> void:
	var max_idx := maxi(SaveData.inventory.size() - 1, 0)
	inv_cursor = clampi(inv_cursor, 0, max_idx)
	# Auto-scroll to keep cursor visible
	var cursor_row := inv_cursor / INV_COLS
	if cursor_row < inv_scroll_offset:
		inv_scroll_offset = cursor_row
	elif cursor_row >= inv_scroll_offset + INV_VISIBLE_ROWS:
		inv_scroll_offset = cursor_row - INV_VISIBLE_ROWS + 1

func _get_max_scroll() -> int:
	var total_rows := ceili(float(SaveData.inventory.size()) / INV_COLS)
	return maxi(0, total_rows - INV_VISIBLE_ROWS)

func _equip_selected() -> void:
	if SaveData.inventory.is_empty():
		return
	if inv_cursor < 0 or inv_cursor >= SaveData.inventory.size():
		return
	var item := SaveData.inventory[inv_cursor]
	SaveData.equip_item(item)
	# Clamp cursor after removal
	_clamp_inv_cursor()
	compare_item = {}

func _scrap_selected() -> void:
	if SaveData.inventory.is_empty():
		return
	if inv_cursor < 0 or inv_cursor >= SaveData.inventory.size():
		return
	var item := SaveData.inventory[inv_cursor]
	# Scrap value: base 5 coins + 5 per rarity tier + 3 per upgrade level
	var scrap_value := 5 + item["rarity"] * 5 + item["level"] * 3
	SaveData.inventory.remove_at(inv_cursor)
	SaveData.add_coins(scrap_value)
	SaveData.equipment_changed.emit()
	SaveData.save_game()
	Audio.play_sell()
	_clamp_inv_cursor()
	compare_item = {}

func _handle_click(pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	var equip_rects := _get_equip_rects(vp)
	var inv_rects := _get_inv_rects(vp)

	# Check equipment slot clicks
	for i in range(equip_rects.size()):
		if equip_rects[i].has_point(pos):
			focus = Focus.EQUIPMENT
			equip_cursor = i
			return

	# Check inventory item clicks
	for i in range(inv_rects.size()):
		var data: Dictionary = inv_rects[i]
		var rect: Rect2 = data["rect"]
		var idx: int = data["index"]
		if rect.has_point(pos):
			if focus == Focus.INVENTORY and inv_cursor == idx:
				# Double-click behavior: equip on second click
				_equip_selected()
			else:
				focus = Focus.INVENTORY
				inv_cursor = idx
			return

func _handle_hover(pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	var inv_rects := _get_inv_rects(vp)
	compare_item = {}
	for i in range(inv_rects.size()):
		var data: Dictionary = inv_rects[i]
		var rect: Rect2 = data["rect"]
		var idx: int = data["index"]
		if rect.has_point(pos):
			if idx >= 0 and idx < SaveData.inventory.size():
				compare_item = SaveData.inventory[idx]
			return

func _get_equip_rects(vp: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var slot_x := vp.x * 0.03
	var slot_w := vp.x * 0.38
	var start_y := 80.0
	var slot_h := 68.0
	for i in range(6):
		var y := start_y + float(i) * slot_h
		rects.append(Rect2(slot_x, y, slot_w, slot_h - 4))
	return rects

func _get_inv_rects(vp: Vector2) -> Array[Dictionary]:
	var rects: Array[Dictionary] = []
	var grid_x := vp.x * 0.44
	var grid_w := vp.x * 0.53
	var cell_w := grid_w / float(INV_COLS)
	var start_y := 80.0
	var cell_h := 68.0

	for row in range(INV_VISIBLE_ROWS):
		for col in range(INV_COLS):
			var idx := (inv_scroll_offset + row) * INV_COLS + col
			if idx >= SaveData.inventory.size():
				break
			var x := grid_x + float(col) * cell_w
			var y := start_y + float(row) * cell_h
			rects.append({"rect": Rect2(x, y, cell_w - 4, cell_h - 4), "index": idx})
	return rects

func _close() -> void:
	queue_free()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.97))

	# Ambient particles
	for i in range(20):
		var seed_val := float(i) * 97.3
		var px := cx + sin(time * 0.2 + seed_val) * 400.0
		var py := vp.y / 2.0 + cos(time * 0.3 + seed_val * 0.6) * 300.0
		draw_circle(Vector2(px, py), 1.5, Color(0.4, 0.3, 0.6, 0.1))

	# Title
	draw_string(font, Vector2(cx - 100, 35), "INVENTORY & EQUIPMENT",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(1.0, 0.85, 0.3))

	# Divider line
	var div_x := vp.x * 0.42
	draw_line(Vector2(div_x, 60), Vector2(div_x, vp.y - 50), Color(0.3, 0.25, 0.45, 0.6), 1.0)

	# Section labels
	draw_string(font, Vector2(vp.x * 0.03, 70), "Equipped",
		HORIZONTAL_ALIGNMENT_LEFT, 120, 14, Color(0.7, 0.6, 0.9))
	draw_string(font, Vector2(vp.x * 0.44, 70), "Inventory (%d/%d)" % [SaveData.inventory.size(), SaveData.MAX_INVENTORY],
		HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color(0.7, 0.6, 0.9))

	# Draw equipment slots
	_draw_equipment(vp, font)

	# Draw inventory grid
	_draw_inventory(vp, font)

	# Draw stat comparison panel
	_draw_comparison(vp, font)

	# Controls hint
	draw_string(font, Vector2(cx - 250, vp.y - 12),
		"Arrows: Navigate  |  Enter: Equip  |  X: Scrap  |  Scroll: Mouse Wheel  |  TAB/ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 500, 11, Color(0.4, 0.35, 0.5))

func _draw_equipment(vp: Vector2, font: Font) -> void:
	var slot_x := vp.x * 0.03
	var slot_w := vp.x * 0.38
	var start_y := 80.0
	var slot_h := 68.0

	for i in range(6):
		var y := start_y + float(i) * slot_h
		var equip := SaveData.equipped[i]
		var slot_info := Equipment.SLOT_INFO[i]
		var is_selected := (focus == Focus.EQUIPMENT and i == equip_cursor)

		# Background
		var bg := Color(0.12, 0.1, 0.18, 0.8) if not is_selected else Color(0.2, 0.15, 0.3, 0.9)
		draw_rect(Rect2(slot_x, y, slot_w, slot_h - 4), bg)
		if is_selected:
			var pulse := 0.3 + 0.1 * sin(time * 3.0)
			draw_rect(Rect2(slot_x, y, slot_w, slot_h - 4), Color(0.6, 0.4, 1.0, pulse), false, 2.0)

		# Slot name label
		draw_string(font, Vector2(slot_x + 8, y + 16), slot_info["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 70, 11, Color(0.5, 0.45, 0.65))

		if equip.is_empty():
			draw_string(font, Vector2(slot_x + 85, y + 16), "-- Empty --",
				HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(0.35, 0.35, 0.4))
			draw_string(font, Vector2(slot_x + 85, y + 32), slot_info["stat"],
				HORIZONTAL_ALIGNMENT_LEFT, 150, 9, Color(0.35, 0.35, 0.4))
		else:
			var rc := Equipment.get_rarity_color(equip["rarity"])
			var display_name: String = equip.get("name", "Unknown")
			if equip["level"] > 0:
				display_name += " +%d" % equip["level"]
			draw_string(font, Vector2(slot_x + 85, y + 16), display_name,
				HORIZONTAL_ALIGNMENT_LEFT, int(slot_w - 95), 12, rc)

			# Rarity label
			draw_string(font, Vector2(slot_x + 85, y + 32),
				Equipment.get_rarity_name(equip["rarity"]),
				HORIZONTAL_ALIGNMENT_LEFT, 60, 9,
				Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7))

			# Stat bonus
			var bonus := Equipment.get_stat_bonus(equip)
			var stat_text := _format_stat(slot_info, bonus)
			draw_string(font, Vector2(slot_x + 85, y + 48), stat_text,
				HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(0.5, 0.8, 0.5))

			# Proc effect for legendary items
			if equip.has("proc_name"):
				var proc_color := Equipment.get_rarity_color(Equipment.Rarity.LEGENDARY)
				draw_string(font, Vector2(slot_x + 85, y + 48), "[%s]" % equip["proc_name"],
					HORIZONTAL_ALIGNMENT_LEFT, int(slot_w - 95), 9, Color(proc_color.r, proc_color.g, proc_color.b, 0.8))

			# Level pips
			var pip_x := slot_x + slot_w - 55.0
			var pip_y := y + 58.0
			var max_pips := mini(equip["level"], 15)
			for p in range(mini(max_pips, 10)):
				var pip_col := Color(0.4, 0.8, 0.3) if p < equip["level"] else Color(0.2, 0.2, 0.2)
				draw_rect(Rect2(pip_x + float(p) * 5.0, pip_y, 3.0, 6.0), pip_col)

func _draw_inventory(vp: Vector2, font: Font) -> void:
	var grid_x := vp.x * 0.44
	var grid_w := vp.x * 0.53
	var cell_w := grid_w / float(INV_COLS)
	var start_y := 80.0
	var cell_h := 68.0

	if SaveData.inventory.is_empty():
		draw_string(font, Vector2(grid_x + grid_w * 0.3, start_y + 80),
			"No items", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(0.4, 0.4, 0.5))
		return

	for row in range(INV_VISIBLE_ROWS):
		for col in range(INV_COLS):
			var idx := (inv_scroll_offset + row) * INV_COLS + col
			if idx >= SaveData.inventory.size():
				# Empty cell
				var x := grid_x + float(col) * cell_w
				var y := start_y + float(row) * cell_h
				draw_rect(Rect2(x, y, cell_w - 4, cell_h - 4), Color(0.06, 0.05, 0.1, 0.4))
				continue

			var item := SaveData.inventory[idx]
			var x := grid_x + float(col) * cell_w
			var y := start_y + float(row) * cell_h
			var is_selected := (focus == Focus.INVENTORY and idx == inv_cursor)
			var rc := Equipment.get_rarity_color(item["rarity"])

			# Cell background
			var bg := Color(0.1, 0.08, 0.15, 0.7) if not is_selected else Color(0.18, 0.13, 0.28, 0.9)
			draw_rect(Rect2(x, y, cell_w - 4, cell_h - 4), bg)

			# Rarity border
			var border_alpha := 0.5 if not is_selected else (0.6 + 0.2 * sin(time * 3.0))
			draw_rect(Rect2(x, y, cell_w - 4, cell_h - 4),
				Color(rc.r, rc.g, rc.b, border_alpha), false, 1.5 if is_selected else 1.0)

			# Slot icon letter
			var slot_name: String = Equipment.SLOT_INFO[item["slot"]]["name"]
			draw_string(font, Vector2(x + 4, y + 14), slot_name.left(3),
				HORIZONTAL_ALIGNMENT_LEFT, 30, 9, Color(0.5, 0.45, 0.6))

			# Item name (truncated)
			var display_name: String = item.get("name", "???")
			if display_name.length() > 10:
				display_name = display_name.left(9) + "."
			draw_string(font, Vector2(x + 4, y + 30), display_name,
				HORIZONTAL_ALIGNMENT_LEFT, int(cell_w - 10), 10, rc)

			# Level
			if item["level"] > 0:
				draw_string(font, Vector2(x + 4, y + 44), "+%d" % item["level"],
					HORIZONTAL_ALIGNMENT_LEFT, 30, 9, Color(0.8, 0.8, 0.3))

			# Rarity short
			draw_string(font, Vector2(x + cell_w - 30, y + 44),
				Equipment.get_rarity_name(item["rarity"]).left(1),
				HORIZONTAL_ALIGNMENT_RIGHT, 20, 9,
				Color(rc.r * 0.8, rc.g * 0.8, rc.b * 0.8))

	# Scroll indicators
	var total_rows := ceili(float(SaveData.inventory.size()) / INV_COLS)
	if inv_scroll_offset > 0:
		draw_string(font, Vector2(grid_x + grid_w * 0.45, start_y - 5), "^ ^ ^",
			HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.6, 0.5, 0.8))
	if inv_scroll_offset + INV_VISIBLE_ROWS < total_rows:
		draw_string(font, Vector2(grid_x + grid_w * 0.45, start_y + INV_VISIBLE_ROWS * cell_h + 12),
			"v v v", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.6, 0.5, 0.8))

func _draw_comparison(vp: Vector2, font: Font) -> void:
	# Use keyboard-selected item if no hover item
	var item := compare_item
	if item.is_empty() and focus == Focus.INVENTORY:
		if inv_cursor >= 0 and inv_cursor < SaveData.inventory.size():
			item = SaveData.inventory[inv_cursor]
	if item.is_empty():
		return

	var panel_x := vp.x * 0.44
	var panel_w := vp.x * 0.53
	var has_proc := item.has("proc_name")
	var panel_h := 130.0 if has_proc else 115.0
	var panel_y := vp.y - panel_h - 55.0

	# Panel background
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.08, 0.06, 0.14, 0.95))
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.4, 0.3, 0.6, 0.4), false, 1.0)

	var slot_id: int = item["slot"]
	var slot_info := Equipment.SLOT_INFO[slot_id]
	var rc := Equipment.get_rarity_color(item["rarity"])
	var item_bonus := Equipment.get_stat_bonus(item)

	# Item header
	var name_str: String = item.get("name", "Unknown")
	if item["level"] > 0:
		name_str += " +%d" % item["level"]
	draw_string(font, Vector2(panel_x + 10, panel_y + 18), name_str,
		HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 20), 13, rc)

	draw_string(font, Vector2(panel_x + 10, panel_y + 34),
		"%s %s" % [Equipment.get_rarity_name(item["rarity"]), slot_info["name"]],
		HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7))

	# Item stat
	var item_stat := _format_stat(slot_info, item_bonus)
	draw_string(font, Vector2(panel_x + 10, panel_y + 52), item_stat,
		HORIZONTAL_ALIGNMENT_LEFT, 200, 11, Color(0.5, 0.8, 0.5))

	# Compare with equipped
	var current := SaveData.equipped[slot_id]
	if current.is_empty():
		draw_string(font, Vector2(panel_x + 10, panel_y + 72),
			"Slot empty — equip to gain bonus",
			HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 20), 10, Color(0.4, 0.8, 0.4))
	else:
		var current_bonus := Equipment.get_stat_bonus(current)
		var diff := item_bonus - current_bonus
		var current_name: String = current.get("name", "Unknown")
		if current["level"] > 0:
			current_name += " +%d" % current["level"]
		var current_rc := Equipment.get_rarity_color(current["rarity"])

		draw_string(font, Vector2(panel_x + 10, panel_y + 72),
			"Equipped: %s (%s)" % [current_name, _format_stat(slot_info, current_bonus)],
			HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 20), 10, current_rc)

		# Diff line
		var diff_text: String
		var diff_color: Color
		if abs(diff) < 0.001:
			diff_text = "No change"
			diff_color = Color(0.6, 0.6, 0.6)
		elif diff > 0:
			if slot_info["per_level"] < 1.0:
				diff_text = "Upgrade: +%d%%" % int(diff * 100)
			else:
				diff_text = "Upgrade: +%.1f" % diff
			diff_color = Color(0.3, 1.0, 0.4)
		else:
			if slot_info["per_level"] < 1.0:
				diff_text = "Downgrade: %d%%" % int(diff * 100)
			else:
				diff_text = "Downgrade: %.1f" % diff
			diff_color = Color(1.0, 0.3, 0.3)

		draw_string(font, Vector2(panel_x + 10, panel_y + 90), diff_text,
			HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 20), 11, diff_color)

	# Legendary proc description
	if item.has("proc_name"):
		var proc_y := panel_y + 90 if current.is_empty() else panel_y + 100
		var proc_color := Equipment.get_rarity_color(Equipment.Rarity.LEGENDARY)
		draw_string(font, Vector2(panel_x + 10, proc_y),
			"[%s] %s" % [item.get("proc_name", ""), item.get("proc_desc", "")],
			HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 20), 9, Color(proc_color.r, proc_color.g, proc_color.b, 0.9))

	# Equip hint
	draw_string(font, Vector2(panel_x + panel_w - 140, panel_y + 112),
		"Enter: Equip  |  X: Scrap",
		HORIZONTAL_ALIGNMENT_RIGHT, 130, 9, Color(0.5, 0.45, 0.6))

func _format_stat(slot_info: Dictionary, bonus: float) -> String:
	if slot_info["per_level"] < 1.0:
		return "%s: +%d%%" % [slot_info["stat"], int(bonus * 100)]
	return "%s: +%.1f" % [slot_info["stat"], bonus]
