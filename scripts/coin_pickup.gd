extends Node2D

## Coin dropped by enemies. Attracted to player, gives coins on pickup.

var coin_value: int = 1
var float_time: float = 0.0
var lifetime: float = 0.0
const MAX_LIFETIME: float = 12.0
const PICKUP_RANGE: float = 35.0
const ATTRACT_RANGE: float = 120.0
var collected: bool = false
var initial_velocity: Vector2 = Vector2.ZERO
var _trail: Array[Vector2] = []
const TRAIL_COUNT: int = 3
var _trail_timer: float = 0.0

func setup(value: int = 1) -> void:
	coin_value = value
	# Random scatter on spawn
	initial_velocity = Vector2(randf_range(-60, 60), randf_range(-80, -20))

func _process(delta: float) -> void:
	if collected:
		return

	float_time += delta
	lifetime += delta

	# Apply initial scatter
	if lifetime < 0.3:
		global_position += initial_velocity * delta
		initial_velocity = initial_velocity.lerp(Vector2.ZERO, 5.0 * delta)

	if lifetime > MAX_LIFETIME:
		_fade_out()
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	var player := players[0]
	var dist := global_position.distance_to(player.global_position)

	var effective_attract := ATTRACT_RANGE + Meta.sanctum_coin_magnet
	if dist < effective_attract:
		var dir := global_position.direction_to(player.global_position)
		var speed := 300.0 * (1.0 - dist / effective_attract)
		global_position += dir * speed * delta
		# Spawn trail particles while attracted
		_trail_timer += delta
		if _trail_timer >= 0.04:
			_trail_timer = 0.0
			_trail.append(global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
			if _trail.size() > TRAIL_COUNT:
				_trail.remove_at(0)
	else:
		_trail.clear()

	if dist < PICKUP_RANGE:
		collected = true
		SaveData.add_coins(coin_value)
		Audio.play_pickup_coin()
		Game.spawn_damage_number(coin_value, global_position, Color(1.0, 0.85, 0.2))
		_fade_out()
		return

	queue_redraw()

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var bob := sin(float_time * 4.0) * 2.0
	var pos := Vector2(0, bob)
	var pulse := 0.7 + 0.3 * sin(float_time * 5.0)

	# Glow
	draw_circle(pos, 8.0, Color(0.9, 0.7, 0.1, 0.15 * pulse))
	# Coin body
	draw_circle(pos, 5.0, Color(1.0, 0.85, 0.2, 0.9))
	# Highlight
	draw_circle(pos + Vector2(-1, -2), 2.5, Color(1.0, 1.0, 0.6, 0.6))
	# Inner detail
	draw_circle(pos, 2.0, Color(0.8, 0.6, 0.1, 0.5))

	# Golden trail particles (drawn in local space)
	for i in range(_trail.size()):
		var trail_pos := _trail[i] - global_position
		var t: float = float(i) / max(float(_trail.size()), 1.0)
		var trail_alpha: float = 0.5 * t
		var trail_size: float = 1.5 + 1.5 * t
		draw_circle(trail_pos, trail_size, Color(1.0, 0.85, 0.2, trail_alpha))

	if not collected and lifetime > MAX_LIFETIME - 2.0:
		var blink := int(lifetime * 4.0) % 2
		if blink == 0:
			modulate.a = 0.4
		else:
			modulate.a = 1.0
