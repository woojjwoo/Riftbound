extends CharacterBody2D

## Base enemy with animated sprite sheets.

@export_enum("melee", "ranged", "tank") var enemy_type: String = "melee"
@export var move_speed: float = 100.0
@export var max_health: float = 40.0
@export var contact_damage: float = 10.0
@export var extraction_chance: float = 0.3
@export var projectile_scene: PackedScene

@export var attack_range: float = 150.0
@export var ranged_cooldown: float = 2.0

# Sprite paths — set per scene
@export var sprite_idle: Texture2D
@export var sprite_run: Texture2D
@export var sprite_death: Texture2D

var current_health: float
var player: Node2D = null
var contact_timer: float = 0.0
var ranged_timer: float = 0.0
var is_dying: bool = false

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	_find_player()
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if Game.is_game_over or player == null or is_dying:
		return

	contact_timer -= delta
	ranged_timer -= delta

	var dir := global_position.direction_to(player.global_position)
	var dist := global_position.distance_to(player.global_position)

	# Flip sprite based on movement direction
	sprite.flip_h = dir.x < 0

	# Ranged enemies keep distance
	if enemy_type == "ranged" and dist < attack_range * 0.5:
		dir = -dir
	elif enemy_type == "ranged" and dist <= attack_range and ranged_timer <= 0.0:
		shoot_at_player()
		ranged_timer = ranged_cooldown

	# Apply knockback decay
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity = dir * move_speed + knockback_velocity
	move_and_slide()

	# Animate
	if velocity.length() > 10:
		if sprite_run:
			sprite.texture = sprite_run
	else:
		if sprite_idle:
			sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 120) % 6

	# Contact damage
	if contact_timer <= 0.0:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.is_in_group("player") and collider.has_method("take_damage"):
				collider.take_damage(contact_damage, global_position)
				contact_timer = 1.0
				break

	# Redraw health bar
	queue_redraw()

func shoot_at_player() -> void:
	if projectile_scene == null or player == null:
		return
	var dir := global_position.direction_to(player.global_position)
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	proj.setup(dir, contact_damage, "player")
	get_tree().current_scene.add_child(proj)

func take_damage(amount: float) -> void:
	if is_dying:
		return
	current_health -= amount

	# Knockback away from player
	if player:
		var kb_dir := player.global_position.direction_to(global_position)
		knockback_velocity = kb_dir * 150.0

	# Flash white
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	# Squash and stretch on hit
	sprite.scale = Vector2(1.3, 0.7)
	var scale_tween := create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	Game.on_enemy_killed()

	# Screen shake on kill
	Game.request_shake(3.0)

	# Play death animation
	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	# Try extraction
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p := players[0]
		if extraction_chance >= 1.0:
			p.force_extract(self)
		else:
			p.try_extract(self, extraction_chance)

	# Death effect: scale up + spin + fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", randf_range(-0.5, 0.5), 0.4)
	tween.chain().tween_callback(queue_free)

func get_enemy_type() -> String:
	return enemy_type

func _draw() -> void:
	if is_dying or current_health >= max_health:
		return
	# Draw health bar above sprite
	var bar_width: float = 24.0
	var bar_height: float = 3.0
	var bar_y: float = -20.0
	var health_ratio := current_health / max_health
	# Background
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	# Health fill
	var fill_color := Color(0.2, 0.8, 0.2) if health_ratio > 0.5 else Color(0.8, 0.2, 0.2)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_ratio, bar_height), fill_color)
