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

# Soul Essence earned notification (emitted at run end for UI display)
signal soul_essence_earned(amount: int)

# XP / Leveling
signal xp_changed(current: int, needed: int)
signal level_up(new_level: int)

var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 10

# Track worlds cleared during this run (for Soul Essence calculation)
var run_worlds_cleared: int = 0
var run_bosses_killed: int = 0

# New Game+ cycle (synced from SaveData on start)
var ng_plus_cycle: int = 0

# Thrall formation
enum Formation { SPREAD, LINE, CLUSTER, ORBIT }
var current_formation: Formation = Formation.SPREAD
signal formation_changed(formation: Formation)

# Thrall synergy bonuses (recalculated when thralls change)
var synergy_thrall_damage_mult: float = 1.0
var synergy_thrall_speed_mult: float = 1.0
var synergy_thrall_defense_mult: float = 1.0
var synergy_extraction_bonus: float = 0.0
var active_synergies: Array[String] = []
signal synergies_changed(synergies: Array[String])

# Arena/endless mode
var arena_mode: bool = false
var arena_wave: int = 0
var arena_best_wave: int = 0
var arena_spawn_timer: float = 0.0
var arena_enemies_remaining: int = 0
var arena_intermission: float = 0.0
signal arena_wave_started(wave: int)

# Combo / kill streak system
var combo_count: int = 0
var combo_timer: float = 0.0
var best_combo: int = 0
const COMBO_WINDOW: float = 3.0  # seconds between kills to maintain combo
signal combo_changed(count: int)
signal combo_ended(final_count: int)

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
var WorldEvent: GDScript = preload("res://scripts/world_event.gd")
var WorldPortal: GDScript = preload("res://scripts/world_portal.gd")
var EquipDrop: GDScript = preload("res://scripts/equip_drop.gd")

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
	{"name": "Bone Wall", "desc": "Thralls take 15% less damage", "icon": "wall",
	 "apply": func(): synergy_thrall_defense_mult *= 0.85},
	{"name": "Soul Storm", "desc": "Cooldown reduction +15%", "icon": "storm",
	 "apply": func(): upgrade_cooldown_mult -= 0.12},
	{"name": "Grave Pact", "desc": "+20% extraction chance", "icon": "grave",
	 "apply": func(): upgrade_extraction_bonus += 0.20},
	{"name": "Iron Will", "desc": "Max health +50", "icon": "iron",
	 "apply": func():
		upgrade_health_bonus += 50.0
		_apply_health_upgrade()},
]

func _ready() -> void:
	ng_plus_cycle = SaveData.ng_plus_cycle
	# Set rift count from world config on first load
	total_rifts = get_world_config().get("rifts", 5)
	_transition_to(GameProcess.EARLY_GAME)
	# Arena mode: start first wave after a short delay
	if arena_mode:
		arena_intermission = 2.0

func _process(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta / max(_freeze_prev_scale, 0.01)
		if _freeze_timer <= 0.0:
			Engine.time_scale = _freeze_prev_scale

	# Combo timer
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_end_combo()

	# Arena mode wave management
	if arena_mode and not is_game_over:
		_process_arena(delta)

## Get current world config from WorldData
func get_world_config() -> Dictionary:
	return WorldData.get_config(current_world)

func on_enemy_killed() -> void:
	kill_count += 1
	enemy_killed.emit()
	add_xp(5)
	if arena_mode:
		on_arena_enemy_killed()
	# Combo system
	combo_count += 1
	combo_timer = COMBO_WINDOW
	if combo_count > best_combo:
		best_combo = combo_count
	combo_changed.emit(combo_count)
	# Bonus rewards at combo milestones
	if combo_count == 10 or combo_count == 25 or combo_count == 50 or combo_count % 50 == 0:
		Audio.play_combo_milestone()
		var bonus_coins := combo_count / 5
		var pos := Vector2.ZERO
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			pos = players[0].global_position
		spawn_damage_number(bonus_coins, pos + Vector2(0, -40), Color(1.0, 0.9, 0.3))

func _end_combo() -> void:
	var final := combo_count
	combo_count = 0
	if final >= 5:
		Audio.play_combo_end()
		combo_ended.emit(final)

func add_xp(amount: int) -> void:
	current_xp += amount
	xp_changed.emit(current_xp, xp_to_next_level)
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		# Each level requires more XP (scaling formula)
		xp_to_next_level = 10 + (current_level - 1) * 5
		level_up.emit(current_level)
		xp_changed.emit(current_xp, xp_to_next_level)

func on_boss_killed() -> void:
	boss_killed = true
	run_bosses_killed += 1
	SaveData.total_bosses_killed += 1
	Audio.play_victory()

func on_boss_spawned() -> void:
	_transition_to(GameProcess.BOSS_FIGHT)

func on_thrall_gained() -> void:
	thrall_count += 1
	thrall_gained.emit()
	_recalculate_synergies()

func on_thrall_lost() -> void:
	thrall_count = max(thrall_count - 1, 0)
	_recalculate_synergies()

func _recalculate_synergies() -> void:
	synergy_thrall_damage_mult = 1.0
	synergy_thrall_speed_mult = 1.0
	synergy_thrall_defense_mult = 1.0
	synergy_extraction_bonus = 0.0
	active_synergies = []

	# Count thrall types
	var type_counts: Dictionary = {}
	var total := 0
	for thrall in get_tree().get_nodes_in_group("thralls"):
		var t: String = thrall.thrall_type
		type_counts[t] = type_counts.get(t, 0) + 1
		total += 1

	# Vanguard: 2+ tank/shielded — all thralls take 15% less damage
	var tank_count: int = type_counts.get("tank", 0) + type_counts.get("shielded", 0)
	if tank_count >= 2:
		synergy_thrall_defense_mult = 0.85
		active_synergies.append("Vanguard (-15%% DMG taken)")

	# Artillery: 2+ ranged/flying — ranged thralls +20% damage
	var ranged_count: int = type_counts.get("ranged", 0) + type_counts.get("flying", 0)
	if ranged_count >= 2:
		synergy_thrall_damage_mult *= 1.2
		active_synergies.append("Artillery (+20%% Ranged DMG)")

	# Swarm: 4+ thralls total — all thralls +10% speed
	if total >= 4:
		synergy_thrall_speed_mult *= 1.1
		active_synergies.append("Swarm (+10%% Speed)")

	# Legion: 6+ thralls total — all thralls +10% damage
	if total >= 6:
		synergy_thrall_damage_mult *= 1.1
		active_synergies.append("Legion (+10%% DMG)")

	# Diversity: 4+ different types — +5% extraction
	if type_counts.size() >= 4:
		synergy_extraction_bonus = 0.05
		active_synergies.append("Diversity (+5%% Extract)")

	synergies_changed.emit(active_synergies)

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
		# Chance to spawn a world event near the closed rift
		if randf() < 0.6:
			_spawn_world_event()

		var mid_threshold := ceili(total_rifts / 2.0)
		if rifts_closed >= mid_threshold:
			_transition_to(GameProcess.MID_GAME)

func on_world_cleared() -> void:
	run_worlds_cleared += 1

func _spawn_world_event() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	var angle := randf() * TAU
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(80.0, 150.0)
	var scene := get_tree().current_scene
	if scene == null:
		return
	var event := Node2D.new()
	event.set_script(WorldEvent)
	event.global_position = pos
	# Random event type, weighted
	var roll := randf()
	var event_type: int
	if roll < 0.35:
		event_type = 0  # SHRINE
	elif roll < 0.55:
		event_type = 1  # CURSED_CHEST
	elif roll < 0.80:
		event_type = 2  # BLESSING_ALTAR
	else:
		event_type = 3  # MERCHANT
	event.setup(event_type)
	scene.add_child(event)

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

## Spawn an equipment drop pickup at a position
func spawn_equip_drop(pos: Vector2, equip: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var drop := Node2D.new()
	drop.set_script(EquipDrop)
	drop.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	drop.setup(equip)
	scene.add_child(drop)

## Spawn coin and EXP drops at a position (called from enemy death)
func spawn_drops(pos: Vector2, enemy_type: String) -> void:
	var config := get_world_config()
	var coin_mult: float = config.get("coin_mult", 1.0) * (1.0 + ng_plus_cycle * 0.3) * (1.0 + Challenges.get_total_coin_bonus()) * (1.0 + SkillTree.bonus_coin_bonus)
	var exp_mult: float = config.get("exp_mult", 1.0) * (1.0 + ng_plus_cycle * 0.2) * (1.0 + Challenges.get_total_exp_bonus())

	# Coin value by enemy type
	var coin_val := 1
	match enemy_type:
		"melee": coin_val = 1
		"ranged": coin_val = 2
		"tank": coin_val = 3
		"flying": coin_val = 2
		"exploder": coin_val = 2
		"charger": coin_val = 2
		"shielded": coin_val = 3
		"splitter": coin_val = 2
		"summoner": coin_val = 4
		"poisoner": coin_val = 3
		"teleporter": coin_val = 3
		"voidcaller": coin_val = 4
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
		"charger": exp_val = 5
		"shielded": exp_val = 8
		"splitter": exp_val = 4
		"summoner": exp_val = 10
		"poisoner": exp_val = 6
		"teleporter": exp_val = 7
		"voidcaller": exp_val = 10
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

	# Equipment drop roll
	var equip := Equipment.roll_enemy_drop(enemy_type, current_world)
	if not equip.is_empty():
		spawn_equip_drop(pos, equip)

## Spawn boss-tier drops (more coins, more EXP)
func spawn_boss_drops(pos: Vector2) -> void:
	var config := get_world_config()
	var coin_mult: float = config.get("coin_mult", 1.0) * (1.0 + ng_plus_cycle * 0.3) * (1.0 + Challenges.get_total_coin_bonus())
	var exp_mult: float = config.get("exp_mult", 1.0) * (1.0 + ng_plus_cycle * 0.2) * (1.0 + Challenges.get_total_exp_bonus())
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
	# Boss guaranteed equipment drop
	var boss_equip := Equipment.roll_boss_drop(current_world)
	spawn_equip_drop(pos, boss_equip)

func trigger_game_over() -> void:
	is_game_over = true
	_transition_to(GameProcess.GAME_OVER)
	# Save progress even on death
	SaveData.total_runs += 1
	SaveData.total_kills += kill_count
	# Record run history
	SaveData.add_run_to_history({
		"kills": kill_count,
		"worlds_cleared": run_worlds_cleared,
		"bosses_killed": run_bosses_killed,
		"thralls": thrall_count,
		"world": current_world,
		"level": current_level,
		"victory": false,
		"ng_plus": ng_plus_cycle,
		"challenges": SaveData.active_challenges.duplicate(),
		"run_number": SaveData.total_runs,
	})
	# Track daily challenge best score
	var date := Time.get_date_dict_from_system()
	var daily_key := "daily_%d-%02d-%02d" % [date["year"], date["month"], date["day"]]
	var run_score := kill_count + run_worlds_cleared * 100 + run_bosses_killed * 250
	var old_best := int(SaveData.run_bests.get(daily_key, 0))
	if run_score > old_best:
		SaveData.run_bests[daily_key] = run_score
	SaveData.save_game()
	# Award Soul Essence for the run
	var earned := Meta.award_run_essence(kill_count, run_worlds_cleared, run_bosses_killed)
	soul_essence_earned.emit(earned)
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	current_world = 0
	ng_plus_cycle = SaveData.ng_plus_cycle
	arena_mode = false
	_reset_run_state()
	get_tree().paused = false
	get_tree().reload_current_scene()
	# Re-emit process state after scene reload so new UI picks it up
	_emit_process_deferred.call_deferred()

func restart_for_next_world() -> void:
	_reset_run_state()
	# Crossfade to the new world's music
	Audio.change_world_music(current_world)
	get_tree().paused = false
	get_tree().reload_current_scene()
	# Re-emit process state after scene reload so new UI picks it up
	_emit_process_deferred.call_deferred()

func _emit_process_deferred() -> void:
	process_changed.emit(current_process)

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
	current_xp = 0
	current_level = 1
	xp_to_next_level = 10
	run_worlds_cleared = 0
	run_bosses_killed = 0
	combo_count = 0
	combo_timer = 0.0
	best_combo = 0
	# Arena mode state
	if not arena_mode:
		arena_wave = 0
		arena_enemies_remaining = 0
		arena_intermission = 0.0
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
	if _freeze_timer <= 0.0:
		_freeze_prev_scale = Engine.time_scale
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
	# Meta-progression (Sanctum) bonuses
	power += Meta.sanctum_base_damage * 0.2
	power += Meta.sanctum_max_health / 200.0
	# Skill tree bonuses
	power += SkillTree.bonus_bolt_damage * 0.3
	power += SkillTree.bonus_thrall_damage * 0.2
	power += SkillTree.bonus_max_hp / 100.0
	# Equipment power — sum stat bonuses across all 6 equipped slots
	for slot_idx in range(Equipment.SLOT_INFO.size()):
		var equip_bonus := SaveData.get_equip_bonus(slot_idx)
		if equip_bonus > 0.0:
			# Normalize each slot's contribution so equipment matters but doesn't dominate.
			# Damage/CDR slots (Grimoire, Ring, Crown) weighted higher than defensive/utility.
			match slot_idx:
				Equipment.Slot.GRIMOIRE:
					power += equip_bonus * 2.0   # soul bolt damage %
				Equipment.Slot.RING:
					power += equip_bonus * 1.5   # thrall damage %
				Equipment.Slot.CROWN:
					power += equip_bonus * 1.5   # cooldown reduction %
				Equipment.Slot.ROBES:
					power += equip_bonus / 50.0  # max HP (large raw numbers)
				Equipment.Slot.AMULET:
					power += equip_bonus * 1.0   # extraction chance %
				Equipment.Slot.BOOTS:
					power += equip_bonus * 0.8   # move speed %
	return power

## NG+ difficulty scaling: each cycle adds 50% HP, 30% damage, 20% count
func get_ng_plus_mult(base: float, per_cycle: float) -> float:
	return base * (1.0 + ng_plus_cycle * per_cycle)

## Get world-scaled difficulty multipliers (with NG+ scaling)
func get_enemy_hp_mult() -> float:
	return get_ng_plus_mult(get_world_config().get("hp_mult", 1.0), 0.5)

func get_enemy_dmg_mult() -> float:
	return get_ng_plus_mult(get_world_config().get("dmg_mult", 1.0), 0.3)

func get_enemy_count_mult() -> float:
	return get_ng_plus_mult(get_world_config().get("enemy_mult", 1.0), 0.2) * Challenges.get_enemy_count_mult()

func cycle_formation() -> void:
	current_formation = (current_formation + 1) % Formation.size() as Formation
	formation_changed.emit(current_formation)

func get_formation_name() -> String:
	match current_formation:
		Formation.SPREAD: return "Spread"
		Formation.LINE: return "Line"
		Formation.CLUSTER: return "Cluster"
		Formation.ORBIT: return "Orbit"
	return "Spread"

## Get formation offset for a thrall given its index and total count
func get_formation_offset(index: int, total: int, facing: Vector2) -> Vector2:
	if total <= 0:
		return Vector2.ZERO
	match current_formation:
		Formation.SPREAD:
			# Semi-circle behind the player
			var angle_range := PI * 0.8
			var start_angle := facing.angle() + PI - angle_range / 2.0
			var angle_step := angle_range / maxf(total - 1, 1)
			var angle := start_angle + angle_step * index
			return Vector2(cos(angle), sin(angle)) * follow_distance_for_formation(total)
		Formation.LINE:
			# Line perpendicular to facing direction
			var perp := Vector2(-facing.y, facing.x).normalized()
			var offset_idx := float(index) - float(total - 1) / 2.0
			return -facing.normalized() * 40.0 + perp * offset_idx * 25.0
		Formation.CLUSTER:
			# Tight cluster behind player
			var angle := float(index) / float(total) * TAU
			var radius := 25.0 + float(index % 3) * 10.0
			return -facing.normalized() * 30.0 + Vector2(cos(angle), sin(angle)) * radius
		Formation.ORBIT:
			# Circle around player
			var angle := float(index) / float(total) * TAU
			return Vector2(cos(angle), sin(angle)) * follow_distance_for_formation(total)
	return Vector2.ZERO

func follow_distance_for_formation(total: int) -> float:
	return 50.0 + min(total, 8) * 5.0

func _process_arena(delta: float) -> void:
	if arena_intermission > 0.0:
		arena_intermission -= delta
		if arena_intermission <= 0.0:
			_start_arena_wave()
		return
	# Check if wave is cleared
	if arena_enemies_remaining <= 0 and arena_wave > 0:
		# Wave cleared — start intermission
		arena_intermission = 3.0
		Audio.play_arena_wave_clear()
		if arena_wave > arena_best_wave:
			arena_best_wave = arena_wave
			SaveData.run_bests["arena_best_wave"] = arena_best_wave
			SaveData.save_game()

func _start_arena_wave() -> void:
	arena_wave += 1
	var enemy_count := 5 + arena_wave * 3
	arena_enemies_remaining = enemy_count
	arena_wave_started.emit(arena_wave)
	Audio.play_arena_wave()
	# Spawn enemies via rift portal system or direct spawn
	var scene := get_tree().current_scene
	if scene == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player_pos: Vector2 = players[0].global_position
	var EnemyScript := preload("res://scripts/enemy.gd")
	var enemy_types: Array[String] = ["melee", "ranged", "tank", "flying", "charger", "exploder"]
	if arena_wave >= 3:
		enemy_types.append("shielded")
		enemy_types.append("splitter")
	if arena_wave >= 5:
		enemy_types.append("summoner")
		enemy_types.append("poisoner")
	if arena_wave >= 8:
		enemy_types.append("teleporter")
		enemy_types.append("voidcaller")
	for i in range(enemy_count):
		var angle := randf() * TAU
		var dist := randf_range(200.0, 400.0)
		var spawn_pos := player_pos + Vector2(cos(angle), sin(angle)) * dist
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		enemy.enemy_type = enemy_types[randi() % enemy_types.size()]
		# Scale stats with wave
		var wave_mult := 1.0 + (arena_wave - 1) * 0.15
		enemy.max_health *= wave_mult * get_enemy_hp_mult()
		enemy.contact_damage *= wave_mult * get_enemy_dmg_mult()
		enemy.move_speed *= 1.0 + arena_wave * 0.02
		# Elite chance increases with waves
		if arena_wave >= 3 and randf() < 0.05 + arena_wave * 0.02:
			var elite_types := ["berserker", "armored", "swift", "vampiric"]
			enemy.call_deferred("make_elite", elite_types[randi() % elite_types.size()])
		enemy.global_position = spawn_pos
		scene.call_deferred("add_child", enemy)

func on_arena_enemy_killed() -> void:
	arena_enemies_remaining = max(0, arena_enemies_remaining - 1)

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
