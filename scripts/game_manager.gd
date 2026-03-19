extends Node

## Global game state. Autoloaded as "Game".
## Rift-based progression: close 5 rifts to win.

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

# Rift tracking
var rifts_closed: int = 0
var total_rifts: int = 5

# Guaranteed extractions for early game
var guaranteed_extractions: int = 2

signal thrall_gained
signal enemy_killed
signal game_over
signal victory
signal process_changed(new_process: GameProcess)
signal shake_camera(intensity: float)
signal upgrade_available
signal rift_closed_signal(rift_number: int)

# Hit freeze
var _freeze_timer: float = 0.0
var _freeze_prev_scale: float = 1.0

# Upgrade multipliers
var upgrade_attack_mult: float = 1.0
var upgrade_speed_mult: float = 1.0
var upgrade_health_bonus: float = 0.0
var upgrade_extraction_bonus: float = 0.0
var upgrade_thrall_damage_mult: float = 1.0
var upgrade_regen: float = 0.0
var upgrade_cooldown_mult: float = 1.0
var upgrade_thrall_speed_mult: float = 1.0

var DamageNumber: GDScript = preload("res://scripts/damage_number.gd")

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
	_set_process(GameProcess.EARLY_GAME)

func _process(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta / max(_freeze_prev_scale, 0.01)
		if _freeze_timer <= 0.0:
			Engine.time_scale = _freeze_prev_scale

func on_enemy_killed() -> void:
	kill_count += 1
	enemy_killed.emit()

func on_boss_killed() -> void:
	boss_killed = true
	# Boss death is significant but doesn't trigger victory
	# Victory comes from closing the final rift
	Audio.play_boss_enrage()

func on_boss_spawned() -> void:
	_set_process(GameProcess.BOSS_FIGHT)

func on_thrall_gained() -> void:
	thrall_count += 1
	thrall_gained.emit()

func on_thrall_lost() -> void:
	thrall_count = max(thrall_count - 1, 0)

func on_rift_closed(rift_number: int) -> void:
	rifts_closed += 1
	rift_closed_signal.emit(rift_number)

	if rifts_closed >= total_rifts:
		_set_process(GameProcess.VICTORY)
		Audio.play_victory()
		victory.emit()
	else:
		# Upgrade reward for closing a rift
		upgrade_available.emit()
		Audio.play_upgrade()

		if rifts_closed >= 3:
			_set_process(GameProcess.MID_GAME)

func trigger_game_over() -> void:
	is_game_over = true
	_set_process(GameProcess.GAME_OVER)
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	is_game_over = false
	boss_killed = false
	thrall_count = 0
	kill_count = 0
	rifts_closed = 0
	guaranteed_extractions = 2
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
	get_tree().paused = false
	get_tree().reload_current_scene()

func get_process_name() -> String:
	match current_process:
		GameProcess.EARLY_GAME:
			return "The Rift Opens"
		GameProcess.MID_GAME:
			return "Rifts Intensify"
		GameProcess.BOSS_FIGHT:
			return "Guardian Awakens"
		GameProcess.VICTORY:
			return "Rifts Sealed"
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
	var available := ALL_UPGRADES.duplicate()
	available.shuffle()
	var result: Array[Dictionary] = []
	for i in range(min(count, available.size())):
		result.append(available[i])
	return result

func _apply_health_upgrade() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		p.max_health += 30.0
		p.current_health += 30.0
		p.health_changed.emit(p.current_health, p.max_health)

func _set_process(new_process: GameProcess) -> void:
	if current_process == new_process:
		return
	current_process = new_process
	process_changed.emit(new_process)
