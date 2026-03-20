extends CanvasLayer

## Achievement unlock notification popup.
## Slides in from the top, shows icon + name + description, then fades out.
## Polls AchievementManager's notification queue each frame.

var _active: bool = false
var _timer: float = 0.0
var _slide_y: float = -80.0
var _target_y: float = 20.0
var _display_duration: float = 3.0
var _slide_duration: float = 0.3
var _fade_duration: float = 0.5
var _alpha: float = 0.0

# Current achievement being displayed
var _current_name: String = ""
var _current_desc: String = ""
var _current_icon: String = ""

# Panel dimensions
const PANEL_WIDTH: float = 320.0
const PANEL_HEIGHT: float = 70.0

# Draw node for rendering
var _draw_node: Control = null

func _ready() -> void:
	layer = 100  # Always on top
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)

func _process(delta: float) -> void:
	if not _active:
		# Check for new notifications
		var next_id := Achievements.pop_notification()
		if next_id != "":
			_show_achievement(next_id)
		return

	_timer += delta

	# Phase 1: Slide in
	if _timer <= _slide_duration:
		var t := _timer / _slide_duration
		t = 1.0 - pow(1.0 - t, 3.0)  # ease out cubic
		_slide_y = lerpf(-PANEL_HEIGHT, _target_y, t)
		_alpha = t
	# Phase 2: Display
	elif _timer <= _slide_duration + _display_duration:
		_slide_y = _target_y
		_alpha = 1.0
	# Phase 3: Fade out
	elif _timer <= _slide_duration + _display_duration + _fade_duration:
		var fade_t := (_timer - _slide_duration - _display_duration) / _fade_duration
		_alpha = 1.0 - fade_t
		_slide_y = _target_y - 10.0 * fade_t  # slight upward drift
	else:
		_active = false
		_alpha = 0.0

	_draw_node.queue_redraw()

func _show_achievement(achievement_id: String) -> void:
	var def := Achievements.get_def(achievement_id)
	if def.is_empty():
		return
	_current_name = def.get("name", "???")
	_current_desc = def.get("desc", "")
	_current_icon = def.get("icon", "?")
	_active = true
	_timer = 0.0
	_slide_y = -PANEL_HEIGHT
	_alpha = 0.0
	Audio.play_upgrade()

func _on_draw() -> void:
	if _alpha <= 0.01:
		return

	var vp := _draw_node.get_viewport_rect().size
	var panel_x := (vp.x - PANEL_WIDTH) / 2.0
	var panel_y := _slide_y
	var font := ThemeDB.fallback_font

	# Background panel
	var bg_color := Color(0.08, 0.05, 0.14, 0.92 * _alpha)
	_draw_node.draw_rect(Rect2(panel_x, panel_y, PANEL_WIDTH, PANEL_HEIGHT), bg_color)

	# Gold border
	var border_color := Color(1.0, 0.85, 0.3, 0.7 * _alpha)
	_draw_node.draw_rect(Rect2(panel_x, panel_y, PANEL_WIDTH, PANEL_HEIGHT), border_color, false, 2.0)

	# Icon area (left side)
	var icon_x := panel_x + 8.0
	var icon_y := panel_y + 8.0
	var icon_size := PANEL_HEIGHT - 16.0
	_draw_node.draw_rect(Rect2(icon_x, icon_y, icon_size, icon_size),
		Color(0.15, 0.1, 0.25, 0.8 * _alpha))
	_draw_node.draw_rect(Rect2(icon_x, icon_y, icon_size, icon_size),
		Color(0.6, 0.4, 1.0, 0.5 * _alpha), false, 1.0)

	# Icon text (centered in icon area)
	var icon_text_x := icon_x + (icon_size - float(_current_icon.length()) * 6.0) / 2.0
	_draw_node.draw_string(font, Vector2(icon_text_x, icon_y + icon_size / 2.0 + 5.0),
		_current_icon, HORIZONTAL_ALIGNMENT_LEFT, int(icon_size), 14,
		Color(1.0, 0.85, 0.3, _alpha))

	# "Achievement Unlocked" header
	var text_x := icon_x + icon_size + 12.0
	var text_w := int(PANEL_WIDTH - icon_size - 32.0)
	_draw_node.draw_string(font, Vector2(text_x, panel_y + 20.0),
		"Achievement Unlocked!", HORIZONTAL_ALIGNMENT_LEFT, text_w, 10,
		Color(1.0, 0.9, 0.5, 0.8 * _alpha))

	# Achievement name
	_draw_node.draw_string(font, Vector2(text_x, panel_y + 38.0),
		_current_name, HORIZONTAL_ALIGNMENT_LEFT, text_w, 14,
		Color(1.0, 0.85, 0.3, _alpha))

	# Description
	_draw_node.draw_string(font, Vector2(text_x, panel_y + 55.0),
		_current_desc, HORIZONTAL_ALIGNMENT_LEFT, text_w, 10,
		Color(0.7, 0.65, 0.85, 0.85 * _alpha))
