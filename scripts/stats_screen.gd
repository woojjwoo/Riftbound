extends CanvasLayer

## Detailed statistics dashboard showing lifetime stats, best runs, and breakdowns.

signal closed

var draw_node: Control = null
var time: float = 0.0
var scroll_offset: int = 0
const MAX_VISIBLE: int = 20

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "StatsDraw"
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
			KEY_ESCAPE, KEY_P:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				scroll_offset = max(0, scroll_offset - 1)
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				scroll_offset += 1
				Audio.play_ui_click()
		get_viewport().set_input_as_handled()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 50, 35), "STATISTICS",
		HORIZONTAL_ALIGNMENT_CENTER, 100, 20, Color(0.85, 0.75, 1.0))

	var y := 65.0
	var line_h := 18.0
	var col_label := 40.0
	var col_value := 300.0
	var label_color := Color(0.5, 0.45, 0.65)
	var value_color := Color(0.8, 0.75, 0.9)
	var header_color := Color(1.0, 0.85, 0.4)

	var stats: Array[Array] = _build_stats()

	# Apply scroll
	var visible_start := scroll_offset
	var visible_end := mini(visible_start + MAX_VISIBLE, stats.size())

	for i in range(visible_start, visible_end):
		var entry: Array = stats[i]
		var draw_y := y + float(i - visible_start) * line_h

		if entry.size() == 1:
			# Section header
			draw_node.draw_line(Vector2(30, draw_y + 4), Vector2(vp.x - 30, draw_y + 4), Color(0.3, 0.25, 0.4, 0.3), 1.0)
			draw_node.draw_string(font, Vector2(col_label, draw_y), str(entry[0]),
				HORIZONTAL_ALIGNMENT_LEFT, 250, 11, header_color)
		else:
			# Stat row
			draw_node.draw_string(font, Vector2(col_label + 10, draw_y), str(entry[0]),
				HORIZONTAL_ALIGNMENT_LEFT, 240, 10, label_color)
			draw_node.draw_string(font, Vector2(col_value, draw_y), str(entry[1]),
				HORIZONTAL_ALIGNMENT_LEFT, 150, 10, value_color)

	# Scroll indicator
	if stats.size() > MAX_VISIBLE:
		draw_node.draw_string(font, Vector2(cx - 50, vp.y - 35), "W/S: Scroll (%d/%d)" % [scroll_offset + 1, stats.size()],
			HORIZONTAL_ALIGNMENT_CENTER, 100, 9, Color(0.4, 0.35, 0.5))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 80, vp.y - 15), "W/S: Scroll  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))

func _build_stats() -> Array[Array]:
	var stats: Array[Array] = []

	# General
	stats.append(["GENERAL"])
	stats.append(["Total Runs", str(SaveData.total_runs)])
	stats.append(["Total Kills", str(SaveData.total_kills)])
	stats.append(["Total Bosses Killed", str(SaveData.total_bosses_killed)])
	stats.append(["Player Level", str(SaveData.player_level)])
	stats.append(["Coins", str(SaveData.coins)])
	stats.append(["Worlds Completed", "%d / %d" % [SaveData.worlds_completed.size(), WorldData.get_world_count()]])
	stats.append(["Highest World", str(SaveData.highest_world_unlocked + 1)])
	stats.append(["NG+ Cycle", str(SaveData.ng_plus_cycle)])

	# Meta Progression
	stats.append(["META PROGRESSION"])
	stats.append(["Soul Essence", str(Meta.soul_essence)])
	stats.append(["Total Essence Earned", str(Meta.total_soul_essence_earned)])
	stats.append(["Meta Total Kills", str(Meta.meta_total_kills)])
	stats.append(["Meta Runs Completed", str(Meta.meta_runs_completed)])
	var sanctum_total := 0
	for lvl in Meta.sanctum_levels:
		sanctum_total += lvl
	stats.append(["Sanctum Upgrades", str(sanctum_total)])
	stats.append(["Skill Tree Skills", "%d / 15" % SkillTree.get_total_unlocked()])

	# Achievements
	stats.append(["ACHIEVEMENTS"])
	stats.append(["Unlocked", "%d / %d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()]])
	var completion := 0.0
	if Achievements.get_total_count() > 0:
		completion = float(Achievements.get_unlocked_count()) / float(Achievements.get_total_count()) * 100.0
	stats.append(["Completion", "%.1f%%" % completion])

	# Equipment
	stats.append(["EQUIPMENT"])
	var equipped_count := 0
	var total_level := 0
	var highest_rarity := -1
	for item in SaveData.equipped:
		if not item.is_empty():
			equipped_count += 1
			total_level += item.get("level", 0)
			highest_rarity = maxi(highest_rarity, item.get("rarity", 0))
	stats.append(["Equipped Slots", "%d / 6" % equipped_count])
	stats.append(["Total Upgrade Levels", str(total_level)])
	if highest_rarity >= 0:
		stats.append(["Highest Rarity", Equipment.get_rarity_name(highest_rarity)])
	stats.append(["Inventory Items", "%d / %d" % [SaveData.inventory.size(), SaveData.MAX_INVENTORY]])
	var enchanted := 0
	for item in SaveData.equipped:
		if item.has("enchant"):
			enchanted += 1
	for item in SaveData.inventory:
		if item.has("enchant"):
			enchanted += 1
	stats.append(["Enchanted Items", str(enchanted)])

	# Bestiary breakdown
	stats.append(["BESTIARY KILLS"])
	var sorted_types: Array = SaveData.bestiary.keys()
	sorted_types.sort()
	for enemy_type in sorted_types:
		var count: int = SaveData.bestiary.get(enemy_type, 0)
		stats.append([enemy_type.capitalize(), str(count)])

	# Run History Summary
	if SaveData.run_history.size() > 0:
		stats.append(["RUN HISTORY"])
		stats.append(["Total Recorded Runs", str(SaveData.run_history.size())])
		var best_kills := 0
		var best_level := 0
		var victories := 0
		for run in SaveData.run_history:
			best_kills = maxi(best_kills, int(run.get("kills", 0)))
			best_level = maxi(best_level, int(run.get("level", 0)))
			if run.get("victory", false):
				victories += 1
		stats.append(["Best Kill Count", str(best_kills)])
		stats.append(["Best Run Level", str(best_level)])
		stats.append(["Victory Runs", str(victories)])

	# Arena
	var arena_best: int = int(SaveData.run_bests.get("arena_best_wave", 0))
	if arena_best > 0:
		stats.append(["ARENA"])
		stats.append(["Best Wave", str(arena_best)])

	# Permanent Upgrades
	stats.append(["PERMANENT UPGRADES"])
	for i in range(SaveData.SHOP_UPGRADES.size()):
		var upgrade: Dictionary = SaveData.SHOP_UPGRADES[i]
		var level: int = SaveData.shop_levels[i]
		if level > 0:
			stats.append([upgrade["name"], "Lv.%d / %d" % [level, upgrade["max_level"]]])

	return stats
