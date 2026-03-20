extends CanvasLayer

## Settings screen with audio volume controls.
## Can be opened from the title screen or pause menu.

var master_slider: HSlider = null
var sfx_slider: HSlider = null
var music_slider: HSlider = null
var shake_toggle: CheckButton = null
var dmg_num_toggle: CheckButton = null
var minimap_slider: HSlider = null
var hud_opacity_slider: HSlider = null
var colorblind_option: OptionButton = null
var font_size_slider: HSlider = null
var auto_aim_toggle: CheckButton = null
var auto_aim_slider: HSlider = null
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
	panel.offset_left = -220
	panel.offset_top = -300
	panel.offset_right = 220
	panel.offset_bottom = 300
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title)

	_add_section_label(vbox, "Audio")

	# Master volume
	master_slider = _add_slider(vbox, "Master Volume")
	master_slider.value_changed.connect(_on_master_changed)

	# SFX volume
	sfx_slider = _add_slider(vbox, "SFX Volume")
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# Music volume
	music_slider = _add_slider(vbox, "Music Volume")
	music_slider.value_changed.connect(_on_music_changed)

	_add_section_label(vbox, "Gameplay")

	# Screen shake toggle
	shake_toggle = _add_toggle(vbox, "Screen Shake")
	shake_toggle.toggled.connect(func(on: bool):
		SaveData.screen_shake_enabled = on
		SaveData.save_game()
	)

	# Damage numbers toggle
	dmg_num_toggle = _add_toggle(vbox, "Damage Numbers")
	dmg_num_toggle.toggled.connect(func(on: bool):
		SaveData.damage_numbers_enabled = on
		SaveData.save_game()
	)

	# Minimap size
	minimap_slider = _add_slider(vbox, "Minimap Size", 0.5, 1.5, 0.1)
	minimap_slider.value_changed.connect(func(val: float):
		SaveData.minimap_size = val
		SaveData.save_game()
	)

	# HUD opacity
	hud_opacity_slider = _add_slider(vbox, "HUD Opacity", 0.3, 1.0, 0.05)
	hud_opacity_slider.value_changed.connect(func(val: float):
		SaveData.hud_opacity = val
		SaveData.save_game()
	)

	_add_section_label(vbox, "Accessibility")

	# Colorblind mode
	var cb_label := Label.new()
	cb_label.text = "Colorblind Mode"
	cb_label.add_theme_font_size_override("font_size", 14)
	cb_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	vbox.add_child(cb_label)

	colorblind_option = OptionButton.new()
	colorblind_option.add_item("Off", 0)
	colorblind_option.add_item("Deuteranopia (Green-Blind)", 1)
	colorblind_option.add_item("Protanopia (Red-Blind)", 2)
	colorblind_option.add_item("Tritanopia (Blue-Blind)", 3)
	colorblind_option.item_selected.connect(func(idx: int):
		SaveData.colorblind_mode = idx
		SaveData.save_game()
	)
	vbox.add_child(colorblind_option)

	# Font size scale
	font_size_slider = _add_slider(vbox, "Font Size", 0.8, 1.5, 0.1)
	font_size_slider.value_changed.connect(func(val: float):
		SaveData.font_size_scale = val
		SaveData.save_game()
	)

	# Auto-aim toggle
	auto_aim_toggle = _add_toggle(vbox, "Auto-Aim Assist")
	auto_aim_toggle.toggled.connect(func(on: bool):
		SaveData.auto_aim_enabled = on
		SaveData.save_game()
	)

	# Auto-aim strength
	auto_aim_slider = _add_slider(vbox, "Auto-Aim Strength", 0.0, 1.0, 0.1)
	auto_aim_slider.value_changed.connect(func(val: float):
		SaveData.auto_aim_strength = val
		SaveData.save_game()
	)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 10
	vbox.add_child(spacer2)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size.y = 40
	back_button.pressed.connect(_on_back)
	vbox.add_child(back_button)

func _add_slider(parent: VBoxContainer, label_text: String,
		min_val: float = 0.0, max_val: float = 1.0, step_val: float = 0.05) -> HSlider:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	parent.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = max_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d%%" % int(max_val * 100)
	value_label.custom_minimum_size.x = 40
	value_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float):
		value_label.text = "%d%%" % int(val * 100)
	)

	return slider

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	parent.add_child(spacer)
	var label := Label.new()
	label.text = "— %s —" % text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.7))
	parent.add_child(label)

func _add_toggle(parent: VBoxContainer, label_text: String) -> CheckButton:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var toggle := CheckButton.new()
	toggle.button_pressed = true
	hbox.add_child(toggle)
	return toggle

func _sync_sliders() -> void:
	master_slider.value = Audio.master_volume
	sfx_slider.value = Audio.sfx_volume
	music_slider.value = Audio.music_volume
	shake_toggle.button_pressed = SaveData.screen_shake_enabled
	dmg_num_toggle.button_pressed = SaveData.damage_numbers_enabled
	minimap_slider.value = SaveData.minimap_size
	hud_opacity_slider.value = SaveData.hud_opacity
	colorblind_option.selected = SaveData.colorblind_mode
	font_size_slider.value = SaveData.font_size_scale
	auto_aim_toggle.button_pressed = SaveData.auto_aim_enabled
	auto_aim_slider.value = SaveData.auto_aim_strength

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
