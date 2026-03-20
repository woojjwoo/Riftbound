extends CanvasLayer

## Arena/Endless mode — survival with escalating waves.
## Accessible from title screen. Tracks wave count and best wave.

signal closed

var draw_node: Control = null
var time: float = 0.0

# Arena state
var arena_active: bool = false
var current_wave: int = 0
var enemies_remaining: int = 0
var enemies_spawned: int = 0
var wave_timer: float = 0.0
var intermission: bool = false
var intermission_timer: float = 0.0
var spawn_timer: float = 0.0
var best_wave: int = 0
var total_kills: int = 0

# Arena world (visual theme)
var arena_world: int = 0

const INTERMISSION_TIME: float = 3.0
const BASE_ENEMIES: int = 5
const ENEMIES_PER_WAVE: int = 3
const SPAWN_INTERVAL: float = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.name = "ArenaDraw"
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)
	# Load best wave from save
	best_wave = int(SaveData.run_bests.get("arena_best_wave", 0))

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
			KEY_ENTER, KEY_SPACE:
				if not arena_active:
					_start_arena()
			KEY_LEFT, KEY_A:
				if not arena_active:
					arena_world = max(0, arena_world - 1)
					Audio.play_ui_click()
			KEY_RIGHT, KEY_D:
				if not arena_active:
					arena_world = min(SaveData.highest_world_unlocked, arena_world + 1)
					arena_world = mini(arena_world, WorldData.get_world_count() - 1)
					Audio.play_ui_click()
		get_viewport().set_input_as_handled()

func _start_arena() -> void:
	arena_active = true
	current_wave = 0
	total_kills = 0
	# Set the world theme and launch the main game scene in arena mode
	Game.current_world = arena_world
	Game.arena_mode = true
	Game.arena_wave = 0
	Game.arena_best_wave = best_wave
	Audio.play_phase_change()
	closed.emit()
	queue_free()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_draw() -> void:
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_node.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.02, 0.08, 0.95))

	# Title
	var pulse := 0.7 + 0.3 * sin(time * 2.0)
	draw_node.draw_string(font, Vector2(cx - 50, cy - 100), "ARENA",
		HORIZONTAL_ALIGNMENT_CENTER, 100, 28, Color(1.0, 0.4, 0.2, pulse))
	draw_node.draw_string(font, Vector2(cx - 60, cy - 75), "ENDLESS MODE",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.7, 0.5, 0.3))

	# Best wave
	if best_wave > 0:
		draw_node.draw_string(font, Vector2(cx - 60, cy - 50), "Best Wave: %d" % best_wave,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.85, 0.3))

	# World selector
	var world_config := WorldData.get_config(arena_world)
	var world_name: String = world_config.get("name", "Unknown")
	var rc: Color = world_config.get("rift_color", Color(0.6, 0.2, 0.9))

	draw_node.draw_string(font, Vector2(cx - 80, cy - 15), "Arena Theme:",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color(0.5, 0.4, 0.6))

	# Arrows
	if arena_world > 0:
		draw_node.draw_string(font, Vector2(cx - 110, cy + 10), "<",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color(0.7, 0.6, 0.9))
	if arena_world < SaveData.highest_world_unlocked and arena_world < WorldData.get_world_count() - 1:
		draw_node.draw_string(font, Vector2(cx + 95, cy + 10), ">",
			HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color(0.7, 0.6, 0.9))

	draw_node.draw_string(font, Vector2(cx - 70, cy + 10), world_name,
		HORIZONTAL_ALIGNMENT_CENTER, 140, 14, rc)

	# Description
	draw_node.draw_string(font, Vector2(cx - 120, cy + 45), "Survive endless waves of enemies.",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 10, Color(0.5, 0.4, 0.6))
	draw_node.draw_string(font, Vector2(cx - 120, cy + 60), "Each wave grows stronger. No rifts, no boss — just combat.",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 10, Color(0.5, 0.4, 0.6))
	draw_node.draw_string(font, Vector2(cx - 120, cy + 75), "Earn coins and essence based on waves survived.",
		HORIZONTAL_ALIGNMENT_CENTER, 240, 10, Color(0.5, 0.4, 0.6))

	# Start button
	var start_pulse := 0.5 + 0.5 * sin(time * 3.0)
	draw_node.draw_rect(Rect2(cx - 60, cy + 100, 120, 35), Color(0.15, 0.08, 0.2, 0.8))
	draw_node.draw_rect(Rect2(cx - 60, cy + 100, 120, 35), Color(1.0, 0.4, 0.2, start_pulse * 0.6), false, 1.5)
	draw_node.draw_string(font, Vector2(cx - 40, cy + 123), "ENTER: Begin",
		HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1.0, 0.6, 0.3))

	# Controls
	draw_node.draw_string(font, Vector2(cx - 100, vp.y - 20), "A/D: Theme  |  ENTER: Start  |  ESC: Back",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(0.4, 0.35, 0.55))
