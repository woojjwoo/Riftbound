extends CanvasLayer

## Game HUD with health bar, boss bar, upgrades, phase flash, victory screen.

@onready var health_bar: ProgressBar = $HealthBar
@onready var thrall_label: Label = $ThrallLabel
@onready var kill_label: Label = $KillLabel
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
@onready var dash_indicator: Label = $DashIndicator

var player: Node2D = null
var arise_timer: float = 0.0
var health_display: float = 100.0
var boss_health_display: float = 0.0

var current_upgrades: Array[Dictionary] = []

func _ready() -> void:
	game_over_panel.visible = false
	arise_label.visible = false
	boss_health_bar.visible = false
	boss_name_label.visible = false
	upgrade_panel.visible = false
	victory_panel.visible = false
	phase_flash.color = Color(1, 1, 1, 0)

	restart_button.pressed.connect(_on_restart)
	victory_restart.pressed.connect(_on_restart)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)
	Game.process_changed.connect(_on_process_changed)
	Game.upgrade_available.connect(_on_upgrade_available)
	Game.victory.connect(_on_victory)

	upgrade_btn1.pressed.connect(_on_upgrade_selected.bind(0))
	upgrade_btn2.pressed.connect(_on_upgrade_selected.bind(1))
	upgrade_btn3.pressed.connect(_on_upgrade_selected.bind(2))

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
	kill_label.text = "Kills: %d" % Game.kill_count
	process_label.text = "Phase: %s" % Game.get_process_name()

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

	# Dash cooldown indicator
	if player:
		if player.dash_cooldown_timer > 0:
			dash_indicator.text = "DASH [%.1fs]" % player.dash_cooldown_timer
			dash_indicator.modulate = Color(0.5, 0.5, 0.5)
		else:
			dash_indicator.text = "DASH [SPACE]"
			dash_indicator.modulate = Color(1.0, 1.0, 1.0)

func _on_health_changed(current: float, max_hp: float) -> void:
	pass  # Handled by smooth lerp in _process

func _on_game_over() -> void:
	game_over_panel.visible = true
	game_over_stats.text = "Enemies Slain: %d\nThralls Bound: %d" % [Game.kill_count, Game.thrall_count]
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
			flash_color = Color(1.0, 0.8, 0.2, 0.4)
			Audio.play_phase_change()
		Game.GameProcess.BOSS_FIGHT:
			flash_color = Color(1.0, 0.2, 0.2, 0.5)
			boss_health_bar.visible = true
			boss_name_label.visible = true
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

	upgrade_btn1.text = "%s\n%s" % [current_upgrades[0]["name"], current_upgrades[0]["desc"]]
	upgrade_btn2.text = "%s\n%s" % [current_upgrades[1]["name"], current_upgrades[1]["desc"]]
	upgrade_btn3.text = "%s\n%s" % [current_upgrades[2]["name"], current_upgrades[2]["desc"]]

	upgrade_panel.visible = true
	upgrade_panel.modulate.a = 0.0
	get_tree().paused = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(upgrade_panel, "modulate:a", 1.0, 0.3)

	Audio.play_upgrade()

func _on_upgrade_selected(index: int) -> void:
	if index < current_upgrades.size():
		current_upgrades[index]["apply"].call()
	upgrade_panel.visible = false
	get_tree().paused = false

func _on_victory() -> void:
	# Brief celebration before showing panel
	var delay_timer := get_tree().create_timer(1.5)
	delay_timer.timeout.connect(_show_victory_panel)

func _show_victory_panel() -> void:
	get_tree().paused = true
	victory_panel.visible = true
	victory_stats.text = "Enemies Slain: %d\nThralls Bound: %d\nThe Rift is sealed!" % [Game.kill_count, Game.thrall_count]
	victory_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(victory_panel, "modulate:a", 1.0, 0.8)

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
