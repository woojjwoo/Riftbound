extends RefCounted

## Static definitions for all abilities. Each ability has a name, description,
## cooldown, icon color (for UI), and a max level.

class AbilityInfo:
	var id: String
	var display_name: String
	var description: String
	var icon_color: Color
	var base_cooldown: float
	var max_level: int

	func _init(p_id: String, p_name: String, p_desc: String, p_color: Color, p_cd: float, p_max: int) -> void:
		id = p_id
		display_name = p_name
		description = p_desc
		icon_color = p_color
		base_cooldown = p_cd
		max_level = p_max

static func get_all_abilities() -> Dictionary:
	var abilities: Dictionary = {}

	abilities["lightning_strike"] = AbilityInfo.new(
		"lightning_strike",
		"Lightning Strike",
		"Strikes a large area around the player with lightning, dealing damage to all enemies.",
		Color(0.6, 0.8, 1.0),
		8.0,
		5
	)

	abilities["frost_nova"] = AbilityInfo.new(
		"frost_nova",
		"Frost Nova",
		"Unleashes a ring of frost that slows all nearby enemies for several seconds.",
		Color(0.4, 0.9, 1.0),
		10.0,
		5
	)

	abilities["shield_bash"] = AbilityInfo.new(
		"shield_bash",
		"Shield Bash",
		"Bashes nearby enemies with a spectral shield, dealing damage and knocking them back.",
		Color(1.0, 0.85, 0.3),
		6.0,
		5
	)

	abilities["heal_pulse"] = AbilityInfo.new(
		"heal_pulse",
		"Heal Pulse",
		"Emits a healing pulse that restores health to the player.",
		Color(0.3, 1.0, 0.4),
		12.0,
		5
	)

	abilities["speed_burst"] = AbilityInfo.new(
		"speed_burst",
		"Speed Burst",
		"Grants a burst of movement speed for a short duration.",
		Color(1.0, 0.6, 0.2),
		15.0,
		5
	)

	abilities["fire_trail"] = AbilityInfo.new(
		"fire_trail",
		"Fire Trail",
		"Leaves a trail of fire behind the player that damages enemies who walk through it.",
		Color(1.0, 0.3, 0.1),
		10.0,
		5
	)

	return abilities

## Returns scaled values per ability per level.
static func get_ability_stats(id: String, level: int) -> Dictionary:
	match id:
		"lightning_strike":
			return {
				"damage": 30.0 + 15.0 * (level - 1),
				"radius": 120.0 + 20.0 * (level - 1),
				"cooldown": max(3.0, 8.0 - 1.0 * (level - 1)),
			}
		"frost_nova":
			return {
				"slow_percent": 0.4 + 0.08 * (level - 1),
				"duration": 2.5 + 0.5 * (level - 1),
				"radius": 150.0 + 20.0 * (level - 1),
				"cooldown": max(5.0, 10.0 - 1.0 * (level - 1)),
			}
		"shield_bash":
			return {
				"damage": 25.0 + 12.0 * (level - 1),
				"knockback": 200.0 + 40.0 * (level - 1),
				"radius": 80.0 + 10.0 * (level - 1),
				"cooldown": max(3.0, 6.0 - 0.6 * (level - 1)),
			}
		"heal_pulse":
			return {
				"heal_amount": 20.0 + 10.0 * (level - 1),
				"cooldown": max(6.0, 12.0 - 1.2 * (level - 1)),
			}
		"speed_burst":
			return {
				"speed_mult": 1.6 + 0.1 * (level - 1),
				"duration": 3.0 + 0.5 * (level - 1),
				"cooldown": max(8.0, 15.0 - 1.4 * (level - 1)),
			}
		"fire_trail":
			return {
				"damage_per_tick": 8.0 + 4.0 * (level - 1),
				"trail_duration": 3.0 + 0.5 * (level - 1),
				"tick_rate": 0.5,
				"cooldown": max(5.0, 10.0 - 1.0 * (level - 1)),
			}
	return {}

## Returns a description line with current level stats.
static func get_level_description(id: String, level: int) -> String:
	var stats := get_ability_stats(id, level)
	match id:
		"lightning_strike":
			return "Deals %.0f damage in a %.0f radius. CD: %.1fs" % [stats.damage, stats.radius, stats.cooldown]
		"frost_nova":
			return "Slows %.0f%% for %.1fs in %.0f radius. CD: %.1fs" % [stats.slow_percent * 100, stats.duration, stats.radius, stats.cooldown]
		"shield_bash":
			return "Deals %.0f damage, knocks back %.0f. CD: %.1fs" % [stats.damage, stats.knockback, stats.cooldown]
		"heal_pulse":
			return "Heals %.0f HP. CD: %.1fs" % [stats.heal_amount, stats.cooldown]
		"speed_burst":
			return "+%.0f%% speed for %.1fs. CD: %.1fs" % [(stats.speed_mult - 1.0) * 100, stats.duration, stats.cooldown]
		"fire_trail":
			return "%.0f damage/tick for %.1fs. CD: %.1fs" % [stats.damage_per_tick, stats.trail_duration, stats.cooldown]
	return ""
