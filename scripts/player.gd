extends CharacterBody2D

## Necromancer player: soul bolt ranged attack, thrall commanding, dash.
## You're a commander, not a fighter. Stay near kills to extract thralls,
## then command your undead army to close the rifts.

@export var move_speed: float = 200.0
@export var max_health: float = 120.0
var current_health: float
var base_move_speed: float

@export var thrall_scene: PackedScene
@export var arise_vfx_scene: PackedScene

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

signal health_changed(current: float, max_hp: float)

# Soul bolt (left-click ranged attack)
var bolt_damage: float = 8.0
var bolt_cooldown: float = 0.25
var bolt_timer: float = 0.0

# Movement
var facing: String = "side"
var facing_right: bool = true
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

# Command system
var command_position: Vector2 = Vector2.ZERO
var has_active_command: bool = false

# Extraction
var extraction_range: float = 100.0

# Sprites
var sprites: Dictionary = {}
var current_anim: String = "idle"

## Ability system
var ability_manager: Node2D = null

## Legendary proc handler
var proc_handler: Node = null

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Apply permanent upgrades from save data
	max_health += SaveData.perm_max_health
	move_speed *= (1.0 + SaveData.perm_speed_mult)
	bolt_damage *= (1.0 + SaveData.perm_attack_mult)
	dash_cooldown = max(0.3, dash_cooldown - SaveData.perm_dash_cooldown)

	# Apply Sanctum (meta-progression) bonuses
	max_health += Meta.sanctum_max_health
	bolt_damage *= (1.0 + Meta.sanctum_base_damage)
	move_speed *= (1.0 + Meta.sanctum_move_speed)

	# Apply Sanctum starting level bonus
	var starting_levels := int(Meta.sanctum_starting_level)
	if starting_levels > 0:
		for i in range(starting_levels):
			SaveData.add_exp(SaveData.exp_to_next_level)

	# Apply equipment bonuses
	bolt_damage += bolt_damage * SaveData.get_equip_bonus(Equipment.Slot.GRIMOIRE)  # Grimoire: +damage%
	max_health += SaveData.get_equip_bonus(Equipment.Slot.ROBES)                    # Robes: +flat HP
	extraction_range += extraction_range * SaveData.get_equip_bonus(Equipment.Slot.AMULET)  # Amulet: +extraction%
	move_speed += move_speed * SaveData.get_equip_bonus(Equipment.Slot.BOOTS)       # Boots: +speed%
	bolt_cooldown *= max(0.2, 1.0 - SaveData.get_equip_bonus(Equipment.Slot.CROWN)) # Crown: -cooldown%

	# Apply equipment set bonuses
	var set_bonuses := Equipment.get_set_bonuses(SaveData.equipped)
	bolt_damage *= (1.0 + set_bonuses["damage_mult"])
	max_health += set_bonuses["health_bonus"]
	move_speed *= (1.0 + set_bonuses["speed_mult"])
	bolt_cooldown *= max(0.2, 1.0 - set_bonuses["cdr"])

	current_health = max_health + Game.upgrade_health_bonus
	max_health += Game.upgrade_health_bonus
	base_move_speed = move_speed
	add_to_group("player")
	_load_sprites()
	_set_animation("idle")
	_setup_ability_manager()
	_setup_proc_handler()
	Game.level_up.connect(_on_level_up)

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

func _setup_proc_handler() -> void:
	var ProcScript := preload("res://scripts/proc_handler.gd")
	proc_handler = ProcScript.new()
	proc_handler.name = "ProcHandler"
	add_child(proc_handler)
	proc_handler.setup(self)

func _setup_ability_manager() -> void:
	var AbilityManagerScript := preload("res://scripts/ability_manager.gd")
	ability_manager = AbilityManagerScript.new()
	ability_manager.name = "AbilityManager"
	add_child(ability_manager)

func _on_level_up(_new_level: int) -> void:
	# Level-up burst effect centered on player + large screen shake
	Effects.spawn_level_up_burst(global_position)
	Game.request_shake(8.0)
	# Brief golden flash on the player sprite
	sprite.modulate = Color(1.0, 1.0, 0.5)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_try_shoot()
			MOUSE_BUTTON_RIGHT:
				_command_thralls()

func _physics_process(delta: float) -> void:
	if Game.is_game_over:
		return

	# Invincibility frames
	if iframes_timer > 0.0:
		iframes_timer -= delta
		sprite.visible = int(iframes_timer * 20.0) % 2 == 0
		if iframes_timer <= 0.0:
			sprite.visible = true
			if not is_dashing:
				is_invincible = false

	# Health regen (run upgrade + permanent upgrade)
	var total_regen := Game.upgrade_regen + SaveData.perm_regen
	if total_regen > 0.0 and current_health < max_health:
		regen_accumulator += total_regen * delta
		if regen_accumulator >= 1.0:
			var heal_amount := floorf(regen_accumulator)
			regen_accumulator -= heal_amount
			heal(heal_amount)

	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	# Dash
	dash_cooldown_timer -= delta
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		var dash_dir := input.normalized() if input.length() > 0.1 else _get_facing_vector()
		_start_dash(dash_dir)

	# Recall thralls
	if Input.is_action_just_pressed("recall"):
		_recall_thralls()

	# Bolt cooldown
	bolt_timer -= delta

	# Dash movement
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

	# Normal movement
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var ability_speed := ability_manager.get_speed_multiplier() if ability_manager else 1.0
	var effective_speed := move_speed * Game.upgrade_speed_mult * ability_speed
	velocity = input.normalized() * effective_speed + knockback_velocity
	move_and_slide()

	# Face toward mouse cursor
	var mouse_dir := (get_global_mouse_position() - global_position).normalized()
	facing_right = mouse_dir.x >= 0
	if abs(mouse_dir.x) > abs(mouse_dir.y):
		facing = "side"
	elif mouse_dir.y > 0:
		facing = "down"
	else:
		facing = "up"

	if input.length() > 0.1:
		_set_animation("run")
	else:
		_set_animation("idle")

	sprite.flip_h = not facing_right
	sprite.frame = int(Time.get_ticks_msec() / 100) % 6

	queue_redraw()

func _get_facing_vector() -> Vector2:
	match facing:
		"down":
			return Vector2.DOWN
		"up":
			return Vector2.UP
		"side":
			return Vector2.RIGHT if facing_right else Vector2.LEFT
	return Vector2.DOWN

# --- Soul Bolt ---

func _try_shoot() -> void:
	if bolt_timer > 0.0 or is_dashing:
		return
	bolt_timer = bolt_cooldown * max(Game.upgrade_cooldown_mult, 0.2)

	var dir := (get_global_mouse_position() - global_position).normalized()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	proj.setup(dir, bolt_damage * Game.upgrade_attack_mult, "enemies")
	scene.add_child(proj)
	Audio.play_shoot()
	_set_animation("attack")

# --- Thrall Commands ---

func _command_thralls() -> void:
	var world_pos := get_global_mouse_position()
	command_position = world_pos
	has_active_command = true

	# Check if clicking on an enemy or rift
	var target_entity: Node2D = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node.get("is_dying") and world_pos.distance_to(node.global_position) < 25.0:
			target_entity = node
			break
	if target_entity == null:
		for node in get_tree().get_nodes_in_group("rifts"):
			if world_pos.distance_to(node.global_position) < 35.0:
				target_entity = node
				break

	for thrall in get_tree().get_nodes_in_group("thralls"):
		thrall.command_to(world_pos, target_entity)

	# Spawn command marker
	var scene := get_tree().current_scene
	if scene:
		var marker := Node2D.new()
		marker.set_script(preload("res://scripts/command_marker.gd"))
		marker.global_position = world_pos
		scene.add_child(marker)
	Audio.play_hit()

func _recall_thralls() -> void:
	has_active_command = false
	for thrall in get_tree().get_nodes_in_group("thralls"):
		thrall.recall()
	Audio.play_recall()

# --- Dash ---

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
	var scene := get_tree().current_scene
	if scene == null:
		ghost.queue_free()
		return
	scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

# --- Extraction (proximity-based) ---

func try_extract_nearby(enemy: Node2D, chance: float) -> void:
	var dist := global_position.distance_to(enemy.global_position)
	var effective_range := extraction_range + Game.upgrade_extraction_bonus * 100.0
	if dist > effective_range:
		return
	var effective_chance := chance + Game.upgrade_extraction_bonus + SaveData.perm_extraction_bonus + Game.extraction_pity
	if randf() <= effective_chance:
		Game.extraction_pity = 0.0
		extract(enemy)
	else:
		Game.extraction_pity += Game.PITY_PER_FAIL

func force_extract(enemy: Node2D) -> void:
	extract(enemy)

func extract(enemy: Node2D) -> void:
	var spawn_pos := enemy.global_position

	var scene := get_tree().current_scene
	if scene == null:
		return

	if arise_vfx_scene:
		var vfx := arise_vfx_scene.instantiate()
		vfx.global_position = spawn_pos
		scene.add_child(vfx)

	var thrall_type: String = "melee"
	if enemy.has_method("get_enemy_type"):
		thrall_type = enemy.get_enemy_type()

	if thrall_scene:
		var thrall := thrall_scene.instantiate()
		thrall.global_position = spawn_pos
		thrall.setup(self, thrall_type)
		scene.add_child(thrall)

	Audio.play_arise()
	Game.on_thrall_gained()

# --- Damage ---

func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or Game.boss_killed:
		return

	current_health -= amount
	current_health = max(current_health, 0.0)
	health_changed.emit(current_health, max_health)

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

# --- Draw ---

func _draw() -> void:
	# Subtle extraction range indicator (includes upgrades)
	var effective_range := extraction_range + Game.upgrade_extraction_bonus * 100.0
	draw_arc(Vector2.ZERO, effective_range, 0, TAU, 32, Color(0.2, 0.6, 0.8, 0.08), 1.0)

	# Command line to target
	if has_active_command:
		var local_cmd := command_position - global_position
		draw_dashed_line(Vector2.ZERO, local_cmd, Color(0.4, 0.8, 1.0, 0.2), 1.0, 6.0)
