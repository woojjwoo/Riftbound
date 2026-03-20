extends CanvasLayer

## First-run tutorial overlay. Shows step-by-step instructions during the first run.
## Automatically advances based on player actions. Skipped if already completed.

var steps: Array[Dictionary] = [
	{"trigger": "start", "text": "Welcome, Necromancer.\nUse WASD to move around.",
	 "hint": "Move to continue", "duration": 0.0},
	{"trigger": "moved", "text": "Good. Left-click to fire Soul Bolts at enemies.",
	 "hint": "Shoot an enemy", "duration": 0.0},
	{"trigger": "killed", "text": "Stay near fallen enemies to extract Thralls.\nThey rise automatically when you're close enough.",
	 "hint": "Extract a thrall", "duration": 0.0},
	{"trigger": "thrall", "text": "Right-click to command your Thralls to a position.\nPress R to recall them to your side.",
	 "hint": "Command your thralls", "duration": 0.0},
	{"trigger": "command", "text": "Press SPACE to Dash through danger.\nYou're invincible while dashing.",
	 "hint": "Try dashing", "duration": 0.0},
	{"trigger": "dash", "text": "Seal all Rifts to clear the world.\nSend your Thralls to attack Rifts!",
	 "hint": "Seal a rift", "duration": 0.0},
	{"trigger": "rift", "text": "Excellent! Each sealed rift grants an upgrade.\nClose all rifts to face the boss.\n\nGood luck, Necromancer!",
	 "hint": "", "duration": 5.0},
]

var current_step: int = 0
var step_timer: float = 0.0
var fade: float = 0.0
var completed: bool = false
var draw_node: Control = null

# Track triggers
var _has_moved: bool = false
var _has_killed: bool = false
var _has_thrall: bool = false
var _has_command: bool = false
var _has_dashed: bool = false
var _has_rift: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create draw surface
	draw_node = Control.new()
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_draw_tutorial)
	add_child(draw_node)

	# Connect signals
	Game.enemy_killed.connect(func(): _has_killed = true)
	Game.thrall_gained.connect(func(): _has_thrall = true)
	Game.rift_closed_signal.connect(func(_n): _has_rift = true)

func _process(delta: float) -> void:
	if completed:
		return

	step_timer += delta

	# Check trigger for current step
	if current_step < steps.size():
		var step := steps[current_step]
		var triggered := false
		match step["trigger"]:
			"start":
				triggered = true  # Always advance from start
				if step_timer < 2.0:
					triggered = false
			"moved":
				triggered = _has_moved
			"killed":
				triggered = _has_killed
			"thrall":
				triggered = _has_thrall
			"command":
				triggered = _has_command
			"dash":
				triggered = _has_dashed
			"rift":
				triggered = _has_rift

		if triggered:
			var duration: float = step["duration"]
			if duration > 0.0:
				if step_timer > duration:
					_advance_step()
			else:
				_advance_step()

	# Track movement
	if Input.get_axis("move_left", "move_right") != 0.0 or Input.get_axis("move_up", "move_down") != 0.0:
		_has_moved = true
	if Input.is_action_just_pressed("dash"):
		_has_dashed = true
	if Input.is_action_just_pressed("command") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_has_command = true

	# Fade
	if not completed and current_step < steps.size():
		fade = minf(fade + delta * 3.0, 1.0)
	else:
		fade = maxf(fade - delta * 2.0, 0.0)
		if fade <= 0.0 and completed:
			queue_free()
			return

	draw_node.queue_redraw()

func _advance_step() -> void:
	current_step += 1
	step_timer = 0.0
	fade = 0.0
	if current_step >= steps.size():
		completed = true
		SaveData.tutorial_completed = true
		SaveData.save_game()

func _draw_tutorial() -> void:
	if current_step >= steps.size() and fade <= 0.0:
		return

	var step_idx := mini(current_step, steps.size() - 1)
	var step := steps[step_idx]
	var vp := draw_node.get_viewport_rect().size
	var cx := vp.x / 2.0
	var font := ThemeDB.fallback_font
	var alpha := fade * 0.9

	# Tutorial banner at top-center
	var text: String = step["text"]
	var hint: String = step["hint"]
	var lines := text.split("\n")
	var line_count := lines.size()
	var banner_h := float(line_count) * 18.0 + 40.0
	if not hint.is_empty():
		banner_h += 20.0
	var banner_y := 110.0
	var banner_w := 400.0

	# Background
	draw_node.draw_rect(Rect2(cx - banner_w / 2.0, banner_y, banner_w, banner_h),
		Color(0.04, 0.02, 0.08, 0.85 * alpha))
	draw_node.draw_rect(Rect2(cx - banner_w / 2.0, banner_y, banner_w, banner_h),
		Color(0.5, 0.3, 0.8, 0.4 * alpha), false, 1.5)

	# Text lines
	var y := banner_y + 22.0
	for line in lines:
		draw_node.draw_string(font, Vector2(cx - 170, y), line,
			HORIZONTAL_ALIGNMENT_CENTER, 340, 12, Color(0.9, 0.85, 1.0, alpha))
		y += 18.0

	# Hint
	if not hint.is_empty():
		y += 5.0
		var hint_blink := 0.5 + 0.5 * sin(step_timer * 3.0)
		draw_node.draw_string(font, Vector2(cx - 80, y), hint,
			HORIZONTAL_ALIGNMENT_CENTER, 160, 10, Color(0.6, 0.4, 1.0, alpha * hint_blink))

	# Step indicator
	var indicator_y := banner_y + banner_h + 8.0
	for i in range(steps.size()):
		var dot_x := cx - float(steps.size()) * 6.0 + float(i) * 12.0
		var dot_color = Color(0.5, 0.3, 0.8, alpha) if i <= current_step else Color(0.3, 0.2, 0.4, alpha * 0.5)
		draw_node.draw_circle(Vector2(dot_x, indicator_y), 3.0, dot_color)
