extends CanvasLayer

## Skill tree screen. Navigate 3 paths (Necromancy, Combat, Survival),
## unlock skills with Soul Essence.

signal closed

var draw_node: Control = null
var time: float = 0.0
var selected_path: int = 0
var selected_skill: int = 0
var result_text: String = ""
var result_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "SkillTreeDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)
	# Set selected_skill to next unlockable
	selected_skill = maxi(SkillTree.get_next_skill(selected_path), 0)

func _process(delta: float) -> void:
	time += delta
	if result_timer > 0.0:
		result_timer -= delta
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_T:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_LEFT, KEY_A:
				selected_path = max(0, selected_path - 1)
				selected_skill = maxi(SkillTree.get_next_skill(selected_path), 0)
				Audio.play_ui_click()
			KEY_RIGHT, KEY_D:
				selected_path = min(2, selected_path + 1)
				selected_skill = maxi(SkillTree.get_next_skill(selected_path), 0)
				Audio.play_ui_click()
			KEY_UP, KEY_W:
				selected_skill = max(0, selected_skill - 1)
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				var max_skill: int = SkillTree.PATHS[selected_path]["skills"].size() - 1
				selected_skill = min(max_skill, selected_skill + 1)
				Audio.play_ui_click()
			KEY_ENTER, KEY_SPACE:
				_try_unlock()
			KEY_R:
				_try_reset()
		get_viewport().set_input_as_handled()

func _try_unlock() -> void:
	if SkillTree.can_unlock(selected_path, selected_skill):
		SkillTree.unlock_skill(selected_path, selected_skill)
		var skills: Array = SkillTree.PATHS[selected_path]["skills"]
		result_text = "Unlocked: %s" % skills[selected_skill]["name"]
		result_timer = 2.5
		Audio.play_ui_confirm()
		# Move cursor to next skill
		var next := SkillTree.get_next_skill(selected_path)
		if next >= 0:
			selected_skill = next
	else:
		var skills: Array = SkillTree.PATHS[selected_path]["skills"]
		if selected_skill >= skills.size():
			return
		if SkillTree.is_unlocked(selected_path, selected_skill):
			result_text = "Already unlocked"
		elif selected_skill != SkillTree.unlocked[selected_path].size():
			result_text = "Unlock previous skills first"
		else:
			var cost: int = skills[selected_skill]["cost"]
			result_text = "Need %d essence (have %d)" % [cost, Meta.soul_essence]
		result_timer = 2.0
		Audio.play_ui_click()

func _try_reset() -> void:
	if SkillTree.get_total_unlocked() == 0:
		result_text = "No skills to reset"
		result_timer = 2.0
		return
	SkillTree.reset_skills()
	result_text = "All skills reset! Essence refunded."
	result_timer = 3.0
	selected_skill = 0
	Audio.play_ui_confirm()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	var pulse := 0.7 + 0.3 * sin(time * 2.0)
	draw_node.draw_string(font, Vector2(cx - 60, 35), "SKILL TREE",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color(0.85, 0.65, 1.0, pulse))

	# Soul Essence
	draw_node.draw_string(font, Vector2(cx - 80, 55), "Soul Essence: %d" % Meta.soul_essence,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.5, 0.25, 0.9))

	# Path tabs
	var tab_y := 75.0
	var tab_width := 140.0
	var tab_start := cx - (tab_width * 1.5)
	for i in range(3):
		var path_data: Dictionary = SkillTree.PATHS[i]
		var tx := tab_start + float(i) * tab_width
		var is_selected := (i == selected_path)
		var path_color: Color = path_data["color"]

		if is_selected:
			draw_node.draw_rect(Rect2(tx, tab_y - 12, tab_width - 10, 24), Color(path_color.r, path_color.g, path_color.b, 0.2))
			draw_node.draw_rect(Rect2(tx, tab_y - 12, tab_width - 10, 24), Color(path_color.r, path_color.g, path_color.b, 0.6), false, 1.5)
		var tab_col = path_color if is_selected else Color(0.4, 0.35, 0.5)
		var unlocked_count: int = SkillTree.unlocked[i].size()
		var total_count: int = path_data["skills"].size()
		draw_node.draw_string(font, Vector2(tx + 5, tab_y + 3), "%s (%d/%d)" % [path_data["name"], unlocked_count, total_count],
			HORIZONTAL_ALIGNMENT_LEFT, int(tab_width - 15), 11, tab_col)

	# Path description
	var path_data: Dictionary = SkillTree.PATHS[selected_path]
	var path_color: Color = path_data["color"]
	draw_node.draw_string(font, Vector2(cx - 100, tab_y + 28), path_data["desc"],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(0.5, 0.4, 0.6))

	# Skill nodes
	var skills: Array = path_data["skills"]
	var node_start_y := tab_y + 50.0
	var node_h := 58.0
	var node_w := 340.0
	var node_x := cx - node_w / 2.0

	for i in range(skills.size()):
		var skill: Dictionary = skills[i]
		var ny := node_start_y + float(i) * node_h
		var is_cursor := (i == selected_skill)
		var is_unlocked := SkillTree.is_unlocked(selected_path, i)
		var is_next := (i == SkillTree.get_next_skill(selected_path))

		# Connection line to next node
		if i < skills.size() - 1:
			var line_color = path_color if is_unlocked else Color(0.25, 0.2, 0.35, 0.5)
			draw_node.draw_line(Vector2(cx, ny + 40), Vector2(cx, ny + node_h - 5), line_color, 1.5)

		# Node background
		var bg_color: Color
		if is_unlocked:
			bg_color = Color(path_color.r * 0.2, path_color.g * 0.2, path_color.b * 0.2, 0.6)
		elif is_next:
			bg_color = Color(0.1, 0.08, 0.15, 0.6)
		else:
			bg_color = Color(0.06, 0.04, 0.1, 0.4)
		draw_node.draw_rect(Rect2(node_x, ny, node_w, node_h - 8), bg_color)

		# Border
		var border_color: Color
		if is_cursor:
			var cursor_pulse := 0.5 + 0.5 * sin(time * 3.0)
			border_color = Color(path_color.r, path_color.g, path_color.b, cursor_pulse)
		elif is_unlocked:
			border_color = Color(path_color.r, path_color.g, path_color.b, 0.6)
		else:
			border_color = Color(0.3, 0.25, 0.4, 0.3)
		draw_node.draw_rect(Rect2(node_x, ny, node_w, node_h - 8), border_color, false, 1.5)

		# Skill name
		var name_color = path_color if is_unlocked else (Color(0.8, 0.75, 0.9) if is_next else Color(0.4, 0.35, 0.5))
		draw_node.draw_string(font, Vector2(node_x + 10, ny + 18), skill["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 200, 12, name_color)

		# Skill description
		var desc_color = Color(0.6, 0.55, 0.7) if is_unlocked or is_next else Color(0.35, 0.3, 0.45)
		draw_node.draw_string(font, Vector2(node_x + 10, ny + 35), skill["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, 200, 10, desc_color)

		# Status / cost
		if is_unlocked:
			draw_node.draw_string(font, Vector2(node_x + node_w - 80, ny + 18), "UNLOCKED",
				HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color(0.3, 0.9, 0.4))
		else:
			var cost: int = skill["cost"]
			var can_afford := Meta.soul_essence >= cost and is_next
			var cost_col = Color(0.3, 1.0, 0.4) if can_afford else Color(0.6, 0.5, 0.7)
			draw_node.draw_string(font, Vector2(node_x + node_w - 80, ny + 18), "%d SE" % cost,
				HORIZONTAL_ALIGNMENT_LEFT, 70, 10, cost_col)
			if not is_next and not is_unlocked:
				draw_node.draw_string(font, Vector2(node_x + node_w - 80, ny + 35), "LOCKED",
					HORIZONTAL_ALIGNMENT_LEFT, 70, 9, Color(0.4, 0.3, 0.45))

	# Result text
	if result_timer > 0.0 and not result_text.is_empty():
		var alpha := minf(result_timer, 1.0)
		draw_node.draw_string(font, Vector2(cx - 120, vp.y - 55), result_text,
			HORIZONTAL_ALIGNMENT_CENTER, 240, 12, Color(1.0, 0.9, 0.4, alpha))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 180, vp.y - 35), "A/D: Path  |  W/S: Skill  |  ENTER: Unlock  |  R: Reset All  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 360, 10, Color(0.4, 0.35, 0.55))

	# Total unlocked
	var total := SkillTree.get_total_unlocked()
	if total > 0:
		draw_node.draw_string(font, Vector2(cx - 60, vp.y - 15), "Total Skills: %d/15" % total,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.5, 0.4, 0.65))
