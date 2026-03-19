extends Node2D

## Manages rift lifecycle. Spawns rifts in sequence, each harder than the last.
## Adapts to current world's difficulty scaling.

var rift_configs: Array[Dictionary] = []
var current_rift_index: int = 0
var total_rifts: int = 5
var player: Node2D = null
var rift_spawn_delay: float = 4.0

var RiftPortal: GDScript = preload("res://scripts/rift_portal.gd")

func _ready() -> void:
	total_rifts = Game.total_rifts
	_setup_rift_configs()
	# Spawn first rift after brief intro
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(_spawn_next_rift)

func _process(_delta: float) -> void:
	if player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func _setup_rift_configs() -> void:
	var melee := load("res://scenes/enemy_melee.tscn")
	var ranged := load("res://scenes/enemy_ranged.tscn")
	var tank := load("res://scenes/enemy_tank.tscn")
	var flying := load("res://scenes/enemy_flying.tscn")
	var exploder := load("res://scenes/enemy_exploder.tscn")

	var world_config := Game.get_world_config()
	var hp_mult: float = world_config.get("hp_mult", 1.0)
	var enemy_mult: float = world_config.get("enemy_mult", 1.0)

	# Base configs scale with world multipliers
	var base_configs: Array[Dictionary] = [
		{"hp": 100.0, "interval": 4.0, "scenes": [melee]},
		{"hp": 150.0, "interval": 3.0, "scenes": [melee, ranged]},
		{"hp": 250.0, "interval": 2.5, "scenes": [melee, ranged, flying]},
		{"hp": 350.0, "interval": 2.0, "scenes": [melee, ranged, tank, flying]},
		{"hp": 400.0, "interval": 1.8, "scenes": [melee, ranged, tank, flying, exploder]},
		{"hp": 500.0, "interval": 1.5, "scenes": [melee, ranged, tank, flying, exploder]},
	]

	rift_configs = []
	for i in range(total_rifts):
		var base_idx := mini(i, base_configs.size() - 1)
		var base := base_configs[base_idx]
		rift_configs.append({
			"hp": base["hp"] * hp_mult,
			"interval": max(base["interval"] / enemy_mult, 0.8),
			"scenes": base["scenes"],
		})

func _spawn_next_rift() -> void:
	if current_rift_index >= total_rifts:
		return
	if player == null:
		return

	var config: Dictionary = rift_configs[current_rift_index]

	# Scale rift HP and spawn rate based on player power
	var power := Game.get_power_level()
	var hp: float = config["hp"]
	var interval: float = config["interval"]
	if power > 1.0:
		hp *= (1.0 + (power - 1.0) * 0.35)  # Rift gets tougher
		interval *= max(0.5, 1.0 - (power - 1.0) * 0.1)  # Spawns faster (floor 50%)

	# Position: random direction, 300-500px from player
	var angle := randf() * TAU
	var dist := randf_range(300.0, 500.0)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var rift := Node2D.new()
	rift.set_script(RiftPortal)
	rift.global_position = pos
	get_tree().current_scene.add_child(rift)

	var scenes_array: Array[PackedScene] = []
	for s in config["scenes"]:
		scenes_array.append(s)
	rift.setup(current_rift_index + 1, hp, interval, scenes_array)
	rift.rift_closed.connect(_on_rift_closed)

func _on_rift_closed(rift_number: int) -> void:
	current_rift_index += 1
	Game.on_rift_closed(rift_number)

	if current_rift_index >= total_rifts:
		return  # Victory handled by game manager

	# Spawn next rift after delay
	var timer := get_tree().create_timer(rift_spawn_delay)
	timer.timeout.connect(_spawn_next_rift)
