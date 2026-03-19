extends Node2D

## A rift tear in reality that spawns enemies. Thralls can attack it to close it.
## The core objective — close all rifts to win.

var max_health: float = 150.0
var current_health: float
var rift_number: int = 1
var is_closed: bool = false

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var time_alive: float = 0.0

var enemy_scenes: Array[PackedScene] = []
var SpawnTelegraph: GDScript = preload("res://scripts/spawn_telegraph.gd")
var _boss_spawned: bool = false

signal rift_closed(rift_number: int)

func setup(number: int, hp: float, interval: float, scenes: Array[PackedScene]) -> void:
	rift_number = number
	max_health = hp
	current_health = hp
	spawn_interval = interval
	enemy_scenes = scenes

func _ready() -> void:
	add_to_group("rifts")
	current_health = max_health
	Game.request_shake(8.0)
	Audio.play_boss_enter()

	# Entrance animation
	scale = Vector2(0.1, 0.1)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Initial spawn delay
	spawn_timer = 1.5

func _process(delta: float) -> void:
	if is_closed:
		return

	time_alive += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval

	queue_redraw()

func take_damage(amount: float) -> void:
	if is_closed:
		return
	current_health -= amount
	Game.spawn_damage_number(amount, global_position + Vector2(0, -30), Color(0.8, 0.4, 1.0))

	# Boss spawn on final rift — threshold scales with player power
	# Stronger players face the boss earlier (at higher rift HP%)
	if rift_number == 5 and not _boss_spawned:
		var power := Game.get_power_level()
		var boss_threshold := 0.5 + clampf((power - 1.0) * 0.1, 0.0, 0.25)  # 50%-75%
		if current_health <= max_health * boss_threshold:
			_spawn_boss()

	if current_health <= 0.0:
		_close()

func _close() -> void:
	is_closed = true
	Audio.play_victory()
	Game.request_shake(12.0)
	Game.hit_freeze(0.1)

	# Kill remaining enemies from this rift? No — let them roam.
	# Dramatic close VFX
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
	vfx.set("max_radius", 120.0)
	get_tree().current_scene.add_child(vfx)

	rift_closed.emit(rift_number)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.01, 0.01), 0.6)
	tween.tween_callback(queue_free)

func _spawn_enemy() -> void:
	if enemy_scenes.is_empty():
		return
	var scene: PackedScene = enemy_scenes[randi() % enemy_scenes.size()]
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * 30.0
	var pos := global_position + offset

	# Telegraph
	var telegraph := Node2D.new()
	telegraph.set_script(SpawnTelegraph)
	telegraph.global_position = pos
	get_tree().current_scene.add_child(telegraph)

	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(_do_spawn.bind(scene, pos))

func _do_spawn(scene: PackedScene, pos: Vector2) -> void:
	if is_closed or Game.is_game_over:
		return
	var enemy := scene.instantiate()
	enemy.global_position = pos

	# Scale enemy stats based on player power level
	var power := Game.get_power_level()
	if power > 1.0:
		var scale_factor := 1.0 + (power - 1.0) * 0.4  # 40% of power surplus
		enemy.max_health *= scale_factor
		enemy.contact_damage *= (1.0 + (power - 1.0) * 0.25)  # 25% of power surplus
		enemy.move_speed *= (1.0 + (power - 1.0) * 0.1)  # 10% speed increase

	get_tree().current_scene.add_child(enemy)

	# Shielded enemies on later rifts — more likely when player is strong
	var shield_chance := 0.0
	if rift_number >= 4:
		shield_chance = 0.25
	if power > 1.5:
		shield_chance += (power - 1.5) * 0.15
	if shield_chance > 0.0 and randf() < shield_chance and enemy.has_method("enable_shield"):
		var shield_hits := 3 if power < 2.0 else 4
		enemy.enable_shield(shield_hits)

func _spawn_boss() -> void:
	_boss_spawned = true
	var boss_scene := load("res://scenes/boss.tscn")
	var angle := randf() * TAU
	var pos := global_position + Vector2(cos(angle), sin(angle)) * 80.0
	var boss := boss_scene.instantiate()
	boss.global_position = pos
	get_tree().current_scene.add_child(boss)
	Game.on_boss_spawned()

func _draw() -> void:
	if is_closed:
		return

	var t := Time.get_ticks_msec() * 0.001
	var ratio := current_health / max_health

	# Background glow — pulsing
	var glow_size := 35.0 + sin(t * 2.0) * 5.0
	draw_circle(Vector2.ZERO, glow_size, Color(0.4, 0.1, 0.6, 0.15))
	draw_circle(Vector2.ZERO, glow_size * 0.6, Color(0.5, 0.15, 0.7, 0.1))

	# Swirling arcs
	for i in range(3):
		var angle_offset := t * (1.5 + float(i) * 0.7)
		var radius := 12.0 + float(i) * 8.0
		var arc_alpha := 0.5 - float(i) * 0.1
		draw_arc(Vector2.ZERO, radius, angle_offset, angle_offset + PI * 1.5, 20,
			Color(0.6, 0.2, 0.9, arc_alpha), 2.0)

	# Reverse arcs
	for i in range(2):
		var angle_offset := -t * (1.2 + float(i) * 0.8)
		var radius := 18.0 + float(i) * 6.0
		draw_arc(Vector2.ZERO, radius, angle_offset, angle_offset + PI, 16,
			Color(0.8, 0.3, 0.5, 0.3), 1.5)

	# Core
	var core_pulse := 0.7 + 0.3 * sin(t * 4.0)
	draw_circle(Vector2.ZERO, 8.0, Color(0.8, 0.3 * core_pulse, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.8, 1.0, 0.6))

	# Spawn particles
	for i in range(6):
		var angle := float(i) / 6.0 * TAU + t * 2.0
		var dist := 25.0 + 10.0 * sin(t * 3.0 + float(i))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		draw_circle(pos, 2.0, Color(0.7, 0.3, 0.9, 0.4))

	# Health bar
	var bar_w: float = 50.0
	var bar_h: float = 5.0
	var bar_y: float = -50.0
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.15, 0.05, 0.2, 0.8))
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * ratio, bar_h), Color(0.6, 0.2, 0.9))
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.8, 0.5, 1.0, 0.6), false, 1.0)

	# Label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-20, bar_y - 4), "RIFT %d" % rift_number,
		HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.8, 0.6, 1.0))
