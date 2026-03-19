extends CharacterBody2D

## Base enemy. Supports: melee, ranged, tank, flying, exploder types.
## Can target player OR thralls. Defends rifts from thralls.
## Drops health orbs on death. Proximity extraction for thrall raising.

@export_enum("melee", "ranged", "tank", "flying", "exploder") var enemy_type: String = "melee"
@export var move_speed: float = 100.0
@export var max_health: float = 40.0
@export var contact_damage: float = 10.0
@export var extraction_chance: float = 0.3
@export var projectile_scene: PackedScene

@export var attack_range: float = 150.0
@export var ranged_cooldown: float = 2.0

@export var sprite_idle: Texture2D
@export var sprite_run: Texture2D
@export var sprite_death: Texture2D

var current_health: float
var player: Node2D = null
var contact_timer: float = 0.0
var ranged_timer: float = 0.0
var is_dying: bool = false

# Targeting
var target_node: Node2D = null
var retarget_timer: float = 0.0
const RETARGET_INTERVAL: float = 1.5

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# Shield
var has_shield: bool = false
var shield_hits: int = 0
var shield_max_hits: int = 3

# Flying
var fly_time: float = 0.0
var fly_amplitude: float = 20.0

# Exploder
var explode_radius: float = 80.0
var explode_damage: float = 20.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	_find_player()
	target_node = player
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

	match enemy_type:
		"flying":
			sprite.modulate = Color(0.7, 0.5, 1.0)
		"exploder":
			sprite.modulate = Color(1.0, 0.5, 0.3)
			scale *= 0.8

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if Game.is_game_over or player == null or is_dying:
		return

	contact_timer -= delta
	ranged_timer -= delta
	fly_time += delta
	retarget_timer -= delta

	# Retarget periodically
	if retarget_timer <= 0.0:
		_retarget()
		retarget_timer = RETARGET_INTERVAL

	# Use target_node for movement direction
	var chase_target: Node2D = target_node if (target_node and is_instance_valid(target_node)) else player
	var dir := global_position.direction_to(chase_target.global_position)
	var dist := global_position.distance_to(chase_target.global_position)

	sprite.flip_h = dir.x < 0

	match enemy_type:
		"ranged":
			if dist < attack_range * 0.5:
				dir = -dir
			elif dist <= attack_range and ranged_timer <= 0.0:
				_shoot_at(chase_target)
				ranged_timer = ranged_cooldown
		"flying":
			dir = dir.rotated(sin(fly_time * 3.0) * 0.5)
			if dist <= attack_range and ranged_timer <= 0.0:
				_shoot_at(chase_target)
				ranged_timer = ranged_cooldown
			sprite.position.y = sin(fly_time * 4.0) * fly_amplitude * 0.3
		"exploder":
			dir = dir * 1.5

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

	if enemy_type == "exploder" and dist < explode_radius * 2:
		var pulse := 0.5 + 0.5 * sin(fly_time * 10.0)
		sprite.modulate = Color(1.0, 0.3 + 0.4 * pulse, 0.2)

	# Contact damage — hits player AND thralls
	if contact_timer <= 0.0:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.has_method("take_damage"):
				if collider.is_in_group("player"):
					if enemy_type == "exploder":
						die()
					else:
						collider.take_damage(contact_damage, global_position)
						contact_timer = 1.0
					break
				elif collider.is_in_group("thralls"):
					# Deal reduced damage to thralls
					collider.take_damage(contact_damage * 0.6, global_position)
					contact_timer = 0.8
					break

	queue_redraw()

func _retarget() -> void:
	# Chance to target thralls instead of player
	var thralls := get_tree().get_nodes_in_group("thralls")
	if thralls.is_empty():
		target_node = player
		return

	# Near a rift? Defend it — higher chance to target thralls
	var thrall_chance := 0.25
	for rift in get_tree().get_nodes_in_group("rifts"):
		if global_position.distance_to(rift.global_position) < 150.0:
			thrall_chance = 0.6
			break

	if randf() < thrall_chance:
		# Target nearest thrall
		var closest_thrall: Node2D = null
		var closest_dist := 9999.0
		for thrall in thralls:
			var d := global_position.distance_to(thrall.global_position)
			if d < closest_dist:
				closest_dist = d
				closest_thrall = thrall
		target_node = closest_thrall
	else:
		target_node = player

func _shoot_at(target: Node2D) -> void:
	if projectile_scene == null or target == null:
		return
	var dir := global_position.direction_to(target.global_position)
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	# Use correct target group based on who we're shooting at
	var group := "thralls" if target.is_in_group("thralls") else "player"
	proj.setup(dir, contact_damage, group)
	get_tree().current_scene.add_child(proj)
	Audio.play_shoot()

func take_damage(amount: float) -> void:
	if is_dying:
		return

	if has_shield:
		shield_hits += 1
		if shield_hits >= shield_max_hits:
			has_shield = false
			Audio.play_shield_break()
			Game.spawn_damage_number(0, global_position, Color(0.3, 0.6, 1.0))
			Game.request_shake(4.0)
			# Shield break VFX — expanding ring
			var vfx := Node2D.new()
			vfx.global_position = global_position
			vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
			vfx.set("max_radius", 30.0)
			get_tree().current_scene.add_child(vfx)
			sprite.modulate = Color(0.3, 0.6, 1.0)
			var flash_tween := create_tween()
			flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		else:
			sprite.modulate = Color(0.5, 0.8, 1.0)
			var abs_tween := create_tween()
			abs_tween.tween_property(sprite, "modulate", Color(0.6, 0.7, 1.0, 1.0), 0.1)
			Game.spawn_damage_number(0, global_position, Color(0.5, 0.8, 1.0))
		return

	current_health -= amount

	if player:
		var kb_dir := player.global_position.direction_to(global_position)
		knockback_velocity = kb_dir * 150.0

	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	var base_color := _get_base_color()
	tween.tween_property(sprite, "modulate", base_color, 0.1)

	sprite.scale = Vector2(1.3, 0.7)
	var scale_tween := create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	Game.on_enemy_killed()
	Game.request_shake(3.0)
	Audio.play_kill()

	if enemy_type == "exploder":
		_explode()

	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	# Spawn coin and EXP drops
	Game.spawn_drops(global_position, enemy_type)

	if randf() < 0.2:
		_spawn_health_orb()

	# Proximity-based extraction
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p := players[0]
		if Game.guaranteed_extractions > 0:
			p.force_extract(self)
			Game.guaranteed_extractions -= 1
		else:
			p.try_extract_nearby(self, extraction_chance)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", randf_range(-0.5, 0.5), 0.4)
	tween.chain().tween_callback(queue_free)

func _explode() -> void:
	Audio.play_explode()
	Game.request_shake(8.0)
	if player and global_position.distance_to(player.global_position) < explode_radius:
		player.take_damage(explode_damage, global_position)
	# Damage thralls in range too
	for thrall in get_tree().get_nodes_in_group("thralls"):
		if global_position.distance_to(thrall.global_position) < explode_radius:
			if thrall.has_method("take_damage"):
				thrall.take_damage(explode_damage * 0.5, global_position)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and not enemy.is_dying:
			if global_position.distance_to(enemy.global_position) < explode_radius:
				enemy.take_damage(explode_damage * 0.5)
	_spawn_explosion_vfx()

func _spawn_explosion_vfx() -> void:
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
	get_tree().current_scene.add_child(vfx)

func _spawn_health_orb() -> void:
	var orb := Node2D.new()
	orb.global_position = global_position
	orb.set_script(preload("res://scripts/health_orb.gd"))
	get_tree().current_scene.add_child(orb)

func get_enemy_type() -> String:
	return enemy_type

func enable_shield(hits: int = 3) -> void:
	has_shield = true
	shield_hits = 0
	shield_max_hits = hits

func _get_base_color() -> Color:
	match enemy_type:
		"flying":
			return Color(0.7, 0.5, 1.0)
		"exploder":
			return Color(1.0, 0.5, 0.3)
	if has_shield:
		return Color(0.6, 0.7, 1.0)
	return Color.WHITE

func _draw() -> void:
	if is_dying:
		return
	if has_shield:
		var shield_alpha := 0.3 + 0.1 * sin(Time.get_ticks_msec() * 0.005)
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, Color(0.3, 0.6, 1.0, shield_alpha), 2.0)

	if current_health >= max_health:
		return
	var bar_width: float = 24.0
	var bar_height: float = 3.0
	var bar_y: float = -20.0
	var health_ratio := current_health / max_health
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	var fill_color := Color(0.2, 0.8, 0.2) if health_ratio > 0.5 else Color(0.8, 0.2, 0.2)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_ratio, bar_height), fill_color)
