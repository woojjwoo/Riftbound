extends CanvasLayer

## Run summary screen shown at game over / victory.
## Displays detailed breakdown of the run: kills, worlds, time, essence earned.
## Tracks and displays personal bests.

var time: float = 0.0
var fade_in: float = 0.0
var panel_rect := Rect2()
var stats: Dictionary = {}
var is_victory: bool = false

# Personal bests (stored in SaveData via run_stats)
signal closed

func setup(victory: bool) -> void:
	is_victory = victory
	stats = {
		"kills": Game.kill_count,
		"thralls": Game.thrall_count,
		"rifts_closed": Game.rifts_closed,
		"total_rifts": Game.total_rifts,
		"worlds_cleared": Game.run_worlds_cleared,
		"bosses_killed": Game.run_bosses_killed,
		"level": Game.current_level,
		"world_name": Game.get_world_config().get("name", "Unknown"),
		"world_id": Game.current_world,
		"coins": SaveData.coins,
		"upgrades": Game.chosen_upgrades.duplicate(),
		"essence_earned": Meta.calculate_run_essence(
			Game.kill_count, Game.run_worlds_cleared, Game.run_bosses_killed),
	}
	# Update personal bests
	_update_bests()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	time += delta
	fade_in = minf(fade_in + delta * 2.0, 1.0)
	_get_draw_node().queue_redraw()

func _get_draw_node() -> Control:
	if get_child_count() == 0:
		var ctrl := Control.new()
		ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
		ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
		ctrl.draw.connect(_draw_summary)
		ctrl.gui_input.connect(_on_input)
		add_child(ctrl)
	return get_child(0)

func _draw_summary() -> void:
	var node := _get_draw_node()
	var vp := node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var font := ThemeDB.fallback_font

	# Dim overlay
	node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.7 * fade_in))

	# Panel
	var pw := 500.0
	var ph := 450.0
	var px := cx - pw / 2.0
	var py := cy - ph / 2.0
	panel_rect = Rect2(px, py, pw, ph)
	node.draw_rect(panel_rect, Color(0.06, 0.04, 0.1, 0.95 * fade_in))
	node.draw_rect(panel_rect, Color(0.5, 0.3, 0.8, 0.4 * fade_in), false, 2.0)

	var alpha := fade_in
	var y := py + 30

	# Title
	var title := "VICTORY — RUN COMPLETE" if is_victory else "THE NECROMANCER FALLS"
	var title_color := Color(0.4, 1.0, 0.5, alpha) if is_victory else Color(1.0, 0.3, 0.3, alpha)
	node.draw_string(font, Vector2(cx - 120, y), title,
		HORIZONTAL_ALIGNMENT_CENTER, 240, 18, title_color)

	# Subtitle
	y += 28
	node.draw_string(font, Vector2(cx - 100, y), "World: %s" % stats.get("world_name", ""),
		HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(0.6, 0.5, 0.8, alpha))

	# Divider
	y += 15
	node.draw_line(Vector2(px + 30, y), Vector2(px + pw - 30, y),
		Color(0.4, 0.3, 0.6, 0.3 * alpha), 1.0)

	# Stats columns
	y += 25
	var col1 := px + 40
	var col2 := cx + 20
	var line_h := 22.0
	var label_color := Color(0.6, 0.5, 0.7, alpha)
	var value_color := Color(0.9, 0.85, 1.0, alpha)

	_draw_stat(node, font, col1, y, "Enemies Slain", str(stats.get("kills", 0)), label_color, value_color)
	_draw_stat(node, font, col2, y, "Thralls Raised", str(stats.get("thralls", 0)), label_color, value_color)
	y += line_h
	_draw_stat(node, font, col1, y, "Rifts Sealed", "%d / %d" % [stats.get("rifts_closed", 0), stats.get("total_rifts", 0)], label_color, value_color)
	_draw_stat(node, font, col2, y, "Bosses Killed", str(stats.get("bosses_killed", 0)), label_color, value_color)
	y += line_h
	_draw_stat(node, font, col1, y, "Worlds Cleared", str(stats.get("worlds_cleared", 0)), label_color, value_color)
	_draw_stat(node, font, col2, y, "Level Reached", str(stats.get("level", 1)), label_color, value_color)

	# Divider
	y += line_h + 10
	node.draw_line(Vector2(px + 30, y), Vector2(px + pw - 30, y),
		Color(0.4, 0.3, 0.6, 0.3 * alpha), 1.0)

	# Essence earned
	y += 25
	var essence: int = stats.get("essence_earned", 0)
	var essence_pulse := 0.7 + 0.3 * sin(time * 2.0)
	var essence_color := Color(0.5 * essence_pulse, 0.25 * essence_pulse, 0.9 * essence_pulse, alpha)
	node.draw_string(font, Vector2(cx - 80, y), "Soul Essence Earned: +%d" % essence,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 14, essence_color)

	# Upgrades chosen
	y += 30
	var upgrades: Array = stats.get("upgrades", [])
	if upgrades.size() > 0:
		node.draw_string(font, Vector2(col1, y), "Upgrades:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.4, 0.6, alpha))
		y += 16
		var upgrade_text := ", ".join(upgrades)
		node.draw_string(font, Vector2(col1, y), upgrade_text,
			HORIZONTAL_ALIGNMENT_LEFT, int(pw - 80), 10, Color(0.7, 0.6, 0.9, alpha))

	# Personal bests
	y += 30
	node.draw_string(font, Vector2(col1, y), "Personal Bests:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.3, alpha))
	y += 18
	var bests := _get_bests()
	_draw_stat(node, font, col1, y, "Most Kills", str(bests.get("best_kills", 0)),
		Color(0.5, 0.4, 0.6, alpha), Color(1.0, 0.9, 0.5, alpha))
	_draw_stat(node, font, col2, y, "Highest Level", str(bests.get("best_level", 1)),
		Color(0.5, 0.4, 0.6, alpha), Color(1.0, 0.9, 0.5, alpha))
	y += line_h
	_draw_stat(node, font, col1, y, "Most Worlds", str(bests.get("best_worlds", 0)),
		Color(0.5, 0.4, 0.6, alpha), Color(1.0, 0.9, 0.5, alpha))
	_draw_stat(node, font, col2, y, "Most Essence", str(bests.get("best_essence", 0)),
		Color(0.5, 0.4, 0.6, alpha), Color(1.0, 0.9, 0.5, alpha))

	# Click to continue
	y = py + ph - 30
	var blink := 0.4 + 0.6 * sin(time * 3.0)
	node.draw_string(font, Vector2(cx - 50, y), "Click to Continue",
		HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(0.7, 0.5, 0.9, blink * alpha))

func _draw_stat(node: Control, font: Font, x: float, y: float,
		label: String, value: String, label_color: Color, value_color: Color) -> void:
	node.draw_string(font, Vector2(x, y), label + ":",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
	node.draw_string(font, Vector2(x + 110, y), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, value_color)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and fade_in >= 0.9:
		closed.emit()
		queue_free()

func _update_bests() -> void:
	# Use SaveData to store bests
	if not SaveData.has_method("get") or not SaveData.get("run_bests"):
		if not "run_bests" in SaveData:
			SaveData.set("run_bests", {})
	var bests := _get_bests()
	var changed := false
	if stats.get("kills", 0) > bests.get("best_kills", 0):
		bests["best_kills"] = stats["kills"]
		changed = true
	if stats.get("level", 1) > bests.get("best_level", 1):
		bests["best_level"] = stats["level"]
		changed = true
	if stats.get("worlds_cleared", 0) > bests.get("best_worlds", 0):
		bests["best_worlds"] = stats["worlds_cleared"]
		changed = true
	if stats.get("essence_earned", 0) > bests.get("best_essence", 0):
		bests["best_essence"] = stats["essence_earned"]
		changed = true
	if changed:
		SaveData.set("run_bests", bests)
		SaveData.save_game()

func _get_bests() -> Dictionary:
	if "run_bests" in SaveData and SaveData.run_bests is Dictionary:
		return SaveData.run_bests
	return {"best_kills": 0, "best_level": 1, "best_worlds": 0, "best_essence": 0}
