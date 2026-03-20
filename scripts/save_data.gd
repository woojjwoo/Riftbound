extends Node

## Persistent save system. Autoloaded as "SaveData".
## Tracks coins, EXP, level, permanent upgrades between runs.

const SAVE_PATH := "user://riftbound_save.dat"
const SAVE_VERSION: int = 2  # Increment when save format changes

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

# Equipment inventory — 6 slots, one per Equipment.Slot
# Each is a Dictionary or empty {} if no equipment in that slot
var equipped: Array[Dictionary] = [{}, {}, {}, {}, {}, {}]
# Equipment inventory (unequipped items waiting to be used)
var inventory: Array[Dictionary] = []
const MAX_INVENTORY: int = 30
# Track which world transition stories have been seen
var stories_seen: Array[int] = []
# Cached achievement data — loaded before AchievementManager is ready
var _cached_achievements: Dictionary = {}

# Audio volume settings (linear 0.0–1.0)
var audio_master_volume: float = 0.8
var audio_sfx_volume: float = 0.8
var audio_music_volume: float = 0.6

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
signal equipment_changed
signal level_up(new_level: int)

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
	var old_level := player_level
	while exp_points >= exp_to_next_level:
		exp_points -= exp_to_next_level
		player_level += 1
		exp_to_next_level = _calc_exp_for_level(player_level)
	if player_level > old_level:
		level_up.emit(player_level)
		Audio.play_level_up()
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

## Equip an item from inventory to a slot. Returns the old item (or {} if empty).
func equip_item(item: Dictionary) -> Dictionary:
	var slot: int = item["slot"]
	var old := equipped[slot]
	equipped[slot] = item
	# Remove from inventory if present
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
	# Put old item in inventory
	if not old.is_empty():
		if inventory.size() < MAX_INVENTORY:
			inventory.append(old)
	equipment_changed.emit()
	save_game()
	return old

## Add an equipment drop to inventory. Returns false if full.
func add_to_inventory(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		return false
	inventory.append(item)
	equipment_changed.emit()
	return true

## Auto-equip if better than current slot, otherwise add to inventory
func try_auto_equip(item: Dictionary) -> String:
	var slot: int = item["slot"]
	var current := equipped[slot]
	if current.is_empty():
		equipped[slot] = item
		equipment_changed.emit()
		save_game()
		return "equipped"
	# Compare: higher rarity or higher level wins
	var item_power := item["rarity"] * 100 + item["level"]
	var current_power := current["rarity"] * 100 + current["level"]
	if item_power > current_power:
		inventory.append(current)
		equipped[slot] = item
		equipment_changed.emit()
		save_game()
		return "upgraded"
	else:
		if inventory.size() < MAX_INVENTORY:
			inventory.append(item)
			equipment_changed.emit()
			return "inventory"
		return "full"

## Get total equipment stat bonus for a given slot
func get_equip_bonus(slot: int) -> float:
	var item := equipped[slot]
	if item.is_empty():
		return 0.0
	return Equipment.get_stat_bonus(item)

## Check if a world transition story has been seen
func has_seen_story(world_id: int) -> bool:
	return world_id in stories_seen

## Mark a world transition story as seen
func mark_story_seen(world_id: int) -> void:
	if world_id not in stories_seen:
		stories_seen.append(world_id)
		save_game()

func complete_world(world_id: int) -> void:
	if world_id not in worlds_completed:
		worlds_completed.append(world_id)
	if world_id + 1 > highest_world_unlocked:
		highest_world_unlocked = world_id + 1

func save_game() -> void:
	var data := {
		"save_version": SAVE_VERSION,
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
		"equipped": _serialize_equipment(equipped),
		"inventory": _serialize_equipment(inventory),
		"stories_seen": stories_seen,
		"audio_master_volume": audio_master_volume,
		"audio_sfx_volume": audio_sfx_volume,
		"audio_music_volume": audio_music_volume,
		"achievements": _get_achievements_data(),
	}
	var json_string := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json_string := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return

	# Migrate old save formats
	var version := int(data.get("save_version", 1))
	if version < 2:
		_migrate_v1_to_v2(data)

	coins = clampi(int(data.get("coins", 0)), 0, 9999999)
	exp_points = clampi(int(data.get("exp_points", 0)), 0, 9999999)
	player_level = clampi(int(data.get("player_level", 1)), 1, 999)
	exp_to_next_level = clampi(int(data.get("exp_to_next_level", 100)), 100, 99999)
	highest_world_unlocked = clampi(int(data.get("highest_world_unlocked", 0)), 0, 10)
	total_runs = maxi(int(data.get("total_runs", 0)), 0)
	total_kills = maxi(int(data.get("total_kills", 0)), 0)
	total_bosses_killed = maxi(int(data.get("total_bosses_killed", 0)), 0)
	var saved_levels = data.get("shop_levels", [])
	if saved_levels is Array:
		for i in range(mini(saved_levels.size(), shop_levels.size())):
			shop_levels[i] = clampi(int(saved_levels[i]), 0, 20)
	var wc = data.get("worlds_completed", [])
	worlds_completed = []
	if wc is Array:
		for w in wc:
			worlds_completed.append(clampi(int(w), 0, 10))
	perm_max_health = clampf(float(data.get("perm_max_health", 0.0)), 0.0, 500.0)
	perm_attack_mult = clampf(float(data.get("perm_attack_mult", 0.0)), 0.0, 5.0)
	perm_speed_mult = clampf(float(data.get("perm_speed_mult", 0.0)), 0.0, 3.0)
	perm_thrall_damage = clampf(float(data.get("perm_thrall_damage", 0.0)), 0.0, 5.0)
	perm_extraction_bonus = clampf(float(data.get("perm_extraction_bonus", 0.0)), 0.0, 1.0)
	perm_dash_cooldown = clampf(float(data.get("perm_dash_cooldown", 0.0)), 0.0, 2.0)
	perm_regen = clampf(float(data.get("perm_regen", 0.0)), 0.0, 20.0)
	perm_coin_mult = clampf(float(data.get("perm_coin_mult", 0.0)), 0.0, 5.0)
	perm_exp_mult = clampf(float(data.get("perm_exp_mult", 0.0)), 0.0, 5.0)
	perm_thrall_health = clampf(float(data.get("perm_thrall_health", 0.0)), 0.0, 200.0)
	# Equipment
	var saved_equipped = data.get("equipped", [])
	equipped = [{}, {}, {}, {}, {}, {}]
	if saved_equipped is Array:
		for i in range(mini(saved_equipped.size(), 6)):
			if saved_equipped[i] is Dictionary and not saved_equipped[i].is_empty():
				equipped[i] = Equipment.dict_to_equip(saved_equipped[i])
	var saved_inventory = data.get("inventory", [])
	inventory = []
	if saved_inventory is Array:
		for item in saved_inventory:
			if item is Dictionary and not item.is_empty():
				inventory.append(Equipment.dict_to_equip(item))
	var saved_stories = data.get("stories_seen", [])
	stories_seen = []
	if saved_stories is Array:
		for s in saved_stories:
			stories_seen.append(clampi(int(s), 0, 20))
	# Audio volume settings
	audio_master_volume = clampf(float(data.get("audio_master_volume", 0.8)), 0.0, 1.0)
	audio_sfx_volume = clampf(float(data.get("audio_sfx_volume", 0.8)), 0.0, 1.0)
	audio_music_volume = clampf(float(data.get("audio_music_volume", 0.6)), 0.0, 1.0)
	# Achievements — stored for AchievementManager to load on its own _ready
	var saved_achievements = data.get("achievements", {})
	if saved_achievements is Dictionary:
		_cached_achievements = saved_achievements

## Migrate saves from version 1 (pre-audio/achievements) to version 2
func _migrate_v1_to_v2(data: Dictionary) -> void:
	# v1 saves may be missing audio volumes and achievements
	if not data.has("audio_master_volume"):
		data["audio_master_volume"] = 0.8
	if not data.has("audio_sfx_volume"):
		data["audio_sfx_volume"] = 0.8
	if not data.has("audio_music_volume"):
		data["audio_music_volume"] = 0.6
	if not data.has("achievements"):
		data["achievements"] = {}
	if not data.has("total_bosses_killed"):
		data["total_bosses_killed"] = 0
	if not data.has("stories_seen"):
		data["stories_seen"] = []
	# Ensure shop_levels has enough entries for new upgrades
	var shop_levels_data = data.get("shop_levels", [])
	if shop_levels_data is Array:
		while shop_levels_data.size() < SHOP_UPGRADES.size():
			shop_levels_data.append(0)
		data["shop_levels"] = shop_levels_data
	data["save_version"] = 2

func _get_achievements_data() -> Dictionary:
	var node := get_node_or_null("/root/Achievements")
	if node and node.has_method("save_to_dict"):
		return node.save_to_dict()
	return _cached_achievements

func _serialize_equipment(items: Array) -> Array:
	var result := []
	for item in items:
		if item is Dictionary and not item.is_empty():
			result.append(Equipment.equip_to_dict(item))
		else:
			result.append({})
	return result

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
	equipped = [{}, {}, {}, {}, {}, {}]
	inventory = []
	stories_seen = []
	audio_master_volume = 0.8
	audio_sfx_volume = 0.8
	audio_music_volume = 0.6
	var ach_node := get_node_or_null("/root/Achievements")
	if ach_node:
		ach_node.unlocked = {}
	_cached_achievements = {}
	save_game()
