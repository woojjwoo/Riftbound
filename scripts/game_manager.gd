extends Node

## Global game state. Autoloaded as "Game".

var thrall_count: int = 0
var kill_count: int = 0
var is_game_over: bool = false

signal thrall_gained
signal enemy_killed
signal game_over

func on_enemy_killed() -> void:
	kill_count += 1
	enemy_killed.emit()

func on_thrall_gained() -> void:
	thrall_count += 1
	thrall_gained.emit()

func trigger_game_over() -> void:
	is_game_over = true
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	is_game_over = false
	thrall_count = 0
	kill_count = 0
	get_tree().paused = false
	get_tree().reload_current_scene()
