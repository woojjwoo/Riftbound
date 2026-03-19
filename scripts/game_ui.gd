extends CanvasLayer

## Game HUD: health bar, thrall count, kill count, game over screen.
## Now includes boss health bar, phase transition flash, and smooth health bar.

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

var player: Node2D = null
var arise_timer: float = 0.0
var health_display: float = 100.0  # for smooth lerp
var boss_health_display: float = 0.0

func _ready() -> void:
	game_over_panel.visible = false
	arise_label.visible = false
	boss_health_bar.visible = false
	boss_name_label.visible = false
	phase_flash.color = Color(1, 1, 1, 0)
	restart_button.pressed.connect(_on_restart)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)
	Game.process_changed.connect(_on_process_changed)

	# Find player
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

	# Smooth health bar lerp
	health_display = lerp(health_display, float(health_bar.value), 8.0 * delta)
	health_bar.value = health_display

	# Arise flash text
	if arise_timer > 0.0:
		arise_timer -= delta
		arise_label.modulate.a = arise_timer / 1.5
		if arise_timer <= 0.0:
			arise_label.visible = false

	# Boss health bar tracking
	_update_boss_health_bar()

func _on_health_changed(current: float, max_hp: float) -> void:
	# Don't set directly — let the lerp handle smooth transition
	health_bar.value = current

func _on_game_over() -> void:
	game_over_panel.visible = true
	game_over_stats.text = "Enemies Slain: %d\nThralls Bound: %d" % [Game.kill_count, Game.thrall_count]
	# Fade in the panel
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
	# Scale pop on arise text
	arise_label.scale = Vector2(1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(arise_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_process_changed(new_process: Game.GameProcess) -> void:
	# Flash the screen on phase transitions
	var flash_color: Color
	match new_process:
		Game.GameProcess.MID_GAME:
			flash_color = Color(1.0, 0.8, 0.2, 0.4)
		Game.GameProcess.BOSS_FIGHT:
			flash_color = Color(1.0, 0.2, 0.2, 0.5)
			# Show boss health bar
			boss_health_bar.visible = true
			boss_name_label.visible = true
		Game.GameProcess.GAME_OVER:
			flash_color = Color(0.5, 0.0, 0.0, 0.6)
		_:
			return

	phase_flash.color = flash_color
	var tween := create_tween()
	if new_process == Game.GameProcess.GAME_OVER:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(phase_flash, "color:a", 0.0, 0.8)

	# Pulse the phase label
	process_label.scale = Vector2(1.4, 1.4)
	var label_tween := create_tween()
	if new_process == Game.GameProcess.GAME_OVER:
		label_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	label_tween.tween_property(process_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)

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
