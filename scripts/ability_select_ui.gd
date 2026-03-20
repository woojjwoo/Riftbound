extends CanvasLayer

## Ability selection screen shown on level-up. Presents 3 random abilities
## to choose from. Pauses the game while visible.

const AbilityData := preload("res://scripts/ability_data.gd")

signal ability_chosen(id: String)

var panel: Panel
var title_label: Label
var choices: Array[Button] = []
var choice_desc_labels: Array[Label] = []
var choice_level_labels: Array[Label] = []
var offered_ids: Array[String] = []

var ability_manager: Node = null

func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Semi-transparent background overlay
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Center panel
	panel = Panel.new()
	panel.name = "SelectPanel"
	panel.offset_left = 240.0
	panel.offset_top = 120.0
	panel.offset_right = 1040.0
	panel.offset_bottom = 600.0
	add_child(panel)

	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "LEVEL UP! Choose an Ability"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.offset_left = 100.0
	title_label.offset_top = 20.0
	title_label.offset_right = 700.0
	title_label.offset_bottom = 50.0
	panel.add_child(title_label)

	# Three choice columns
	for i in range(3):
		var x_offset := 20.0 + i * 260.0

		var btn := Button.new()
		btn.name = "Choice%d" % i
		btn.offset_left = x_offset
		btn.offset_top = 80.0
		btn.offset_right = x_offset + 240.0
		btn.offset_bottom = 160.0
		btn.text = "Ability Name"
		var idx := i
		btn.pressed.connect(func() -> void: _on_choice_selected(idx))
		panel.add_child(btn)
		choices.append(btn)

		var desc := Label.new()
		desc.name = "Desc%d" % i
		desc.offset_left = x_offset
		desc.offset_top = 170.0
		desc.offset_right = x_offset + 240.0
		desc.offset_bottom = 300.0
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = "Description"
		panel.add_child(desc)
		choice_desc_labels.append(desc)

		var lvl := Label.new()
		lvl.name = "Level%d" % i
		lvl.offset_left = x_offset
		lvl.offset_top = 310.0
		lvl.offset_right = x_offset + 240.0
		lvl.offset_bottom = 380.0
		lvl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lvl.text = ""
		panel.add_child(lvl)
		choice_level_labels.append(lvl)

func show_selection(mgr: Node) -> void:
	ability_manager = mgr
	offered_ids = _pick_random_abilities(3)

	var all_info := AbilityData.get_all_abilities()

	for i in range(3):
		# Reset button state
		choices[i].disabled = false

		if i < offered_ids.size():
			var id: String = offered_ids[i]
			var info = all_info[id]
			var current_level: int = mgr.get_ability_level(id)
			var next_level: int = current_level + 1

			if current_level == 0:
				choices[i].text = info.display_name + " (NEW)"
			else:
				choices[i].text = info.display_name + " Lv.%d -> %d" % [current_level, next_level]

			choice_desc_labels[i].text = info.description

			if next_level <= info.max_level:
				choice_level_labels[i].text = AbilityData.get_level_description(id, next_level)
			else:
				choice_level_labels[i].text = "MAX LEVEL"
				choices[i].disabled = true

			choices[i].visible = true
			choice_desc_labels[i].visible = true
			choice_level_labels[i].visible = true
		else:
			choices[i].visible = false
			choice_desc_labels[i].visible = false
			choice_level_labels[i].visible = false

	visible = true
	get_tree().paused = true

func _pick_random_abilities(count: int) -> Array[String]:
	var all_info := AbilityData.get_all_abilities()
	var pool: Array[String] = []

	for id in all_info.keys():
		var info = all_info[id]
		var current_lvl: int = 0
		if ability_manager:
			current_lvl = ability_manager.get_ability_level(id)
		if current_lvl < info.max_level:
			pool.append(id)

	# Shuffle and take up to count
	pool.shuffle()
	var result: Array[String] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

func _on_choice_selected(index: int) -> void:
	if index >= offered_ids.size():
		return

	var id: String = offered_ids[index]
	ability_chosen.emit(id)
	visible = false
	get_tree().paused = false
