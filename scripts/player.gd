extends CharacterBody2D

## Player controller: WASD movement + auto-attack nearest enemy.
## Uses directional sprite sheets (Down, Side, Up) with 6 frames each.

@export var move_speed: float = 200.0
@export var attack_damage: float = 20.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 0.5

@export var max_health: float = 100.0
var current_health: float

@export var thrall_scene: PackedScene
@export var arise_vfx_scene: PackedScene

signal health_changed(current: float, max_hp: float)

var attack_timer: float = 0.0
var facing: String = "down"  # down, side, up
var facing_right: bool = true

# Sprite sheet references (loaded in _ready)
var sprites: Dictionary = {}
var current_anim: String = "idle"

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	current_health = max_health
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

	# Movement
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	velocity = input.normalized() * move_speed
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

	# Flip sprite for left/right
	sprite.flip_h = not facing_right

	# Animate frames
	sprite.frame = int(Time.get_ticks_msec() / 100) % 6

	# Auto-attack
	attack_timer -= delta
	if attack_timer <= 0.0:
		if try_attack():
			_set_animation("attack")
		attack_timer = attack_cooldown

func try_attack() -> bool:
	var closest_enemy: Node2D = null
	var closest_dist: float = attack_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy

	if closest_enemy and closest_enemy.has_method("take_damage"):
		closest_enemy.take_damage(attack_damage)
		return true
	return false

func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = max(current_health, 0.0)
	health_changed.emit(current_health, max_health)

	# Flash white
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if current_health <= 0.0:
		Game.trigger_game_over()

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func try_extract(enemy: Node2D, chance: float) -> void:
	if randf() <= chance:
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

	Game.on_thrall_gained()
