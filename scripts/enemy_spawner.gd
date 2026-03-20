extends Node2D

## Spawns waves of enemies around the player. Difficulty scales over time.
## Now with spawn telegraphs, new enemy types, and shielded enemies.

@export var enemy_melee_scene: PackedScene
@export var enemy_ranged_scene: PackedScene
@export var enemy_tank_scene: PackedScene
@export var enemy_charger_scene: PackedScene
@export var enemy_exploder_scene: PackedScene
@export var enemy_shielded_scene: PackedScene
@export var enemy_splitter_scene: PackedScene
@export var enemy_summoner_scene: PackedScene
@export var enemy_poisoner_scene: PackedScene
@export var enemy_teleporter_scene: PackedScene
@export var enemy_voidcaller_scene: PackedScene
@export var enemy_flying_scene: PackedScene
@export var boss_scene: PackedScene

@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 400.0
@export var max_enemies: int = 30
@export var boss_spawn_at_kills: int = 20
@export var telegraph_delay: float = 0.6

## Which world we are in (0-5). Controls which enemy pool is active.
@export var current_world: int = 0

var spawn_timer: float = 0.0
var boss_spawned: bool = false
var player: Node2D = null

var SpawnTelegraph: GDScript = preload("res://scripts/spawn_telegraph.gd")
var EnvHazard: GDScript = preload("res://scripts/env_hazard.gd")

# World hazard spawning
var _hazard_timer: float = 10.0
var _hazard_interval: float = 12.0
const MAX_HAZARDS: int = 8

# Dynamic difficulty adjustment
var _dd_eval_timer: float = 15.0  # Evaluate every 15 seconds
const DD_EVAL_INTERVAL: float = 15.0
var _dd_spawn_mult: float = 1.0   # Multiplier on spawn rate (0.5 = half, 2.0 = double)
var _dd_recent_kills: int = 0
var _dd_recent_damage_taken: float = 0.0
var _dd_last_kill_count: int = 0
var _dd_last_player_hp: float = -1.0

## World-specific enemy pools. Each world introduces new enemy types.
## Structure: Array of {scene, weight} dicts per world.
var _world_pools: Array[Array] = []

func _ready() -> void:
	current_world = Game.current_world
	spawn_timer = spawn_interval
	_build_world_pools()

func _process(delta: float) -> void:
	if Game.is_game_over or Game.boss_killed:
		return

	if player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	# Boss spawn
	if not boss_spawned and Game.kill_count >= boss_spawn_at_kills and boss_scene:
		spawn_boss()

	# Wave spawn
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		try_spawn()
		spawn_interval = max(0.5, spawn_interval - 0.01)
		spawn_timer = spawn_interval

	# World hazard spawning (worlds 1+ only)
	if current_world > 0:
		_hazard_timer -= delta
		if _hazard_timer <= 0.0:
			_spawn_world_hazard()
			_hazard_timer = _hazard_interval

	# Dynamic difficulty evaluation
	_dd_eval_timer -= delta
	if _dd_eval_timer <= 0.0:
		_evaluate_dynamic_difficulty()
		_dd_eval_timer = DD_EVAL_INTERVAL

func try_spawn() -> void:
	var effective_max := int(max_enemies * _dd_spawn_mult)
	var current_enemies := get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= effective_max:
		return

	var scene := _pick_enemy_scene()
	if scene == null:
		return

	var pos := get_spawn_position()
	_spawn_with_telegraph(scene, pos)

func _build_world_pools() -> void:
	# World 0: The Dark Realm — basic enemies only
	_world_pools.append(_make_pool([
		[enemy_melee_scene, 50],
		[enemy_ranged_scene, 30],
		[enemy_tank_scene, 20],
	]))
	# World 1: Scorched Sands — introduces chargers and exploders
	_world_pools.append(_make_pool([
		[enemy_melee_scene, 30],
		[enemy_ranged_scene, 15],
		[enemy_charger_scene, 30],
		[enemy_exploder_scene, 25],
	]))
	# World 2: Frozen Wastes — introduces shielded and splitters
	_world_pools.append(_make_pool([
		[enemy_melee_scene, 20],
		[enemy_ranged_scene, 15],
		[enemy_shielded_scene, 30],
		[enemy_splitter_scene, 25],
		[enemy_tank_scene, 10],
	]))
	# World 3: Toxic Marshes — introduces summoners and poisoners
	_world_pools.append(_make_pool([
		[enemy_melee_scene, 15],
		[enemy_summoner_scene, 25],
		[enemy_poisoner_scene, 25],
		[enemy_exploder_scene, 15],
		[enemy_ranged_scene, 10],
		[enemy_flying_scene, 10],
	]))
	# World 4: The Void — introduces teleporters and voidcallers
	_world_pools.append(_make_pool([
		[enemy_teleporter_scene, 25],
		[enemy_voidcaller_scene, 20],
		[enemy_shielded_scene, 15],
		[enemy_charger_scene, 15],
		[enemy_splitter_scene, 15],
		[enemy_ranged_scene, 10],
	]))
	# World 5: Celestial Realm — all enemy types
	_world_pools.append(_make_pool([
		[enemy_charger_scene, 12],
		[enemy_exploder_scene, 12],
		[enemy_shielded_scene, 12],
		[enemy_splitter_scene, 12],
		[enemy_summoner_scene, 12],
		[enemy_poisoner_scene, 10],
		[enemy_teleporter_scene, 12],
		[enemy_voidcaller_scene, 10],
		[enemy_melee_scene, 4],
		[enemy_tank_scene, 4],
	]))

func _make_pool(entries: Array) -> Array:
	var pool: Array = []
	for entry in entries:
		if entry[0] != null:
			pool.append({"scene": entry[0], "weight": entry[1]})
	return pool

func _pick_enemy_scene() -> PackedScene:
	var world_idx := clampi(current_world, 0, _world_pools.size() - 1)
	var pool: Array = _world_pools[world_idx] if world_idx < _world_pools.size() else []

	if pool.is_empty():
		return enemy_melee_scene

	# Progressive unlock: early kills only use first few entries
	var available_count: int = pool.size()
	if Game.kill_count < 5:
		available_count = mini(1, pool.size())
	elif Game.kill_count < 15:
		available_count = mini(2, pool.size())
	elif Game.kill_count < 25:
		available_count = mini(3, pool.size())
	elif Game.kill_count < 40:
		available_count = mini(4, pool.size())

	# Weighted random selection from available entries
	var total_weight: int = 0
	for i in range(available_count):
		total_weight += pool[i]["weight"]

	var roll := randi() % max(total_weight, 1)
	var cumulative: int = 0
	for i in range(available_count):
		cumulative += pool[i]["weight"]
		if roll < cumulative:
			return pool[i]["scene"]

	return pool[0]["scene"] if not pool.is_empty() else enemy_melee_scene

func _spawn_with_telegraph(scene: PackedScene, pos: Vector2) -> void:
	# Show telegraph
	var telegraph := Node2D.new()
	telegraph.set_script(SpawnTelegraph)
	telegraph.global_position = pos
	get_tree().current_scene.add_child(telegraph)

	# Delayed spawn
	var timer := get_tree().create_timer(telegraph_delay)
	timer.timeout.connect(_do_spawn.bind(scene, pos))

func _do_spawn(scene: PackedScene, pos: Vector2) -> void:
	if Game.is_game_over:
		return
	var enemy := scene.instantiate()
	enemy.global_position = pos
	get_tree().current_scene.add_child(enemy)

	# Chance for shielded enemies in later game
	if Game.kill_count >= 12 and randf() < 0.2 and enemy.has_method("enable_shield"):
		enemy.enable_shield(3)

func spawn_boss() -> void:
	boss_spawned = true
	Audio.play_boss_spawn()
	var pos := get_spawn_position()

	# Big telegraph for boss
	var telegraph := Node2D.new()
	telegraph.set_script(SpawnTelegraph)
	telegraph.global_position = pos
	telegraph.set("max_radius", 40.0)
	telegraph.set("duration", 1.0)
	get_tree().current_scene.add_child(telegraph)

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_do_boss_spawn.bind(pos))

func _do_boss_spawn(pos: Vector2) -> void:
	var boss := boss_scene.instantiate()
	boss.global_position = pos
	get_tree().current_scene.add_child(boss)
	Game.on_boss_spawned()

func _spawn_world_hazard() -> void:
	var hazards := get_tree().get_nodes_in_group("hazards")
	if hazards.size() >= MAX_HAZARDS:
		return
	if player == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	# Pick hazard type based on world
	var hazard_type: int
	var hazard_radius := 35.0
	var hazard_damage := 4.0 + Game.current_world * 2.0
	var hazard_duration := 8.0 + Game.current_world * 1.0
	match current_world:
		1:  # Desert — lava pools
			hazard_type = 0  # LAVA
			hazard_radius = 30.0
		2:  # Ice — ice patches
			hazard_type = 1  # ICE_PATCH
			hazard_radius = 40.0
			hazard_damage = 0.0  # Ice just slows
		3:  # Swamp — poison fog
			hazard_type = 2  # POISON_FOG
			hazard_radius = 45.0
		4:  # Void — gravity wells
			hazard_type = 3  # GRAVITY_WELL
			hazard_radius = 35.0
		5:  # Celestial — light beams
			hazard_type = 4  # LIGHT_BEAM
			hazard_radius = 25.0
			hazard_damage *= 1.5
		_:
			return

	# Spawn at random position near player (but not on top)
	var angle := randf() * TAU
	var dist := randf_range(80.0, 200.0)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var hazard := Node2D.new()
	hazard.set_script(EnvHazard)
	hazard.global_position = pos
	scene.add_child(hazard)
	hazard.setup(hazard_type, hazard_radius, hazard_damage, hazard_duration)

func get_spawn_position() -> Vector2:
	# Spawn at edge of screen, never too close to player
	var min_dist := 250.0
	for attempt in range(5):
		var angle := randf() * TAU
		var dist := spawn_radius + randf_range(-50.0, 50.0)
		var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
		if pos.distance_to(player.global_position) >= min_dist:
			return pos
	# Fallback
	var angle := randf() * TAU
	return player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius

## Evaluate player performance and adjust spawn difficulty.
## Criteria: kill rate (kills per evaluation window) and HP percentage.
func _evaluate_dynamic_difficulty() -> void:
	# Calculate kills in this window
	_dd_recent_kills = Game.kill_count - _dd_last_kill_count
	_dd_last_kill_count = Game.kill_count

	# Track player HP
	var players := get_tree().get_nodes_in_group("player")
	var hp_ratio := 1.0
	if players.size() > 0:
		var p = players[0]
		hp_ratio = p.current_health / max(p.max_health, 1.0)

	# High kill rate + high HP = player dominating -> increase difficulty
	# Low kill rate + low HP = player struggling -> ease off
	var kill_score := clampf(float(_dd_recent_kills) / 8.0, 0.0, 2.0)  # 8 kills/window = 1.0
	var hp_score := hp_ratio  # 1.0 = full, 0.0 = dead

	# Combined performance (0.0 = struggling, 2.0+ = dominating)
	var performance := kill_score * 0.6 + hp_score * 0.4

	# Adjust spawn multiplier toward performance target
	if performance > 1.2:
		# Player is dominating — ramp up (max 1.8x)
		_dd_spawn_mult = minf(_dd_spawn_mult + 0.1, 1.8)
	elif performance > 0.8:
		# Balanced — drift toward 1.0
		_dd_spawn_mult = move_toward(_dd_spawn_mult, 1.0, 0.05)
	elif performance > 0.4:
		# Struggling slightly — ease off
		_dd_spawn_mult = maxf(_dd_spawn_mult - 0.1, 0.6)
	else:
		# Severely struggling — significant relief
		_dd_spawn_mult = maxf(_dd_spawn_mult - 0.15, 0.5)

	# Also adjust spawn interval (faster when dominating)
	spawn_interval = max(0.5, 2.0 / _dd_spawn_mult - 0.01 * Game.kill_count)
