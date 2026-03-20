extends CanvasLayer

## Challenge modifier selection screen. Toggle mutators on/off before a run.
## Accessed from the title screen.

signal closed

var cursor: int = 0
var time: float = 0.0
var draw_node: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "ChallengeDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _process(delta: float) -> void:
	time += delta
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				cursor = max(0, cursor - 1)
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				cursor = min(Challenges.MODIFIERS.size() - 1, cursor + 1)
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				var mod := Challenges.MODIFIERS[cursor]
				Challenges.toggle(mod["id"])
				Audio.play_ui_confirm()
		get_viewport().set_input_as_handled()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 80, 40), "CHALLENGE MODIFIERS",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(1.0, 0.7, 0.3))

	# Bonus summary
	var coin_bonus := Challenges.get_total_coin_bonus()
	var exp_bonus := Challenges.get_total_exp_bonus()
	var bonus_text := "Active: %d  |  Coin Bonus: +%d%%  |  EXP Bonus: +%d%%" % [
		Challenges.get_active_count(), int(coin_bonus * 100), int(exp_bonus * 100)]
	draw_node.draw_string(font, Vector2(cx - 140, 60), bonus_text,
		HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.6, 0.5, 0.7))

	# Modifier list
	var list_y := 90.0
	var row_h := 40.0

	for i in range(Challenges.MODIFIERS.size()):
		var mod := Challenges.MODIFIERS[i]
		var y := list_y + float(i) * row_h
		var is_selected := (i == cursor)
		var is_active := Challenges.is_active(mod["id"])

		# Selection highlight
		if is_selected:
			draw_node.draw_rect(Rect2(cx - 180, y - 14, 360, row_h - 4), Color(0.3, 0.2, 0.5, 0.4))

		# Active indicator
		var check_color = Color(0.3, 1.0, 0.4) if is_active else Color(0.3, 0.3, 0.35)
		var check_text = "[X]" if is_active else "[ ]"
		draw_node.draw_string(font, Vector2(cx - 170, y), check_text,
			HORIZONTAL_ALIGNMENT_LEFT, 30, 12, check_color)

		# Name
		var name_color = Color(1.0, 0.8, 0.3) if is_active else (Color(0.9, 0.85, 1.0) if is_selected else Color(0.6, 0.55, 0.7))
		draw_node.draw_string(font, Vector2(cx - 138, y), mod["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 120, 13, name_color)

		# Description
		draw_node.draw_string(font, Vector2(cx - 138, y + 14), mod["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, 250, 9, Color(0.5, 0.45, 0.6))

		# Bonus
		var bonus_str := "+%d%% coins, +%d%% exp" % [int(mod["coin_bonus"] * 100), int(mod["exp_bonus"] * 100)]
		draw_node.draw_string(font, Vector2(cx + 80, y), bonus_str,
			HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color(0.4, 0.8, 0.4))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 140, vp.y - 20), "W/S: Navigate  |  ENTER: Toggle  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.4, 0.35, 0.55))
