extends Node2D

## Thrall Sacrifice & Equipment Upgrade screen.
## Shown when entering a world portal. Flow:
## 1. Story text (if first time reaching this world)
## 2. Thrall sacrifice animation + bonus
## 3. Equipment upgrade interface
## 4. Proceed to next world

enum Phase { STORY, SACRIFICE, UPGRADE, DONE }

var phase: Phase = Phase.STORY
var time: float = 0.0
var next_world_id: int = 1
var thrall_count: int = 0
var sacrifice_bonus: float = 0.0

# Story state
var story_lines: Array = []
var story_title: String = ""
var story_line_index: int = 0
var story_char_index: int = 0
var story_timer: float = 0.0
var story_speed: float = 30.0  # chars per second
var story_complete: bool = false
var is_first_time: bool = false

# Sacrifice animation
var sacrifice_timer: float = 0.0
var sacrifice_particles: Array[Dictionary] = []

# Upgrade state
var selected_slot: int = 0
var upgrade_result: String = ""
var result_timer: float = 0.0
var scroll_offset: int = 0

func setup(next_world: int, thralls: int) -> void:
	next_world_id = next_world
	thrall_count = thralls
	sacrifice_bonus = minf(thralls * Equipment.SACRIFICE_BONUS_PER_THRALL,
		Equipment.MAX_SACRIFICE_BONUS)

	# Check if this is first time seeing this world's story
	is_first_time = not SaveData.has_seen_story(next_world_id)
	if is_first_time:
		var story := WorldData.get_transition_story(next_world_id)
		story_title = story["title"]
		story_lines = story["lines"]
		phase = Phase.STORY
	elif thrall_count > 0:
		phase = Phase.SACRIFICE
		sacrifice_timer = 2.5
		_generate_sacrifice_particles()
	else:
		phase = Phase.UPGRADE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	time += delta

	match phase:
		Phase.STORY:
			_process_story(delta)
		Phase.SACRIFICE:
			_process_sacrifice(delta)
		Phase.UPGRADE:
			pass  # Handled by input

	if result_timer > 0.0:
		result_timer -= delta

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match phase:
			Phase.STORY:
				if story_complete:
					_advance_story()
				else:
					# Skip to end of current line
					story_complete = true
					story_char_index = 999
			Phase.SACRIFICE:
				if sacrifice_timer <= 0.0:
					phase = Phase.UPGRADE
			Phase.UPGRADE:
				match event.keycode:
					KEY_UP, KEY_W:
						selected_slot = max(0, selected_slot - 1)
					KEY_DOWN, KEY_S:
						selected_slot = min(5, selected_slot + 1)
					KEY_ENTER, KEY_SPACE:
						_try_upgrade_selected()
					KEY_ESCAPE:
						_proceed_to_next_world()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match phase:
			Phase.STORY:
				if story_complete:
					_advance_story()
				else:
					story_complete = true
					story_char_index = 999
			Phase.SACRIFICE:
				if sacrifice_timer <= 0.0:
					phase = Phase.UPGRADE
			Phase.UPGRADE:
				_handle_upgrade_click(event.position)

func _process_story(delta: float) -> void:
	if story_line_index >= story_lines.size():
		return
	story_timer += delta * story_speed
	story_char_index = int(story_timer)
	var current_line: String = story_lines[story_line_index]
	if story_char_index >= current_line.length():
		story_complete = true

func _advance_story() -> void:
	story_line_index += 1
	story_char_index = 0
	story_timer = 0.0
	story_complete = false
	if story_line_index >= story_lines.size():
		SaveData.mark_story_seen(next_world_id)
		if thrall_count > 0:
			phase = Phase.SACRIFICE
			sacrifice_timer = 2.5
			_generate_sacrifice_particles()
		else:
			phase = Phase.UPGRADE

func _process_sacrifice(delta: float) -> void:
	sacrifice_timer -= delta
	# Animate particles
	for p in sacrifice_particles:
		p["time"] += delta
		var t: float = p["time"] / p["duration"]
		if t >= 1.0:
			t = 1.0
		p["pos"] = p["start"].lerp(p["end"], t)
		p["alpha"] = 1.0 - t * 0.5
	if sacrifice_timer <= 0.0:
		sacrifice_timer = 0.0

func _generate_sacrifice_particles() -> void:
	sacrifice_particles.clear()
	var vp := get_viewport_rect().size
	var center := vp / 2.0
	for i in range(thrall_count * 3):
		var angle := randf() * TAU
		var dist := randf_range(100, 250)
		var start := center + Vector2(cos(angle), sin(angle)) * dist
		sacrifice_particles.append({
			"start": start,
			"end": center + Vector2(randf_range(-20, 20), randf_range(-30, 10)),
			"pos": start,
			"time": randf_range(0.0, 0.5),
			"duration": randf_range(1.5, 2.5),
			"alpha": 1.0,
			"color": Color(0.4, 0.8 + randf() * 0.2, 0.9 + randf() * 0.1),
		})

func _try_upgrade_selected() -> void:
	var equip := SaveData.equipped[selected_slot]
	if equip.is_empty():
		upgrade_result = "No equipment in this slot"
		result_timer = 2.0
		return
	if equip["level"] >= Equipment.MAX_LEVEL:
		upgrade_result = "Already at max level!"
		result_timer = 2.0
		return
	var cost := Equipment.get_upgrade_cost(equip)
	if SaveData.coins < cost:
		upgrade_result = "Not enough coins! (%d needed)" % cost
		result_timer = 2.0
		Audio.play_hit()
		return
	SaveData.coins -= cost
	var success := Equipment.try_upgrade(equip, thrall_count)
	if success:
		equip["level"] += 1
		upgrade_result = "SUCCESS! +%d" % equip["level"]
		result_timer = 2.5
		Audio.play_upgrade()
		Game.request_shake(5.0)
	else:
		upgrade_result = "FAILED... Equipment unchanged."
		result_timer = 2.5
		Audio.play_shield_break()
		Game.request_shake(3.0)
	SaveData.save_game()

func _handle_upgrade_click(pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var start_y := 140.0
	var slot_h := 75.0

	# Check slot clicks
	for i in range(6):
		var y := start_y + float(i) * slot_h
		if pos.y >= y and pos.y < y + slot_h - 5:
			if pos.x > vp.x * 0.1 and pos.x < vp.x * 0.65:
				selected_slot = i
				return
			# Upgrade button area
			if pos.x > vp.x * 0.65 and pos.x < vp.x * 0.9:
				selected_slot = i
				_try_upgrade_selected()
				return

	# Proceed button
	if pos.y > vp.y - 60 and pos.x > cx - 100 and pos.x < cx + 100:
		_proceed_to_next_world()

func _proceed_to_next_world() -> void:
	phase = Phase.DONE
	Game.current_world = next_world_id
	Game.restart_for_next_world()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var font := ThemeDB.fallback_font

	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06))

	match phase:
		Phase.STORY:
			_draw_story(vp, cx, cy, font)
		Phase.SACRIFICE:
			_draw_sacrifice(vp, cx, cy, font)
		Phase.UPGRADE:
			_draw_upgrade(vp, cx, cy, font)

func _draw_story(vp: Vector2, cx: float, cy: float, font: Font) -> void:
	# Ambient particles
	for i in range(15):
		var seed_val := float(i) * 97.3
		var px := cx + sin(time * 0.2 + seed_val) * 400.0
		var py := cy + cos(time * 0.3 + seed_val * 0.6) * 250.0
		draw_circle(Vector2(px, py), 1.5, Color(0.4, 0.3, 0.6, 0.1))

	# Title
	var title_alpha := minf(time * 2.0, 1.0)
	draw_string(font, Vector2(cx - 100, cy - 120), story_title,
		HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color(0.85, 0.65, 1.0, title_alpha))

	# Story lines (show all completed lines + current line with typewriter)
	var y := cy - 60
	for i in range(story_line_index + 1):
		if i >= story_lines.size():
			break
		var line: String = story_lines[i]
		if i < story_line_index:
			draw_string(font, Vector2(cx - 250, y), line,
				HORIZONTAL_ALIGNMENT_CENTER, 500, 13, Color(0.7, 0.65, 0.8))
		elif i == story_line_index:
			var visible_chars := mini(story_char_index, line.length())
			var partial := line.substr(0, visible_chars)
			draw_string(font, Vector2(cx - 250, y), partial,
				HORIZONTAL_ALIGNMENT_CENTER, 500, 13, Color(0.85, 0.8, 0.95))
		y += 22

	# Continue prompt
	if story_complete or story_line_index >= story_lines.size():
		var blink := 0.4 + 0.6 * sin(time * 3.0)
		var prompt_text := "Click to continue..." if story_line_index < story_lines.size() else "Click to proceed..."
		draw_string(font, Vector2(cx - 80, vp.y - 40), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.6, 0.5, 0.8, blink))

func _draw_sacrifice(vp: Vector2, cx: float, cy: float, font: Font) -> void:
	# Title
	draw_string(font, Vector2(cx - 100, 50), "THRALL SACRIFICE",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(0.9, 0.4, 0.3))

	# Flavor text
	var flavor_idx := (next_world_id - 1) % WorldData.SACRIFICE_FLAVOR.size()
	if flavor_idx < 0:
		flavor_idx = 0
	draw_string(font, Vector2(cx - 200, 85), WorldData.SACRIFICE_FLAVOR[flavor_idx],
		HORIZONTAL_ALIGNMENT_CENTER, 400, 12, Color(0.6, 0.5, 0.7))

	# Sacrifice particles
	for p in sacrifice_particles:
		var col: Color = p["color"]
		col.a = p["alpha"] * 0.6
		var pos: Vector2 = p["pos"]
		draw_circle(pos, 3.0, col)
		draw_circle(pos, 1.5, Color(1.0, 1.0, 1.0, col.a * 0.5))

	# Central soul collector glow
	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	draw_circle(Vector2(cx, cy), 30.0 + pulse * 10.0, Color(0.4, 0.8, 1.0, 0.1 * pulse))
	draw_circle(Vector2(cx, cy), 15.0, Color(0.6, 0.9, 1.0, 0.2 * pulse))

	# Stats
	var info_y := cy + 80
	draw_string(font, Vector2(cx - 120, info_y), "Thralls Sacrificed: %d" % thrall_count,
		HORIZONTAL_ALIGNMENT_CENTER, 240, 14, Color(0.8, 0.6, 0.3))
	draw_string(font, Vector2(cx - 120, info_y + 25), "Upgrade Bonus: +%d%%" % int(sacrifice_bonus * 100),
		HORIZONTAL_ALIGNMENT_CENTER, 240, 14, Color(0.3, 0.9, 0.5))

	if sacrifice_timer <= 0.0:
		var blink := 0.4 + 0.6 * sin(time * 3.0)
		draw_string(font, Vector2(cx - 80, vp.y - 40), "Click to continue...",
			HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.6, 0.5, 0.8, blink))

func _draw_upgrade(vp: Vector2, cx: float, cy: float, font: Font) -> void:
	# Title
	draw_string(font, Vector2(cx - 100, 35), "EQUIPMENT",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(1.0, 0.85, 0.3))

	# Coins
	draw_string(font, Vector2(cx - 60, 60), "Coins: %d" % SaveData.coins,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1.0, 0.9, 0.4))

	# Sacrifice bonus reminder
	if sacrifice_bonus > 0:
		draw_string(font, Vector2(cx - 100, 80), "Thrall Sacrifice: +%d%% success rate" % int(sacrifice_bonus * 100),
			HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color(0.3, 0.9, 0.5))

	# Equipment slots
	var start_y := 110.0
	var slot_h := 75.0
	var slot_w := vp.x * 0.55
	var slot_x := vp.x * 0.1

	for i in range(6):
		var y := start_y + float(i) * slot_h
		var equip := SaveData.equipped[i]
		var slot_info := Equipment.SLOT_INFO[i]
		var is_selected := i == selected_slot

		# Background
		var bg := Color(0.12, 0.1, 0.18, 0.8) if not is_selected else Color(0.2, 0.15, 0.3, 0.9)
		draw_rect(Rect2(slot_x, y, slot_w, slot_h - 5), bg)
		if is_selected:
			draw_rect(Rect2(slot_x, y, slot_w, slot_h - 5), Color(0.6, 0.4, 1.0, 0.4), false, 2.0)

		# Slot name
		draw_string(font, Vector2(slot_x + 10, y + 18), slot_info["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.6, 0.5, 0.7))

		if equip.is_empty():
			draw_string(font, Vector2(slot_x + 100, y + 18), "— Empty —",
				HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(0.4, 0.4, 0.4))
			draw_string(font, Vector2(slot_x + 10, y + 38), slot_info["stat"],
				HORIZONTAL_ALIGNMENT_LEFT, 150, 10, Color(0.4, 0.4, 0.5))
		else:
			# Equipment name with rarity color
			var rc := Equipment.get_rarity_color(equip["rarity"])
			var display_name: String = equip.get("name", "Unknown")
			if equip["level"] > 0:
				display_name += " +%d" % equip["level"]
			draw_string(font, Vector2(slot_x + 100, y + 18), display_name,
				HORIZONTAL_ALIGNMENT_LEFT, 200, 12, rc)

			# Rarity tag
			draw_string(font, Vector2(slot_x + 100, y + 35), Equipment.get_rarity_name(equip["rarity"]),
				HORIZONTAL_ALIGNMENT_LEFT, 60, 9, Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7))

			# Stat bonus
			var bonus := Equipment.get_stat_bonus(equip)
			var stat_text := "%s: +%.1f" % [slot_info["stat"], bonus]
			if slot_info["per_level"] < 1.0:
				stat_text = "%s: +%d%%" % [slot_info["stat"], int(bonus * 100)]
			draw_string(font, Vector2(slot_x + 10, y + 55), stat_text,
				HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(0.5, 0.8, 0.5))

			# Upgrade button
			if equip["level"] < Equipment.MAX_LEVEL:
				var btn_x := vp.x * 0.65
				var btn_w := vp.x * 0.22
				var cost := Equipment.get_upgrade_cost(equip)
				var rate := Equipment.get_success_rate(equip["level"], thrall_count)
				var can_afford := SaveData.coins >= cost

				var btn_bg := Color(0.15, 0.12, 0.25, 0.8) if can_afford else Color(0.1, 0.08, 0.12, 0.6)
				draw_rect(Rect2(btn_x, y + 5, btn_w, slot_h - 15), btn_bg)
				if is_selected and can_afford:
					draw_rect(Rect2(btn_x, y + 5, btn_w, slot_h - 15), Color(0.4, 0.8, 0.3, 0.3), false, 1.5)

				draw_string(font, Vector2(btn_x + 5, y + 22), "Upgrade: %d coins" % cost,
					HORIZONTAL_ALIGNMENT_LEFT, int(btn_w - 10), 11,
					Color(1.0, 0.9, 0.3) if can_afford else Color(0.5, 0.4, 0.4))

				# Success rate with color coding
				var rate_color := Color(0.3, 0.9, 0.3) if rate >= 0.75 else (
					Color(1.0, 0.8, 0.2) if rate >= 0.45 else Color(0.9, 0.3, 0.3))
				draw_string(font, Vector2(btn_x + 5, y + 40), "Success: %d%%" % int(rate * 100),
					HORIZONTAL_ALIGNMENT_LEFT, int(btn_w - 10), 11, rate_color)

				# Next level preview
				var next_bonus := Equipment.get_stat_bonus({"slot": equip["slot"], "rarity": equip["rarity"], "level": equip["level"] + 1})
				var preview_text := "+%.1f" % next_bonus
				if slot_info["per_level"] < 1.0:
					preview_text = "+%d%%" % int(next_bonus * 100)
				draw_string(font, Vector2(btn_x + 5, y + 56), "Next: %s" % preview_text,
					HORIZONTAL_ALIGNMENT_LEFT, int(btn_w - 10), 9, Color(0.5, 0.6, 0.7))
			else:
				var btn_x := vp.x * 0.65
				draw_string(font, Vector2(btn_x + 10, y + 35), "MAX LEVEL",
					HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.4, 0.8, 0.3))

	# Upgrade result message
	if result_timer > 0.0:
		var result_alpha := minf(result_timer, 1.0)
		var result_color := Color(0.3, 1.0, 0.4, result_alpha) if "SUCCESS" in upgrade_result else Color(1.0, 0.3, 0.3, result_alpha)
		draw_string(font, Vector2(cx - 120, vp.y - 80), upgrade_result,
			HORIZONTAL_ALIGNMENT_CENTER, 240, 16, result_color)

	# Proceed button
	var btn_y := vp.y - 55
	draw_rect(Rect2(cx - 100, btn_y, 200, 40), Color(0.15, 0.1, 0.25, 0.9))
	draw_rect(Rect2(cx - 100, btn_y, 200, 40), Color(0.6, 0.4, 1.0, 0.5), false, 2.0)
	var next_name := "Enter Next World"
	if next_world_id < WorldData.get_world_count():
		next_name = "Enter: %s" % WorldData.get_config(next_world_id)["name"]
	draw_string(font, Vector2(cx - 80, btn_y + 25), next_name,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(0.8, 0.7, 1.0))

	# Controls hint
	draw_string(font, Vector2(cx - 150, vp.y - 10), "W/S: Select  |  Enter: Upgrade  |  ESC: Proceed",
		HORIZONTAL_ALIGNMENT_CENTER, 300, 11, Color(0.4, 0.35, 0.5))
