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

## World-specific enemy pools. Each world introduces new enemy types.
## Structure: Array of {scene, weight} dicts per world.
var _world_pools: Array[Array] = []

func _ready() -> void:
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

func try_spawn() -> void:
	var current_enemies := get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
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
