extends Node

## Challenge modifier system. Optional mutators that increase difficulty
## for bonus rewards. Autoloaded as "Challenges".

const MODIFIERS: Array[Dictionary] = [
	{"id": "double_hp", "name": "Ironhide", "desc": "Enemies have 2x HP",
	 "coin_bonus": 0.5, "exp_bonus": 0.3},
	{"id": "fast_enemies", "name": "Haste", "desc": "Enemies move 40% faster",
	 "coin_bonus": 0.4, "exp_bonus": 0.25},
	{"id": "no_regen", "name": "Blighted", "desc": "No health regeneration",
	 "coin_bonus": 0.3, "exp_bonus": 0.2},
	{"id": "glass_cannon", "name": "Glass Cannon", "desc": "Deal 50% more damage, take 2x damage",
	 "coin_bonus": 0.35, "exp_bonus": 0.25},
	{"id": "swarm", "name": "Swarm", "desc": "50% more enemies spawn",
	 "coin_bonus": 0.6, "exp_bonus": 0.4},
	{"id": "no_extract", "name": "Solitary", "desc": "Extraction chance halved",
	 "coin_bonus": 0.4, "exp_bonus": 0.3},
	{"id": "elite_bosses", "name": "Tyrant", "desc": "Bosses have 3x HP and faster attacks",
	 "coin_bonus": 0.5, "exp_bonus": 0.35},
	{"id": "fog_of_war", "name": "Fog of War", "desc": "Minimap disabled",
	 "coin_bonus": 0.15, "exp_bonus": 0.1},
]

func get_modifier(id: String) -> Dictionary:
	for mod in MODIFIERS:
		if mod["id"] == id:
			return mod
	return {}

func is_active(id: String) -> bool:
	return id in SaveData.active_challenges

func toggle(id: String) -> void:
	if id in SaveData.active_challenges:
		SaveData.active_challenges.erase(id)
	else:
		SaveData.active_challenges.append(id)
	SaveData.save_game()

func get_active_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in SaveData.active_challenges:
		var mod := get_modifier(id)
		if not mod.is_empty():
			result.append(mod)
	return result

func get_total_coin_bonus() -> float:
	var bonus := 0.0
	for mod in get_active_modifiers():
		bonus += mod["coin_bonus"]
	return bonus

func get_total_exp_bonus() -> float:
	var bonus := 0.0
	for mod in get_active_modifiers():
		bonus += mod["exp_bonus"]
	return bonus

## Get enemy HP multiplier from active challenges
func get_enemy_hp_mult() -> float:
	return 2.0 if is_active("double_hp") else 1.0

## Get enemy speed multiplier from active challenges
func get_enemy_speed_mult() -> float:
	return 1.4 if is_active("fast_enemies") else 1.0

## Get enemy count multiplier from active challenges
func get_enemy_count_mult() -> float:
	return 1.5 if is_active("swarm") else 1.0

## Get player damage dealt multiplier
func get_player_damage_mult() -> float:
	return 1.5 if is_active("glass_cannon") else 1.0

## Get player damage taken multiplier
func get_player_damage_taken_mult() -> float:
	return 2.0 if is_active("glass_cannon") else 1.0

## Whether health regen is disabled
func is_regen_disabled() -> bool:
	return is_active("no_regen")

## Get extraction chance multiplier
func get_extraction_mult() -> float:
	return 0.5 if is_active("no_extract") else 1.0

## Get boss HP multiplier from challenges
func get_boss_hp_mult() -> float:
	return 3.0 if is_active("elite_bosses") else 1.0

## Whether minimap should be hidden
func is_minimap_disabled() -> bool:
	return is_active("fog_of_war")

func get_active_count() -> int:
	return SaveData.active_challenges.size()
