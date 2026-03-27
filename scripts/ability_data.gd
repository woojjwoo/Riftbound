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

	abilities["bone_shield"] = AbilityInfo.new(
		"bone_shield",
		"Bone Shield",
		"Surrounds the player with orbiting bone fragments that absorb incoming damage.",
		Color(0.85, 0.8, 0.7),
		14.0,
		5
	)

	abilities["soul_link"] = AbilityInfo.new(
		"soul_link",
		"Soul Link",
		"Links the player to nearby thralls, sharing damage taken and boosting their attack.",
		Color(0.6, 0.3, 1.0),
		16.0,
		5
	)

	abilities["death_coil"] = AbilityInfo.new(
		"death_coil",
		"Death Coil",
		"Fires a homing coil of dark energy that damages enemies and heals on hit.",
		Color(0.4, 0.1, 0.6),
		7.0,
		5
	)

	abilities["corpse_explosion"] = AbilityInfo.new(
		"corpse_explosion",
		"Corpse Explosion",
		"Detonates nearby enemy corpses, dealing massive area damage.",
		Color(0.7, 0.2, 0.1),
		9.0,
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
		"bone_shield":
			return {
				"charges": 3 + level,
				"absorb_per_charge": 10.0 + 5.0 * (level - 1),
				"duration": 8.0 + 1.0 * (level - 1),
				"cooldown": max(8.0, 14.0 - 1.2 * (level - 1)),
			}
		"soul_link":
			return {
				"damage_share": 0.25 + 0.05 * (level - 1),
				"thrall_damage_boost": 0.15 + 0.05 * (level - 1),
				"duration": 5.0 + 1.0 * (level - 1),
				"radius": 150.0 + 20.0 * (level - 1),
				"cooldown": max(8.0, 16.0 - 1.6 * (level - 1)),
			}
		"death_coil":
			return {
				"damage": 25.0 + 12.0 * (level - 1),
				"heal_percent": 0.3 + 0.05 * (level - 1),
				"projectile_speed": 250.0,
				"cooldown": max(3.0, 7.0 - 0.8 * (level - 1)),
			}
		"corpse_explosion":
			return {
				"damage_per_corpse": 40.0 + 20.0 * (level - 1),
				"radius": 80.0 + 15.0 * (level - 1),
				"max_corpses": 3 + level,
				"cooldown": max(4.0, 9.0 - 1.0 * (level - 1)),
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
		"bone_shield":
			return "%d charges, absorbs %.0f each for %.0fs. CD: %.1fs" % [stats.charges, stats.absorb_per_charge, stats.duration, stats.cooldown]
		"soul_link":
			return "Share %.0f%% damage, thralls +%.0f%% DMG for %.0fs. CD: %.1fs" % [stats.damage_share * 100, stats.thrall_damage_boost * 100, stats.duration, stats.cooldown]
		"death_coil":
			return "%.0f damage, heals %.0f%%. CD: %.1fs" % [stats.damage, stats.heal_percent * 100, stats.cooldown]
		"corpse_explosion":
			return "%.0f per corpse in %.0f radius (max %d). CD: %.1fs" % [stats.damage_per_corpse, stats.radius, stats.max_corpses, stats.cooldown]
	return ""
