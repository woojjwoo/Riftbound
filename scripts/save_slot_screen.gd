extends CanvasLayer

## Save slot selection screen. Shows 3 save slots with preview info.
## Allows switching, creating, and deleting saves.

signal closed

var cursor: int = 0
var time: float = 0.0
var confirm_delete: bool = false
var slot_infos: Array[Dictionary] = []

var draw_node: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cursor = SaveData.current_slot
	_refresh_slots()
	draw_node = Control.new()
	draw_node.name = "SlotDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _refresh_slots() -> void:
	slot_infos = []
	for i in range(SaveData.SAVE_SLOTS):
		slot_infos.append(SaveData.get_slot_info(i))

func _process(delta: float) -> void:
	time += delta
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if confirm_delete:
			match event.keycode:
				KEY_Y:
					SaveData.delete_slot(cursor)
					if cursor == SaveData.current_slot:
						SaveData.reset_save()
					_refresh_slots()
					confirm_delete = false
					Audio.play_ui_confirm()
				_:
					confirm_delete = false
					Audio.play_ui_cancel()
			get_viewport().set_input_as_handled()
			return

		match event.keycode:
			KEY_ESCAPE:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				cursor = max(0, cursor - 1)
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				cursor = min(SaveData.SAVE_SLOTS - 1, cursor + 1)
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				_select_slot()
			KEY_DELETE, KEY_X:
				if slot_infos[cursor].get("empty", true) == false:
					confirm_delete = true
					Audio.play_ui_click()
		get_viewport().set_input_as_handled()

func _select_slot() -> void:
	if cursor == SaveData.current_slot:
		Audio.play_ui_click()
		closed.emit()
		queue_free()
		return
	SaveData.switch_slot(cursor)
	_refresh_slots()
	Audio.play_ui_confirm()
	closed.emit()
	queue_free()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 60, 45), "SAVE SLOTS",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(0.8, 0.6, 1.0))

	# Delete confirmation overlay
	if confirm_delete:
		var warn_y := cy + 80
		draw_node.draw_rect(Rect2(cx - 120, warn_y - 25, 240, 50), Color(0.3, 0.05, 0.05, 0.9))
		draw_node.draw_rect(Rect2(cx - 120, warn_y - 25, 240, 50), Color(1.0, 0.3, 0.2, 0.6), false, 1.0)
		draw_node.draw_string(font, Vector2(cx - 100, warn_y - 5), "Delete Slot %d? Press Y to confirm" % (cursor + 1),
			HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(1.0, 0.4, 0.3))
		draw_node.draw_string(font, Vector2(cx - 80, warn_y + 14), "Any other key to cancel",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.6, 0.4, 0.5))

	# Slot cards
	var card_w := 300.0
	var card_h := 70.0
	var start_y := 80.0
	var gap := 12.0

	for i in range(SaveData.SAVE_SLOTS):
		var info: Dictionary = slot_infos[i]
		var y := start_y + float(i) * (card_h + gap)
		var x := cx - card_w / 2.0
		var is_selected := (i == cursor)
		var is_active := (i == SaveData.current_slot)

		# Card background
		var bg_color = Color(0.15, 0.1, 0.25, 0.9) if is_selected else Color(0.08, 0.05, 0.12, 0.8)
		draw_node.draw_rect(Rect2(x, y, card_w, card_h), bg_color)

		# Border
		var border_color: Color
		if is_active:
			var pulse := 0.5 + 0.3 * sin(time * 2.5)
			border_color = Color(0.4, 0.8, 1.0, pulse)
		elif is_selected:
			border_color = Color(0.6, 0.4, 0.9, 0.7)
		else:
			border_color = Color(0.3, 0.25, 0.4, 0.4)
		draw_node.draw_rect(Rect2(x, y, card_w, card_h), border_color, false, 1.5 if is_selected else 1.0)

		# Active indicator
		if is_active:
			draw_node.draw_string(font, Vector2(x + card_w - 55, y + 15), "ACTIVE",
				HORIZONTAL_ALIGNMENT_LEFT, 50, 9, Color(0.4, 0.9, 1.0))

		# Slot label
		draw_node.draw_string(font, Vector2(x + 12, y + 18), "Slot %d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, 60, 14, Color(0.9, 0.8, 1.0) if is_selected else Color(0.6, 0.55, 0.7))

		if info.get("empty", true):
			# Empty slot
			draw_node.draw_string(font, Vector2(x + 12, y + 40), "— Empty —",
				HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color(0.4, 0.35, 0.5))
			draw_node.draw_string(font, Vector2(x + 12, y + 56), "Select to create new save",
				HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color(0.35, 0.3, 0.45))
		else:
			# Slot info
			var level: int = info.get("level", 1)
			var coins: int = info.get("coins", 0)
			var worlds: int = info.get("worlds", 0)
			var runs: int = info.get("runs", 0)
			var ng: int = info.get("ng_plus", 0)

			var ng_text := ""
			if ng > 0:
				ng_text = " (NG+%d)" % ng

			draw_node.draw_string(font, Vector2(x + 12, y + 38),
				"Level %d%s  |  Coins: %d" % [level, ng_text, coins],
				HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color(0.7, 0.65, 0.8))
			draw_node.draw_string(font, Vector2(x + 12, y + 55),
				"Worlds: %d/6  |  Runs: %d" % [worlds, runs],
				HORIZONTAL_ALIGNMENT_LEFT, 280, 10, Color(0.5, 0.45, 0.6))

	# Selection cursor arrow
	var arrow_y := start_y + float(cursor) * (card_h + gap) + card_h / 2.0
	var arrow_pulse := sin(time * 4.0) * 3.0
	draw_node.draw_string(font, Vector2(cx - card_w / 2.0 - 18 + arrow_pulse, arrow_y + 5), ">",
		HORIZONTAL_ALIGNMENT_CENTER, 12, 16, Color(0.8, 0.6, 1.0))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 160, vp.y - 20),
		"W/S: Navigate  |  ENTER: Select  |  X: Delete  |  ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.4, 0.35, 0.55))
