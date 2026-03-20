extends CanvasLayer

## Screen transition effects — fade in/out, wipe, flash.
## Used when changing scenes or entering boss fights.

var rect: ColorRect = null
var time: float = 0.0
var transitioning: bool = false

signal transition_midpoint
signal transition_complete

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

## Fade to black and back
func fade_through(duration: float = 0.6, color: Color = Color.BLACK) -> void:
	if transitioning:
		return
	transitioning = true
	rect.color = Color(color.r, color.g, color.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 1.0, duration * 0.5)
	tween.tween_callback(func(): transition_midpoint.emit())
	tween.tween_property(rect, "color:a", 0.0, duration * 0.5)
	tween.tween_callback(func():
		transitioning = false
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_complete.emit())

## Fade in from black (for scene entry)
func fade_in(duration: float = 0.5, color: Color = Color.BLACK) -> void:
	rect.color = Color(color.r, color.g, color.b, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 0.0, duration)
	tween.tween_callback(func():
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_complete.emit())

## Flash effect (for boss spawn, phase change, etc.)
func flash(color: Color = Color.WHITE, duration: float = 0.3) -> void:
	rect.color = Color(color.r, color.g, color.b, 0.6)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 0.0, duration)

## Death screen effect — slow red fade
func death_fade(duration: float = 1.5) -> void:
	rect.color = Color(0.3, 0.0, 0.0, 0.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 0.7, duration).set_ease(Tween.EASE_IN)
