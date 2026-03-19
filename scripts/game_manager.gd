extends Node

## Global game state. Autoloaded as "Game".
## Multi-world rift-based progression with persistent upgrades.

enum GameProcess {
	INITIALIZING,
	EARLY_GAME,
	MID_GAME,
	BOSS_FIGHT,
	VICTORY,
	GAME_OVER,
}

var thrall_count: int = 0
var kill_count: int = 0
var is_game_over: bool = false
var boss_killed: bool = false
var current_process: GameProcess = GameProcess.INITIALIZING

# World/stage progression
var current_world: int = 0

# Rift tracking
var rifts_closed: int = 0
var total_rifts: int = 5

# Guaranteed extractions for early game
var guaranteed_extractions: int = 3

# Pity system: extraction chance increases with consecutive failures
var extraction_pity: float = 0.0
const PITY_PER_FAIL: float = 0.08

signal thrall_gained
signal enemy_killed
signal game_over
signal victory
signal process_changed(new_process: GameProcess)
signal shake_camera(intensity: float)
signal upgrade_available
signal rift_closed_signal(rift_number: int)
signal world_portal_spawned

# Hit freeze
var _freeze_timer: float = 0.0
var _freeze_prev_scale: float = 1.0

# Upgrade multipliers (per-run, reset each world)
var upgrade_attack_mult: float = 1.0
var upgrade_speed_mult: float = 1.0
var upgrade_health_bonus: float = 0.0
var upgrade_extraction_bonus: float = 0.0
var upgrade_thrall_damage_mult: float = 1.0
var upgrade_regen: float = 0.0
var upgrade_cooldown_mult: float = 1.0
var upgrade_thrall_speed_mult: float = 1.0

var DamageNumber: GDScript = preload("res://scripts/damage_number.gd")
var CoinPickup: GDScript = preload("res://scripts/coin_pickup.gd")
var ExpOrb: GDScript = preload("res://scripts/exp_orb.gd")
var WorldPortal: GDScript = preload("res://scripts/world_portal.gd")

# Chosen upgrades tracking — prevents duplicates, shown in HUD
var chosen_upgrades: Array[String] = []

# Upgrades — tailored for necromancer + rift gameplay
var ALL_UPGRADES: Array[Dictionary] = [
	{"name": "Soul Pierce", "desc": "Soul bolt damage +25%", "icon": "bolt",
	 "apply": func(): upgrade_attack_mult += 0.25},
	{"name": "Rapid Fire", "desc": "Attack speed +20%", "icon": "speed",
	 "apply": func(): upgrade_cooldown_mult -= 0.15},
	{"name": "Fleet Foot", "desc": "Move speed +20%", "icon": "boot",
	 "apply": func(): upgrade_speed_mult += 0.2},
	{"name": "Fortify", "desc": "Max health +30", "icon": "shield",
	 "apply": func():
		upgrade_health_bonus += 30.0
		_apply_health_upgrade()},
	{"name": "Soul Reach", "desc": "Extraction range +50%", "icon": "hand",
	 "apply": func(): upgrade_extraction_bonus += 0.15},
	{"name": "Dark Pact", "desc": "Thrall damage +25%", "icon": "skull",
	 "apply": func(): upgrade_thrall_damage_mult += 0.25},
	{"name": "Life Siphon", "desc": "Regenerate 2 HP/sec", "icon": "heart",
	 "apply": func(): upgrade_regen += 2.0},
	{"name": "Rallying Cry", "desc": "Thrall speed +25%", "icon": "horn",
	 "apply": func(): upgrade_thrall_speed_mult += 0.25},
]

func _ready() -> void:
	# Set rift count from world config on first load
	total_rifts = get_world_config().get("rifts", 5)
	_transition_to(GameProcess.EARLY_GAME)

func _process(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta / max(_freeze_prev_scale, 0.01)
		if _freeze_timer <= 0.0:
			Engine.time_scale = _freeze_prev_scale

## Get current world config from WorldData
func get_world_config() -> Dictionary:
	return WorldData.get_config(current_world)

func on_enemy_killed() -> void:
	kill_count += 1
	enemy_killed.emit()

func on_boss_killed() -> void:
	boss_killed = true
	SaveData.total_bosses_killed += 1
	Audio.play_victory()

func on_boss_spawned() -> void:
	_transition_to(GameProcess.BOSS_FIGHT)

func on_thrall_gained() -> void:
	thrall_count += 1
	thrall_gained.emit()

func on_thrall_lost() -> void:
	thrall_count = max(thrall_count - 1, 0)

func on_rift_closed(rift_number: int) -> void:
	rifts_closed += 1
	rift_closed_signal.emit(rift_number)

	if rifts_closed >= total_rifts:
		_transition_to(GameProcess.VICTORY)
		Audio.play_victory()
		victory.emit()
		# Spawn world portal after a delay
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(_spawn_world_portal)
	else:
		# Upgrade reward for closing a rift
		upgrade_available.emit()
		Audio.play_upgrade()

		var mid_threshold := ceili(total_rifts / 2.0)
		if rifts_closed >= mid_threshold:
			_transition_to(GameProcess.MID_GAME)

func _spawn_world_portal() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	var angle := randf() * TAU
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * 150.0

	var scene := get_tree().current_scene
	if scene == null:
		return
	var portal := Node2D.new()
	portal.set_script(WorldPortal)
	portal.global_position = pos
	portal.setup(current_world + 1)
	scene.add_child(portal)
	world_portal_spawned.emit()

## Spawn coin and EXP drops at a position (called from enemy death)
func spawn_drops(pos: Vector2, enemy_type: String) -> void:
	var config := get_world_config()
	var coin_mult: float = config.get("coin_mult", 1.0)
	var exp_mult: float = config.get("exp_mult", 1.0)

	# Coin value by enemy type
	var coin_val := 1
	match enemy_type:
		"melee": coin_val = 1
		"ranged": coin_val = 2
		"tank": coin_val = 3
		"flying": coin_val = 2
		"exploder": coin_val = 2
		_: coin_val = 1
	coin_val = int(coin_val * coin_mult)

	# EXP value by type
	var exp_val := 3
	match enemy_type:
		"melee": exp_val = 3
		"ranged": exp_val = 5
		"tank": exp_val = 8
		"flying": exp_val = 5
		"exploder": exp_val = 4
		_: exp_val = 3
	exp_val = int(exp_val * exp_mult)

	var scene := get_tree().current_scene
	if scene == null:
		return

	# Spawn coin
	var coin := Node2D.new()
	coin.set_script(CoinPickup)
	coin.global_position = pos
	coin.setup(coin_val)
	scene.add_child(coin)

	# Spawn EXP orb
	var orb := Node2D.new()
	orb.set_script(ExpOrb)
	orb.global_position = pos
	orb.setup(exp_val)
	scene.add_child(orb)

## Spawn boss-tier drops (more coins, more EXP)
func spawn_boss_drops(pos: Vector2) -> void:
	var config := get_world_config()
	var coin_mult: float = config.get("coin_mult", 1.0)
	var exp_mult: float = config.get("exp_mult", 1.0)
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Scatter multiple coins
	for i in range(8):
		var coin := Node2D.new()
		coin.set_script(CoinPickup)
		coin.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		coin.setup(int(5 * coin_mult))
		scene.add_child(coin)
	# Scatter EXP orbs
	for i in range(5):
		var orb := Node2D.new()
		orb.set_script(ExpOrb)
		orb.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		orb.setup(int(20 * exp_mult))
		scene.add_child(orb)

func trigger_game_over() -> void:
	is_game_over = true
	_transition_to(GameProcess.GAME_OVER)
	# Save progress even on death
	SaveData.total_runs += 1
	SaveData.total_kills += kill_count
	SaveData.save_game()
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	current_world = 0
	_reset_run_state()
	get_tree().paused = false
	get_tree().reload_current_scene()

func restart_for_next_world() -> void:
	_reset_run_state()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _reset_run_state() -> void:
	is_game_over = false
	boss_killed = false
	thrall_count = 0
	kill_count = 0
	rifts_closed = 0
	guaranteed_extractions = 3
	extraction_pity = 0.0
	chosen_upgrades = []
	current_process = GameProcess.EARLY_GAME
	Engine.time_scale = 1.0
	upgrade_attack_mult = 1.0
	upgrade_speed_mult = 1.0
	upgrade_health_bonus = 0.0
	upgrade_extraction_bonus = 0.0
	upgrade_thrall_damage_mult = 1.0
	upgrade_regen = 0.0
	upgrade_cooldown_mult = 1.0
	upgrade_thrall_speed_mult = 1.0
	# Apply permanent upgrades from save data
	var w_config := get_world_config()
	total_rifts = w_config.get("rifts", 5)

func get_process_name() -> String:
	var world_name: String = get_world_config().get("name", "Unknown")
	match current_process:
		GameProcess.EARLY_GAME:
			return world_name
		GameProcess.MID_GAME:
			return world_name + " — Intensifying"
		GameProcess.BOSS_FIGHT:
			return get_world_config().get("boss_name", "Boss") + " Awakens"
		GameProcess.VICTORY:
			return world_name + " — Cleared!"
		GameProcess.GAME_OVER:
			return "Fallen"
	return ""

func request_shake(intensity: float) -> void:
	shake_camera.emit(intensity)

func hit_freeze(duration: float = 0.05) -> void:
	_freeze_prev_scale = 1.0
	Engine.time_scale = 0.05
	_freeze_timer = duration

func spawn_damage_number(amount: float, pos: Vector2, color: Color = Color.WHITE) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dmg_num := Node2D.new()
	dmg_num.set_script(DamageNumber)
	dmg_num.global_position = pos
	scene.add_child(dmg_num)
	dmg_num.setup(amount, color)

func get_random_upgrades(count: int = 3) -> Array[Dictionary]:
	# Filter out already-chosen upgrades
	var available: Array[Dictionary] = []
	for upgrade in ALL_UPGRADES:
		if upgrade["name"] not in chosen_upgrades:
			available.append(upgrade)
	# If fewer than needed remain, allow all (fallback for late game)
	if available.size() < count:
		available = ALL_UPGRADES.duplicate()
	available.shuffle()
	var result: Array[Dictionary] = []
	for i in range(min(count, available.size())):
		result.append(available[i])
	return result

func apply_upgrade(upgrade_name: String) -> void:
	chosen_upgrades.append(upgrade_name)

## Player power level — used to scale enemy difficulty.
## Returns 1.0 at baseline (no upgrades, no thralls), scales up with power.
func get_power_level() -> float:
	var power := 1.0
	# Offensive upgrades
	power += (upgrade_attack_mult - 1.0) * 0.5
	power += (1.0 - upgrade_cooldown_mult) * 0.8
	power += (upgrade_thrall_damage_mult - 1.0) * 0.4
	# Defensive upgrades
	power += upgrade_health_bonus / 100.0
	power += upgrade_regen * 0.1
	# Thrall army strength
	power += thrall_count * 0.15
	# Utility
	power += (upgrade_speed_mult - 1.0) * 0.2
	power += (upgrade_thrall_speed_mult - 1.0) * 0.15
	# Permanent upgrades from save
	power += SaveData.perm_attack_mult * 0.3
	power += SaveData.perm_thrall_damage * 0.2
	return power

## Get world-scaled difficulty multipliers
func get_enemy_hp_mult() -> float:
	return get_world_config().get("hp_mult", 1.0)

func get_enemy_dmg_mult() -> float:
	return get_world_config().get("dmg_mult", 1.0)

func get_enemy_count_mult() -> float:
	return get_world_config().get("enemy_mult", 1.0)

func _apply_health_upgrade() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p := players[0] as CharacterBody2D
		p.max_health += 30.0
		p.current_health += 30.0
		p.health_changed.emit(p.current_health, p.max_health)

func _transition_to(new_process: GameProcess) -> void:
	if current_process == new_process:
		return
	current_process = new_process
	process_changed.emit(new_process)
