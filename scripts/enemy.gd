extends CharacterBody2D

## Base enemy. Supports multiple behavior types including melee, ranged, tank,
## charger, exploder, shielded, splitter, summoner, poisoner, teleporter, voidcaller, flying.
## Can target player OR thralls. Defends rifts from thralls.
## Drops health orbs on death. Proximity extraction for thrall raising.

@export_enum("melee", "ranged", "tank", "charger", "exploder", "shielded",
	"splitter", "summoner", "poisoner", "teleporter", "voidcaller",
	"flying") var enemy_type: String = "melee"
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

# -- Charger config --
@export var charge_speed_mult: float = 3.0
@export var charge_duration: float = 0.4
@export var charge_windup: float = 1.0
@export var charge_cooldown_time: float = 3.0
@export var charge_trigger_range: float = 200.0

# -- Splitter config --
@export var split_count: int = 2
@export var split_scene: PackedScene

# -- Summoner config --
@export var summon_scene: PackedScene
@export var summon_cooldown: float = 5.0
@export var summon_count: int = 2
@export var summon_range: float = 200.0

# -- Poisoner config --
@export var poison_drop_interval: float = 0.8
@export var poison_radius: float = 20.0
@export var poison_damage: float = 3.0
@export var poison_duration: float = 4.0

# -- Teleporter config --
@export var teleport_cooldown: float = 3.0
@export var teleport_range: float = 120.0

# -- Voidcaller config --
@export var pull_strength: float = 60.0
@export var pull_radius: float = 150.0
@export var pull_cooldown: float = 4.0
@export var pull_duration: float = 2.0

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

# Charger state
var _charge_timer: float = 0.0
var _charge_state: int = 0  # 0=approach, 1=windup, 2=charging
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_elapsed: float = 0.0
var _windup_elapsed: float = 0.0

# Summoner state
var _summon_timer: float = 0.0

# Poisoner state
var _poison_timer: float = 0.0

# Teleporter state
var _teleport_timer: float = 0.0

# Voidcaller state
var _pull_timer: float = 0.0
var _pulling: bool = false
var _pull_elapsed: float = 0.0

# Draw helpers
var _draw_timer: float = 0.0

# Debuffs (from legendary procs)
var _slow_timer: float = 0.0
var _slow_amount: float = 0.0
var _burn_timer: float = 0.0
var _burn_dps: float = 0.0

# Shield
var has_shield: bool = false
var shield_hits: int = 0
var shield_max_hits: int = 3

# Elite variant
var is_elite: bool = false
var elite_type: String = ""  # "berserker", "armored", "swift", "vampiric"

# Flying
var fly_time: float = 0.0
var fly_amplitude: float = 20.0

# Exploder
var explode_radius: float = 80.0
var explode_damage: float = 20.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Apply world difficulty scaling to base stats
	var hp_mult: float = Game.get_enemy_hp_mult()
	var dmg_mult: float = Game.get_enemy_dmg_mult()
	max_health *= hp_mult * Challenges.get_enemy_hp_mult()
	contact_damage *= dmg_mult
	explode_damage *= dmg_mult
	poison_damage *= dmg_mult
	move_speed *= Challenges.get_enemy_speed_mult()

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
		"shielded":
			has_shield = true
			shield_hits = 0
			shield_max_hits = 3
		"summoner":
			_summon_timer = summon_cooldown * 0.5
		"teleporter":
			_teleport_timer = teleport_cooldown * 0.5
		"voidcaller":
			_pull_timer = pull_cooldown * 0.5
		"charger":
			_charge_timer = charge_cooldown_time * 0.3

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
	_draw_timer += delta

	# Retarget periodically
	if retarget_timer <= 0.0:
		_retarget()
		retarget_timer = RETARGET_INTERVAL

	# Process debuffs
	if _slow_timer > 0.0:
		_slow_timer -= delta
	if _burn_timer > 0.0:
		_burn_timer -= delta
		current_health -= _burn_dps * delta
		if current_health <= 0.0 and not is_dying:
			die()
			return

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
		"charger":
			_process_charger(delta, dir, dist)
			# charger handles its own velocity
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
			velocity += knockback_velocity
			move_and_slide()
			# Skip default movement below
			_animate_sprite()
			_process_contact_damage()
			queue_redraw()
			return
		"summoner":
			_process_summoner(delta, dir, dist)
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
			velocity += knockback_velocity
			move_and_slide()
			_animate_sprite()
			_process_contact_damage()
			queue_redraw()
			return
		"poisoner":
			_process_poisoner(delta, dir, dist)
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
			velocity += knockback_velocity
			move_and_slide()
			_animate_sprite()
			_process_contact_damage()
			queue_redraw()
			return
		"teleporter":
			_process_teleporter(delta, dir, dist)
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
			velocity += knockback_velocity
			move_and_slide()
			_animate_sprite()
			_process_contact_damage()
			queue_redraw()
			return
		"voidcaller":
			_process_voidcaller(delta, dir, dist)
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
			velocity += knockback_velocity
			move_and_slide()
			_animate_sprite()
			_process_contact_damage()
			queue_redraw()
			return

	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var effective_speed := move_speed * (1.0 - _slow_amount if _slow_timer > 0.0 else 1.0)
	velocity = dir * effective_speed + knockback_velocity
	move_and_slide()

	_animate_sprite()

	if enemy_type == "exploder" and dist < explode_radius * 2:
		var pulse := 0.5 + 0.5 * sin(fly_time * 10.0)
		sprite.modulate = Color(1.0, 0.3 + 0.4 * pulse, 0.2)

	_process_contact_damage()
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

func _animate_sprite() -> void:
	if velocity.length() > 10:
		if sprite_run:
			sprite.texture = sprite_run
	else:
		if sprite_idle:
			sprite.texture = sprite_idle
	sprite.hframes = 6
	sprite.frame = int(Time.get_ticks_msec() / 120) % 6

func _process_contact_damage() -> void:
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
						# Vampiric elite: heal on hit
						if is_elite and elite_type == "vampiric":
							var heal := contact_damage * 0.25
							current_health = minf(current_health + heal, max_health)
					break
				elif collider.is_in_group("thralls"):
					collider.take_damage(contact_damage * 0.6, global_position)
					contact_timer = 0.8
					break

## ---- NEW BEHAVIOR PROCESSORS ----

func _process_charger(delta: float, dir: Vector2, dist: float) -> void:
	_charge_timer -= delta
	match _charge_state:
		0:  # Approach
			velocity = dir * move_speed
			if dist <= charge_trigger_range and _charge_timer <= 0.0:
				_charge_state = 1
				_windup_elapsed = 0.0
				_charge_dir = dir
		1:  # Windup — pause and flash
			velocity = Vector2.ZERO
			_windup_elapsed += delta
			var flash := 0.5 + 0.5 * sin(_windup_elapsed * 20.0)
			sprite.modulate = Color(1.0 + flash, 1.0 - flash * 0.5, 1.0 - flash * 0.5)
			if _windup_elapsed >= charge_windup:
				_charge_state = 2
				_charge_elapsed = 0.0
				_charge_dir = global_position.direction_to(player.global_position) if player else dir
				sprite.modulate = Color.WHITE
		2:  # Charging
			velocity = _charge_dir * move_speed * charge_speed_mult
			_charge_elapsed += delta
			if _charge_elapsed >= charge_duration:
				_charge_state = 0
				_charge_timer = charge_cooldown_time

func _process_summoner(delta: float, dir: Vector2, dist: float) -> void:
	_summon_timer -= delta
	if dist < summon_range * 0.4:
		velocity = -dir * move_speed
	elif dist > summon_range:
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
		if _summon_timer <= 0.0:
			_do_summon()
			_summon_timer = summon_cooldown

func _process_poisoner(delta: float, dir: Vector2, _dist: float) -> void:
	velocity = dir * move_speed * 0.8
	_poison_timer -= delta
	if _poison_timer <= 0.0:
		_drop_poison()
		_poison_timer = poison_drop_interval

func _process_teleporter(delta: float, dir: Vector2, dist: float) -> void:
	_teleport_timer -= delta
	velocity = dir * move_speed
	if _teleport_timer <= 0.0 and dist > teleport_range * 0.5:
		_do_teleport()
		_teleport_timer = teleport_cooldown

func _process_voidcaller(delta: float, dir: Vector2, dist: float) -> void:
	_pull_timer -= delta
	if dist < pull_radius * 0.4:
		velocity = -dir * move_speed
	elif dist > pull_radius * 1.2:
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO

	if _pulling:
		_pull_elapsed += delta
		if _pull_elapsed >= pull_duration:
			_pulling = false
		else:
			if player and dist > 30.0:
				var pull_dir := player.global_position.direction_to(global_position)
				var strength := pull_strength * (1.0 - _pull_elapsed / pull_duration)
				player.velocity += pull_dir * strength * delta * 60.0
	elif _pull_timer <= 0.0 and dist <= pull_radius:
		_pulling = true
		_pull_elapsed = 0.0
		_pull_timer = pull_cooldown

## ---- ABILITY IMPLEMENTATIONS ----

func _do_summon() -> void:
	if summon_scene == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in range(summon_count):
		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 30.0
		var minion := summon_scene.instantiate()
		minion.global_position = global_position + offset
		minion.max_health *= 0.4
		minion.contact_damage *= 0.5
		minion.extraction_chance = 0.1
		scene.add_child(minion)

func _drop_poison() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pool := Node2D.new()
	pool.global_position = global_position
	pool.set_script(preload("res://scripts/poison_pool.gd"))
	pool.setup(poison_radius, poison_damage, poison_duration)
	scene.add_child(pool)

func _do_teleport() -> void:
	if player == null:
		return
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * randf_range(50.0, teleport_range)
	var target_pos := player.global_position + offset
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		global_position = target_pos
	)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.15)

func _split() -> void:
	if split_scene == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in range(split_count):
		var angle := float(i) / float(split_count) * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 20.0
		var child := split_scene.instantiate()
		child.global_position = global_position + offset
		scene.add_child(child)

func _shoot_at(target: Node2D) -> void:
	if projectile_scene == null or target == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dir := global_position.direction_to(target.global_position)
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	# Use correct target group based on who we're shooting at
	var group := "thralls" if target.is_in_group("thralls") else "player"
	proj.setup(dir, contact_damage, group)
	scene.add_child(proj)
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
			var shield_scene := get_tree().current_scene
			if shield_scene:
				var vfx := Node2D.new()
				vfx.global_position = global_position
				vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
				vfx.set("max_radius", 30.0)
				shield_scene.add_child(vfx)
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

	# Hit spark particles + small screen shake
	Effects.spawn_hit_sparks(global_position, Effects.ENEMY_COLORS.get(enemy_type, Color.WHITE))
	Game.request_shake(2.0)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dying = true
	Game.on_enemy_killed()
	SaveData.record_enemy_kill(enemy_type)
	Game.request_shake(3.0)
	Audio.play_kill()

	# Notify nearby thralls for kill assist (evolution system)
	for thrall in get_tree().get_nodes_in_group("thralls"):
		if global_position.distance_to(thrall.global_position) < 150.0:
			if thrall.has_method("record_kill_assist"):
				thrall.record_kill_assist()

	# Death explosion particles + medium screen shake
	Effects.spawn_death_explosion(global_position, enemy_type)
	Game.request_shake(5.0)

	if enemy_type == "exploder":
		_explode()
	elif enemy_type == "splitter":
		_split()

	if sprite_death:
		sprite.texture = sprite_death
		sprite.hframes = 6

	# Spawn coin and EXP drops
	Game.spawn_drops(global_position, enemy_type)

	if randf() < 0.2:
		_spawn_health_orb()

	# Proximity-based extraction + proc on kill
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p := players[0]
		if p.proc_handler:
			p.proc_handler.on_kill(self)
		if Game.guaranteed_extractions > 0:
			p.force_extract(self)
			Game.guaranteed_extractions -= 1
		else:
			p.try_extract_nearby(self, extraction_chance)

	var death_duration := 0.4
	if is_elite:
		# Elite death: bright flash + longer animation
		sprite.modulate = Color(2.0, 2.0, 1.5, 1.0)
		death_duration = 0.6
		Game.request_shake(6.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, death_duration)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), death_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", randf_range(-0.5, 0.5), death_duration)
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
	var scene := get_tree().current_scene
	if scene == null:
		return
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
	scene.add_child(vfx)

func _spawn_health_orb() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var orb := Node2D.new()
	orb.global_position = global_position
	orb.set_script(preload("res://scripts/health_orb.gd"))
	scene.add_child(orb)

## Apply slow debuff from legendary proc
func apply_slow(amount: float, duration: float) -> void:
	_slow_amount = amount
	_slow_timer = duration

## Apply burn debuff from legendary proc
func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = dps
	_burn_timer = duration

func get_enemy_type() -> String:
	return enemy_type

func enable_shield(hits: int = 3) -> void:
	has_shield = true
	shield_hits = 0
	shield_max_hits = hits

## Make this enemy an elite variant with bonus stats and abilities
func make_elite(type: String) -> void:
	is_elite = true
	elite_type = type
	match type:
		"berserker":
			contact_damage *= 1.6
			move_speed *= 1.15
			max_health *= 1.2
		"armored":
			max_health *= 2.0
			move_speed *= 0.85
		"swift":
			move_speed *= 1.5
			max_health *= 0.9
		"vampiric":
			max_health *= 1.4
	current_health = max_health
	# Elites are slightly larger
	scale *= 1.15

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

	# Shield ring
	if has_shield:
		var shield_alpha := 0.3 + 0.1 * sin(Time.get_ticks_msec() * 0.005)
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, Color(0.3, 0.6, 1.0, shield_alpha), 2.0)
		# Shield pips
		for i in range(shield_hits, shield_max_hits):
			var angle := float(i) / float(shield_max_hits) * TAU - PI / 2.0
			var pip_pos := Vector2(cos(angle), sin(angle)) * 18.0
			draw_circle(pip_pos, 2.5, Color(0.4, 0.7, 1.0, 0.8))

	# Voidcaller pull ring
	if enemy_type == "voidcaller" and _pulling:
		var pulse := _pull_elapsed / pull_duration
		var ring_alpha := 0.3 * (1.0 - pulse)
		var ring_color := Color(0.6, 0.1, 0.9, ring_alpha)
		var ring_radius := pull_radius * (0.3 + 0.7 * pulse)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 24, ring_color, 2.0)

	# Charger windup indicator
	if enemy_type == "charger" and _charge_state == 1:
		var progress := _windup_elapsed / charge_windup
		var indicator_color := Color(1.0, 0.3, 0.1, 0.4 + 0.4 * progress)
		draw_arc(Vector2.ZERO, 22.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 16,
			indicator_color, 3.0)

	# Summoner aura
	if enemy_type == "summoner":
		var aura_alpha := 0.1 + 0.05 * sin(_draw_timer * 2.0)
		draw_circle(Vector2.ZERO, 15.0, Color(0.3, 0.9, 0.2, aura_alpha))

	# Elite indicator
	if is_elite:
		var elite_color: Color
		match elite_type:
			"berserker": elite_color = Color(1.0, 0.2, 0.1, 0.6)
			"armored": elite_color = Color(0.6, 0.6, 0.7, 0.6)
			"swift": elite_color = Color(0.2, 0.9, 1.0, 0.6)
			"vampiric": elite_color = Color(0.8, 0.1, 0.3, 0.6)
			_: elite_color = Color(1.0, 0.8, 0.2, 0.6)
		var pulse := 0.7 + 0.3 * sin(_draw_timer * 3.0)
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 16, Color(elite_color.r, elite_color.g, elite_color.b, elite_color.a * pulse), 2.0)
		# Elite crown pips
		for i in range(3):
			var angle := float(i) / 3.0 * PI - PI / 2.0
			var pip_pos := Vector2(cos(angle), sin(angle)) * 22.0
			draw_circle(pip_pos, 2.0, elite_color)

	# Debuff indicators
	if _slow_timer > 0.0:
		# Frost/slow indicator — blue snowflake particles orbiting
		var slow_alpha := minf(_slow_timer, 1.0)
		draw_circle(Vector2.ZERO, 14.0, Color(0.3, 0.6, 1.0, 0.08 * slow_alpha))
		for i in range(4):
			var angle := float(i) / 4.0 * TAU + _draw_timer * 3.0
			var pos := Vector2(cos(angle), sin(angle)) * 12.0
			draw_circle(pos, 1.5, Color(0.4, 0.7, 1.0, 0.6 * slow_alpha))
		# Small "SLOW" text
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-10, 14), "SLOW", HORIZONTAL_ALIGNMENT_CENTER, 20, 7, Color(0.4, 0.7, 1.0, 0.5 * slow_alpha))

	if _burn_timer > 0.0:
		# Burn indicator — flickering orange/red flames
		var burn_alpha := minf(_burn_timer, 1.0)
		for i in range(5):
			var seed_val := float(i) * 73.1
			var fx := sin(_draw_timer * 6.0 + seed_val) * 8.0
			var fy := -6.0 - abs(sin(_draw_timer * 8.0 + seed_val * 0.5)) * 8.0
			var flame_size := 1.5 + sin(_draw_timer * 10.0 + seed_val) * 0.5
			var flame_color := Color(1.0, 0.4 + 0.3 * sin(_draw_timer * 7.0 + seed_val), 0.1, 0.6 * burn_alpha)
			draw_circle(Vector2(fx, fy), flame_size, flame_color)

	if current_health >= max_health:
		return
	var bar_width: float = 24.0
	var bar_height: float = 3.0
	var bar_y: float = -20.0
	var health_ratio := current_health / max_health
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	var fill_color := Color(0.2, 0.8, 0.2) if health_ratio > 0.5 else Color(0.8, 0.2, 0.2)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_ratio, bar_height), fill_color)
