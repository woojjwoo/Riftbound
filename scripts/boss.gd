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

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health
	base_speed = move_speed
	add_to_group("enemies")
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if Game.is_game_over or player == null or is_dying:
		return

	contact_timer -= delta
	var dir := global_position.direction_to(player.global_position)
	sprite.flip_h = dir.x < 0

	velocity = dir * move_speed
	move_and_slide()

	# Animate
	if velocity.length() > 10 and sprite_run:
		sprite.texture = sprite_run
	elif sprite_idle:
		sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 120) % 6

	# Contact damage
	if contact_timer <= 0.0:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.is_in_group("player") and collider.has_method("take_damage"):
				collider.take_damage(contact_damage)
				contact_timer = 1.0
				break

func take_damage(amount: float) -> void:
	if is_dying:
		return
	current_health -= amount
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if not enraged and current_health / max_health <= enrage_percent:
		enraged = true
		move_speed = base_speed * enrage_speed_mult
		sprite.modulate = Color(1.0, 0.3, 0.3)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	Game.on_enemy_killed()

	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].force_extract(self)

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func get_enemy_type() -> String:
	return "tank"
