extends CanvasLayer

## Daily challenge screen. Shows today's seeded run with preset modifiers and scoring.
## Tracks best daily score.

signal closed

var draw_node: Control = null
var time: float = 0.0
var daily_seed: int = 0
var daily_world: int = 0
var daily_modifiers: Array[String] = []
var daily_best_score: int = 0
var today_key: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generate_daily()
	draw_node = Control.new()
	draw_node.name = "DailyDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _generate_daily() -> void:
	# Generate seed from today's date
	var date := Time.get_date_dict_from_system()
	today_key = "%d-%02d-%02d" % [date["year"], date["month"], date["day"]]
	daily_seed = hash(today_key)
	# Deterministic world and modifiers from seed
	var rng := RandomNumberGenerator.new()
	rng.seed = daily_seed
	daily_world = rng.randi_range(0, mini(WorldData.get_world_count() - 1, SaveData.highest_world_unlocked))
	# Pick 2-3 random modifiers
	var all_mods: Array[String] = ["double_hp", "fast_enemies", "no_regen", "glass_cannon", "swarm", "no_extract"]
	all_mods.shuffle()
	var mod_count := rng.randi_range(2, 3)
	daily_modifiers = []
	for i in range(mini(mod_count, all_mods.size())):
		daily_modifiers.append(all_mods[i])
	# Load best score
	daily_best_score = int(SaveData.run_bests.get("daily_" + today_key, 0))

func _process(delta: float) -> void:
	time += delta
	draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_D:
				Audio.play_ui_click()
				closed.emit()
				queue_free()
			KEY_ENTER, KEY_SPACE:
				_start_daily()
		get_viewport().set_input_as_handled()

func _start_daily() -> void:
	# Apply daily seed
	seed(daily_seed)
	# Set world
	Game.current_world = daily_world
	# Activate daily modifiers
	SaveData.active_challenges = daily_modifiers.duplicate()
	for mod_id in daily_modifiers:
		if not mod_id in SaveData.active_challenges:
			SaveData.active_challenges.append(mod_id)
	Audio.play_phase_change()
	closed.emit()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.06, 0.95))

	# Title
	var pulse := 0.7 + 0.3 * sin(time * 2.0)
	draw_node.draw_string(font, Vector2(cx - 80, 45), "DAILY CHALLENGE",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(1.0, 0.6, 0.2, pulse))

	# Date
	draw_node.draw_string(font, Vector2(cx - 60, 65), today_key,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.5, 0.4, 0.6))

	# World info
	var world_config := WorldData.get_config(daily_world)
	var world_name: String = world_config.get("name", "Unknown")
	var rc: Color = world_config.get("rift_color", Color(0.6, 0.2, 0.9))

	draw_node.draw_string(font, Vector2(cx - 80, 100), "World: %s" % world_name,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 14, rc)

	# Modifiers
	draw_node.draw_string(font, Vector2(cx - 60, 130), "Modifiers:",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.7, 0.5, 0.3))

	var mod_y := 150.0
	for mod_id in daily_modifiers:
		var mod_name := mod_id.replace("_", " ").capitalize()
		draw_node.draw_string(font, Vector2(cx - 80, mod_y), "- %s" % mod_name,
			HORIZONTAL_ALIGNMENT_LEFT, 160, 11, Color(1.0, 0.5, 0.3))
		mod_y += 18.0

	# Best score
	draw_node.draw_string(font, Vector2(cx - 80, mod_y + 15), "Best Score: %d" % daily_best_score,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(1.0, 0.9, 0.3))

	# Scoring rules
	draw_node.draw_string(font, Vector2(cx - 100, mod_y + 40), "Score = Kills + Worlds x100 + Bosses x250",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(0.4, 0.35, 0.55))

	# Start prompt
	var blink := 0.4 + 0.6 * sin(time * 3.0)
	draw_node.draw_string(font, Vector2(cx - 60, vp.y - 50), "ENTER: Start Daily Run",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1.0, 0.8, 0.3, blink))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 60, vp.y - 20), "ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.4, 0.35, 0.55))
