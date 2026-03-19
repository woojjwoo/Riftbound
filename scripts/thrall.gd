extends CharacterBody2D

## Thrall with command system, HP, and death.
## FOLLOW player or move to COMMANDED position.
## Can attack rifts when commanded to them.
## Abilities: melee lifesteal, ranged AoE, tank taunt.

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

# Abilities
var attack_count: int = 0
var ability_timer: float = 0.0
var taunt_cooldown: float = 5.0
var taunt_radius: float = 120.0

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
		"ranged":
			attack_range = 150.0
			attack_damage = 10.0
			attack_cooldown = 1.2
			follow_speed = 160.0
			max_health = 20.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		"tank":
			attack_range = 50.0
			attack_damage = 8.0
			attack_cooldown = 1.5
			follow_speed = 140.0
			max_health = 50.0
			scale *= 1.3
			sprite_idle = load("res://sprites/skeleton_warrior/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_warrior/Run-Sheet.png")
		_:
			attack_range = 50.0
			attack_damage = 15.0
			attack_cooldown = 0.8
			follow_speed = 190.0
			max_health = 30.0
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
	current_health = max_health

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
	sprite.modulate = Color(0.4, 1.0, 0.9)  # teal when following

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

	# Tank taunt
	if thrall_type == "tank" and ability_timer <= 0.0:
		_taunt()
		ability_timer = taunt_cooldown

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
				var dist := global_position.distance_to(leader.global_position)
				if dist > follow_distance:
					move_dir = global_position.direction_to(leader.global_position)

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

	var effective_damage := attack_damage * Game.upgrade_thrall_damage_mult
	attack_count += 1
	var is_enemy := current_target.is_in_group("enemies")

	# Ranged thralls shoot projectiles at enemies, but attack rifts directly
	if thrall_type == "ranged" and projectile_scene and is_enemy:
		var dir := global_position.direction_to(current_target.global_position)
		var proj := projectile_scene.instantiate()
		proj.global_position = global_position
		proj.setup(dir, effective_damage, "enemies")
		get_tree().current_scene.add_child(proj)
		# AoE every 3rd shot
		if attack_count % 3 == 0:
			_aoe_attack(effective_damage)
	else:
		if current_target.has_method("take_damage"):
			current_target.take_damage(effective_damage)
			var dmg_color := Color(0.8, 0.4, 1.0) if not is_enemy else Color(0.4, 1.0, 0.9)
			Game.spawn_damage_number(effective_damage, current_target.global_position, dmg_color)

		# Melee lifesteal on enemies only
		if thrall_type == "melee" and is_enemy and leader and leader.has_method("heal"):
			var heal_amount := effective_damage * 0.15
			leader.heal(heal_amount)

func _aoe_attack(damage: float) -> void:
	var aoe_range := 60.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == current_target:
			continue
		if global_position.distance_to(enemy.global_position) < aoe_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.5)
				Game.spawn_damage_number(damage * 0.5, enemy.global_position, Color(0.6, 0.4, 1.0))
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
	vfx.set("max_radius", aoe_range)
	get_tree().current_scene.add_child(vfx)

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

func _draw() -> void:
	if is_dying:
		return

	# Mode indicator
	if mode == ThrallMode.COMMANDED:
		draw_arc(Vector2.ZERO, 8.0, 0, TAU, 8, Color(1.0, 0.8, 0.3, 0.3), 1.0)

	# Tank taunt range preview
	if thrall_type == "tank" and ability_timer <= 1.0 and ability_timer > 0.0:
		var alpha := 0.15 * (1.0 - ability_timer)
		draw_arc(Vector2.ZERO, taunt_radius / scale.x, 0, TAU, 24, Color(1.0, 0.8, 0.3, alpha), 1.5)

	# Health bar (only when damaged)
	if current_health < max_health:
		var bar_w: float = 18.0
		var bar_h: float = 2.0
		var bar_y: float = -16.0
		var ratio := current_health / max_health
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.6))
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * ratio, bar_h), Color(0.3, 0.9, 0.8))
