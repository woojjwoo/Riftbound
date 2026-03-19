extends Node

## Global game state. Autoloaded as "Game".

## Represents the current phase of gameplay.
enum GameProcess {
	INITIALIZING,  ## Game is loading/setting up.
	EARLY_GAME,    ## First wave of enemies (kills < 10).
	MID_GAME,      ## Mixed enemy types (kills 10-19).
	BOSS_FIGHT,    ## Boss has spawned (kills >= 20).
	GAME_OVER,     ## Player has died.
}

var thrall_count: int = 0
var kill_count: int = 0
var is_game_over: bool = false
var current_process: GameProcess = GameProcess.INITIALIZING

signal thrall_gained
signal enemy_killed
signal game_over
signal process_changed(new_process: GameProcess)

func _ready() -> void:
	_set_process(GameProcess.EARLY_GAME)

func on_enemy_killed() -> void:
	kill_count += 1
	enemy_killed.emit()
	_update_process()

func on_thrall_gained() -> void:
	thrall_count += 1
	thrall_gained.emit()

func on_boss_spawned() -> void:
	_set_process(GameProcess.BOSS_FIGHT)

func trigger_game_over() -> void:
	is_game_over = true
	_set_process(GameProcess.GAME_OVER)
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	is_game_over = false
	thrall_count = 0
	kill_count = 0
	current_process = GameProcess.EARLY_GAME
	get_tree().paused = false
	get_tree().reload_current_scene()

func get_process_name() -> String:
	match current_process:
		GameProcess.INITIALIZING:
			return "Initializing"
		GameProcess.EARLY_GAME:
			return "Early Game"
		GameProcess.MID_GAME:
			return "Mid Game"
		GameProcess.BOSS_FIGHT:
			return "Boss Fight"
		GameProcess.GAME_OVER:
			return "Game Over"
	return "Unknown"

func _update_process() -> void:
	if is_game_over:
		return
	# Boss fight takes priority — once boss spawns, stay in that phase
	if current_process == GameProcess.BOSS_FIGHT:
		return
	if kill_count >= 10:
		_set_process(GameProcess.MID_GAME)

func _set_process(new_process: GameProcess) -> void:
	if current_process == new_process:
		return
	current_process = new_process
	process_changed.emit(new_process)
