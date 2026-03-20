extends Node2D

## Random mid-run events that spawn after closing rifts.
## Types: shrine (buff), cursed chest (risk/reward), blessing altar (coin sacrifice), merchant.

enum EventType { SHRINE, CURSED_CHEST, BLESSING_ALTAR, MERCHANT, AMBUSH, TREASURE_HUNT, SURVIVAL_WAVE, NPC_RESCUE }

var event_type: EventType = EventType.SHRINE
var interacted: bool = false
var time: float = 0.0
var interact_range: float = 50.0
var prompt_visible: bool = false

# Merchant stock
var merchant_items: Array[Dictionary] = []
var merchant_selected: int = 0

func setup(type: EventType) -> void:
	event_type = type

func _ready() -> void:
	add_to_group("world_events")

func _process(delta: float) -> void:
	if interacted:
		return
	time += delta

	# Check player proximity
	prompt_visible = false
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var dist := global_position.distance_to(players[0].global_position)
		if dist < interact_range:
			prompt_visible = true

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if interacted or not prompt_visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()

func _interact() -> void:
	interacted = true
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]

	match event_type:
		EventType.SHRINE:
			_shrine_effect(player)
		EventType.CURSED_CHEST:
			_cursed_chest_effect(player)
		EventType.BLESSING_ALTAR:
			_blessing_effect(player)
		EventType.MERCHANT:
			_merchant_effect(player)
		EventType.AMBUSH:
			_ambush_effect(player)
		EventType.TREASURE_HUNT:
			_treasure_hunt_effect(player)
		EventType.SURVIVAL_WAVE:
			_survival_wave_effect(player)
		EventType.NPC_RESCUE:
			_npc_rescue_effect(player)

	# Fade out after interaction
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func _shrine_effect(player: Node2D) -> void:
	# Random beneficial effect
	var roll := randi() % 4
	match roll:
		0:  # Heal 40%
			if player.has_method("heal"):
				var heal_amount: float = player.max_health * 0.4
				player.heal(heal_amount)
			Game.spawn_damage_number(0, global_position + Vector2(0, -30), Color(0.3, 1.0, 0.4))
			_show_event_text("Healing Shrine")
		1:  # Damage boost
			Game.upgrade_attack_mult += 0.15
			_show_event_text("Shrine of Fury (+15% DMG)")
		2:  # Speed boost
			Game.upgrade_speed_mult += 0.15
			_show_event_text("Shrine of Haste (+15% Speed)")
		3:  # Thrall boost
			Game.upgrade_thrall_damage_mult += 0.15
			_show_event_text("Shrine of Command (+15% Thrall DMG)")
	Effects.spawn_particles(global_position, Color(0.3, 1.0, 0.5), 16, 0.5)
	Audio.play_upgrade()
	Game.request_shake(4.0)

func _cursed_chest_effect(player: Node2D) -> void:
	# Take damage but get guaranteed equipment drop
	var damage: float = player.max_health * 0.2
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position)
	# Guaranteed rare+ equipment
	var min_rarity = Equipment.Rarity.RARE if Game.current_world >= 2 else Equipment.Rarity.UNCOMMON
	var rarity := min_rarity
	if randf() < 0.3:
		rarity = mini(rarity + 1, Equipment.Rarity.LEGENDARY)
	var equip := Equipment.create_equipment(randi() % 6, rarity)
	Game.spawn_equip_drop(global_position, equip)
	_show_event_text("Cursed Chest!")
	Effects.spawn_particles(global_position, Color(0.8, 0.2, 0.1), 16, 0.5)
	Audio.play_hit_heavy()
	Game.request_shake(8.0)

func _blessing_effect(_player: Node2D) -> void:
	# Sacrifice coins for a permanent bonus
	var cost := 50 + Game.current_world * 25
	if SaveData.coins < cost:
		_show_event_text("Need %d coins" % cost)
		interacted = false
		return
	SaveData.coins -= cost
	# Random permanent buff
	var roll := randi() % 3
	match roll:
		0:
			Game.upgrade_extraction_bonus += 0.05
			_show_event_text("Blessed: +5%% Extraction")
		1:
			Game.upgrade_health_bonus += 15.0
			_show_event_text("Blessed: +15 Max HP")
		2:
			Game.upgrade_regen += 1.0
			_show_event_text("Blessed: +1 HP/sec Regen")
	Effects.spawn_level_up_burst(global_position)
	Audio.play_level_up()
	Game.request_shake(4.0)

func _merchant_effect(_player: Node2D) -> void:
	# Instant purchase: heal potion for coins
	var cost := 30 + Game.current_world * 10
	if SaveData.coins < cost:
		_show_event_text("Need %d coins" % cost)
		interacted = false
		return
	SaveData.coins -= cost
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("heal"):
		players[0].heal(players[0].max_health * 0.5)
	_show_event_text("Merchant: Full Heal!")
	Effects.spawn_particles(global_position, Color(1.0, 0.9, 0.3), 12, 0.4)
	Audio.play_ui_confirm()

func _ambush_effect(player: Node2D) -> void:
	# Spawn a ring of enemies around the player — survive for a reward
	_show_event_text("AMBUSH!")
	Game.request_shake(8.0)
	Audio.play_boss_enter()
	var EnemyScript := preload("res://scripts/enemy.gd")
	var scene := get_tree().current_scene
	if scene == null:
		return
	var count := 6 + Game.current_world * 2
	for i in range(count):
		var angle := float(i) / float(count) * TAU
		var pos := player.global_position + Vector2(cos(angle), sin(angle)) * 100.0
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		var types := ["melee", "ranged", "charger"]
		enemy.enemy_type = types[randi() % types.size()]
		enemy.global_position = pos
		scene.call_deferred("add_child", enemy)
	# Reward coins after a delay (assuming player survives)
	get_tree().create_timer(8.0).timeout.connect(func():
		if not Game.is_game_over:
			var bonus := 20 + Game.current_world * 15
			SaveData.add_coins(bonus)
			Game.spawn_damage_number(bonus, player.global_position + Vector2(0, -30), Color(1.0, 0.9, 0.3))
	)

func _treasure_hunt_effect(_player: Node2D) -> void:
	# Spawn 3 equipment drops scattered around the event location
	_show_event_text("Treasure Found!")
	Effects.spawn_level_up_burst(global_position)
	Audio.play_upgrade()
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in range(3):
		var angle := float(i) / 3.0 * TAU + randf() * 0.5
		var pos := global_position + Vector2(cos(angle), sin(angle)) * randf_range(30.0, 60.0)
		var min_rarity := mini(Game.current_world, Equipment.Rarity.EPIC)
		var rarity := clampi(randi() % 3 + min_rarity, 0, Equipment.Rarity.LEGENDARY)
		var equip := Equipment.create_equipment(randi() % 6, rarity)
		Game.spawn_equip_drop(pos, equip)

func _survival_wave_effect(player: Node2D) -> void:
	# Timed survival challenge: survive 15 seconds of intense spawns for big reward
	_show_event_text("Survive 15 seconds!")
	Game.request_shake(6.0)
	Audio.play_boss_enter()
	var EnemyScript := preload("res://scripts/enemy.gd")
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Spawn waves over 15 seconds
	for wave in range(5):
		get_tree().create_timer(float(wave) * 3.0).timeout.connect(func():
			if Game.is_game_over:
				return
			for j in range(4):
				var angle := randf() * TAU
				var pos := player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(150.0, 300.0)
				var enemy := CharacterBody2D.new()
				enemy.set_script(EnemyScript)
				enemy.enemy_type = ["melee", "ranged", "tank", "charger", "exploder"][randi() % 5]
				enemy.global_position = pos
				if scene and is_instance_valid(scene):
					scene.call_deferred("add_child", enemy)
		)
	# Reward at end
	get_tree().create_timer(15.0).timeout.connect(func():
		if not Game.is_game_over:
			var bonus := 50 + Game.current_world * 25
			SaveData.add_coins(bonus)
			Game.upgrade_available.emit()
			Game.spawn_damage_number(bonus, player.global_position + Vector2(0, -30), Color(1.0, 0.9, 0.3))
			_show_event_text("Survived! +Upgrade")
	)

func _npc_rescue_effect(player: Node2D) -> void:
	# Rescue NPC for a permanent thrall damage buff
	_show_event_text("Spirit Rescued! +10% Thrall DMG")
	Effects.spawn_particles(global_position, Color(0.3, 0.8, 1.0), 16, 0.5)
	Audio.play_level_up()
	Game.upgrade_thrall_damage_mult += 0.10
	# Also heal player as thanks
	if player.has_method("heal"):
		player.heal(player.max_health * 0.25)

func _show_event_text(text: String) -> void:
	var font := ThemeDB.fallback_font
	# Use damage number system to show floating text
	Game.spawn_damage_number(0, global_position + Vector2(0, -40), Color(1.0, 0.9, 0.3))
	# Also show as narrative in the game UI
	var ui_nodes := get_tree().get_nodes_in_group("game_ui")
	# Broadcast via a simple approach - just spawn a label
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-60, -50)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", -80.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)

func _draw() -> void:
	if interacted:
		return

	var pulse := 0.7 + 0.3 * sin(time * 3.0)

	match event_type:
		EventType.SHRINE:
			# Green glowing shrine
			draw_circle(Vector2.ZERO, 12.0, Color(0.2, 0.8, 0.4, 0.15 * pulse))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 12, Color(0.3, 0.9, 0.5, 0.5 * pulse), 2.0)
			# Cross/plus symbol
			draw_line(Vector2(0, -6), Vector2(0, 6), Color(0.3, 1.0, 0.5, 0.7), 2.0)
			draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.3, 1.0, 0.5, 0.7), 2.0)

		EventType.CURSED_CHEST:
			# Red glowing chest
			draw_rect(Rect2(-8, -6, 16, 12), Color(0.6, 0.1, 0.1, 0.4 * pulse))
			draw_rect(Rect2(-8, -6, 16, 12), Color(1.0, 0.3, 0.2, 0.6 * pulse), false, 1.5)
			# Lock symbol
			draw_arc(Vector2(0, -4), 3.0, PI, TAU + PI, 8, Color(1.0, 0.4, 0.2, 0.7), 1.5)

		EventType.BLESSING_ALTAR:
			# Golden altar
			draw_circle(Vector2.ZERO, 10.0, Color(0.9, 0.7, 0.2, 0.12 * pulse))
			draw_arc(Vector2.ZERO, 12.0, 0, TAU, 12, Color(1.0, 0.85, 0.3, 0.5 * pulse), 2.0)
			# Star
			for i in range(5):
				var angle := float(i) / 5.0 * TAU - PI / 2.0
				var tip := Vector2(cos(angle), sin(angle)) * 6.0
				draw_line(Vector2.ZERO, tip, Color(1.0, 0.9, 0.4, 0.7), 1.5)

		EventType.MERCHANT:
			# Blue merchant
			draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.4, 0.9, 0.12 * pulse))
			draw_arc(Vector2.ZERO, 12.0, 0, TAU, 12, Color(0.3, 0.5, 1.0, 0.5 * pulse), 2.0)
			# Coin symbol
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.3, 0.6))

		EventType.AMBUSH:
			# Red skull
			draw_circle(Vector2.ZERO, 10.0, Color(0.9, 0.1, 0.1, 0.15 * pulse))
			draw_arc(Vector2.ZERO, 12.0, 0, TAU, 12, Color(1.0, 0.2, 0.1, 0.5 * pulse), 2.0)
			draw_circle(Vector2(-3, -2), 2.0, Color(1.0, 0.3, 0.1, 0.7))
			draw_circle(Vector2(3, -2), 2.0, Color(1.0, 0.3, 0.1, 0.7))

		EventType.TREASURE_HUNT:
			# Gold chest with sparkle
			draw_rect(Rect2(-9, -7, 18, 14), Color(0.8, 0.6, 0.1, 0.4 * pulse))
			draw_rect(Rect2(-9, -7, 18, 14), Color(1.0, 0.85, 0.3, 0.6 * pulse), false, 1.5)
			for ti in range(3):
				var ta := float(ti) / 3.0 * TAU + time * 4.0
				var tp := Vector2(cos(ta), sin(ta)) * 8.0
				draw_circle(tp, 1.5, Color(1.0, 0.9, 0.4, 0.6 * pulse))

		EventType.SURVIVAL_WAVE:
			# Purple arena ring
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 16, Color(0.8, 0.2, 1.0, 0.4 * pulse), 2.0)
			draw_arc(Vector2.ZERO, 8.0, 0, TAU * pulse, 12, Color(0.6, 0.1, 0.9, 0.6), 1.5)

		EventType.NPC_RESCUE:
			# Blue spirit
			draw_circle(Vector2.ZERO, 8.0, Color(0.2, 0.5, 1.0, 0.2 * pulse))
			draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.7, 1.0, 0.4 * pulse))
			draw_circle(Vector2(0, -4), 3.0, Color(0.6, 0.8, 1.0, 0.5))

	# Floating particles
	for i in range(3):
		var angle := float(i) / 3.0 * TAU + time * 2.0
		var pos := Vector2(cos(angle), sin(angle)) * (16.0 + sin(time * 3.0 + float(i)) * 3.0)
		var pc := _get_event_color()
		draw_circle(pos, 1.5, Color(pc.r, pc.g, pc.b, 0.4 * pulse))

	# Interaction prompt
	if prompt_visible:
		var font := ThemeDB.fallback_font
		var label := "E: Interact"
		match event_type:
			EventType.SHRINE: label = "E: Touch Shrine"
			EventType.CURSED_CHEST: label = "E: Open Chest"
			EventType.BLESSING_ALTAR: label = "E: Pray (%d coins)" % (50 + Game.current_world * 25)
			EventType.MERCHANT: label = "E: Buy Heal (%d coins)" % (30 + Game.current_world * 10)
			EventType.AMBUSH: label = "E: Spring Trap"
			EventType.TREASURE_HUNT: label = "E: Open Treasure"
			EventType.SURVIVAL_WAVE: label = "E: Accept Challenge"
			EventType.NPC_RESCUE: label = "E: Rescue Spirit"
		draw_string(font, Vector2(-40, -22), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(1.0, 0.9, 0.6, pulse))

func _get_event_color() -> Color:
	match event_type:
		EventType.SHRINE: return Color(0.3, 1.0, 0.5)
		EventType.CURSED_CHEST: return Color(1.0, 0.3, 0.2)
		EventType.BLESSING_ALTAR: return Color(1.0, 0.85, 0.3)
		EventType.MERCHANT: return Color(0.3, 0.5, 1.0)
		EventType.AMBUSH: return Color(1.0, 0.2, 0.1)
		EventType.TREASURE_HUNT: return Color(1.0, 0.85, 0.3)
		EventType.SURVIVAL_WAVE: return Color(0.8, 0.2, 1.0)
		EventType.NPC_RESCUE: return Color(0.4, 0.7, 1.0)
	return Color.WHITE
