extends Node2D

## Title screen with animated rift visual. Click or press any key to start.

var time: float = 0.0
var started: bool = false

func _ready() -> void:
	Audio.start_music()

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if started:
		return
	if (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventKey and event.pressed):
		_start_game()

func _start_game() -> void:
	started = true
	Audio.play_phase_change()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var center := Vector2(cx, cy)

	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.02, 0.07))

	# Floating particles
	for i in range(30):
		var seed_val := float(i) * 137.5
		var px := cx + sin(time * 0.3 + seed_val) * 300.0
		var py := cy + cos(time * 0.4 + seed_val * 0.7) * 200.0
		var p_alpha := 0.15 + 0.1 * sin(time * 0.8 + seed_val)
		draw_circle(Vector2(px, py), 1.5, Color(0.5, 0.2, 0.8, p_alpha))

	# Rift visual — swirling arcs
	for i in range(5):
		var angle_offset := time * (0.8 + float(i) * 0.3)
		var radius := 50.0 + float(i) * 18.0
		var alpha := 0.35 - float(i) * 0.05
		draw_arc(center, radius, angle_offset, angle_offset + PI * 1.5, 24,
			Color(0.6, 0.2, 0.9, alpha), 2.5)
	for i in range(3):
		var angle_offset := -time * (1.0 + float(i) * 0.5)
		var radius := 35.0 + float(i) * 15.0
		draw_arc(center, radius, angle_offset, angle_offset + PI, 16,
			Color(0.8, 0.3, 0.5, 0.2), 1.5)

	# Core glow
	var pulse := 0.6 + 0.4 * sin(time * 2.0)
	draw_circle(center, 25.0, Color(0.5, 0.15, 0.7, 0.15 * pulse))
	draw_circle(center, 12.0, Color(0.8, 0.3, 1.0, 0.35 * pulse))
	draw_circle(center, 5.0, Color(1.0, 0.8, 1.0, 0.5 * pulse))

	# Title
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(cx - 90, cy - 110), "RIFTBOUND",
		HORIZONTAL_ALIGNMENT_CENTER, 180, 36, Color(0.85, 0.65, 1.0))

	# Subtitle
	draw_string(font, Vector2(cx - 80, cy - 80), "A Necromancer's Tale",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(0.5, 0.35, 0.65))

	# Click to start
	var blink := 0.4 + 0.6 * sin(time * 3.0)
	draw_string(font, Vector2(cx - 60, cy + 140), "Click to Begin",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.7, 0.5, 0.9, blink))

	# Controls preview
	draw_string(font, Vector2(cx - 100, cy + 190), "WASD: Move  |  LMB: Soul Bolt",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color(0.4, 0.3, 0.5, 0.6))
	draw_string(font, Vector2(cx - 100, cy + 205), "RMB: Command Thralls  |  R: Recall",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color(0.4, 0.3, 0.5, 0.6))
	draw_string(font, Vector2(cx - 100, cy + 220), "SPACE: Dash  |  Close 5 Rifts to Win",
		HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color(0.4, 0.3, 0.5, 0.6))
