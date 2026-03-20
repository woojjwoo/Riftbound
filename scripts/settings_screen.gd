extends CanvasLayer

## Settings screen with audio volume controls.
## Can be opened from the title screen or pause menu.

var master_slider: HSlider = null
var sfx_slider: HSlider = null
var music_slider: HSlider = null
var back_button: Button = null

var _return_scene: String = ""

signal closed

func setup(return_scene: String = "") -> void:
	_return_scene = return_scene

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_sync_sliders()

func _build_ui() -> void:
	var panel := Panel.new()
	panel.name = "SettingsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.95)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.5, 0.3, 0.8, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -200
	panel.offset_right = 180
	panel.offset_bottom = 200
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Master volume
	master_slider = _add_slider(vbox, "Master Volume")
	master_slider.value_changed.connect(_on_master_changed)

	# SFX volume
	sfx_slider = _add_slider(vbox, "SFX Volume")
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# Music volume
	music_slider = _add_slider(vbox, "Music Volume")
	music_slider.value_changed.connect(_on_music_changed)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	vbox.add_child(spacer2)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size.y = 40
	back_button.pressed.connect(_on_back)
	vbox.add_child(back_button)

func _add_slider(parent: VBoxContainer, label_text: String) -> HSlider:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	parent.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.8
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "80%"
	value_label.custom_minimum_size.x = 40
	value_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float):
		value_label.text = "%d%%" % int(val * 100)
	)

	return slider

func _sync_sliders() -> void:
	master_slider.value = Audio.master_volume
	sfx_slider.value = Audio.sfx_volume
	music_slider.value = Audio.music_volume

func _on_master_changed(value: float) -> void:
	Audio.set_master_volume(value)

func _on_sfx_changed(value: float) -> void:
	Audio.set_sfx_volume(value)

func _on_music_changed(value: float) -> void:
	Audio.set_music_volume(value)

func _on_back() -> void:
	Audio.play_ui_cancel()
	closed.emit()
	if _return_scene.is_empty():
		queue_free()
	else:
		get_tree().change_scene_to_file(_return_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
