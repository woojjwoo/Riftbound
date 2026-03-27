extends CanvasLayer

## Bestiary / Enemy Codex screen. Shows all enemy types encountered,
## their stats, descriptions, and kill counts. Accessed from title screen.

signal closed

var cursor: int = 0
var scroll_offset: int = 0
const VISIBLE_ROWS: int = 8
var time: float = 0.0

var draw_node: Control = null

const ENEMY_DATA: Array[Dictionary] = [
	{"type": "melee", "name": "Shambler", "desc": "Basic undead that charges toward targets.",
	 "color": Color(0.8, 0.8, 0.8), "base_hp": 40, "base_dmg": 10},
	{"type": "ranged", "name": "Bone Archer", "desc": "Fires projectiles from a distance. Retreats when too close.",
	 "color": Color(0.9, 0.7, 0.4), "base_hp": 40, "base_dmg": 10},
	{"type": "tank", "name": "Brute", "desc": "Slow but durable. Takes many hits to bring down.",
	 "color": Color(0.6, 0.6, 0.7), "base_hp": 40, "base_dmg": 10},
	{"type": "charger", "name": "Charger", "desc": "Winds up then dashes at high speed. Dangerous in packs.",
	 "color": Color(1.0, 0.5, 0.3), "base_hp": 40, "base_dmg": 10},
	{"type": "exploder", "name": "Volatile", "desc": "Explodes on contact, damaging everything nearby.",
	 "color": Color(1.0, 0.4, 0.2), "base_hp": 40, "base_dmg": 10},
	{"type": "shielded", "name": "Warden", "desc": "Protected by an energy shield that absorbs hits.",
	 "color": Color(0.4, 0.6, 1.0), "base_hp": 40, "base_dmg": 10},
	{"type": "splitter", "name": "Divider", "desc": "Splits into smaller copies on death.",
	 "color": Color(0.7, 0.9, 0.5), "base_hp": 40, "base_dmg": 10},
	{"type": "summoner", "name": "Summoner", "desc": "Calls reinforcements periodically. Stay at range to attack.",
	 "color": Color(0.3, 0.9, 0.3), "base_hp": 40, "base_dmg": 10},
	{"type": "poisoner", "name": "Blighter", "desc": "Leaves toxic pools in its wake. Avoid the trail.",
	 "color": Color(0.5, 1.0, 0.3), "base_hp": 40, "base_dmg": 10},
	{"type": "teleporter", "name": "Blinker", "desc": "Teleports near its target. Hard to pin down.",
	 "color": Color(0.8, 0.4, 1.0), "base_hp": 40, "base_dmg": 10},
	{"type": "voidcaller", "name": "Voidcaller", "desc": "Pulls players toward it with gravity wells.",
	 "color": Color(0.6, 0.2, 0.9), "base_hp": 40, "base_dmg": 10},
	{"type": "flying", "name": "Wraith", "desc": "Floats above the ground. Fires projectiles while dodging.",
	 "color": Color(0.7, 0.5, 1.0), "base_hp": 40, "base_dmg": 10},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "BestiaryDraw"
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
			KEY_ESCAPE, KEY_B:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				cursor = max(0, cursor - 1)
				if cursor < scroll_offset:
					scroll_offset = cursor
				Audio.play_ui_click()
			KEY_DOWN, KEY_S:
				cursor = min(ENEMY_DATA.size() - 1, cursor + 1)
				if cursor >= scroll_offset + VISIBLE_ROWS:
					scroll_offset = cursor - VISIBLE_ROWS + 1
				Audio.play_ui_click()
		get_viewport().set_input_as_handled()

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	draw_node.draw_string(font, Vector2(cx - 60, 40), "BESTIARY",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color(0.8, 0.6, 1.0))

	var total_kills := 0
	for entry in ENEMY_DATA:
		total_kills += SaveData.bestiary.get(entry["type"], 0)
	var discovered := 0
	for entry in ENEMY_DATA:
		if SaveData.bestiary.get(entry["type"], 0) > 0:
			discovered += 1
	draw_node.draw_string(font, Vector2(cx - 100, 62), "Discovered: %d/%d  |  Total Kills: %d" % [discovered, ENEMY_DATA.size(), total_kills],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(0.5, 0.4, 0.6))

	# Enemy list (left side)
	var list_x := 40.0
	var list_y := 90.0
	var row_h := 32.0

	for i in range(scroll_offset, mini(scroll_offset + VISIBLE_ROWS, ENEMY_DATA.size())):
		var entry := ENEMY_DATA[i]
		var etype: String = entry["type"]
		var kills: int = SaveData.bestiary.get(etype, 0)
		var known := kills > 0
		var y := list_y + float(i - scroll_offset) * row_h
		var is_selected := (i == cursor)

		# Selection highlight
		if is_selected:
			draw_node.draw_rect(Rect2(list_x - 4, y - 14, 220, row_h - 2), Color(0.3, 0.2, 0.5, 0.4))

		# Enemy color indicator
		var ecolor: Color = entry["color"] if known else Color(0.3, 0.3, 0.3)
		draw_node.draw_circle(Vector2(list_x + 8, y - 2), 5.0, ecolor)

		# Name
		var name_text: String = entry["name"] if known else "???"
		var name_color = Color(0.9, 0.85, 1.0) if is_selected else Color(0.6, 0.55, 0.7)
		if not known:
			name_color = Color(0.4, 0.35, 0.45)
		draw_node.draw_string(font, Vector2(list_x + 22, y), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, 120, 12, name_color)

		# Kill count
		if known:
			draw_node.draw_string(font, Vector2(list_x + 155, y), "%d kills" % kills,
				HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.5, 0.45, 0.6))

	# Scroll indicators
	if scroll_offset > 0:
		draw_node.draw_string(font, Vector2(list_x + 80, list_y - 20), "^",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(0.5, 0.4, 0.7))
	if scroll_offset + VISIBLE_ROWS < ENEMY_DATA.size():
		draw_node.draw_string(font, Vector2(list_x + 80, list_y + VISIBLE_ROWS * row_h), "v",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(0.5, 0.4, 0.7))

	# Detail panel (right side)
	var detail_x := 290.0
	var detail_y := 90.0
	var detail_w := vp.x - detail_x - 30.0
	var detail_h := 200.0

	draw_node.draw_rect(Rect2(detail_x, detail_y - 10, detail_w, detail_h), Color(0.06, 0.04, 0.1, 0.8))
	draw_node.draw_rect(Rect2(detail_x, detail_y - 10, detail_w, detail_h), Color(0.4, 0.3, 0.6, 0.3), false, 1.0)

	if cursor >= 0 and cursor < ENEMY_DATA.size():
		var entry := ENEMY_DATA[cursor]
		var etype: String = entry["type"]
		var kills: int = SaveData.bestiary.get(etype, 0)
		var known := kills > 0

		if known:
			var ecolor: Color = entry["color"]
			# Name
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 10), entry["name"],
				HORIZONTAL_ALIGNMENT_LEFT, 200, 18, ecolor)
			# Type
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 30), "Type: %s" % etype.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(0.5, 0.45, 0.6))
			# Description
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 52), entry["desc"],
				HORIZONTAL_ALIGNMENT_LEFT, detail_w - 20, 10, Color(0.7, 0.65, 0.8))
			# Stats
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 78), "Base HP: %d  |  Base Dmg: %d" % [entry["base_hp"], entry["base_dmg"]],
				HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color(0.6, 0.5, 0.7))
			# Kill count
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 100), "Total Kills: %d" % kills,
				HORIZONTAL_ALIGNMENT_LEFT, 200, 11, Color(0.8, 0.6, 1.0))

			# Animated enemy preview
			var preview_cx := detail_x + detail_w / 2.0
			var preview_cy := detail_y + 155.0
			var bob := sin(time * 2.0) * 3.0
			draw_node.draw_circle(Vector2(preview_cx, preview_cy + bob), 12.0, Color(ecolor.r, ecolor.g, ecolor.b, 0.6))
			draw_node.draw_circle(Vector2(preview_cx, preview_cy + bob), 8.0, Color(ecolor.r, ecolor.g, ecolor.b, 0.9))
			draw_node.draw_circle(Vector2(preview_cx, preview_cy + bob), 3.0, Color(1.0, 1.0, 1.0, 0.5))
		else:
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 10), "???",
				HORIZONTAL_ALIGNMENT_LEFT, 200, 18, Color(0.4, 0.35, 0.45))
			draw_node.draw_string(font, Vector2(detail_x + 10, detail_y + 40), "Defeat this enemy to learn about it.",
				HORIZONTAL_ALIGNMENT_LEFT, detail_w - 20, 10, Color(0.4, 0.35, 0.5))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 120, vp.y - 20), "W/S: Navigate  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 10, Color(0.4, 0.35, 0.55))
