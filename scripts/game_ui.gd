extends CanvasLayer

## Game HUD: health bar, thrall count, kill count, game over screen.

@onready var health_bar: ProgressBar = $HealthBar
@onready var thrall_label: Label = $ThrallLabel
@onready var kill_label: Label = $KillLabel
@onready var process_label: Label = $ProcessLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_stats: Label = $GameOverPanel/StatsLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var arise_label: Label = $AriseLabel

var player: Node2D = null
var arise_timer: float = 0.0

func _ready() -> void:
	game_over_panel.visible = false
	arise_label.visible = false
	restart_button.pressed.connect(_on_restart)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)

	# Find player
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player.health_changed.connect(_on_health_changed)
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health

func _process(delta: float) -> void:
	thrall_label.text = "Thralls: %d" % Game.thrall_count
	kill_label.text = "Kills: %d" % Game.kill_count
	process_label.text = "Phase: %s" % Game.get_process_name()

	# Arise flash text
	if arise_timer > 0.0:
		arise_timer -= delta
		arise_label.modulate.a = arise_timer / 1.5
		if arise_timer <= 0.0:
			arise_label.visible = false

func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.value = current

func _on_game_over() -> void:
	game_over_panel.visible = true
	game_over_stats.text = "Enemies Slain: %d\nThralls Bound: %d" % [Game.kill_count, Game.thrall_count]

func _on_restart() -> void:
	Game.restart()

func _on_thrall_gained() -> void:
	arise_label.visible = true
	arise_label.text = "ARISE!"
	arise_label.modulate.a = 1.0
	arise_timer = 1.5
