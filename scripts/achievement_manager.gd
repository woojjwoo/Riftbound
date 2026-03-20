extends Node

## Achievement tracking and notification system. Autoloaded as "Achievements".
## Listens to game signals and SaveData to unlock achievements.
## Persists unlocked achievements through SaveData.

signal achievement_unlocked(achievement_id: String)

## Achievement definition: id, name, description, icon symbol, category
const ACHIEVEMENT_DEFS: Array[Dictionary] = [
	# Kill milestones
	{"id": "first_kill", "name": "First Blood",
	 "desc": "Slay your first enemy.", "icon": "X", "category": "combat"},
	{"id": "kill_100", "name": "Centurion",
	 "desc": "Slay 100 enemies across all runs.", "icon": "XX", "category": "combat"},
	{"id": "kill_500", "name": "Slaughter",
	 "desc": "Slay 500 enemies across all runs.", "icon": "XXX", "category": "combat"},
	{"id": "kill_1000", "name": "Reaper",
	 "desc": "Slay 1000 enemies across all runs.", "icon": "XXXX", "category": "combat"},
	# Boss achievements
	{"id": "first_boss", "name": "Guardian Slayer",
	 "desc": "Defeat your first boss.", "icon": "B", "category": "combat"},
	{"id": "boss_speed_kill", "name": "Overwhelming Power",
	 "desc": "Defeat a boss in under 30 seconds.", "icon": "BZ", "category": "combat"},
	# World progression
	{"id": "clear_world_1", "name": "Dark Realm Sealed",
	 "desc": "Clear World 1: The Dark Realm.", "icon": "W1", "category": "progression"},
	{"id": "clear_world_2", "name": "Sands Conquered",
	 "desc": "Clear World 2: Scorched Sands.", "icon": "W2", "category": "progression"},
	{"id": "clear_world_3", "name": "Frost Shattered",
	 "desc": "Clear World 3: Frozen Wastes.", "icon": "W3", "category": "progression"},
	# Level milestones
	{"id": "reach_level_10", "name": "Apprentice",
	 "desc": "Reach player level 10.", "icon": "L10", "category": "progression"},
	{"id": "reach_level_25", "name": "Adept",
	 "desc": "Reach player level 25.", "icon": "L25", "category": "progression"},
	{"id": "reach_level_50", "name": "Master Necromancer",
	 "desc": "Reach player level 50.", "icon": "L50", "category": "progression"},
	# Economy
	{"id": "collect_500_coins", "name": "Hoarder",
	 "desc": "Accumulate 500 coins.", "icon": "$", "category": "economy"},
	# Equipment
	{"id": "equip_first_item", "name": "Geared Up",
	 "desc": "Equip your first piece of equipment.", "icon": "E", "category": "economy"},
	# Survival
	{"id": "survive_5_min", "name": "Endurance",
	 "desc": "Survive for 5 minutes in a single run.", "icon": "T5", "category": "survival"},
	{"id": "survive_10_min", "name": "Tenacity",
	 "desc": "Survive for 10 minutes in a single run.", "icon": "T10", "category": "survival"},
	{"id": "survive_15_min", "name": "Undying Will",
	 "desc": "Survive for 15 minutes in a single run.", "icon": "T15", "category": "survival"},
	# Death
	{"id": "first_death", "name": "Mortality",
	 "desc": "Die for the first time.", "icon": "D", "category": "misc"},
	# Thralls
	{"id": "raise_10_thralls", "name": "Army of the Dead",
	 "desc": "Have 10 thralls at once in a single run.", "icon": "A", "category": "combat"},
]

## Map of id -> definition for fast lookup
var _defs: Dictionary = {}

## Set of unlocked achievement ids
var unlocked: Dictionary = {}

## Queue of achievements to display (id strings)
var _notification_queue: Array[String] = []

## Boss fight timer — tracks duration from boss spawn to boss kill
var _boss_fight_start: float = 0.0
var _boss_fight_active: bool = false

## Run timer — tracks survival time in current run
var _run_time: float = 0.0
var _run_active: bool = false

var AchievementNotification: GDScript = preload("res://scripts/achievement_notification.gd")

func _ready() -> void:
	# Build lookup map
	for def in ACHIEVEMENT_DEFS:
		_defs[def["id"]] = def

	# Spawn notification overlay (persists across scenes as child of autoload)
	var notif := CanvasLayer.new()
	notif.set_script(AchievementNotification)
	add_child(notif)

	# Connect to game signals
	Game.enemy_killed.connect(_on_enemy_killed)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)
	Game.process_changed.connect(_on_process_changed)

	# Connect to save data signals
	SaveData.coins_changed.connect(_on_coins_changed)
	SaveData.exp_changed.connect(_on_exp_changed)
	SaveData.equipment_changed.connect(_on_equipment_changed)

	# Load cached achievement data from SaveData (loaded before this autoload)
	if not SaveData._cached_achievements.is_empty():
		load_from_dict(SaveData._cached_achievements)

func _process(delta: float) -> void:
	if _run_active and not Game.is_game_over:
		_run_time += delta
		# Check survival milestones
		if _run_time >= 300.0:  # 5 minutes
			try_unlock("survive_5_min")
		if _run_time >= 600.0:  # 10 minutes
			try_unlock("survive_10_min")
		if _run_time >= 900.0:  # 15 minutes
			try_unlock("survive_15_min")

## Try to unlock an achievement. Returns true if newly unlocked.
func try_unlock(achievement_id: String) -> bool:
	if achievement_id in unlocked:
		return false
	if achievement_id not in _defs:
		return false
	unlocked[achievement_id] = true
	_notification_queue.append(achievement_id)
	achievement_unlocked.emit(achievement_id)
	_save_achievements()
	return true

## Check if an achievement is unlocked
func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked

## Get the definition for an achievement
func get_def(achievement_id: String) -> Dictionary:
	return _defs.get(achievement_id, {})

## Get all achievement definitions
func get_all_defs() -> Array[Dictionary]:
	return ACHIEVEMENT_DEFS

## Get count of unlocked achievements
func get_unlocked_count() -> int:
	return unlocked.size()

## Get total achievement count
func get_total_count() -> int:
	return ACHIEVEMENT_DEFS.size()

## Pop the next notification from the queue (returns "" if empty)
func pop_notification() -> String:
	if _notification_queue.is_empty():
		return ""
	return _notification_queue.pop_front()

## Reset run timer — called when a new run starts
func reset_run_timer() -> void:
	_run_time = 0.0
	_run_active = true
	_boss_fight_active = false

# --- Signal handlers ---

func _on_enemy_killed() -> void:
	# First kill (in this run)
	if Game.kill_count == 1:
		try_unlock("first_kill")
	# Cumulative kill milestones (total_kills includes current run's kills at save time)
	var total := SaveData.total_kills + Game.kill_count
	if total >= 100:
		try_unlock("kill_100")
	if total >= 500:
		try_unlock("kill_500")
	if total >= 1000:
		try_unlock("kill_1000")

func _on_game_over() -> void:
	_run_active = false
	try_unlock("first_death")

func _on_thrall_gained() -> void:
	if Game.thrall_count >= 10:
		try_unlock("raise_10_thralls")

func _on_process_changed(new_process: Game.GameProcess) -> void:
	match new_process:
		Game.GameProcess.EARLY_GAME:
			reset_run_timer()
		Game.GameProcess.BOSS_FIGHT:
			_boss_fight_start = _run_time
			_boss_fight_active = true
		Game.GameProcess.VICTORY:
			_run_active = false
			# Boss kill achievements
			if _boss_fight_active:
				try_unlock("first_boss")
				var boss_duration := _run_time - _boss_fight_start
				if boss_duration <= 30.0:
					try_unlock("boss_speed_kill")
				_boss_fight_active = false
			# World clear achievements
			_check_world_clears()

func _on_coins_changed(new_amount: int) -> void:
	if new_amount >= 500:
		try_unlock("collect_500_coins")

func _on_exp_changed(_new_exp: int, level: int, _to_next: int) -> void:
	if level >= 10:
		try_unlock("reach_level_10")
	if level >= 25:
		try_unlock("reach_level_25")
	if level >= 50:
		try_unlock("reach_level_50")

func _on_equipment_changed() -> void:
	# Check if any slot is equipped
	for slot in SaveData.equipped:
		if not slot.is_empty():
			try_unlock("equip_first_item")
			return

func _check_world_clears() -> void:
	# Check based on current_world (the world just completed)
	match Game.current_world:
		0:
			try_unlock("clear_world_1")
		1:
			try_unlock("clear_world_2")
		2:
			try_unlock("clear_world_3")

# --- Persistence ---

func _save_achievements() -> void:
	# Piggyback on SaveData's save system
	SaveData.save_game()

func save_to_dict() -> Dictionary:
	var data: Dictionary = {}
	for id in unlocked:
		data[id] = true
	return data

func load_from_dict(data: Dictionary) -> void:
	unlocked = {}
	if data is Dictionary:
		for id in data:
			if id is String and id in _defs:
				unlocked[id] = true
