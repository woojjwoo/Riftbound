extends CharacterBody2D

## Boss enemy with attack patterns. Guaranteed extraction. Triggers victory on death.
## Patterns: chase, charge attack, ground slam, summon minions.

@export var move_speed: float = 80.0
@export var max_health: float = 300.0
@export var contact_damage: float = 20.0
@export var boss_name: String = "Rift Guardian"
@export var enrage_percent: float = 0.3
@export var enrage_speed_mult: float = 1.5

@export var sprite_idle: Texture2D
@export var sprite_run: Texture2D
@export var sprite_death: Texture2D
@export var projectile_scene: PackedScene

var current_health: float
var player: Node2D = null
var contact_timer: float = 0.0
var enraged: bool = false
var base_speed: float
var is_dying: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var world_color: Color = Color.WHITE
var enrage_color: Color = Color(1.0, 0.3, 0.3)

# Attack pattern state machine
enum BossState { CHASE, CHARGE_WINDUP, CHARGING, SLAM_WINDUP, SLAMMING, SUMMON, COOLDOWN }
var state: BossState = BossState.CHASE
var state_timer: float = 0.0
var pattern_timer: float = 3.0  # time until first pattern
var charge_direction: Vector2 = Vector2.ZERO
var charge_speed: float = 400.0
var slam_radius: float = 100.0
var slam_damage: float = 30.0
var pattern_index: int = 0

# World-specific boss abilities
var boss_world: int = 0
var _special_timer: float = 0.0
var _special_active: bool = false
var _barrage_count: int = 0
var _spin_elapsed: float = 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Apply world-specific boss stats
	var world_config := Game.get_world_config()
	max_health = world_config.get("boss_hp", 300.0)
	contact_damage = world_config.get("boss_dmg", 20.0)
	boss_name = world_config.get("boss_name", "Rift Guardian")
	slam_damage = contact_damage * 1.5

	# Scale boss stats based on player power level
	var power := Game.get_power_level()
	if power > 1.0:
		var hp_scale := 1.0 + (power - 1.0) * 0.5
		var dmg_scale := 1.0 + (power - 1.0) * 0.3
		max_health *= hp_scale
		contact_damage *= dmg_scale
		slam_damage *= dmg_scale
		charge_speed *= (1.0 + (power - 1.0) * 0.15)

	current_health = max_health
	base_speed = move_speed
	add_to_group("enemies")
	add_to_group("boss")

	# World-colored tint for boss identity
	var rift_color: Color = world_config.get("rift_color", Color(0.6, 0.2, 0.9))
	world_color = Color(
		lerp(1.0, rift_color.r, 0.3),
		lerp(1.0, rift_color.g, 0.3),
		lerp(1.0, rift_color.b, 0.3))
	enrage_color = Color(
		lerp(1.0, rift_color.r, 0.5),
		lerp(0.3, rift_color.g * 0.5, 0.3),
		lerp(0.3, rift_color.b * 0.5, 0.3))

	# Scale boss size per world for visual progression
	var boss_scale := 1.0 + Game.current_world * 0.08
	scale *= boss_scale

	if sprite_idle:
		sprite.texture = sprite_idle
		sprite.hframes = 6
	sprite.modulate = world_color

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	boss_world = Game.current_world

	# Dramatic entrance
	Effects.spawn_boss_entrance(global_position)
	Game.request_shake(12.0)
	Game.hit_freeze(0.1)
	Audio.play_boss_enter()

	scale = Vector2(0.2, 0.2)
	var entrance_tween := create_tween()
	entrance_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta: float) -> void:
	if Game.is_game_over or player == null or is_dying:
		return

	contact_timer -= delta
	state_timer -= delta
	pattern_timer -= delta
	_special_timer -= delta

	var dir := global_position.direction_to(player.global_position)
	var dist := global_position.distance_to(player.global_position)
	sprite.flip_h = dir.x < 0

	# World-specific periodic abilities
	if _special_timer <= 0.0 and state == BossState.CHASE:
		_do_world_special()
		_special_timer = _get_special_cooldown()

	# Check if it's time for an attack pattern
	if state == BossState.CHASE and pattern_timer <= 0.0:
		_start_next_pattern()

	match state:
		BossState.CHASE:
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
			velocity = dir * move_speed + knockback_velocity
			move_and_slide()

		BossState.CHARGE_WINDUP:
			# Stop and telegraph the charge
			velocity = Vector2.ZERO
			move_and_slide()
			# Flash red during windup
			var flash := 0.5 + 0.5 * sin(state_timer * 20.0)
			sprite.modulate = Color(1.0, flash, flash)
			if state_timer <= 0.0:
				state = BossState.CHARGING
				state_timer = 0.6
				charge_direction = dir
				Audio.play_boss_enrage()
				Game.request_shake(6.0)

		BossState.CHARGING:
			velocity = charge_direction * charge_speed
			move_and_slide()
			# Check for player collision during charge
			if dist < 30.0 and contact_timer <= 0.0:
				player.take_damage(contact_damage * 1.5, global_position)
				contact_timer = 1.0
				Game.request_shake(10.0)
				Game.hit_freeze(0.06)
			if state_timer <= 0.0:
				state = BossState.COOLDOWN
				state_timer = 1.0
				sprite.modulate = world_color if not enraged else enrage_color

		BossState.SLAM_WINDUP:
			velocity = Vector2.ZERO
			move_and_slide()
			# Jump up effect
			var t := 1.0 - state_timer / 0.6
			sprite.position.y = -40.0 * sin(t * PI)
			# Shadow growing
			if state_timer <= 0.0:
				state = BossState.SLAMMING
				state_timer = 0.1
				sprite.position.y = 0
				_do_slam()

		BossState.SLAMMING:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = BossState.COOLDOWN
				state_timer = 1.5

		BossState.SUMMON:
			velocity = Vector2.ZERO
			move_and_slide()
			sprite.modulate = Color(0.5, 0.3, 1.0)
			if state_timer <= 0.0:
				_do_summon()
				state = BossState.COOLDOWN
				state_timer = 1.5
				sprite.modulate = world_color if not enraged else enrage_color

		BossState.COOLDOWN:
			# Slowly approach player
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
			velocity = dir * move_speed * 0.5 + knockback_velocity
			move_and_slide()
			if state_timer <= 0.0:
				state = BossState.CHASE
				pattern_timer = 2.5 if not enraged else 1.5

	# Animate
	if velocity.length() > 10 and sprite_run:
		sprite.texture = sprite_run
	elif sprite_idle:
		sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 120) % 6

	if enraged and state == BossState.CHASE:
		var pulse := 0.3 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		sprite.modulate = Color(enrage_color.r, enrage_color.g * pulse / 0.3, enrage_color.b * pulse / 0.3)

	# Contact damage during chase
	if state == BossState.CHASE and contact_timer <= 0.0:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.is_in_group("player") and collider.has_method("take_damage"):
				collider.take_damage(contact_damage, global_position)
				contact_timer = 1.0
				Game.request_shake(6.0)
				Game.hit_freeze(0.04)
				break

	queue_redraw()

func _start_next_pattern() -> void:
	pattern_index += 1
	var patterns := [BossState.CHARGE_WINDUP, BossState.SLAM_WINDUP]
	if enraged:
		patterns.append(BossState.SUMMON)

	# World-specific boss abilities inject extra patterns
	match boss_world:
		1:  # Sand Colossus — extra charge attacks
			patterns.append(BossState.CHARGE_WINDUP)
		2:  # Frost Wyrm — extra slams (ice shatter)
			patterns.append(BossState.SLAM_WINDUP)
		3:  # Swamp Horror — extra summons
			patterns.append(BossState.SUMMON)
		4:  # Void Sovereign — charges more when enraged
			if enraged:
				patterns.append(BossState.CHARGE_WINDUP)
				patterns.append(BossState.CHARGE_WINDUP)
		5:  # The Eternal One — all patterns available always
			patterns.append(BossState.SUMMON)
			patterns.append(BossState.CHARGE_WINDUP)

	# Cycle through patterns with some randomness
	var chosen := patterns[pattern_index % patterns.size()]
	state = chosen

	match chosen:
		BossState.CHARGE_WINDUP:
			state_timer = 0.6  # windup time
		BossState.SLAM_WINDUP:
			state_timer = 0.6
		BossState.SUMMON:
			state_timer = 0.8

func _do_slam() -> void:
	Audio.play_explode()
	Game.request_shake(12.0)
	Game.hit_freeze(0.08)
	# Damage everything in radius
	if player and global_position.distance_to(player.global_position) < slam_radius:
		player.take_damage(slam_damage, global_position)
	# VFX
	var scene := get_tree().current_scene
	if scene:
		var vfx := Node2D.new()
		vfx.global_position = global_position
		vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
		vfx.set("max_radius", slam_radius)
		scene.add_child(vfx)

func _do_summon() -> void:
	# Spawn 2-3 small melee enemies around the boss
	Audio.play_boss_enrage()
	Game.request_shake(6.0)
	var count := 2 if not enraged else 3
	var melee_scene := load("res://scenes/enemy_melee.tscn")
	for i in range(count):
		var angle := float(i) / float(count) * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 60.0
		var spawn_pos := global_position + offset
		# Telegraph
		var telegraph := Node2D.new()
		telegraph.set_script(preload("res://scripts/spawn_telegraph.gd"))
		telegraph.global_position = spawn_pos
		var summon_scene := get_tree().current_scene
		if summon_scene:
			summon_scene.add_child(telegraph)
		# Delayed spawn
		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(_spawn_minion.bind(melee_scene, spawn_pos))

func _spawn_minion(scene: PackedScene, pos: Vector2) -> void:
	if is_dying or Game.is_game_over:
		return
	var enemy := scene.instantiate()
	enemy.global_position = pos
	# Minions are weaker than normal
	enemy.max_health = 20.0
	enemy.contact_damage = 5.0
	var current := get_tree().current_scene
	if current:
		current.add_child(enemy)

func take_damage(amount: float) -> void:
	if is_dying:
		return
	current_health -= amount

	if player:
		var kb_dir := player.global_position.direction_to(global_position)
		knockback_velocity = kb_dir * 60.0

	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", enrage_color if enraged else world_color, 0.15)

	sprite.scale = Vector2(1.2, 0.8)
	var scale_tween := create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

	Effects.spawn_hit_sparks(global_position, Color(1.0, 0.3, 0.2))
	Game.hit_freeze(0.03)
	Audio.play_hit_heavy()

	if not enraged and current_health / max_health <= enrage_percent:
		enraged = true
		move_speed = base_speed * enrage_speed_mult
		charge_speed *= 1.3
		sprite.modulate = enrage_color
		Game.request_shake(10.0)
		Game.hit_freeze(0.12)
		Audio.play_boss_enrage()

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	# Remove from groups immediately to prevent double-processing
	remove_from_group("enemies")
	remove_from_group("boss")
	Game.on_enemy_killed()
	# Boss death: big explosion + large screen shake
	Effects.spawn_death_explosion(global_position, "tank")
	Effects.spawn_particles(global_position, Color(1.0, 0.3, 0.1), 24, 0.6)
	Game.request_shake(15.0)
	Game.hit_freeze(0.15)

	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	# Capture position before any async operations
	var death_pos := global_position
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].force_extract(self)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", PI, 0.8)
	tween.chain().tween_callback(_on_death_complete.bind(death_pos))

func _on_death_complete(death_pos: Vector2) -> void:
	Game.on_boss_killed()
	# Boss drops big loot — use captured position since node may be invalid
	Game.spawn_boss_drops(death_pos)
	# Boss death weakens the final rift — deal 40% of its max HP
	for rift in get_tree().get_nodes_in_group("rifts"):
		if rift.has_method("take_damage"):
			rift.take_damage(rift.max_health * 0.4)
	queue_free()

## World-specific boss specials
func _get_special_cooldown() -> float:
	match boss_world:
		1: return 6.0 if not enraged else 4.0  # Sand barrage
		2: return 8.0 if not enraged else 5.0  # Frost ring
		3: return 5.0 if not enraged else 3.0  # Poison pools
		4: return 7.0 if not enraged else 4.0  # Void pull
		5: return 4.0 if not enraged else 2.5  # All abilities
	return 99.0  # World 0 has no special

func _do_world_special() -> void:
	match boss_world:
		1: _boss_sand_barrage()
		2: _boss_frost_ring()
		3: _boss_poison_pools()
		4: _boss_void_pull()
		5: _boss_eternal_wrath()

## Sand Colossus: fires projectiles in a spread pattern
func _boss_sand_barrage() -> void:
	if player == null:
		return
	Audio.play_boss_sand_barrage()
	var base_dir := global_position.direction_to(player.global_position)
	var spread := 5 if not enraged else 8
	var melee_scene := load("res://scenes/enemy_melee.tscn")
	for i in range(spread):
		var angle := (float(i) - float(spread) / 2.0) * 0.2
		var dir := base_dir.rotated(angle)
		# Spawn a fast-moving projectile
		if projectile_scene:
			var barrage_scene := get_tree().current_scene
			if barrage_scene:
				var proj := projectile_scene.instantiate()
				proj.global_position = global_position + dir * 20.0
				proj.setup(dir, contact_damage * 0.6, "player")
				barrage_scene.add_child(proj)
	Effects.spawn_particles(global_position, Color(0.9, 0.7, 0.2), 12, 0.3)

## Frost Wyrm: expanding ice ring that slows player
func _boss_frost_ring() -> void:
	if player == null:
		return
	Audio.play_boss_frost_ring()
	Game.request_shake(6.0)
	var radius := 140.0 if not enraged else 200.0
	if player and global_position.distance_to(player.global_position) < radius:
		# Slow the player temporarily
		var original_speed := player.move_speed
		player.move_speed *= 0.5
		player.sprite.modulate = Color(0.5, 0.7, 1.0)
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(player):
				player.move_speed = original_speed
				player.sprite.modulate = Color.WHITE
		)
	Effects.spawn_particles(global_position, Color(0.3, 0.7, 1.0), 20, 0.5)

## Swamp Horror: drops poison pools around the arena
func _boss_poison_pools() -> void:
	Audio.play_boss_poison_pools()
	var count := 3 if not enraged else 5
	for i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(60.0, 180.0)
		var pos := global_position + Vector2(cos(angle), sin(angle)) * dist
		var pool := Node2D.new()
		pool.global_position = pos
		pool.set_script(preload("res://scripts/poison_pool.gd"))
		pool.setup(25.0, contact_damage * 0.15, 6.0)
		var pool_scene := get_tree().current_scene
		if pool_scene:
			pool_scene.add_child(pool)
	Effects.spawn_particles(global_position, Color(0.3, 0.9, 0.2), 16, 0.4)

## Void Sovereign: pulls player toward the boss
func _boss_void_pull() -> void:
	if player == null:
		return
	Audio.play_boss_void_pull()
	Game.request_shake(8.0)
	var pull_strength := 150.0 if not enraged else 220.0
	var dir := player.global_position.direction_to(global_position)
	player.knockback_velocity += dir * pull_strength
	Effects.spawn_particles(global_position, Color(0.6, 0.1, 0.9), 20, 0.6)

## The Eternal One: random combination of all specials
func _boss_eternal_wrath() -> void:
	var abilities := [1, 2, 3, 4]
	abilities.shuffle()
	# Execute two random specials
	for i in range(2):
		match abilities[i]:
			1: _boss_sand_barrage()
			2: _boss_frost_ring()
			3: _boss_poison_pools()
			4: _boss_void_pull()

func get_enemy_type() -> String:
	return "tank"

func _draw() -> void:
	if is_dying:
		return

	# Slam windup shadow
	if state == BossState.SLAM_WINDUP:
		var t := 1.0 - state_timer / 0.6
		var shadow_radius := slam_radius * t
		draw_circle(Vector2.ZERO, shadow_radius, Color(0.0, 0.0, 0.0, 0.2 * t))
		draw_arc(Vector2.ZERO, shadow_radius, 0, TAU, 24, Color(enrage_color.r, enrage_color.g, enrage_color.b, 0.4 * t), 2.0)

	# Charge windup line
	if state == BossState.CHARGE_WINDUP and player:
		var dir := global_position.direction_to(player.global_position)
		var end := dir * 200.0
		var alpha := 0.3 + 0.3 * sin(state_timer * 15.0)
		draw_line(Vector2.ZERO, end, Color(enrage_color.r, enrage_color.g, enrage_color.b, alpha), 2.0)

	# Health bar
	var bar_width: float = 40.0
	var bar_height: float = 4.0
	var bar_y: float = -28.0
	var health_ratio := current_health / max_health
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.8, 0.7, 0.2, 0.8), false, 1.0)
	var fill_color := Color(0.8, 0.2, 0.2) if enraged else Color(0.8, 0.6, 0.1)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_ratio, bar_height), fill_color)
