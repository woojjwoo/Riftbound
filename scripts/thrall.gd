extends CharacterBody2D

## Thrall with command system, HP, death, and type-specific abilities.
## FOLLOW player or move to COMMANDED position.
## Can attack rifts when commanded to them.
## Type abilities:
##   melee: lifesteal on attack
##   ranged/flying: ranged projectiles, AoE every 3rd shot
##   tank/shielded: taunt pull, damage reduction
##   charger: charge dash at enemies
##   exploder: self-destruct at low HP for big AOE
##   splitter: double-strike attacks
##   summoner/voidcaller: buff aura for nearby thralls
##   poisoner: poison DOT on attack
##   teleporter: blink behind enemies

enum ThrallMode { FOLLOW, COMMANDED }

var thrall_type: String = "melee"
var leader: Node2D = null
var mode: ThrallMode = ThrallMode.FOLLOW
var is_dying: bool = false

# HP
var max_health: float = 30.0
var current_health: float = 30.0
var knockback_velocity_thrall: Vector2 = Vector2.ZERO

# Command
var command_target_pos: Vector2 = Vector2.ZERO
var command_entity: Node2D = null

# Stats
var follow_speed: float = 180.0
var follow_distance: float = 60.0
var attack_range: float = 60.0
var attack_damage: float = 15.0
var attack_cooldown: float = 0.8

var attack_timer: float = 0.0
var current_target: Node2D = null
var formation_index: int = 0

# Abilities
var attack_count: int = 0
var ability_timer: float = 0.0
var taunt_cooldown: float = 5.0
var taunt_radius: float = 120.0

# Charger state
var _charge_state: int = 0  # 0=normal, 1=windup, 2=charging
var _charge_timer: float = 3.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_elapsed: float = 0.0

# Exploder state
var _explode_triggered: bool = false

# Teleporter state
var _blink_timer: float = 2.0

# Buff aura (summoner/voidcaller)
var _buff_timer: float = 4.0
var _buff_radius: float = 100.0

@export var projectile_scene: PackedScene

var sprite_idle: Texture2D
var sprite_run: Texture2D

@onready var sprite: Sprite2D = $Sprite

func setup(player: Node2D, type: String) -> void:
	leader = player
	thrall_type = type
	add_to_group("thralls")

	match type:
		"melee":
			attack_range = 50.0
			attack_damage = 15.0
			attack_cooldown = 0.8
			follow_speed = 190.0
			max_health = 30.0
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
		"ranged", "flying":
			attack_range = 150.0
			attack_damage = 10.0
			attack_cooldown = 1.2
			follow_speed = 160.0
			max_health = 20.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		"tank", "shielded":
			attack_range = 50.0
			attack_damage = 8.0
			attack_cooldown = 1.5
			follow_speed = 140.0
			max_health = 50.0
			scale *= 1.3
			sprite_idle = load("res://sprites/skeleton_warrior/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_warrior/Run-Sheet.png")
		"charger":
			attack_range = 60.0
			attack_damage = 20.0
			attack_cooldown = 2.0
			follow_speed = 200.0
			max_health = 35.0
			sprite_idle = load("res://sprites/skeleton_warrior/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_warrior/Run-Sheet.png")
		"exploder":
			attack_range = 70.0
			attack_damage = 12.0
			attack_cooldown = 1.0
			follow_speed = 190.0
			max_health = 25.0
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
		"splitter":
			attack_range = 50.0
			attack_damage = 12.0
			attack_cooldown = 0.9
			follow_speed = 180.0
			max_health = 25.0
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
		"summoner", "voidcaller":
			attack_range = 130.0
			attack_damage = 8.0
			attack_cooldown = 1.5
			follow_speed = 155.0
			max_health = 25.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		"poisoner":
			attack_range = 100.0
			attack_damage = 10.0
			attack_cooldown = 1.0
			follow_speed = 165.0
			max_health = 25.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		"teleporter":
			attack_range = 60.0
			attack_damage = 16.0
			attack_cooldown = 1.0
			follow_speed = 200.0
			max_health = 25.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		_:
			attack_range = 50.0
			attack_damage = 15.0
			attack_cooldown = 0.8
			follow_speed = 190.0
			max_health = 30.0
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
	max_health += SaveData.perm_thrall_health
	current_health = max_health
	# Assign formation index based on current thrall count
	formation_index = get_tree().get_nodes_in_group("thralls").size()

func _ready() -> void:
	sprite.modulate = Color(0.4, 1.0, 0.9, 1.0)
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

func command_to(pos: Vector2, entity: Node2D = null) -> void:
	mode = ThrallMode.COMMANDED
	command_target_pos = pos
	command_entity = entity
	sprite.modulate = Color(1.0, 0.8, 0.4)  # golden when commanded

func recall() -> void:
	mode = ThrallMode.FOLLOW
	command_entity = null
	# Flash + scale pulse on recall
	sprite.modulate = Color(2.0, 2.0, 2.0)
	sprite.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(0.4, 1.0, 0.9), 0.25)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
	current_health -= amount
	if from_pos != Vector2.ZERO:
		knockback_velocity_thrall = (global_position - from_pos).normalized() * 100.0
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	var base_color := Color(1.0, 0.8, 0.4) if mode == ThrallMode.COMMANDED else Color(0.4, 1.0, 0.9)
	tween.tween_property(sprite, "modulate", base_color, 0.1)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	is_dying = true
	remove_from_group("thralls")
	Game.on_thrall_lost()
	Audio.play_thrall_death()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.4)
	tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if Game.is_game_over or leader == null or is_dying:
		return

	attack_timer -= delta
	ability_timer -= delta

	# Find target based on mode
	match mode:
		ThrallMode.FOLLOW:
			_find_target_near(leader.global_position, attack_range * 2.0, false)
		ThrallMode.COMMANDED:
			if command_entity and is_instance_valid(command_entity):
				current_target = command_entity
			else:
				command_entity = null
				_find_target_near(command_target_pos, attack_range * 2.5, true)

	# Attack
	if current_target and is_instance_valid(current_target) and attack_timer <= 0.0:
		var dist := global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			_do_attack()
			attack_timer = attack_cooldown

	# Type-specific abilities
	match thrall_type:
		"tank", "shielded":
			if ability_timer <= 0.0:
				_taunt()
				ability_timer = taunt_cooldown
		"charger":
			_process_charger_ability(delta)
		"exploder":
			_check_explode_threshold()
		"teleporter":
			_process_blink(delta)
		"summoner", "voidcaller":
			_process_buff_aura(delta)

	# Movement
	var effective_speed := follow_speed * Game.upgrade_thrall_speed_mult
	var move_dir := Vector2.ZERO

	match mode:
		ThrallMode.FOLLOW:
			if current_target and is_instance_valid(current_target):
				var dist_to_leader := global_position.distance_to(leader.global_position)
				var dist_to_target := global_position.distance_to(current_target.global_position)
				if dist_to_leader > follow_distance * 3.0:
					move_dir = global_position.direction_to(leader.global_position)
				elif thrall_type == "ranged" and dist_to_target <= attack_range:
					move_dir = Vector2.ZERO
				else:
					move_dir = global_position.direction_to(current_target.global_position)
			else:
				# Use formation positioning
				var thralls := get_tree().get_nodes_in_group("thralls")
				var total := thralls.size()
				var facing := leader.velocity.normalized() if leader.velocity.length() > 10 else Vector2.DOWN
				var target_pos := leader.global_position + Game.get_formation_offset(formation_index, total, facing)
				var dist := global_position.distance_to(target_pos)
				if dist > 15.0:
					move_dir = global_position.direction_to(target_pos)

		ThrallMode.COMMANDED:
			if current_target and is_instance_valid(current_target):
				var dist := global_position.distance_to(current_target.global_position)
				if thrall_type == "ranged" and dist <= attack_range:
					move_dir = Vector2.ZERO
				elif dist > attack_range * 0.8:
					move_dir = global_position.direction_to(current_target.global_position)
			else:
				var dist := global_position.distance_to(command_target_pos)
				if dist > 20.0:
					move_dir = global_position.direction_to(command_target_pos)

	knockback_velocity_thrall = knockback_velocity_thrall.lerp(Vector2.ZERO, 8.0 * delta)
	velocity = move_dir * effective_speed + knockback_velocity_thrall
	move_and_slide()

	# Animation
	if move_dir.length() > 0.1:
		sprite.flip_h = move_dir.x < 0
	if velocity.length() > 10 and sprite_run:
		sprite.texture = sprite_run
	elif sprite_idle:
		sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 100) % 6

	queue_redraw()

func _find_target_near(center: Vector2, search_range: float, include_rifts: bool) -> void:
	current_target = null
	var closest_dist := search_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_dying"):
			continue
		var dist := center.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			current_target = enemy

	# In COMMANDED mode, also consider rifts as targets
	if include_rifts:
		for rift in get_tree().get_nodes_in_group("rifts"):
			var dist := center.distance_to(rift.global_position)
			if dist < closest_dist:
				closest_dist = dist
				current_target = rift

func _do_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return

	var ring_bonus := SaveData.get_equip_bonus(Equipment.Slot.RING)
	var effective_damage := attack_damage * Game.upgrade_thrall_damage_mult * (1.0 + SaveData.perm_thrall_damage + ring_bonus)
	attack_count += 1
	var is_enemy := current_target.is_in_group("enemies")

	# Ranged thralls shoot projectiles at enemies, but attack rifts directly
	if thrall_type in ["ranged", "flying"] and projectile_scene and is_enemy:
		var dir := global_position.direction_to(current_target.global_position)
		var proj := projectile_scene.instantiate()
		proj.global_position = global_position
		proj.setup(dir, effective_damage, "enemies")
		var scene := get_tree().current_scene
		if scene:
			scene.add_child(proj)
		# AoE every 3rd shot
		if attack_count % 3 == 0:
			_aoe_attack(effective_damage)
	else:
		# Splitter: double-strike (attack twice)
		var strikes := 2 if thrall_type == "splitter" else 1
		for _i in range(strikes):
			if current_target and is_instance_valid(current_target) and current_target.has_method("take_damage"):
				var strike_dmg := effective_damage * (0.7 if thrall_type == "splitter" else 1.0)
				current_target.take_damage(strike_dmg)
				var dmg_color := Color(0.8, 0.4, 1.0) if not is_enemy else Color(0.4, 1.0, 0.9)
				Game.spawn_damage_number(strike_dmg, current_target.global_position, dmg_color)

		# Melee lifesteal on enemies only
		if thrall_type == "melee" and is_enemy and leader and leader.has_method("heal"):
			var heal_amount := effective_damage * 0.15
			leader.heal(heal_amount)

		# Poisoner: apply poison DOT on attack
		if thrall_type == "poisoner" and is_enemy and current_target.has_method("apply_burn"):
			current_target.apply_burn(3.0, 2.5)  # 3 dps for 2.5s

func _aoe_attack(damage: float) -> void:
	var aoe_range := 60.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == current_target:
			continue
		if global_position.distance_to(enemy.global_position) < aoe_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.5)
				Game.spawn_damage_number(damage * 0.5, enemy.global_position, Color(0.6, 0.4, 1.0))
	var scene := get_tree().current_scene
	if scene == null:
		return
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
	vfx.set("max_radius", aoe_range)
	scene.add_child(vfx)

func _taunt() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < taunt_radius:
			if not enemy.get("is_dying") and enemy.has_method("take_damage"):
				var pull_dir := enemy.global_position.direction_to(global_position)
				enemy.knockback_velocity = pull_dir * 80.0
	sprite.modulate = Color(1.0, 0.8, 0.3)
	var tween := create_tween()
	var base_color := Color(1.0, 0.8, 0.4) if mode == ThrallMode.COMMANDED else Color(0.4, 1.0, 0.9)
	tween.tween_property(sprite, "modulate", base_color, 0.3)

## Charger thrall: dash at target periodically
func _process_charger_ability(delta: float) -> void:
	_charge_timer -= delta
	match _charge_state:
		0:  # Normal — wait for cooldown
			if _charge_timer <= 0.0 and current_target and is_instance_valid(current_target):
				var dist := global_position.distance_to(current_target.global_position)
				if dist < 200.0 and dist > 40.0:
					_charge_state = 1
					_charge_elapsed = 0.0
					_charge_dir = global_position.direction_to(current_target.global_position)
					sprite.modulate = Color(1.5, 0.8, 0.4)
		1:  # Windup (0.3s)
			_charge_elapsed += delta
			velocity = Vector2.ZERO
			if _charge_elapsed >= 0.3:
				_charge_state = 2
				_charge_elapsed = 0.0
				if current_target and is_instance_valid(current_target):
					_charge_dir = global_position.direction_to(current_target.global_position)
		2:  # Charging
			_charge_elapsed += delta
			velocity = _charge_dir * follow_speed * 3.5
			move_and_slide()
			if _charge_elapsed >= 0.35:
				_charge_state = 0
				_charge_timer = 3.0
				var base_color := Color(1.0, 0.8, 0.4) if mode == ThrallMode.COMMANDED else Color(0.4, 1.0, 0.9)
				sprite.modulate = base_color

## Exploder thrall: self-destruct at low HP for big AOE
func _check_explode_threshold() -> void:
	if _explode_triggered:
		return
	if current_health <= max_health * 0.3 and current_health > 0:
		_explode_triggered = true
		_self_destruct()

func _self_destruct() -> void:
	var aoe_range := 90.0
	var ring_bonus := SaveData.get_equip_bonus(Equipment.Slot.RING)
	var aoe_damage := attack_damage * 3.0 * Game.upgrade_thrall_damage_mult * (1.0 + SaveData.perm_thrall_damage + ring_bonus)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_dying"):
			continue
		if global_position.distance_to(enemy.global_position) < aoe_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(aoe_damage)
				Game.spawn_damage_number(aoe_damage, enemy.global_position, Color(1.0, 0.5, 0.2))
	Effects.spawn_death_explosion(global_position, Color(1.0, 0.6, 0.2))
	Game.request_shake(6.0)
	Audio.play_explode()
	current_health = 0
	_die()

## Teleporter thrall: blink behind target
func _process_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0 and current_target and is_instance_valid(current_target):
		var dist := global_position.distance_to(current_target.global_position)
		if dist > 40.0 and dist < 200.0:
			_do_blink()
			_blink_timer = 2.5

func _do_blink() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	var behind := current_target.global_position + (current_target.global_position - global_position).normalized() * -30.0
	Effects.spawn_hit_sparks(global_position, Color(0.8, 0.3, 1.0))
	global_position = behind
	Effects.spawn_hit_sparks(global_position, Color(0.8, 0.3, 1.0))

## Summoner/Voidcaller thrall: buff aura for nearby thralls
func _process_buff_aura(delta: float) -> void:
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = 4.0
		for thrall in get_tree().get_nodes_in_group("thralls"):
			if thrall == self or not is_instance_valid(thrall):
				continue
			if global_position.distance_to(thrall.global_position) < _buff_radius:
				# Boost damage temporarily by increasing attack_damage
				thrall.attack_damage *= 1.15
				# Schedule reset after 3 seconds
				get_tree().create_timer(3.0).timeout.connect(
					func():
						if is_instance_valid(thrall):
							thrall.attack_damage /= 1.15
				)
				# Visual feedback
				thrall.sprite.modulate = Color(0.6, 1.0, 0.4)
				var tween := thrall.create_tween()
				var base := Color(1.0, 0.8, 0.4) if thrall.mode == ThrallMode.COMMANDED else Color(0.4, 1.0, 0.9)
				tween.tween_property(thrall.sprite, "modulate", base, 0.5)

func _draw() -> void:
	if is_dying:
		return

	# Mode indicator
	if mode == ThrallMode.COMMANDED:
		draw_arc(Vector2.ZERO, 8.0, 0, TAU, 8, Color(1.0, 0.8, 0.3, 0.3), 1.0)

	# Tank/shielded taunt range preview
	if (thrall_type == "tank" or thrall_type == "shielded") and ability_timer <= 1.0 and ability_timer > 0.0:
		var alpha := 0.15 * (1.0 - ability_timer)
		draw_arc(Vector2.ZERO, taunt_radius / scale.x, 0, TAU, 24, Color(1.0, 0.8, 0.3, alpha), 1.5)

	# Charger windup indicator
	if thrall_type == "charger" and _charge_state == 1:
		draw_arc(Vector2.ZERO, 14.0, 0, TAU * (_charge_elapsed / 0.3), 12, Color(1.0, 0.6, 0.2, 0.6), 2.0)

	# Buff aura indicator
	if (thrall_type == "summoner" or thrall_type == "voidcaller") and _buff_timer <= 0.5:
		var aura_alpha := 0.1 * (1.0 - _buff_timer * 2.0)
		draw_arc(Vector2.ZERO, _buff_radius / scale.x, 0, TAU, 20, Color(0.3, 0.9, 0.4, aura_alpha), 1.5)

	# Exploder low-health warning
	if thrall_type == "exploder" and current_health <= max_health * 0.5 and not _explode_triggered:
		var pulse := 0.3 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.4, 0.1, pulse))

	# Health bar (only when damaged)
	if current_health < max_health:
		var bar_w: float = 18.0
		var bar_h: float = 2.0
		var bar_y: float = -16.0
		var ratio := current_health / max_health
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.6))
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * ratio, bar_h), Color(0.3, 0.9, 0.8))
