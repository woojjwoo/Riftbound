extends Node

## Passive skill tree system. Autoloaded as "SkillTree".
## Three paths: Necromancy, Combat, Survival. Each has 5 skills.
## Skills cost Soul Essence and provide permanent passive bonuses.
## Saved alongside Meta progression data.

signal skill_unlocked(path_index: int, skill_index: int)

enum Path { NECROMANCY, COMBAT, SURVIVAL }

## Skill definitions: 3 paths x 5 skills each. Skills must be unlocked in order.
const PATHS: Array[Dictionary] = [
	{"name": "Necromancy", "color": Color(0.6, 0.2, 0.9),
	 "desc": "Empower your thralls and extraction",
	 "skills": [
		{"name": "Soul Harvest", "desc": "+10% Extraction Chance",
		 "key": "extraction_chance", "value": 0.10, "cost": 20},
		{"name": "Dark Pact", "desc": "+15% Thrall Damage",
		 "key": "thrall_damage", "value": 0.15, "cost": 35},
		{"name": "Undying Will", "desc": "+25% Thrall HP",
		 "key": "thrall_hp", "value": 0.25, "cost": 50},
		{"name": "Mass Raising", "desc": "+1 Max Thrall Count",
		 "key": "max_thralls", "value": 1.0, "cost": 75},
		{"name": "Lich's Command", "desc": "Thralls gain +20% Speed",
		 "key": "thrall_speed", "value": 0.20, "cost": 100},
	]},
	{"name": "Combat", "color": Color(1.0, 0.4, 0.2),
	 "desc": "Increase your offensive power",
	 "skills": [
		{"name": "Soul Bolt Mastery", "desc": "+15% Soul Bolt Damage",
		 "key": "bolt_damage", "value": 0.15, "cost": 20},
		{"name": "Rapid Channeling", "desc": "+10% Attack Speed",
		 "key": "attack_speed", "value": 0.10, "cost": 35},
		{"name": "Piercing Souls", "desc": "+1 Soul Bolt Pierce",
		 "key": "bolt_pierce", "value": 1.0, "cost": 50},
		{"name": "Critical Strike", "desc": "+8% Crit Chance",
		 "key": "crit_chance", "value": 0.08, "cost": 75},
		{"name": "Annihilation", "desc": "+25% Damage to Elites/Bosses",
		 "key": "elite_damage", "value": 0.25, "cost": 100},
	]},
	{"name": "Survival", "color": Color(0.3, 0.9, 0.4),
	 "desc": "Improve your durability and utility",
	 "skills": [
		{"name": "Thick Skin", "desc": "+20 Max HP",
		 "key": "max_hp", "value": 20.0, "cost": 20},
		{"name": "Fleet Foot", "desc": "+8% Move Speed",
		 "key": "move_speed", "value": 0.08, "cost": 35},
		{"name": "Soul Shield", "desc": "+10% Damage Reduction",
		 "key": "damage_reduction", "value": 0.10, "cost": 50},
		{"name": "Coin Sense", "desc": "+20% Coin Drops",
		 "key": "coin_bonus", "value": 0.20, "cost": 75},
		{"name": "Second Wind", "desc": "+1 HP Regen per second",
		 "key": "hp_regen", "value": 1.0, "cost": 100},
	]},
]

## Unlocked skills: path_index -> array of unlocked skill indices
var unlocked: Array[Array] = [[], [], []]

## Computed bonuses (recalculated on load/unlock)
var bonus_extraction_chance: float = 0.0
var bonus_thrall_damage: float = 0.0
var bonus_thrall_hp: float = 0.0
var bonus_max_thralls: float = 0.0
var bonus_thrall_speed: float = 0.0
var bonus_bolt_damage: float = 0.0
var bonus_attack_speed: float = 0.0
var bonus_bolt_pierce: float = 0.0
var bonus_crit_chance: float = 0.0
var bonus_elite_damage: float = 0.0
var bonus_max_hp: float = 0.0
var bonus_move_speed: float = 0.0
var bonus_damage_reduction: float = 0.0
var bonus_coin_bonus: float = 0.0
var bonus_hp_regen: float = 0.0

func _ready() -> void:
	_load_skills()

## Get the next unlockable skill index for a path (-1 if all unlocked)
func get_next_skill(path_index: int) -> int:
	var count: int = unlocked[path_index].size()
	var total: int = PATHS[path_index]["skills"].size()
	if count >= total:
		return -1
	return count

## Check if a skill can be purchased
func can_unlock(path_index: int, skill_index: int) -> bool:
	if path_index < 0 or path_index >= PATHS.size():
		return false
	var skills: Array = PATHS[path_index]["skills"]
	if skill_index < 0 or skill_index >= skills.size():
		return false
	# Must unlock in order
	if skill_index != unlocked[path_index].size():
		return false
	var cost: int = skills[skill_index]["cost"]
	return Meta.soul_essence >= cost

## Purchase a skill
func unlock_skill(path_index: int, skill_index: int) -> bool:
	if not can_unlock(path_index, skill_index):
		return false
	var skills: Array = PATHS[path_index]["skills"]
	var cost: int = skills[skill_index]["cost"]
	Meta.soul_essence -= cost
	unlocked[path_index].append(skill_index)
	_recalculate_bonuses()
	skill_unlocked.emit(path_index, skill_index)
	Meta.soul_essence_changed.emit(Meta.soul_essence)
	_save_skills()
	Meta.save_meta()
	return true

## Check if a specific skill is unlocked
func is_unlocked(path_index: int, skill_index: int) -> bool:
	return skill_index in unlocked[path_index]

## Get total skills unlocked across all paths
func get_total_unlocked() -> int:
	var total := 0
	for path in unlocked:
		total += path.size()
	return total

## Recalculate all bonuses from unlocked skills
func _recalculate_bonuses() -> void:
	# Reset all
	bonus_extraction_chance = 0.0
	bonus_thrall_damage = 0.0
	bonus_thrall_hp = 0.0
	bonus_max_thralls = 0.0
	bonus_thrall_speed = 0.0
	bonus_bolt_damage = 0.0
	bonus_attack_speed = 0.0
	bonus_bolt_pierce = 0.0
	bonus_crit_chance = 0.0
	bonus_elite_damage = 0.0
	bonus_max_hp = 0.0
	bonus_move_speed = 0.0
	bonus_damage_reduction = 0.0
	bonus_coin_bonus = 0.0
	bonus_hp_regen = 0.0

	for path_idx in range(PATHS.size()):
		var skills: Array = PATHS[path_idx]["skills"]
		for skill_idx in unlocked[path_idx]:
			if skill_idx >= 0 and skill_idx < skills.size():
				var skill: Dictionary = skills[skill_idx]
				var key: String = skill["key"]
				var bonus_key := "bonus_" + key
				var current: float = get(bonus_key)
				if current != null:
					set(bonus_key, current + skill["value"])

## Save skill tree data to meta save
func _save_skills() -> void:
	var data: Array[Array] = []
	for path in unlocked:
		data.append(path.duplicate())
	# Store in meta save file alongside other meta data
	var file := FileAccess.open("user://riftbound_skills.dat", FileAccess.WRITE)
	if file:
		var save_data := {"unlocked": data}
		file.store_string(JSON.stringify(save_data))

## Load skill tree data
func _load_skills() -> void:
	unlocked = [[], [], []]
	if not FileAccess.file_exists("user://riftbound_skills.dat"):
		return
	var file := FileAccess.open("user://riftbound_skills.dat", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return
	var saved = data.get("unlocked", [])
	if saved is Array:
		for i in range(mini(saved.size(), 3)):
			if saved[i] is Array:
				for idx in saved[i]:
					unlocked[i].append(int(idx))
	_recalculate_bonuses()

## Reset all skills (refunds essence)
func reset_skills() -> void:
	var refund := 0
	for path_idx in range(PATHS.size()):
		var skills: Array = PATHS[path_idx]["skills"]
		for skill_idx in unlocked[path_idx]:
			if skill_idx >= 0 and skill_idx < skills.size():
				refund += skills[skill_idx]["cost"]
	Meta.soul_essence += refund
	unlocked = [[], [], []]
	_recalculate_bonuses()
	_save_skills()
	Meta.save_meta()
