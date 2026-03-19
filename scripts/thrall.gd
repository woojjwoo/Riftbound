extends CharacterBody2D

## Thrall (bound shadow). Follows the player, attacks enemies automatically.
## Uses skeleton sprites — tinted cyan to show they're yours.

var thrall_type: String = "melee"
var leader: Node2D = null

var follow_speed: float = 180.0
var follow_distance: float = 60.0
var attack_range: float = 60.0
var attack_damage: float = 15.0
var attack_cooldown: float = 0.8

var attack_timer: float = 0.0
var current_target: Node2D = null

@export var projectile_scene: PackedScene

# Sprite sheets loaded based on type
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
			sprite_idle = load("res://sprites/skeleton/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton/Run-Sheet.png")
		"ranged":
			attack_range = 150.0
			attack_damage = 10.0
			attack_cooldown = 1.2
			follow_speed = 160.0
			sprite_idle = load("res://sprites/skeleton_mage/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_mage/Run-Sheet.png")
		"tank":
			attack_range = 50.0
			attack_damage = 8.0
			attack_cooldown = 1.5
			follow_speed = 140.0
			scale *= 1.3
			sprite_idle = load("res://sprites/skeleton_warrior/Idle-Sheet.png")
			sprite_run = load("res://sprites/skeleton_warrior/Run-Sheet.png")

func _ready() -> void:
	# Tint thralls with a cyan glow to distinguish from enemies
	sprite.modulate = Color(0.4, 1.0, 0.9, 1.0)
	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6

func _physics_process(delta: float) -> void:
	if Game.is_game_over or leader == null:
		return

	attack_timer -= delta
	find_target()

	if current_target and attack_timer <= 0.0:
		var dist := global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			attack()
			attack_timer = attack_cooldown

	# Movement
	var move_dir := Vector2.ZERO

	if current_target:
		var dist_to_target := global_position.distance_to(current_target.global_position)
		var dist_to_leader := global_position.distance_to(leader.global_position)

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

	velocity = move_dir * follow_speed
	move_and_slide()

	# Animate
	if move_dir.length() > 0.1:
		sprite.flip_h = move_dir.x < 0
	if velocity.length() > 10 and sprite_run:
		sprite.texture = sprite_run
	elif sprite_idle:
		sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 100) % 6

func find_target() -> void:
	current_target = null
	var closest_dist: float = attack_range * 2.0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			current_target = enemy

func attack() -> void:
	if current_target == null:
		return

	if thrall_type == "ranged" and projectile_scene:
		var dir := global_position.direction_to(current_target.global_position)
		var proj := projectile_scene.instantiate()
		proj.global_position = global_position
		proj.setup(dir, attack_damage, "enemies")
		get_tree().current_scene.add_child(proj)
	else:
		if current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage)
