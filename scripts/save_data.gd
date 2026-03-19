extends Node

## Persistent save system. Autoloaded as "SaveData".
## Tracks coins, EXP, level, permanent upgrades between runs.

const SAVE_PATH := "user://riftbound_save.dat"

# Persistent currency
var coins: int = 0
var exp_points: int = 0
var player_level: int = 1
var exp_to_next_level: int = 100

# World progression
var highest_world_unlocked: int = 0
var worlds_completed: Array[int] = []
var total_runs: int = 0
var total_kills: int = 0
var total_bosses_killed: int = 0

# Permanent upgrades (bought with coins in shop)
var perm_max_health: float = 0.0       # bonus HP
var perm_attack_mult: float = 0.0      # bonus attack %
var perm_speed_mult: float = 0.0       # bonus move speed %
var perm_thrall_damage: float = 0.0    # bonus thrall damage %
var perm_extraction_bonus: float = 0.0 # bonus extraction chance
var perm_dash_cooldown: float = 0.0    # dash cooldown reduction
var perm_regen: float = 0.0            # bonus HP regen
var perm_coin_mult: float = 0.0        # bonus coin gain %
var perm_exp_mult: float = 0.0         # bonus exp gain %
var perm_thrall_health: float = 0.0    # bonus thrall health

# Shop upgrade definitions — cost scales with level
const SHOP_UPGRADES: Array[Dictionary] = [
	{"key": "perm_max_health", "name": "Vitality", "desc": "+20 Max HP", "value": 20.0,
	 "base_cost": 50, "max_level": 10, "level": 0},
	{"key": "perm_attack_mult", "name": "Soul Power", "desc": "+10% Attack", "value": 0.10,
	 "base_cost": 75, "max_level": 10, "level": 0},
	{"key": "perm_speed_mult", "name": "Swiftness", "desc": "+8% Speed", "value": 0.08,
	 "base_cost": 60, "max_level": 8, "level": 0},
	{"key": "perm_thrall_damage", "name": "Dark Command", "desc": "+10% Thrall Dmg", "value": 0.10,
	 "base_cost": 80, "max_level": 10, "level": 0},
	{"key": "perm_extraction_bonus", "name": "Soul Harvest", "desc": "+5% Extraction", "value": 0.05,
	 "base_cost": 100, "max_level": 6, "level": 0},
	{"key": "perm_dash_cooldown", "name": "Shadow Step", "desc": "-0.1s Dash CD", "value": 0.1,
	 "base_cost": 90, "max_level": 5, "level": 0},
	{"key": "perm_regen", "name": "Undying", "desc": "+0.5 HP/sec", "value": 0.5,
	 "base_cost": 120, "max_level": 6, "level": 0},
	{"key": "perm_coin_mult", "name": "Greed", "desc": "+15% Coins", "value": 0.15,
	 "base_cost": 60, "max_level": 5, "level": 0},
	{"key": "perm_exp_mult", "name": "Wisdom", "desc": "+15% EXP", "value": 0.15,
	 "base_cost": 60, "max_level": 5, "level": 0},
	{"key": "perm_thrall_health", "name": "Bone Armor", "desc": "+10 Thrall HP", "value": 10.0,
	 "base_cost": 70, "max_level": 8, "level": 0},
]

var shop_levels: Array[int] = []

signal coins_changed(new_amount: int)
signal exp_changed(new_exp: int, level: int, to_next: int)

func _ready() -> void:
	shop_levels.resize(SHOP_UPGRADES.size())
	shop_levels.fill(0)
	load_game()

func add_coins(amount: int) -> void:
	var effective := int(amount * (1.0 + perm_coin_mult))
	coins += effective
	coins_changed.emit(coins)

func add_exp(amount: int) -> void:
	var effective := int(amount * (1.0 + perm_exp_mult))
	exp_points += effective
	while exp_points >= exp_to_next_level:
		exp_points -= exp_to_next_level
		player_level += 1
		exp_to_next_level = _calc_exp_for_level(player_level)
	exp_changed.emit(exp_points, player_level, exp_to_next_level)

func _calc_exp_for_level(level: int) -> int:
	return 100 + (level - 1) * 50

func get_upgrade_cost(upgrade_index: int) -> int:
	var base: int = SHOP_UPGRADES[upgrade_index]["base_cost"]
	var level: int = shop_levels[upgrade_index]
	return int(base * (1.0 + level * 0.5))

func can_buy_upgrade(upgrade_index: int) -> bool:
	if upgrade_index < 0 or upgrade_index >= SHOP_UPGRADES.size():
		return false
	var max_lvl: int = SHOP_UPGRADES[upgrade_index]["max_level"]
	if shop_levels[upgrade_index] >= max_lvl:
		return false
	return coins >= get_upgrade_cost(upgrade_index)

func buy_upgrade(upgrade_index: int) -> bool:
	if not can_buy_upgrade(upgrade_index):
		return false
	var cost := get_upgrade_cost(upgrade_index)
	coins -= cost
	shop_levels[upgrade_index] += 1
	var key: String = SHOP_UPGRADES[upgrade_index]["key"]
	var value: float = SHOP_UPGRADES[upgrade_index]["value"]
	set(key, get(key) + value)
	coins_changed.emit(coins)
	save_game()
	return true

func complete_world(world_id: int) -> void:
	if world_id not in worlds_completed:
		worlds_completed.append(world_id)
	if world_id + 1 > highest_world_unlocked:
		highest_world_unlocked = world_id + 1

func save_game() -> void:
	var data := {
		"coins": coins,
		"exp_points": exp_points,
		"player_level": player_level,
		"exp_to_next_level": exp_to_next_level,
		"highest_world_unlocked": highest_world_unlocked,
		"worlds_completed": worlds_completed,
		"total_runs": total_runs,
		"total_kills": total_kills,
		"total_bosses_killed": total_bosses_killed,
		"shop_levels": shop_levels,
		"perm_max_health": perm_max_health,
		"perm_attack_mult": perm_attack_mult,
		"perm_speed_mult": perm_speed_mult,
		"perm_thrall_damage": perm_thrall_damage,
		"perm_extraction_bonus": perm_extraction_bonus,
		"perm_dash_cooldown": perm_dash_cooldown,
		"perm_regen": perm_regen,
		"perm_coin_mult": perm_coin_mult,
		"perm_exp_mult": perm_exp_mult,
		"perm_thrall_health": perm_thrall_health,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = file.get_var()
	if data is not Dictionary:
		return
	coins = data.get("coins", 0)
	exp_points = data.get("exp_points", 0)
	player_level = data.get("player_level", 1)
	exp_to_next_level = data.get("exp_to_next_level", 100)
	highest_world_unlocked = data.get("highest_world_unlocked", 0)
	total_runs = data.get("total_runs", 0)
	total_kills = data.get("total_kills", 0)
	total_bosses_killed = data.get("total_bosses_killed", 0)
	var saved_levels = data.get("shop_levels", [])
	for i in range(min(saved_levels.size(), shop_levels.size())):
		shop_levels[i] = saved_levels[i]
	var wc = data.get("worlds_completed", [])
	worlds_completed = []
	for w in wc:
		worlds_completed.append(int(w))
	perm_max_health = data.get("perm_max_health", 0.0)
	perm_attack_mult = data.get("perm_attack_mult", 0.0)
	perm_speed_mult = data.get("perm_speed_mult", 0.0)
	perm_thrall_damage = data.get("perm_thrall_damage", 0.0)
	perm_extraction_bonus = data.get("perm_extraction_bonus", 0.0)
	perm_dash_cooldown = data.get("perm_dash_cooldown", 0.0)
	perm_regen = data.get("perm_regen", 0.0)
	perm_coin_mult = data.get("perm_coin_mult", 0.0)
	perm_exp_mult = data.get("perm_exp_mult", 0.0)
	perm_thrall_health = data.get("perm_thrall_health", 0.0)

func reset_save() -> void:
	coins = 0
	exp_points = 0
	player_level = 1
	exp_to_next_level = 100
	highest_world_unlocked = 0
	worlds_completed = []
	total_runs = 0
	total_kills = 0
	total_bosses_killed = 0
	shop_levels.fill(0)
	perm_max_health = 0.0
	perm_attack_mult = 0.0
	perm_speed_mult = 0.0
	perm_thrall_damage = 0.0
	perm_extraction_bonus = 0.0
	perm_dash_cooldown = 0.0
	perm_regen = 0.0
	perm_coin_mult = 0.0
	perm_exp_mult = 0.0
	perm_thrall_health = 0.0
	save_game()
