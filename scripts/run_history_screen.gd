extends CanvasLayer

## Run history / leaderboard screen. Shows past run results sorted by kills.
## Accessed from the title screen.

signal closed

var cursor: int = 0
var scroll_offset: int = 0
const VISIBLE_ROWS: int = 12
var time: float = 0.0
var sort_by: String = "kills"  # kills, worlds_cleared, level

var draw_node: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "HistoryDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _process(delta: float) -> void:
	time += delta
	draw_node.queue_redraw()

func _get_sorted_runs() -> Array:
	var runs := SaveData.run_history.duplicate()
	runs.sort_custom(func(a, b): return a.get(sort_by, 0) > b.get(sort_by, 0))
	return runs

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var runs := _get_sorted_runs()
		match event.keycode:
			KEY_ESCAPE, KEY_H:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				cursor = max(0, cursor - 1)
				if cursor < scroll_offset:
					scroll_offset = cursor
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				cursor = min(runs.size() - 1, cursor + 1)
				if cursor >= scroll_offset + VISIBLE_ROWS:
					scroll_offset = cursor - VISIBLE_ROWS + 1
				Audio.play_ui_click()
			KEY_TAB:
				# Cycle sort
				match sort_by:
					"kills": sort_by = "worlds_cleared"
					"worlds_cleared": sort_by = "level"
					"level": sort_by = "kills"
				cursor = 0
				scroll_offset = 0
				Audio.play_ui_click()
		get_viewport().set_input_as_handled()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 60, 40), "RUN HISTORY",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(0.8, 0.6, 1.0))

	# Stats summary
	var total_runs := SaveData.total_runs
	var total_kills := SaveData.total_kills
	draw_node.draw_string(font, Vector2(cx - 140, 62), "Total Runs: %d  |  Total Kills: %d  |  Sort: %s (TAB)" % [total_runs, total_kills, sort_by.replace("_", " ").capitalize()],
		HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.5, 0.4, 0.6))

	var runs := _get_sorted_runs()

	if runs.is_empty():
		draw_node.draw_string(font, Vector2(cx - 80, 120), "No runs recorded yet.",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.4, 0.35, 0.5))
		draw_node.draw_string(font, Vector2(cx - 80, 140), "Complete a world or die to record a run.",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.35, 0.3, 0.45))
		# Controls
		draw_node.draw_string(font, Vector2(cx - 80, vp.y - 20), "ESC: Close",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))
		return

	# Column headers
	var header_y := 85.0
	var col_rank := 40.0
	var col_result := 70.0
	var col_world := 180.0
	var col_kills := 280.0
	var col_worlds := 360.0
	var col_level := 440.0
	var col_ng := 500.0
	var col_chal := 560.0
	var header_color := Color(0.6, 0.5, 0.75)

	draw_node.draw_string(font, Vector2(col_rank, header_y), "#", HORIZONTAL_ALIGNMENT_LEFT, 20, 9, header_color)
	draw_node.draw_string(font, Vector2(col_result, header_y), "Result", HORIZONTAL_ALIGNMENT_LEFT, 80, 9, header_color)
	draw_node.draw_string(font, Vector2(col_world, header_y), "World", HORIZONTAL_ALIGNMENT_LEFT, 80, 9, header_color)
	draw_node.draw_string(font, Vector2(col_kills, header_y), "Kills", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, header_color)
	draw_node.draw_string(font, Vector2(col_worlds, header_y), "Cleared", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, header_color)
	draw_node.draw_string(font, Vector2(col_level, header_y), "Level", HORIZONTAL_ALIGNMENT_LEFT, 50, 9, header_color)
	draw_node.draw_string(font, Vector2(col_ng, header_y), "NG+", HORIZONTAL_ALIGNMENT_LEFT, 40, 9, header_color)
	draw_node.draw_string(font, Vector2(col_chal, header_y), "Mods", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, header_color)

	# Separator
	draw_node.draw_line(Vector2(30, header_y + 5), Vector2(vp.x - 30, header_y + 5), Color(0.3, 0.25, 0.4, 0.5), 1.0)

	# Run rows
	var row_y := header_y + 22.0
	var row_h := 24.0

	for i in range(scroll_offset, mini(scroll_offset + VISIBLE_ROWS, runs.size())):
		var run: Dictionary = runs[i]
		var y := row_y + float(i - scroll_offset) * row_h
		var is_selected := (i == cursor)
		var is_victory: bool = run.get("victory", false)

		# Selection highlight
		if is_selected:
			draw_node.draw_rect(Rect2(30, y - 12, vp.x - 60, row_h - 2), Color(0.3, 0.2, 0.5, 0.3))

		# Rank
		var rank_color := Color(1.0, 0.85, 0.3) if i == 0 else (Color(0.8, 0.8, 0.9) if i == 1 else (Color(0.8, 0.5, 0.3) if i == 2 else Color(0.5, 0.45, 0.6)))
		draw_node.draw_string(font, Vector2(col_rank, y), "%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, 20, 10, rank_color)

		# Result
		var result_text := "Victory" if is_victory else "Defeat"
		var result_color := Color(0.3, 1.0, 0.4) if is_victory else Color(0.8, 0.3, 0.3)
		draw_node.draw_string(font, Vector2(col_result, y), result_text,
			HORIZONTAL_ALIGNMENT_LEFT, 80, 10, result_color)

		# World
		var world_id: int = run.get("world", 0)
		var world_name: String = WorldData.get_config(world_id).get("name", "Unknown")
		draw_node.draw_string(font, Vector2(col_world, y), world_name,
			HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color(0.6, 0.55, 0.7))

		# Kills
		draw_node.draw_string(font, Vector2(col_kills, y), "%d" % run.get("kills", 0),
			HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.7, 0.6, 0.8))

		# Worlds cleared
		draw_node.draw_string(font, Vector2(col_worlds, y), "%d" % run.get("worlds_cleared", 0),
			HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.6, 0.7, 0.8))

		# Level
		draw_node.draw_string(font, Vector2(col_level, y), "Lv.%d" % run.get("level", 1),
			HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(0.6, 0.5, 0.8))

		# NG+
		var ng: int = run.get("ng_plus", 0)
		var ng_text := "-" if ng == 0 else "+%d" % ng
		draw_node.draw_string(font, Vector2(col_ng, y), ng_text,
			HORIZONTAL_ALIGNMENT_LEFT, 40, 10, Color(1.0, 0.6, 0.2) if ng > 0 else Color(0.4, 0.35, 0.5))

		# Challenge count
		var chal_count: int = run.get("challenges", []).size()
		var chal_text := "-" if chal_count == 0 else "%d" % chal_count
		draw_node.draw_string(font, Vector2(col_chal, y), chal_text,
			HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(1.0, 0.5, 0.3) if chal_count > 0 else Color(0.4, 0.35, 0.5))

	# Scroll indicators
	if scroll_offset > 0:
		draw_node.draw_string(font, Vector2(cx, row_y - 15), "^ more",
			HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(0.5, 0.4, 0.7))
	if scroll_offset + VISIBLE_ROWS < runs.size():
		draw_node.draw_string(font, Vector2(cx, row_y + VISIBLE_ROWS * row_h + 5), "v more",
			HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(0.5, 0.4, 0.7))

	# Selected run detail
	if cursor >= 0 and cursor < runs.size():
		var run: Dictionary = runs[cursor]
		var detail_y := vp.y - 60.0
		var chal_list: Array = run.get("challenges", [])
		var chal_names := ""
		for cid in chal_list:
			var mod := Challenges.get_modifier(cid)
			if not mod.is_empty():
				chal_names += mod["name"] + "  "
		if chal_names.is_empty():
			chal_names = "None"
		draw_node.draw_string(font, Vector2(40, detail_y), "Run #%d  |  Thralls: %d  |  Challenges: %s" % [
			run.get("run_number", 0), run.get("thralls", 0), chal_names],
			HORIZONTAL_ALIGNMENT_LEFT, vp.x - 80, 9, Color(0.5, 0.45, 0.6))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 140, vp.y - 20), "W/S: Navigate  |  TAB: Sort  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 280, 10, Color(0.4, 0.35, 0.55))
