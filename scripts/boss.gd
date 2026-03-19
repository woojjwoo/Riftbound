extends CharacterBody2D

## Boss enemy with animated sprites. Guaranteed extraction. Enrages at low HP.

@export var move_speed: float = 80.0
@export var max_health: float = 300.0
@export var contact_damage: float = 20.0
@export var boss_name: String = "Rift Guardian"
@export var enrage_percent: float = 0.3
@export var enrage_speed_mult: float = 1.5

@export var sprite_idle: Texture2D
@export var sprite_run: Texture2D
@export var sprite_death: Texture2D

var current_health: float
var player: Node2D = null
var contact_timer: float = 0.0
var enraged: bool = false
var base_speed: float
var is_dying: bool = false

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health
	base_speed = move_speed
	add_to_group("enemies")
	add_to_group("boss")
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	# Dramatic entrance: big screen shake + hit freeze
	Game.request_shake(12.0)
	Game.hit_freeze(0.1)

	# Scale-in entrance animation
	scale = Vector2(0.2, 0.2)
	var entrance_tween := create_tween()
	entrance_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta: float) -> void:
	if Game.is_game_over or player == null or is_dying:
		return

	contact_timer -= delta
	var dir := global_position.direction_to(player.global_position)
	sprite.flip_h = dir.x < 0

	# Apply knockback decay (boss resists more)
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	velocity = dir * move_speed + knockback_velocity
	move_and_slide()

	# Animate
	if velocity.length() > 10 and sprite_run:
		sprite.texture = sprite_run
	elif sprite_idle:
		sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 120) % 6

	# Enrage pulsing glow
	if enraged:
		var pulse := 0.3 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		sprite.modulate = Color(1.0, pulse, pulse)

	# Contact damage
	if contact_timer <= 0.0:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.is_in_group("player") and collider.has_method("take_damage"):
				collider.take_damage(contact_damage, global_position)
				contact_timer = 1.0
				Game.request_shake(6.0)
				Game.hit_freeze(0.04)
				break

	# Redraw health bar
	queue_redraw()

func take_damage(amount: float) -> void:
	if is_dying:
		return
	current_health -= amount

	# Knockback (boss is heavy, less knockback)
	if player:
		var kb_dir := player.global_position.direction_to(global_position)
		knockback_velocity = kb_dir * 60.0

	# Flash
	sprite.modulate = Color.RED
	var tween := create_tween()
	if enraged:
		tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3), 0.15)
	else:
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	# Squash on hit
	sprite.scale = Vector2(1.2, 0.8)
	var scale_tween := create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

	# Hit freeze on big damage
	Game.hit_freeze(0.03)

	if not enraged and current_health / max_health <= enrage_percent:
		enraged = true
		move_speed = base_speed * enrage_speed_mult
		sprite.modulate = Color(1.0, 0.3, 0.3)
		# Dramatic enrage
		Game.request_shake(10.0)
		Game.hit_freeze(0.12)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	Game.on_enemy_killed()

	# Big screen shake on boss death
	Game.request_shake(15.0)
	Game.hit_freeze(0.15)

	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].force_extract(self)

	# Epic death: scale up big + spin + fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", PI, 0.8)
	tween.chain().tween_callback(queue_free)

func get_enemy_type() -> String:
	return "tank"

func _draw() -> void:
	if is_dying:
		return
	# Draw boss health bar (larger than normal enemies)
	var bar_width: float = 40.0
	var bar_height: float = 4.0
	var bar_y: float = -28.0
	var health_ratio := current_health / max_health
	# Background
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	# Border
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.8, 0.7, 0.2, 0.8), false, 1.0)
	# Health fill
	var fill_color := Color(0.8, 0.2, 0.2) if enraged else Color(0.8, 0.6, 0.1)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_ratio, bar_height), fill_color)
