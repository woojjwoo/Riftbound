extends CharacterBody2D

## Player controller: WASD movement, auto-attack, dash ability.
## Has damage invincibility frames to prevent getting melted.

@export var move_speed: float = 200.0
@export var attack_damage: float = 20.0
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 0.45

@export var max_health: float = 100.0
var current_health: float

@export var thrall_scene: PackedScene
@export var arise_vfx_scene: PackedScene

signal health_changed(current: float, max_hp: float)

var attack_timer: float = 0.0
var facing: String = "down"
var facing_right: bool = true

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# Dash
var dash_speed: float = 600.0
var dash_duration: float = 0.15
var dash_cooldown: float = 1.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false

# Damage iframes
var iframes_timer: float = 0.0
const IFRAMES_DURATION: float = 0.4

# Regen
var regen_accumulator: float = 0.0

# Sprite sheet references
var sprites: Dictionary = {}
var current_anim: String = "idle"

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health + Game.upgrade_health_bonus
	max_health += Game.upgrade_health_bonus
	add_to_group("player")
	_load_sprites()
	_set_animation("idle")

func _load_sprites() -> void:
	sprites = {
		"idle_down": load("res://sprites/player/Idle_Down-Sheet.png"),
		"idle_side": load("res://sprites/player/Idle_Side-Sheet.png"),
		"idle_up": load("res://sprites/player/Idle_Up-Sheet.png"),
		"run_down": load("res://sprites/player/Run_Down-Sheet.png"),
		"run_side": load("res://sprites/player/Run_Side-Sheet.png"),
		"run_up": load("res://sprites/player/Run_Up-Sheet.png"),
		"attack_down": load("res://sprites/player/Slice_Down-Sheet.png"),
		"attack_side": load("res://sprites/player/Slice_Side-Sheet.png"),
		"attack_up": load("res://sprites/player/Slice_Up-Sheet.png"),
		"death_down": load("res://sprites/player/Death_Down-Sheet.png"),
	}

func _set_animation(anim_name: String) -> void:
	var key := anim_name + "_" + facing
	if sprites.has(key):
		sprite.texture = sprites[key]
		sprite.hframes = 6
		current_anim = anim_name

func _physics_process(delta: float) -> void:
	if Game.is_game_over:
		return

	# Invincibility frames countdown
	if iframes_timer > 0.0:
		iframes_timer -= delta
		# Flicker effect during iframes
		sprite.visible = int(iframes_timer * 20.0) % 2 == 0
		if iframes_timer <= 0.0:
			sprite.visible = true
			if not is_dashing:
				is_invincible = false

	# Health regen
	if Game.upgrade_regen > 0.0 and current_health < max_health:
		regen_accumulator += Game.upgrade_regen * delta
		if regen_accumulator >= 1.0:
			var heal_amount := floorf(regen_accumulator)
			regen_accumulator -= heal_amount
			heal(heal_amount)

	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	# Dash input
	dash_cooldown_timer -= delta
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		var dash_dir := input.normalized() if input.length() > 0.1 else _get_facing_vector()
		_start_dash(dash_dir)

	# Dash logic
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			_end_dash()
		else:
			velocity = dash_direction * dash_speed
			move_and_slide()
			_spawn_afterimage()
			sprite.frame = int(Time.get_ticks_msec() / 100) % 6
			return

	# Normal movement with upgrades
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var effective_speed := move_speed * Game.upgrade_speed_mult
	velocity = input.normalized() * effective_speed + knockback_velocity
	move_and_slide()

	# Update facing direction
	if input.length() > 0.1:
		if abs(input.x) > abs(input.y):
			facing = "side"
			facing_right = input.x > 0
		elif input.y > 0:
			facing = "down"
		else:
			facing = "up"
		_set_animation("run")
	else:
		_set_animation("idle")

	sprite.flip_h = not facing_right
	sprite.frame = int(Time.get_ticks_msec() / 100) % 6

	# Auto-attack with upgrade cooldown
	attack_timer -= delta
	var effective_cooldown := attack_cooldown * max(Game.upgrade_cooldown_mult, 0.2)
	if attack_timer <= 0.0:
		if try_attack():
			_set_animation("attack")
		attack_timer = effective_cooldown

func _get_facing_vector() -> Vector2:
	match facing:
		"down":
			return Vector2.DOWN
		"up":
			return Vector2.UP
		"side":
			return Vector2.RIGHT if facing_right else Vector2.LEFT
	return Vector2.DOWN

func _start_dash(dir: Vector2) -> void:
	is_dashing = true
	is_invincible = true
	dash_direction = dir
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	sprite.modulate = Color(1.5, 1.5, 2.0, 0.7)
	Audio.play_dash()

func _end_dash() -> void:
	is_dashing = false
	# Keep invincible if iframes are still active
	if iframes_timer <= 0.0:
		is_invincible = false
	sprite.modulate = Color.WHITE

func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.global_position = global_position
	ghost.modulate = Color(0.3, 0.5, 1.0, 0.5)
	ghost.z_index = -1
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

func try_attack() -> bool:
	var closest_enemy: Node2D = null
	var closest_dist: float = attack_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("take_damage") and not enemy.get("is_dying"):
			var dist := global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = enemy

	if closest_enemy:
		var dmg := attack_damage * Game.upgrade_attack_mult
		closest_enemy.take_damage(dmg)
		Game.spawn_damage_number(dmg, closest_enemy.global_position, Color(1.0, 1.0, 0.4))
		Audio.play_hit()

		# Attack lunge — small push toward target for game feel
		var lunge_dir := global_position.direction_to(closest_enemy.global_position)
		knockback_velocity = lunge_dir * 60.0
		return true
	return false

func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or Game.boss_killed:
		return

	current_health -= amount
	current_health = max(current_health, 0.0)
	health_changed.emit(current_health, max_health)

	# Start invincibility frames
	is_invincible = true
	iframes_timer = IFRAMES_DURATION

	if from_pos != Vector2.ZERO:
		knockback_velocity = (global_position - from_pos).normalized() * 250.0

	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	Game.request_shake(4.0)
	Game.spawn_damage_number(amount, global_position, Color(1.0, 0.3, 0.3))

	if current_health <= 0.0:
		Game.trigger_game_over()

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	Game.spawn_damage_number(amount, global_position + Vector2(0, -10), Color(0.3, 1.0, 0.3))

func try_extract(enemy: Node2D, chance: float) -> void:
	var effective_chance := chance + Game.upgrade_extraction_bonus
	if randf() <= effective_chance:
		extract(enemy)

func force_extract(enemy: Node2D) -> void:
	extract(enemy)

func extract(enemy: Node2D) -> void:
	var spawn_pos := enemy.global_position

	if arise_vfx_scene:
		var vfx := arise_vfx_scene.instantiate()
		vfx.global_position = spawn_pos
		get_tree().current_scene.add_child(vfx)

	var thrall_type: String = "melee"
	if enemy.has_method("get_enemy_type"):
		thrall_type = enemy.get_enemy_type()

	if thrall_scene:
		var thrall := thrall_scene.instantiate()
		thrall.global_position = spawn_pos
		thrall.setup(self, thrall_type)
		get_tree().current_scene.add_child(thrall)

	Audio.play_arise()
	Game.on_thrall_gained()
