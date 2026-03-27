extends Control

## HUD element showing active ability cooldowns as small bars at the bottom of the screen.

const AbilityData := preload("res://scripts/ability_data.gd")

var ability_manager: Node = null
var slot_panels: Dictionary = {}  # ability_id -> Panel node
var slot_bars: Dictionary = {}    # ability_id -> ProgressBar node
var slot_labels: Dictionary = {}  # ability_id -> Label node

var container: HBoxContainer

func _ready() -> void:
	# Anchor to bottom center
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -80.0
	offset_bottom = 0.0
	offset_left = -300.0
	offset_right = 300.0

	container = HBoxContainer.new()
	container.name = "SlotContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 8)
	add_child(container)

func setup(mgr: Node) -> void:
	ability_manager = mgr
	mgr.ability_activated.connect(_on_ability_activated)
	mgr.ability_cooldown_updated.connect(_on_cooldown_updated)

func _on_ability_activated(id: String) -> void:
	if not slot_panels.has(id):
		_create_slot(id)

func _create_slot(id: String) -> void:
	var all_info := AbilityData.get_all_abilities()
	if not all_info.has(id):
		return
	var info = all_info[id]

	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(80, 60)

	# Style the panel background with the ability color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(info.icon_color.r * 0.3, info.icon_color.g * 0.3, info.icon_color.b * 0.3, 0.8)
	style.border_color = info.icon_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	# Ability name label
	var name_label := Label.new()
	name_label.text = info.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.offset_left = 2.0
	name_label.offset_top = 2.0
	name_label.offset_right = 78.0
	name_label.offset_bottom = 20.0
	name_label.add_theme_font_size_override("font_size", 10)
	slot.add_child(name_label)

	# Cooldown progress bar
	var bar := ProgressBar.new()
	bar.offset_left = 4.0
	bar.offset_top = 22.0
	bar.offset_right = 76.0
	bar.offset_bottom = 36.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = info.icon_color
	bar_fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	bar_bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bar_bg)

	slot.add_child(bar)

	# Level label
	var lvl_label := Label.new()
	lvl_label.text = "Lv.1"
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.offset_left = 2.0
	lvl_label.offset_top = 40.0
	lvl_label.offset_right = 78.0
	lvl_label.offset_bottom = 58.0
	lvl_label.add_theme_font_size_override("font_size", 10)
	slot.add_child(lvl_label)

	container.add_child(slot)
	slot_panels[id] = slot
	slot_bars[id] = bar
	slot_labels[id] = lvl_label

func _on_cooldown_updated(id: String, fraction: float) -> void:
	if slot_bars.has(id):
		# fraction = remaining / max, so "ready" = 0.0
		slot_bars[id].value = fraction

func update_level(id: String, level: int) -> void:
	if slot_labels.has(id):
		slot_labels[id].text = "Lv.%d" % level
