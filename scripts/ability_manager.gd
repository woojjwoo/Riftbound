extends Node2D

## Manages player abilities: cooldowns, activation, and visual effects.
## Attached as a child of the Player node.

const AbilityData := preload("res://scripts/ability_data.gd")

signal ability_activated(id: String)
signal ability_cooldown_updated(id: String, fraction: float)

## Dictionary of ability_id -> current level (1+). Only contains unlocked abilities.
var ability_levels: Dictionary = {}

## Dictionary of ability_id -> remaining cooldown time.
var ability_cooldowns: Dictionary = {}

## Dictionary of ability_id -> total cooldown for current level.
var ability_max_cooldowns: Dictionary = {}

## Active timed effects
var speed_burst_timer: float = 0.0
var speed_burst_mult: float = 1.0
var fire_trail_timer: float = 0.0
var fire_trail_stats: Dictionary = {}

var player: CharacterBody2D = null
var all_ability_info: Dictionary = {}

func _ready() -> void:
	all_ability_info = AbilityData.get_all_abilities()
	player = get_parent() as CharacterBody2D

func _process(delta: float) -> void:
	if Game.is_game_over or player == null:
		return

	# Tick cooldowns
	for id in ability_cooldowns.keys():
		if ability_cooldowns[id] > 0.0:
			ability_cooldowns[id] -= delta
			if ability_cooldowns[id] < 0.0:
				ability_cooldowns[id] = 0.0
			# Emit fraction for UI
			var max_cd: float = ability_max_cooldowns.get(id, 1.0)
			var fraction: float = ability_cooldowns[id] / max_cd if max_cd > 0.0 else 0.0
			ability_cooldown_updated.emit(id, fraction)

	# Auto-activate abilities that are off cooldown
	for id in ability_levels.keys():
		if ability_cooldowns.get(id, 0.0) <= 0.0:
			activate_ability(id)

	# Speed burst effect
	if speed_burst_timer > 0.0:
		speed_burst_timer -= delta
		if speed_burst_timer <= 0.0:
			speed_burst_mult = 1.0

	# Fire trail effect
	if fire_trail_timer > 0.0:
		fire_trail_timer -= delta
		if player.velocity.length() > 10.0:
			_spawn_fire_patch()

func unlock_ability(id: String) -> void:
	if ability_levels.has(id):
		ability_levels[id] += 1
	else:
		ability_levels[id] = 1
		ability_cooldowns[id] = 0.0
	# Refresh max cooldown
	var stats := AbilityData.get_ability_stats(id, ability_levels[id])
	ability_max_cooldowns[id] = stats.get("cooldown", 5.0)

func get_ability_level(id: String) -> int:
	return ability_levels.get(id, 0)

func get_speed_multiplier() -> float:
	return speed_burst_mult

func activate_ability(id: String) -> void:
	var level: int = ability_levels.get(id, 0)
	if level <= 0:
		return
	var stats := AbilityData.get_ability_stats(id, level)

	match id:
		"lightning_strike":
			_do_lightning_strike(stats)
		"frost_nova":
			_do_frost_nova(stats)
		"shield_bash":
			_do_shield_bash(stats)
		"heal_pulse":
			_do_heal_pulse(stats)
		"speed_burst":
			_do_speed_burst(stats)
		"fire_trail":
			_do_fire_trail(stats)

	ability_cooldowns[id] = stats.get("cooldown", 5.0)
	ability_max_cooldowns[id] = stats.get("cooldown", 5.0)
	ability_activated.emit(id)

# ── Lightning Strike ─────────────────────────────────────────────────────────

func _do_lightning_strike(stats: Dictionary) -> void:
	var radius: float = stats.radius
	var damage: float = stats.damage

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist <= radius and enemy.has_method("take_damage"):
			enemy.take_damage(damage)

	# VFX: expanding ring
	_spawn_ring_vfx(player.global_position, radius, Color(0.6, 0.8, 1.0, 0.8), 0.4)

# ── Frost Nova ───────────────────────────────────────────────────────────────

func _do_frost_nova(stats: Dictionary) -> void:
	var radius: float = stats.radius
	var slow_pct: float = stats.slow_percent
	var duration: float = stats.duration

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist <= radius:
			_apply_slow(enemy, slow_pct, duration)

	_spawn_ring_vfx(player.global_position, radius, Color(0.4, 0.9, 1.0, 0.7), 0.5)

func _apply_slow(enemy: Node2D, slow_pct: float, duration: float) -> void:
	if not enemy.has_meta("base_speed"):
		enemy.set_meta("base_speed", enemy.move_speed)

	var base: float = enemy.get_meta("base_speed")
	enemy.move_speed = base * (1.0 - slow_pct)

	# Tint blue
	if enemy.has_node("Sprite"):
		enemy.get_node("Sprite").modulate = Color(0.5, 0.7, 1.0)

	# Restore after duration
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(enemy):
			enemy.move_speed = enemy.get_meta("base_speed") if enemy.has_meta("base_speed") else base
			if enemy.has_node("Sprite"):
				enemy.get_node("Sprite").modulate = Color.WHITE
	)

# ── Shield Bash ──────────────────────────────────────────────────────────────

func _do_shield_bash(stats: Dictionary) -> void:
	var radius: float = stats.radius
	var damage: float = stats.damage
	var knockback: float = stats.knockback

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			# Knockback via tween
			var dir := player.global_position.direction_to(enemy.global_position)
			var target_pos := enemy.global_position + dir * knockback
			var tween := create_tween()
			tween.tween_property(enemy, "global_position", target_pos, 0.2)

	_spawn_ring_vfx(player.global_position, radius, Color(1.0, 0.85, 0.3, 0.8), 0.3)

# ── Heal Pulse ───────────────────────────────────────────────────────────────

func _do_heal_pulse(stats: Dictionary) -> void:
	var heal: float = stats.heal_amount
	if player.has_method("heal"):
		player.heal(heal)

	# Green flash on player
	if player.has_node("Sprite"):
		var spr: Sprite2D = player.get_node("Sprite")
		spr.modulate = Color(0.3, 1.0, 0.4)
		var tween := create_tween()
		tween.tween_property(spr, "modulate", Color.WHITE, 0.3)

	_spawn_ring_vfx(player.global_position, 50.0, Color(0.3, 1.0, 0.4, 0.6), 0.3)

# ── Speed Burst ──────────────────────────────────────────────────────────────

func _do_speed_burst(stats: Dictionary) -> void:
	speed_burst_mult = stats.speed_mult
	speed_burst_timer = stats.duration

	# Orange flash
	if player.has_node("Sprite"):
		var spr: Sprite2D = player.get_node("Sprite")
		spr.modulate = Color(1.0, 0.6, 0.2)
		var tween := create_tween()
		tween.tween_property(spr, "modulate", Color.WHITE, 0.5)

# ── Fire Trail ───────────────────────────────────────────────────────────────

func _do_fire_trail(stats: Dictionary) -> void:
	fire_trail_timer = stats.trail_duration
	fire_trail_stats = stats

var _fire_trail_spawn_timer: float = 0.0

func _spawn_fire_patch() -> void:
	_fire_trail_spawn_timer -= get_process_delta_time()
	if _fire_trail_spawn_timer > 0.0:
		return
	_fire_trail_spawn_timer = 0.15  # Spawn a patch every 0.15s while moving

	var patch := FirePatch.new()
	patch.damage = fire_trail_stats.get("damage_per_tick", 8.0)
	patch.tick_rate = fire_trail_stats.get("tick_rate", 0.5)
	patch.lifetime = fire_trail_stats.get("trail_duration", 3.0)
	patch.global_position = player.global_position
	get_tree().current_scene.add_child(patch)

# ── Visual Effects ───────────────────────────────────────────────────────────

func _spawn_ring_vfx(pos: Vector2, radius: float, color: Color, duration: float) -> void:
	var ring := RingVFX.new()
	ring.radius = radius
	ring.color = color
	ring.duration = duration
	ring.global_position = pos
	get_tree().current_scene.add_child(ring)

# ── Inner classes for VFX ────────────────────────────────────────────────────

class RingVFX extends Node2D:
	var radius: float = 100.0
	var color: Color = Color.WHITE
	var duration: float = 0.4
	var elapsed: float = 0.0

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := elapsed / duration
		var current_radius := radius * progress
		var alpha := color.a * (1.0 - progress)
		var draw_color := Color(color.r, color.g, color.b, alpha)
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, draw_color, 3.0)

class FirePatch extends Area2D:
	var damage: float = 8.0
	var tick_rate: float = 0.5
	var lifetime: float = 3.0
	var elapsed: float = 0.0
	var tick_timer: float = 0.0

	func _ready() -> void:
		# Create collision shape
		var shape := CircleShape2D.new()
		shape.radius = 16.0
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)
		collision_layer = 0
		collision_mask = 2  # Enemy layer
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= lifetime:
			queue_free()
			return
		tick_timer -= delta
		# Damage enemies overlapping
		if tick_timer <= 0.0:
			tick_timer = tick_rate
			for body in get_overlapping_bodies():
				if body.is_in_group("enemies") and body.has_method("take_damage"):
					body.take_damage(damage)
		queue_redraw()

	func _draw() -> void:
		var alpha := 1.0 - (elapsed / lifetime)
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.3, 0.1, alpha * 0.6))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.7, 0.1, alpha * 0.8))

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage)
