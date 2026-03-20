extends Node2D

## The Sanctum — meta-progression upgrade screen.
## Spend Soul Essence on permanent upgrades that persist between runs.
## Accessible from the title screen via the "Sanctum" button.

var time: float = 0.0
var selected_index: int = 0
var scroll_offset: int = 0
const VISIBLE_ITEMS: int = 6

# Particle system for ambient atmosphere
var particles: Array[Dictionary] = []
const PARTICLE_COUNT: int = 25

func _ready() -> void:
	# Generate ambient particles
	for i in range(PARTICLE_COUNT):
		particles.append({
			"x": randf() * get_viewport_rect().size.x,
			"y": randf() * get_viewport_rect().size.y,
			"speed": randf_range(10.0, 30.0),
			"size": randf_range(1.0, 3.0),
			"phase": randf() * TAU,
		})

func _process(delta: float) -> void:
	time += delta
	# Update particles
	for p in particles:
		p["y"] -= p["speed"] * delta
		if p["y"] < -10:
			p["y"] = get_viewport_rect().size.y + 10
			p["x"] = randf() * get_viewport_rect().size.x
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
			KEY_UP, KEY_W:
				selected_index = max(0, selected_index - 1)
				if selected_index < scroll_offset:
					scroll_offset = selected_index
			KEY_DOWN, KEY_S:
				selected_index = min(Meta.SANCTUM_UPGRADES.size() - 1, selected_index + 1)
				if selected_index >= scroll_offset + VISIBLE_ITEMS:
					scroll_offset = selected_index - VISIBLE_ITEMS + 1
			KEY_ENTER, KEY_SPACE:
				_try_buy(selected_index)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_offset = max(0, scroll_offset - 1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_offset = min(Meta.SANCTUM_UPGRADES.size() - VISIBLE_ITEMS, scroll_offset + 1)
			scroll_offset = max(0, scroll_offset)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport_rect().size
		var start_y := 170.0
		var item_h := 72.0
		var mx := event.position.x
		var my := event.position.y
		if mx > vp.x * 0.12 and mx < vp.x * 0.88:
			for i in range(VISIBLE_ITEMS):
				var idx := scroll_offset + i
				if idx >= Meta.SANCTUM_UPGRADES.size():
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
	if Meta.buy_sanctum(index):
		Audio.play_upgrade()
		Game.request_shake(3.0)
	else:
		Audio.play_hit()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background — deep purple-black
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.01, 0.06))

	# Ambient particles (soul wisps)
	for p in particles:
		var alpha := 0.1 + 0.08 * sin(time * 1.5 + p["phase"])
		var c := Color(0.5, 0.3, 0.9, alpha)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], c)

	# Central sanctum glow
	var glow_pulse := 0.5 + 0.3 * sin(time * 1.2)
	draw_circle(Vector2(cx, 80), 60.0, Color(0.4, 0.2, 0.8, 0.04 * glow_pulse))
	draw_circle(Vector2(cx, 80), 35.0, Color(0.5, 0.3, 0.9, 0.08 * glow_pulse))

	# Swirling arcs around title
	for i in range(3):
		var angle_offset := time * (0.5 + float(i) * 0.3)
		var radius := 30.0 + float(i) * 12.0
		var alpha := 0.2 - float(i) * 0.04
		draw_arc(Vector2(cx, 70), radius, angle_offset, angle_offset + PI * 1.2, 16,
			Color(0.6, 0.3, 1.0, alpha), 1.5)

	# Title
	draw_string(font, Vector2(cx - 70, 45), "THE SANCTUM",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 28, Color(0.7, 0.4, 1.0))

	# Subtitle
	draw_string(font, Vector2(cx - 100, 70), "Permanent upgrades for your soul",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color(0.45, 0.3, 0.6))

	# Soul Essence display — prominent
	var essence_text := "Soul Essence: %d" % Meta.soul_essence
	var essence_pulse := 0.8 + 0.2 * sin(time * 2.5)
	draw_string(font, Vector2(cx - 80, 105), essence_text,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color(0.6 * essence_pulse, 0.3 * essence_pulse, 1.0 * essence_pulse))

	# Soul Essence icon (small diamond)
	var icon_x := cx - 95
	var icon_y := 93.0
	_draw_soul_essence_icon(Vector2(icon_x, icon_y), 6.0)

	# Stats line
	var stats_text := "Runs: %d  |  Total Earned: %d" % [Meta.meta_runs_completed, Meta.total_soul_essence_earned]
	draw_string(font, Vector2(cx - 120, 125), stats_text,
		HORIZONTAL_ALIGNMENT_CENTER, 240, 10, Color(0.4, 0.35, 0.55))

	# Divider
	draw_line(Vector2(vp.x * 0.1, 140), Vector2(vp.x * 0.9, 140), Color(0.3, 0.2, 0.5, 0.4), 1.0)

	# Upgrade list
	var start_y := 170.0
	var item_h := 72.0
	var item_w := vp.x * 0.76
	var item_x := vp.x * 0.12

	for i in range(VISIBLE_ITEMS):
		var idx := scroll_offset + i
		if idx >= Meta.SANCTUM_UPGRADES.size():
			break

		var upgrade := Meta.SANCTUM_UPGRADES[idx]
		var y := start_y + float(i) * item_h
		var level: int = Meta.sanctum_levels[idx]
		var max_level: int = upgrade["max_level"]
		var cost := Meta.get_sanctum_cost(idx)
		var is_maxed := level >= max_level
		var can_afford := Meta.soul_essence >= cost and not is_maxed
		var is_selected := idx == selected_index
		var upgrade_color: Color = upgrade["color"]

		# Background
		var bg_alpha := 0.9 if is_selected else 0.7
		var bg_color := Color(0.1, 0.06, 0.16, bg_alpha)
		if is_selected:
			bg_color = Color(0.15, 0.08, 0.25, bg_alpha)
		draw_rect(Rect2(item_x, y, item_w, item_h - 5), bg_color)

		# Selection border with upgrade color
		if is_selected:
			var sel_alpha := 0.5 + 0.2 * sin(time * 3.0)
			draw_rect(Rect2(item_x, y, item_w, item_h - 5),
				Color(upgrade_color.r, upgrade_color.g, upgrade_color.b, sel_alpha), false, 2.0)

		# Color accent bar on left
		draw_rect(Rect2(item_x, y, 4, item_h - 5), upgrade_color)

		# Name
		var name_color := Color(0.95, 0.9, 1.0) if can_afford else Color(0.5, 0.45, 0.55)
		if is_maxed:
			name_color = Color(0.4, 0.8, 0.3)
		draw_string(font, Vector2(item_x + 14, y + 20), upgrade["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 180, 14, name_color)

		# Description
		draw_string(font, Vector2(item_x + 14, y + 38), upgrade["desc"],
			HORIZONTAL_ALIGNMENT_LEFT, 250, 10, Color(0.55, 0.5, 0.65))

		# Current bonus display
		var current_value: float = Meta.get(upgrade["key"])
		var bonus_text := ""
		match upgrade["key"]:
			"sanctum_max_health":
				bonus_text = "+%.0f HP" % current_value
			"sanctum_base_damage":
				bonus_text = "+%.0f%% Dmg" % (current_value * 100.0)
			"sanctum_move_speed":
				bonus_text = "+%.0f%% Spd" % (current_value * 100.0)
			"sanctum_xp_gain":
				bonus_text = "+%.0f%% XP" % (current_value * 100.0)
			"sanctum_coin_magnet":
				bonus_text = "+%.0f Range" % current_value
			"sanctum_starting_level":
				bonus_text = "+%.0f Levels" % current_value
		if current_value > 0.0:
			draw_string(font, Vector2(item_x + 14, y + 54), bonus_text,
				HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color(upgrade_color.r, upgrade_color.g, upgrade_color.b, 0.8))

		# Level pips
		var pip_x := item_x + item_w * 0.48
		var pip_w := 120.0
		for j in range(max_level):
			var seg_x := pip_x + float(j) * (pip_w / float(max_level))
			var seg_w := pip_w / float(max_level) - 2.0
			var seg_color: Color
			if j < level:
				seg_color = upgrade_color
			else:
				seg_color = Color(0.15, 0.1, 0.2, 0.6)
			draw_rect(Rect2(seg_x, y + 14, seg_w, 10), seg_color)

		# Level text
		var lvl_text := "%d/%d" % [level, max_level]
		draw_string(font, Vector2(pip_x + pip_w + 5, y + 24), lvl_text,
			HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(0.6, 0.55, 0.7))

		# Cost
		if is_maxed:
			draw_string(font, Vector2(item_x + item_w - 70, y + 38), "MAXED",
				HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(0.4, 0.8, 0.3))
		else:
			var cost_color := Color(0.6, 0.3, 1.0) if can_afford else Color(0.6, 0.25, 0.25)
			_draw_soul_essence_icon(Vector2(item_x + item_w - 75, y + 27), 4.0)
			draw_string(font, Vector2(item_x + item_w - 65, y + 38), "%d" % cost,
				HORIZONTAL_ALIGNMENT_RIGHT, 55, 11, cost_color)

	# Scroll indicators
	if scroll_offset > 0:
		draw_string(font, Vector2(cx - 10, 162), "^",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.6, 0.5, 0.8))
	if scroll_offset + VISIBLE_ITEMS < Meta.SANCTUM_UPGRADES.size():
		draw_string(font, Vector2(cx - 10, start_y + VISIBLE_ITEMS * item_h + 10), "v",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.6, 0.5, 0.8))

	# Lifetime stats at bottom
	var stats_y := start_y + VISIBLE_ITEMS * item_h + 30
	draw_string(font, Vector2(cx - 160, stats_y),
		"Lifetime — Kills: %d  |  Worlds: %d  |  Bosses: %d  |  Runs: %d" % [
			Meta.meta_total_kills, Meta.meta_worlds_cleared,
			Meta.meta_bosses_killed, Meta.meta_runs_completed],
		HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.4, 0.35, 0.55))

	# Back button
	var back_y := vp.y - 50
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.12, 0.06, 0.18, 0.8))
	draw_rect(Rect2(20, back_y, 160, 35), Color(0.5, 0.3, 0.8, 0.5), false, 1.0)
	draw_string(font, Vector2(55, back_y + 22), "ESC: Back",
		HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.6, 0.4, 0.9))

	# Controls hint
	draw_string(font, Vector2(cx - 160, vp.y - 20),
		"W/S: Navigate  |  Enter/Double-Click: Buy  |  Scroll: Mouse Wheel  |  ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 11, Color(0.4, 0.35, 0.55))

func _draw_soul_essence_icon(pos: Vector2, size: float) -> void:
	# Diamond-shaped soul essence icon with glow
	var pts := PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size * 0.7, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size * 0.7, 0),
	])
	draw_colored_polygon(pts, Color(0.5, 0.2, 1.0, 0.8))
	# Inner highlight
	var inner_pts := PackedVector2Array([
		pos + Vector2(0, -size * 0.5),
		pos + Vector2(size * 0.35, 0),
		pos + Vector2(0, size * 0.5),
		pos + Vector2(-size * 0.35, 0),
	])
	draw_colored_polygon(inner_pts, Color(0.8, 0.6, 1.0, 0.6))
