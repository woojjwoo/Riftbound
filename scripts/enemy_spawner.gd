extends Node2D

## Spawns waves of enemies around the player. Difficulty scales over time.

@export var enemy_melee_scene: PackedScene
@export var enemy_ranged_scene: PackedScene
@export var enemy_tank_scene: PackedScene
@export var boss_scene: PackedScene

@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 400.0
@export var max_enemies: int = 30
@export var boss_spawn_at_kills: int = 20

var spawn_timer: float = 0.0
var boss_spawned: bool = false
var player: Node2D = null

func _ready() -> void:
	spawn_timer = spawn_interval

func _process(delta: float) -> void:
	if Game.is_game_over:
		return

	# Find player
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
		# Gradually speed up (min 0.5s)
		spawn_interval = max(0.5, spawn_interval - 0.01)
		spawn_timer = spawn_interval

func try_spawn() -> void:
	var current_enemies := get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return

	var scenes: Array[PackedScene] = []
	if enemy_melee_scene:
		scenes.append(enemy_melee_scene)
	if enemy_ranged_scene:
		scenes.append(enemy_ranged_scene)
	if enemy_tank_scene:
		scenes.append(enemy_tank_scene)

	if scenes.is_empty():
		return

	# Weight: more melee early, mix in others as kills increase
	var scene: PackedScene
	var roll := randf()
	if Game.kill_count < 10 or roll < 0.5:
		scene = scenes[0]  # melee
	elif roll < 0.8 and scenes.size() > 1:
		scene = scenes[1]  # ranged
	elif scenes.size() > 2:
		scene = scenes[2]  # tank
	else:
		scene = scenes[0]

	var enemy := scene.instantiate()
	enemy.global_position = get_spawn_position()
	get_tree().current_scene.add_child(enemy)

func spawn_boss() -> void:
	boss_spawned = true
	var boss := boss_scene.instantiate()
	boss.global_position = get_spawn_position()
	get_tree().current_scene.add_child(boss)

func get_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset
