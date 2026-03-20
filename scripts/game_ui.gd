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
@onready var pause_settings_button: Button = $PausePanel/PauseSettingsButton
@onready var pause_restart_button: Button = $PausePanel/PauseRestartButton
@onready var active_upgrades_label: Label = $ActiveUpgradesLabel
@onready var coin_label: Label = $CoinLabel
@onready var exp_label: Label = $ExpLabel
@onready var world_label: Label = $WorldLabel
@onready var damage_vignette: ColorRect = $DamageVignette

var player: Node2D = null
var arise_timer: float = 0.0
var health_display: float = 120.0
var boss_health_display: float = 0.0
var is_paused: bool = false
var inventory_open: bool = false

var current_upgrades: Array[Dictionary] = []
var controls_timer: float = 8.0  # show controls for 8 seconds
var narrative_timer: float = 0.0
var narrative_text: String = ""

# Equipment HUD overlay — draws equipped items in bottom-right corner
var equip_hud: Control = null

## XP bar (created in code)
var xp_bar: ProgressBar = null
var level_label: Label = null

## Ability UI nodes (created in code)
var ability_select_ui: Node = null
var ability_cooldown_ui: Node = null

## Queue of pending level-ups waiting for ability selection
var pending_level_ups: int = 0

func _ready() -> void:
	Audio.start_music(Game.current_world)
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
	pause_settings_button.pressed.connect(_on_pause_settings)
	pause_restart_button.pressed.connect(_on_restart)
	Game.game_over.connect(_on_game_over)
	Game.thrall_gained.connect(_on_thrall_gained)
	Game.process_changed.connect(_on_process_changed)
	Game.upgrade_available.connect(_on_upgrade_available)
	Game.victory.connect(_on_victory)
	Game.xp_changed.connect(_on_xp_changed)
	Game.level_up.connect(_on_level_up)

	upgrade_btn1.pressed.connect(_on_upgrade_selected.bind(0))
	upgrade_btn2.pressed.connect(_on_upgrade_selected.bind(1))
	upgrade_btn3.pressed.connect(_on_upgrade_selected.bind(2))

	# Hover effects for upgrade buttons
	for btn in [upgrade_btn1, upgrade_btn2, upgrade_btn3]:
		btn.mouse_entered.connect(_on_upgrade_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_upgrade_hover.bind(btn, false))

	# Set world label and show intro narrative
	var config := Game.get_world_config()
	world_label.text = "World %d: %s" % [Game.current_world + 1, config.get("name", "Unknown")]
	_show_narrative(config.get("intro", ""), 6.0)

	# Equipment HUD overlay
	_setup_equip_hud()
	SaveData.equipment_changed.connect(_on_equipment_changed)

	# XP bar and ability UI
	_create_xp_bar()
	_create_ability_ui()

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player.health_changed.connect(_on_health_changed)
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
		health_display = player.current_health
		# Connect ability cooldown UI to the player's ability manager
		if player.ability_manager and ability_cooldown_ui:
			ability_cooldown_ui.setup(player.ability_manager)

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

	# Narrative text fade
	if narrative_timer > 0.0:
		narrative_timer -= delta
		arise_label.visible = true
		arise_label.text = narrative_text
		if narrative_timer <= 2.0:
			arise_label.modulate.a = narrative_timer / 2.0
		if narrative_timer <= 0.0:
			arise_label.visible = false

	# Command hint — show thrall count context
	if Game.thrall_count == 0:
		command_hint.text = "Kill enemies nearby to extract thralls"
	else:
		command_hint.text = "RMB: Command Thralls  |  R: Recall"

func _on_health_changed(current: float, _max_hp: float) -> void:
	# Damage vignette flash when health decreases
	if current < health_display:
		damage_vignette.color = Color(0.8, 0.0, 0.0, 0.25)
		var vignette_tween := create_tween()
		vignette_tween.tween_property(damage_vignette, "color:a", 0.0, 0.4)
	health_display = current

func _on_game_over() -> void:
	game_over_panel.visible = true
	# Calculate Soul Essence earned this run
	var essence_earned := Meta.calculate_run_essence(
		Game.kill_count, Game.run_worlds_cleared, Game.run_bosses_killed)
	var essence_text := ""
	if essence_earned > 0:
		essence_text = "\nSoul Essence Earned: +%d" % essence_earned
	game_over_stats.text = "World: %s\nRifts Sealed: %d / %d\nEnemies Slain: %d\nThralls Bound: %d\nCoins: %d%s" % [
		Game.get_world_config().get("name", "Unknown"),
		Game.rifts_closed, Game.total_rifts, Game.kill_count, Game.thrall_count, SaveData.coins,
		essence_text]
	game_over_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.5)

func _on_restart() -> void:
	Audio.play_ui_click()
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
			_show_narrative(Game.get_world_config().get("mid_text", ""), 4.0)
		Game.GameProcess.BOSS_FIGHT:
			flash_color = Color(1.0, 0.2, 0.2, 0.5)
			boss_health_bar.visible = true
			boss_name_label.visible = true
			boss_name_label.text = Game.get_world_config().get("boss_name", "Rift Guardian")
			_show_narrative(Game.get_world_config().get("boss_taunt", ""), 5.0)
		Game.GameProcess.VICTORY:
			flash_color = Color(0.2, 1.0, 0.5, 0.4)
			_show_narrative(Game.get_world_config().get("victory_text", ""), 5.0)
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
		Audio.play_ui_confirm()
	upgrade_panel.visible = false
	get_tree().paused = false

func _on_victory() -> void:
	# Don't show victory panel — portal handles progression now
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if not Game.is_game_over and not inventory_open:
			if upgrade_panel.visible or victory_panel.visible:
				return
			_open_inventory()
			return

	if event.is_action_pressed("pause") and not Game.is_game_over:
		if upgrade_panel.visible or victory_panel.visible:
			return
		if inventory_open:
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

func _on_pause_settings() -> void:
	Audio.play_ui_click()
	var settings := CanvasLayer.new()
	settings.set_script(preload("res://scripts/settings_screen.gd"))
	settings.closed.connect(func(): settings.queue_free())
	add_child(settings)

func _open_inventory() -> void:
	inventory_open = true
	get_tree().paused = true
	var inv_scene := load("res://scenes/inventory_screen.tscn")
	var inv_instance := inv_scene.instantiate()
	inv_instance.tree_exited.connect(_on_inventory_closed)
	get_tree().current_scene.add_child(inv_instance)

func _on_inventory_closed() -> void:
	inventory_open = false
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

func _show_narrative(text: String, duration: float = 4.0) -> void:
	if text.is_empty():
		return
	narrative_text = text
	narrative_timer = duration
	arise_label.visible = true
	arise_label.text = text
	arise_label.modulate.a = 1.0
	arise_label.scale = Vector2(1.0, 1.0)

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

# --- XP Bar and Ability UI ---

func _create_xp_bar() -> void:
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.offset_left = 20.0
	xp_bar.offset_top = 42.0
	xp_bar.offset_right = 220.0
	xp_bar.offset_bottom = 52.0
	xp_bar.max_value = Game.xp_to_next_level
	xp_bar.value = Game.current_xp
	xp_bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.6, 0.3, 1.0)
	fill_style.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.2)
	bg_style.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("background", bg_style)
	add_child(xp_bar)
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.offset_left = 225.0
	level_label.offset_top = 38.0
	level_label.offset_right = 320.0
	level_label.offset_bottom = 55.0
	level_label.text = "Lv.1"
	add_child(level_label)

func _create_ability_ui() -> void:
	var ability_select_path := "res://scripts/ability_select_ui.gd"
	if ResourceLoader.exists(ability_select_path):
		var AbilitySelectScript := preload("res://scripts/ability_select_ui.gd")
		ability_select_ui = AbilitySelectScript.new()
		ability_select_ui.name = "AbilitySelectUI"
		ability_select_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		ability_select_ui.ability_chosen.connect(_on_ability_chosen)
		add_child(ability_select_ui)
	var ability_cd_path := "res://scripts/ability_cooldown_ui.gd"
	if ResourceLoader.exists(ability_cd_path):
		var AbilityCooldownScript := preload("res://scripts/ability_cooldown_ui.gd")
		ability_cooldown_ui = AbilityCooldownScript.new()
		ability_cooldown_ui.name = "AbilityCooldownUI"
		add_child(ability_cooldown_ui)

func _on_xp_changed(current: int, needed: int) -> void:
	if xp_bar:
		xp_bar.max_value = needed
		xp_bar.value = current

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv.%d" % new_level
	pending_level_ups += 1
	if pending_level_ups == 1:
		_show_next_ability_selection()

func _show_next_ability_selection() -> void:
	if pending_level_ups <= 0:
		return
	if ability_select_ui and player and player.ability_manager:
		ability_select_ui.show_selection(player.ability_manager)

func _on_ability_chosen(id: String) -> void:
	if player and player.ability_manager:
		player.ability_manager.unlock_ability(id)
		var level: int = player.ability_manager.get_ability_level(id)
		if ability_cooldown_ui:
			ability_cooldown_ui.update_level(id, level)
	pending_level_ups -= 1
	if pending_level_ups > 0:
		_show_next_ability_selection()

# --- Equipment HUD Overlay ---

func _setup_equip_hud() -> void:
	equip_hud = Control.new()
	equip_hud.name = "EquipHUD"
	equip_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip_hud.draw.connect(_draw_equip_hud)
	add_child(equip_hud)

func _on_equipment_changed() -> void:
	if equip_hud:
		equip_hud.queue_redraw()

func _draw_equip_hud() -> void:
	# Layout: 2 columns x 3 rows of equipment slots, bottom-right corner
	var slot_size := 20.0      # diamond radius
	var cell_w := 50.0         # horizontal spacing per slot
	var cell_h := 28.0         # vertical spacing per slot
	var cols := 3
	var rows := 2
	var panel_w := cols * cell_w + 12.0
	var panel_h := rows * cell_h + 28.0
	var margin := 10.0
	var screen_w := equip_hud.get_viewport_rect().size.x
	var screen_h := equip_hud.get_viewport_rect().size.y
	var panel_x := screen_w - panel_w - margin
	var panel_y := screen_h - panel_h - margin

	# Panel background
	var bg_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	equip_hud.draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.3))
	equip_hud.draw_rect(bg_rect, Color(0.5, 0.5, 0.5, 0.15), false, 1.0)

	# Title
	var title_pos := Vector2(panel_x + 6.0, panel_y + 12.0)
	equip_hud.draw_string(ThemeDB.fallback_font, title_pos, "Equip", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.7, 0.6))

	# Slot layout: top row [0,1,2], bottom row [3,4,5]
	# Slots: GRIMOIRE, ROBES, AMULET, RING, BOOTS, CROWN
	var slot_names := ["Grm", "Rbs", "Aml", "Rng", "Bts", "Crn"]
	var start_x := panel_x + 6.0 + cell_w * 0.5
	var start_y := panel_y + 24.0 + cell_h * 0.5

	for i in range(6):
		var col := i % cols
		var row := i / cols
		var cx := start_x + col * cell_w
		var cy := start_y + row * cell_h
		var center := Vector2(cx, cy)
		var item: Dictionary = SaveData.equipped[i]

		if item.is_empty():
			# Empty slot: dim diamond outline
			_draw_diamond_outline(center, 7.0, Color(0.4, 0.4, 0.4, 0.3))
		else:
			# Filled slot: colored diamond by rarity
			var rarity_color: Color = Equipment.get_rarity_color(item["rarity"])
			_draw_diamond_filled(center, 7.0, rarity_color)
			# Upgrade level text
			var level: int = item["level"]
			var level_text := "+%d" % level
			var level_color := Color(1.0, 1.0, 1.0, 0.7) if level == 0 else Color(1.0, 0.9, 0.4, 0.9)
			equip_hud.draw_string(ThemeDB.fallback_font, Vector2(cx + 9.0, cy + 4.0), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, level_color)

func _draw_diamond_filled(center: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size * 0.7, 0),
		center + Vector2(0, size),
		center + Vector2(-size * 0.7, 0),
	])
	equip_hud.draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.75))
	# Small highlight
	equip_hud.draw_circle(center + Vector2(-1, -2), 2.0, Color(1.0, 1.0, 1.0, 0.35))

func _draw_diamond_outline(center: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size * 0.7, 0),
		center + Vector2(0, size),
		center + Vector2(-size * 0.7, 0),
		center + Vector2(0, -size),  # close the loop
	])
	equip_hud.draw_polyline(pts, color, 1.0)
