extends CanvasLayer

## Game HUD: health, rift progress, controls overlay, upgrades, victory/death.
## Now includes coins, EXP, level, and world indicators.

@onready var health_bar: ProgressBar = $HealthBar
@onready var thrall_label: Label = $ThrallLabel
@onready var rift_label: Label = $RiftLabel
@onready var process_label: Label = $ProcessLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_stats: Label = $GameOverPanel/StatsLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var arise_label: Label = $AriseLabel
@onready var boss_health_bar: ProgressBar = $BossHealthBar
@onready var boss_name_label: Label = $BossNameLabel
@onready var phase_flash: ColorRect = $PhaseFlash
@onready var upgrade_panel: Panel = $UpgradePanel
@onready var upgrade_btn1: Button = $UpgradePanel/UpgradeBtn1
@onready var upgrade_btn2: Button = $UpgradePanel/UpgradeBtn2
@onready var upgrade_btn3: Button = $UpgradePanel/UpgradeBtn3
@onready var upgrade_title: Label = $UpgradePanel/UpgradeTitle
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_stats: Label = $VictoryPanel/VictoryStats
@onready var victory_restart: Button = $VictoryPanel/VictoryRestart
@onready var controls_label: Label = $ControlsLabel
@onready var command_hint: Label = $CommandHint
@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/ResumeButton
@onready var pause_restart_button: Button = $PausePanel/PauseRestartButton
@onready var active_upgrades_label: Label = $ActiveUpgradesLabel
@onready var coin_label: Label = $CoinLabel
@onready var exp_label: Label = $ExpLabel
@onready var world_label: Label = $WorldLabel

var player: Node2D = null
var arise_timer: float = 0.0
var health_display: float = 120.0
var boss_health_display: float = 0.0
var is_paused: bool = false

var current_upgrades: Array[Dictionary] = []
var controls_timer: float = 8.0  # show controls for 8 seconds

func _ready() -> void:
	Audio.start_music()
	game_over_panel.visible = false
	arise_label.visible = false
	boss_health_bar.visible = false
	boss_name_label.visible = false
	upgrade_panel.visible = false
	victory_panel.visible = false
	phase_flash.color = Color(1, 1, 1, 0)
	controls_label.visible = true
	controls_label.modulate.a = 1.0

	pause_panel.visible = false
	restart_button.pressed.connect(_on_restart)
	victory_restart.pressed.connect(_on_restart)
	resume_button.pressed.connect(_on_resume)
	pause_restart_button.pressed.connect(_on_restart)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)
	Game.process_changed.connect(_on_process_changed)
	Game.upgrade_available.connect(_on_upgrade_available)
	Game.victory.connect(_on_victory)

	upgrade_btn1.pressed.connect(_on_upgrade_selected.bind(0))
	upgrade_btn2.pressed.connect(_on_upgrade_selected.bind(1))
	upgrade_btn3.pressed.connect(_on_upgrade_selected.bind(2))

	# Hover effects for upgrade buttons
	for btn in [upgrade_btn1, upgrade_btn2, upgrade_btn3]:
		btn.mouse_entered.connect(_on_upgrade_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_upgrade_hover.bind(btn, false))

	# Set world label
	var config := Game.get_world_config()
	world_label.text = "World %d: %s" % [Game.current_world + 1, config.get("name", "Unknown")]

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player.health_changed.connect(_on_health_changed)
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
		health_display = player.current_health

func _process(delta: float) -> void:
	thrall_label.text = "Thralls: %d" % Game.thrall_count
	rift_label.text = "Rifts: %d / %d" % [Game.rifts_closed, Game.total_rifts]
	process_label.text = Game.get_process_name()

	# Coins and EXP
	coin_label.text = "Coins: %d" % SaveData.coins
	exp_label.text = "Lv.%d  EXP: %d/%d" % [SaveData.player_level, SaveData.exp_points, SaveData.exp_to_next_level]

	# Smooth health bar
	if player:
		health_bar.max_value = player.max_health
		health_display = lerp(health_display, float(player.current_health), 8.0 * delta)
		health_bar.value = health_display

	# Arise text
	if arise_timer > 0.0:
		arise_timer -= delta
		arise_label.modulate.a = arise_timer / 1.5
		if arise_timer <= 0.0:
			arise_label.visible = false

	# Boss health bar
	_update_boss_health_bar()

	# Controls overlay fade
	if controls_timer > 0.0:
		controls_timer -= delta
		if controls_timer <= 2.0:
			controls_label.modulate.a = controls_timer / 2.0
		if controls_timer <= 0.0:
			controls_label.visible = false

	# Command hint — show thrall count context
	if Game.thrall_count == 0:
		command_hint.text = "Kill enemies nearby to extract thralls"
	else:
		command_hint.text = "RMB: Command Thralls  |  R: Recall"

func _on_health_changed(current: float, _max_hp: float) -> void:
	health_display = current

func _on_game_over() -> void:
	game_over_panel.visible = true
	game_over_stats.text = "World: %s\nRifts Sealed: %d / %d\nEnemies Slain: %d\nThralls Bound: %d\nCoins: %d" % [
		Game.get_world_config().get("name", "Unknown"),
		Game.rifts_closed, Game.total_rifts, Game.kill_count, Game.thrall_count, SaveData.coins]
	game_over_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.5)

func _on_restart() -> void:
	Game.restart()

func _on_thrall_gained() -> void:
	arise_label.visible = true
	arise_label.text = "ARISE!"
	arise_label.modulate.a = 1.0
	arise_timer = 1.5
	arise_label.scale = Vector2(1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(arise_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_process_changed(new_process: Game.GameProcess) -> void:
	var flash_color: Color
	match new_process:
		Game.GameProcess.MID_GAME:
			flash_color = Color(0.6, 0.3, 0.9, 0.4)
			Audio.play_phase_change()
		Game.GameProcess.BOSS_FIGHT:
			flash_color = Color(1.0, 0.2, 0.2, 0.5)
			boss_health_bar.visible = true
			boss_name_label.visible = true
			boss_name_label.text = Game.get_world_config().get("boss_name", "Rift Guardian")
		Game.GameProcess.VICTORY:
			flash_color = Color(0.2, 1.0, 0.5, 0.4)
		Game.GameProcess.GAME_OVER:
			flash_color = Color(0.5, 0.0, 0.0, 0.6)
		_:
			return

	phase_flash.color = flash_color
	var tween := create_tween()
	if new_process == Game.GameProcess.GAME_OVER:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(phase_flash, "color:a", 0.0, 0.8)

	process_label.scale = Vector2(1.4, 1.4)
	var label_tween := create_tween()
	if new_process == Game.GameProcess.GAME_OVER:
		label_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	label_tween.tween_property(process_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)

func _on_upgrade_available() -> void:
	current_upgrades = Game.get_random_upgrades(3)
	if current_upgrades.is_empty():
		return
	upgrade_title.text = "RIFT SEALED — CHOOSE AN UPGRADE"
	var buttons := [upgrade_btn1, upgrade_btn2, upgrade_btn3]
	for i in range(3):
		if i < current_upgrades.size():
			buttons[i].text = "%s\n%s" % [current_upgrades[i]["name"], current_upgrades[i]["desc"]]
			buttons[i].visible = true
		else:
			buttons[i].visible = false

	upgrade_panel.visible = true
	upgrade_panel.modulate.a = 0.0
	get_tree().paused = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(upgrade_panel, "modulate:a", 1.0, 0.3)

func _on_upgrade_selected(index: int) -> void:
	if index < current_upgrades.size():
		current_upgrades[index]["apply"].call()
		Game.apply_upgrade(current_upgrades[index]["name"])
		_update_active_upgrades()
	upgrade_panel.visible = false
	get_tree().paused = false

func _on_victory() -> void:
	# Don't show victory panel — portal handles progression now
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not Game.is_game_over:
		if upgrade_panel.visible or victory_panel.visible:
			return
		if is_paused:
			_on_resume()
		else:
			_on_pause()

func _on_pause() -> void:
	is_paused = true
	get_tree().paused = true
	pause_panel.visible = true
	pause_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(pause_panel, "modulate:a", 1.0, 0.2)

func _on_resume() -> void:
	is_paused = false
	pause_panel.visible = false
	get_tree().paused = false

func _on_upgrade_hover(btn: Button, hovered: bool) -> void:
	if hovered:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
		btn.modulate = Color(1.2, 1.2, 1.0)
	else:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		btn.modulate = Color.WHITE

func _update_active_upgrades() -> void:
	if Game.chosen_upgrades.is_empty():
		active_upgrades_label.visible = false
	else:
		active_upgrades_label.visible = true
		active_upgrades_label.text = "Upgrades: " + ", ".join(Game.chosen_upgrades)

func _update_boss_health_bar() -> void:
	if not boss_health_bar.visible:
		return
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		var boss := bosses[0]
		boss_health_bar.max_value = boss.max_health
		boss_health_display = lerp(boss_health_display, float(boss.current_health), 8.0 * get_process_delta_time())
		boss_health_bar.value = boss_health_display
	else:
		boss_health_bar.visible = false
		boss_name_label.visible = false
