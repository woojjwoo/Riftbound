extends Control

## Reusable tooltip overlay. Shows contextual info for equipment, skills, achievements.
## Usage: var tip = Tooltip.new(); add_child(tip); tip.show_equipment(item, pos)

var time: float = 0.0
var visible_tooltip: bool = false
var tooltip_lines: Array[Dictionary] = []  # {text, color, size}
var tooltip_pos: Vector2 = Vector2.ZERO
var tooltip_width: float = 200.0
var fade_alpha: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	time += delta
	if visible_tooltip:
		fade_alpha = minf(fade_alpha + delta * 8.0, 1.0)
	else:
		fade_alpha = maxf(fade_alpha - delta * 8.0, 0.0)
	if fade_alpha > 0.0:
		queue_redraw()

func hide_tooltip() -> void:
	visible_tooltip = false

## Show tooltip for an equipment item
func show_equipment(item: Dictionary, pos: Vector2) -> void:
	tooltip_lines = []
	if item.is_empty():
		hide_tooltip()
		return

	var slot_name := Equipment.get_slot_name(item["slot"])
	var rarity_name := Equipment.get_rarity_name(item["rarity"])
	var rarity_color := Equipment.get_rarity_color(item["rarity"])
	var name_text: String = item.get("name", "Unknown")

	tooltip_lines.append({"text": name_text, "color": rarity_color, "size": 13})
	tooltip_lines.append({"text": "%s %s" % [rarity_name, slot_name], "color": Color(0.6, 0.55, 0.7), "size": 10})

	# Stats
	var bonus := Equipment.get_stat_bonus(item)
	var stat_name: String = Equipment.SLOT_INFO[item["slot"]]["stat"]
	var level: int = item.get("level", 0)
	if level > 0:
		tooltip_lines.append({"text": "+%d %s (Lv.%d)" % [int(bonus * 100) if bonus < 10 else int(bonus), stat_name, level], "color": Color(0.3, 1.0, 0.4), "size": 10})
	else:
		tooltip_lines.append({"text": "%s: +%.0f%%" % [stat_name, bonus * 100] if bonus < 10 else "%s: +%d" % [stat_name, int(bonus)], "color": Color(0.7, 0.65, 0.8), "size": 10})

	# Enchantment
	if item.has("enchant"):
		var enchant_info := Equipment.get_enchant_info(item["enchant"])
		if not enchant_info.is_empty():
			var enchant_color: Color = enchant_info.get("color", Color(0.6, 0.3, 1.0))
			tooltip_lines.append({"text": "Enchant: %s" % enchant_info["name"], "color": enchant_color, "size": 10})

	# Proc effect
	if item.has("proc_name"):
		tooltip_lines.append({"text": "", "color": Color.WHITE, "size": 4})  # spacer
		tooltip_lines.append({"text": item["proc_name"], "color": Color(1.0, 0.65, 0.0), "size": 11})
		tooltip_lines.append({"text": item.get("proc_desc", ""), "color": Color(0.7, 0.6, 0.5), "size": 9})

	tooltip_pos = pos
	tooltip_width = 220.0
	visible_tooltip = true
	fade_alpha = 0.0

## Show tooltip for a skill tree skill
func show_skill(skill: Dictionary, unlocked: bool, pos: Vector2) -> void:
	tooltip_lines = []
	var name_text: String = skill.get("name", "")
	var desc: String = skill.get("desc", "")
	var cost: int = skill.get("cost", 0)

	var name_color = Color(0.3, 1.0, 0.5) if unlocked else Color(0.8, 0.7, 1.0)
	tooltip_lines.append({"text": name_text, "color": name_color, "size": 13})
	tooltip_lines.append({"text": desc, "color": Color(0.6, 0.55, 0.7), "size": 10})

	if unlocked:
		tooltip_lines.append({"text": "UNLOCKED", "color": Color(0.3, 1.0, 0.4), "size": 10})
	else:
		tooltip_lines.append({"text": "Cost: %d Soul Essence" % cost, "color": Color(0.5, 0.3, 0.9), "size": 10})

	tooltip_pos = pos
	tooltip_width = 200.0
	visible_tooltip = true
	fade_alpha = 0.0

## Show tooltip for an achievement
func show_achievement(achievement: Dictionary, unlocked: bool, pos: Vector2) -> void:
	tooltip_lines = []
	var name_text: String = achievement.get("name", "")
	var desc: String = achievement.get("desc", "")

	var name_color = Color(1.0, 0.85, 0.3) if unlocked else Color(0.6, 0.55, 0.7)
	tooltip_lines.append({"text": name_text, "color": name_color, "size": 13})
	tooltip_lines.append({"text": desc, "color": Color(0.6, 0.55, 0.7), "size": 10})

	if unlocked:
		tooltip_lines.append({"text": "COMPLETED", "color": Color(0.3, 1.0, 0.4), "size": 10})
	else:
		tooltip_lines.append({"text": "Locked", "color": Color(0.4, 0.35, 0.5), "size": 10})

	# Reward info
	var reward: Dictionary = achievement.get("reward", {})
	if not reward.is_empty():
		var reward_parts: Array[String] = []
		if reward.has("essence"):
			reward_parts.append("%d Essence" % reward["essence"])
		if reward.has("coins"):
			reward_parts.append("%d Coins" % reward["coins"])
		if reward.has("equipment_rarity"):
			reward_parts.append("%s Equipment" % Equipment.get_rarity_name(reward["equipment_rarity"]))
		if reward_parts.size() > 0:
			tooltip_lines.append({"text": "Reward: " + ", ".join(reward_parts), "color": Color(1.0, 0.9, 0.4), "size": 9})

	tooltip_pos = pos
	tooltip_width = 220.0
	visible_tooltip = true
	fade_alpha = 0.0

## Show generic text tooltip
func show_text(title: String, body: String, pos: Vector2) -> void:
	tooltip_lines = []
	tooltip_lines.append({"text": title, "color": Color(0.9, 0.8, 1.0), "size": 12})
	if not body.is_empty():
		tooltip_lines.append({"text": body, "color": Color(0.6, 0.55, 0.7), "size": 10})
	tooltip_pos = pos
	tooltip_width = 180.0
	visible_tooltip = true
	fade_alpha = 0.0

func _draw() -> void:
	if fade_alpha <= 0.01 or tooltip_lines.is_empty():
		return

	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size
	var padding := 8.0
	var line_gap := 4.0

	# Calculate total height
	var total_h := padding * 2.0
	for line in tooltip_lines:
		var s: int = line["size"]
		if s <= 4:
			total_h += 4.0  # spacer
		else:
			total_h += float(s) + line_gap

	# Position: prefer below-right of cursor, but clamp to screen
	var tx := tooltip_pos.x + 12.0
	var ty := tooltip_pos.y + 12.0
	if tx + tooltip_width + padding > vp.x:
		tx = tooltip_pos.x - tooltip_width - 12.0
	if ty + total_h > vp.y:
		ty = tooltip_pos.y - total_h - 12.0
	tx = maxf(tx, 4.0)
	ty = maxf(ty, 4.0)

	# Background
	var bg_rect := Rect2(tx, ty, tooltip_width + padding * 2, total_h)
	draw_rect(bg_rect, Color(0.05, 0.03, 0.1, 0.92 * fade_alpha))
	draw_rect(bg_rect, Color(0.5, 0.4, 0.7, 0.4 * fade_alpha), false, 1.0)

	# Lines
	var cy := ty + padding
	for line in tooltip_lines:
		var s: int = line["size"]
		if s <= 4:
			cy += 4.0
			continue
		cy += float(s)
		var col: Color = line["color"]
		col.a *= fade_alpha
		draw_string(font, Vector2(tx + padding, cy), line["text"],
			HORIZONTAL_ALIGNMENT_LEFT, tooltip_width, s, col)
		cy += line_gap
