extends CanvasLayer

## Controls help screen showing all keybindings and gameplay tips.

signal closed

var draw_node: Control = null
var scroll_offset: int = 0
const MAX_VISIBLE: int = 22

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "ControlsDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _process(_delta: float) -> void:
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_F1:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_UP, KEY_W:
				scroll_offset = max(0, scroll_offset - 1)
			KEY_DOWN, KEY_S:
				scroll_offset += 1
		get_viewport().set_input_as_handled()

const CONTROLS: Array[Array] = [
	["MOVEMENT"],
	["WASD", "Move character"],
	["SPACE", "Dash (invincible)"],

	["COMBAT"],
	["Left Click", "Fire soul bolt"],
	["Right Click", "Command thralls to position"],
	["R", "Recall thralls to you"],
	["F", "Cycle thrall formation"],
	["E", "Interact with world events"],

	["MENUS"],
	["TAB", "Open inventory (in game)"],
	["ESC", "Pause / Close menu"],

	["TITLE SCREEN"],
	["A/D", "Select world"],
	["ENTER", "Start game"],
	["TAB", "Shop (coin upgrades)"],
	["Q", "Sanctum (soul essence)"],
	["T", "Skill tree"],
	["G", "Crafting & Enchanting"],
	["B", "Bestiary"],
	["I", "Achievements"],
	["C", "Challenges"],
	["H", "Run history"],
	["D", "Daily challenge"],
	["N", "Arena mode"],
	["P", "Statistics"],
	["O", "Settings"],

	["GAMEPLAY TIPS"],
	["", "Kill enemies near you to extract thralls"],
	["", "Thralls gain types based on enemy killed"],
	["", "Close rifts to progress through the world"],
	["", "Combo kills for bonus coin rewards"],
	["", "Equipment drops from enemies and bosses"],
	["", "Enchant gear for extra stat bonuses"],
	["", "Unlock skills with Soul Essence"],
]

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	draw_node.draw_string(font, Vector2(cx - 50, 35), "CONTROLS",
		HORIZONTAL_ALIGNMENT_CENTER, 100, 20, Color(0.85, 0.75, 1.0))

	var y := 60.0
	var line_h := 22.0
	var col_key := 50.0
	var col_desc := 200.0

	var visible_end := mini(scroll_offset + MAX_VISIBLE, CONTROLS.size())

	for i in range(scroll_offset, visible_end):
		var entry: Array = CONTROLS[i]
		var draw_y := y + float(i - scroll_offset) * line_h

		if entry.size() == 1:
			# Section header
			draw_node.draw_line(Vector2(30, draw_y + 4), Vector2(vp.x - 30, draw_y + 4),
				Color(0.3, 0.25, 0.4, 0.3), 1.0)
			draw_node.draw_string(font, Vector2(col_key, draw_y), str(entry[0]),
				HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(1.0, 0.85, 0.4))
		else:
			var key: String = entry[0]
			var desc: String = entry[1]
			if key.is_empty():
				# Tip line
				draw_node.draw_string(font, Vector2(col_key + 10, draw_y), desc,
					HORIZONTAL_ALIGNMENT_LEFT, 350, 10, Color(0.5, 0.45, 0.6))
			else:
				draw_node.draw_string(font, Vector2(col_key, draw_y), key,
					HORIZONTAL_ALIGNMENT_LEFT, 130, 11, Color(0.7, 0.6, 0.9))
				draw_node.draw_string(font, Vector2(col_desc, draw_y), desc,
					HORIZONTAL_ALIGNMENT_LEFT, 250, 10, Color(0.5, 0.45, 0.65))

	draw_node.draw_string(font, Vector2(cx - 80, vp.y - 15), "W/S: Scroll  |  ESC: Close",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.4, 0.35, 0.55))
