extends Node

## Meta-progression system. Autoloaded as "Meta".
## Manages Soul Essence currency earned from runs and permanent Sanctum upgrades.
## Uses a separate save file from the run-level save (SaveData).

const META_SAVE_PATH := "user://riftbound_meta.dat"

# Soul Essence — the meta-progression currency
var soul_essence: int = 0
var total_soul_essence_earned: int = 0

# Lifetime stats for Soul Essence calculation
var meta_total_kills: int = 0
var meta_worlds_cleared: int = 0
var meta_bosses_killed: int = 0
var meta_runs_completed: int = 0

# Sanctum upgrade levels (index matches SANCTUM_UPGRADES)
var sanctum_levels: Array[int] = []

# Pending Soul Essence from the current run (accumulated, awarded at run end)
var pending_essence: int = 0
var pending_kill_count: int = 0
var pending_worlds_cleared: int = 0
var pending_bosses_killed: int = 0

signal soul_essence_changed(new_amount: int)
signal sanctum_upgrade_purchased(upgrade_index: int, new_level: int)

# Sanctum upgrade definitions — purchased with Soul Essence
# These are separate from the coin-based shop upgrades in SaveData
const SANCTUM_UPGRADES: Array[Dictionary] = [
	{"key": "sanctum_max_health", "name": "Resilient Soul",
	 "desc": "+15 Max HP per level", "value": 15.0,
	 "base_cost": 30, "max_level": 10, "icon": "heart",
	 "color": Color(0.9, 0.3, 0.3)},
	{"key": "sanctum_base_damage", "name": "Soul Fury",
	 "desc": "+12% Base Damage per level", "value": 0.12,
	 "base_cost": 40, "max_level": 8, "icon": "bolt",
	 "color": Color(1.0, 0.6, 0.2)},
	{"key": "sanctum_move_speed", "name": "Phantom Stride",
	 "desc": "+6% Move Speed per level", "value": 0.06,
	 "base_cost": 35, "max_level": 8, "icon": "boot",
	 "color": Color(0.3, 0.9, 0.5)},
	{"key": "sanctum_xp_gain", "name": "Eldritch Wisdom",
	 "desc": "+10% XP Gain per level", "value": 0.10,
	 "base_cost": 25, "max_level": 10, "icon": "book",
	 "color": Color(0.3, 0.5, 1.0)},
	{"key": "sanctum_coin_magnet", "name": "Graviton Pull",
	 "desc": "+20 Coin Magnet Range per level", "value": 20.0,
	 "base_cost": 20, "max_level": 8, "icon": "magnet",
	 "color": Color(1.0, 0.85, 0.2)},
	{"key": "sanctum_starting_level", "name": "Ancient Knowledge",
	 "desc": "+1 Starting Level per level", "value": 1.0,
	 "base_cost": 80, "max_level": 5, "icon": "crown",
	 "color": Color(0.8, 0.4, 1.0)},
]

# Computed bonuses (derived from sanctum_levels)
var sanctum_max_health: float = 0.0
var sanctum_base_damage: float = 0.0
var sanctum_move_speed: float = 0.0
var sanctum_xp_gain: float = 0.0
var sanctum_coin_magnet: float = 0.0
var sanctum_starting_level: float = 0.0

func _ready() -> void:
	sanctum_levels.resize(SANCTUM_UPGRADES.size())
	sanctum_levels.fill(0)
	load_meta()

## Calculate Soul Essence earned from a run based on performance
func calculate_run_essence(kills: int, worlds_cleared: int, bosses_killed: int) -> int:
	var essence := 0
	# Base essence from kills: 1 per 5 kills
	essence += kills / 5
	# Bonus for worlds cleared: 15 per world
	essence += worlds_cleared * 15
	# Bonus for bosses killed: 25 per boss
	essence += bosses_killed * 25
	# Minimum of 1 essence if any kills happened
	if kills > 0 and essence == 0:
		essence = 1
	return essence

## Award Soul Essence at the end of a run
func award_run_essence(kills: int, worlds_cleared: int, bosses_killed: int) -> int:
	var earned := calculate_run_essence(kills, worlds_cleared, bosses_killed)
	soul_essence += earned
	total_soul_essence_earned += earned
	meta_total_kills += kills
	meta_worlds_cleared += worlds_cleared
	meta_bosses_killed += bosses_killed
	meta_runs_completed += 1
	soul_essence_changed.emit(soul_essence)
	save_meta()
	return earned

## Get the cost of a Sanctum upgrade at its current level
func get_sanctum_cost(upgrade_index: int) -> int:
	if upgrade_index < 0 or upgrade_index >= SANCTUM_UPGRADES.size():
		return 9999999
	var base: int = SANCTUM_UPGRADES[upgrade_index]["base_cost"]
	var level: int = sanctum_levels[upgrade_index]
	# Cost scales: base * (1 + level * 0.6), so each subsequent level costs more
	return int(base * (1.0 + level * 0.6))

## Check if a Sanctum upgrade can be purchased
func can_buy_sanctum(upgrade_index: int) -> bool:
	if upgrade_index < 0 or upgrade_index >= SANCTUM_UPGRADES.size():
		return false
	var max_lvl: int = SANCTUM_UPGRADES[upgrade_index]["max_level"]
	if sanctum_levels[upgrade_index] >= max_lvl:
		return false
	return soul_essence >= get_sanctum_cost(upgrade_index)

## Purchase a Sanctum upgrade
func buy_sanctum(upgrade_index: int) -> bool:
	if not can_buy_sanctum(upgrade_index):
		return false
	var cost := get_sanctum_cost(upgrade_index)
	soul_essence -= cost
	sanctum_levels[upgrade_index] += 1
	_recalculate_bonuses()
	soul_essence_changed.emit(soul_essence)
	sanctum_upgrade_purchased.emit(upgrade_index, sanctum_levels[upgrade_index])
	save_meta()
	return true

## Recalculate all bonus values from sanctum levels
func _recalculate_bonuses() -> void:
	for i in range(SANCTUM_UPGRADES.size()):
		var key: String = SANCTUM_UPGRADES[i]["key"]
		var value: float = SANCTUM_UPGRADES[i]["value"]
		var level: int = sanctum_levels[i]
		set(key, value * level)

## Get the total bonus for a specific upgrade key
func get_bonus(key: String) -> float:
	return get(key) if get(key) != null else 0.0

# --- Save / Load ---

const META_SAVE_VERSION: int = 1

func save_meta() -> void:
	var data := {
		"meta_save_version": META_SAVE_VERSION,
		"soul_essence": soul_essence,
		"total_soul_essence_earned": total_soul_essence_earned,
		"meta_total_kills": meta_total_kills,
		"meta_worlds_cleared": meta_worlds_cleared,
		"meta_bosses_killed": meta_bosses_killed,
		"meta_runs_completed": meta_runs_completed,
		"sanctum_levels": sanctum_levels,
	}
	var json_string := JSON.stringify(data)
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)

func load_meta() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH):
		return
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json_string := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return
	soul_essence = clampi(int(data.get("soul_essence", 0)), 0, 9999999)
	total_soul_essence_earned = clampi(int(data.get("total_soul_essence_earned", 0)), 0, 9999999)
	meta_total_kills = maxi(int(data.get("meta_total_kills", 0)), 0)
	meta_worlds_cleared = maxi(int(data.get("meta_worlds_cleared", 0)), 0)
	meta_bosses_killed = maxi(int(data.get("meta_bosses_killed", 0)), 0)
	meta_runs_completed = maxi(int(data.get("meta_runs_completed", 0)), 0)
	var saved_levels = data.get("sanctum_levels", [])
	if saved_levels is Array:
		for i in range(mini(saved_levels.size(), sanctum_levels.size())):
			sanctum_levels[i] = clampi(int(saved_levels[i]), 0, 20)
	_recalculate_bonuses()

func reset_meta() -> void:
	soul_essence = 0
	total_soul_essence_earned = 0
	meta_total_kills = 0
	meta_worlds_cleared = 0
	meta_bosses_killed = 0
	meta_runs_completed = 0
	sanctum_levels.fill(0)
	_recalculate_bonuses()
	save_meta()
