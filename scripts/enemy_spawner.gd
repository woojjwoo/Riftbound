extends Node2D

## Spawns waves of enemies around the player. Difficulty scales over time.
## Now with spawn telegraphs, new enemy types, and shielded enemies.

@export var enemy_melee_scene: PackedScene
@export var enemy_ranged_scene: PackedScene
@export var enemy_tank_scene: PackedScene
@export var enemy_flying_scene: PackedScene
@export var enemy_exploder_scene: PackedScene
@export var boss_scene: PackedScene

@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 400.0
@export var max_enemies: int = 30
@export var boss_spawn_at_kills: int = 20
@export var telegraph_delay: float = 0.6

var spawn_timer: float = 0.0
var boss_spawned: bool = false
var player: Node2D = null

var SpawnTelegraph: GDScript = preload("res://scripts/spawn_telegraph.gd")

func _ready() -> void:
	spawn_timer = spawn_interval

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

func _pick_enemy_scene() -> PackedScene:
	var roll := randf()
	var kills := Game.kill_count

	# Early game: melee only
	if kills < 5:
		return enemy_melee_scene

	# Kills 5-9: mostly melee, some ranged
	if kills < 10:
		if roll < 0.7:
			return enemy_melee_scene
		elif enemy_ranged_scene:
			return enemy_ranged_scene
		return enemy_melee_scene

	# Mid game (10-14): mix in tanks and flying
	if kills < 15:
		if roll < 0.35:
			return enemy_melee_scene
		elif roll < 0.55 and enemy_ranged_scene:
			return enemy_ranged_scene
		elif roll < 0.75 and enemy_tank_scene:
			return enemy_tank_scene
		elif enemy_flying_scene:
			return enemy_flying_scene
		return enemy_melee_scene

	# Late mid (15-19): all types including exploders
	if roll < 0.2:
		return enemy_melee_scene
	elif roll < 0.35 and enemy_ranged_scene:
		return enemy_ranged_scene
	elif roll < 0.5 and enemy_tank_scene:
		return enemy_tank_scene
	elif roll < 0.7 and enemy_flying_scene:
		return enemy_flying_scene
	elif roll < 0.85 and enemy_exploder_scene:
		return enemy_exploder_scene
	return enemy_melee_scene

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
