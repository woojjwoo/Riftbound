extends Node2D

## EXP orb dropped by enemies. Attracted to player, gives experience.

var exp_value: int = 5
var float_time: float = 0.0
var lifetime: float = 0.0
const MAX_LIFETIME: float = 15.0
const PICKUP_RANGE: float = 40.0
const ATTRACT_RANGE: float = 150.0
var collected: bool = false
var initial_velocity: Vector2 = Vector2.ZERO

func setup(value: int = 5) -> void:
	exp_value = value
	initial_velocity = Vector2(randf_range(-50, 50), randf_range(-70, -10))

func _process(delta: float) -> void:
	if collected:
		return

	float_time += delta
	lifetime += delta

	if lifetime < 0.3:
		global_position += initial_velocity * delta
		initial_velocity = initial_velocity.lerp(Vector2.ZERO, 5.0 * delta)

	if lifetime > MAX_LIFETIME:
		_fade_out()
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	var player: Node = players[0]
	var dist := global_position.distance_to(player.global_position)

	var effective_attract := ATTRACT_RANGE + Meta.sanctum_coin_magnet
	if dist < effective_attract:
		var dir := global_position.direction_to(player.global_position)
		var speed := 350.0 * (1.0 - dist / effective_attract)
		global_position += dir * speed * delta

	if dist < PICKUP_RANGE:
		collected = true
		# Apply Sanctum XP gain bonus on top of SaveData's perm_exp_mult
		var bonus_exp := int(exp_value * (1.0 + Meta.sanctum_xp_gain))
		SaveData.add_exp(bonus_exp)
		Audio.play_pickup_exp()
		Game.spawn_damage_number(bonus_exp, global_position, Color(0.3, 0.6, 1.0))
		_fade_out()
		return

	queue_redraw()

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var bob := sin(float_time * 3.5) * 2.5
	var pos := Vector2(0, bob)
	var pulse := 0.6 + 0.4 * sin(float_time * 4.0)

	# Pulsing glow circle behind the orb
	var glow_pulse := 0.5 + 0.5 * sin(float_time * 2.5)
	var glow_radius := 10.0 + 4.0 * glow_pulse
	draw_circle(pos, glow_radius, Color(0.2, 0.4, 1.0, 0.08 * glow_pulse))
	draw_circle(pos, glow_radius * 0.7, Color(0.3, 0.5, 1.0, 0.12 * glow_pulse))

	# Glow
	draw_circle(pos, 7.0, Color(0.2, 0.5, 1.0, 0.15 * pulse))
	# Core
	draw_circle(pos, 4.0, Color(0.3, 0.6, 1.0, 0.85))
	# Highlight
	draw_circle(pos + Vector2(-1, -1), 2.0, Color(0.6, 0.8, 1.0, 0.7))

	if not collected and lifetime > MAX_LIFETIME - 2.0:
		var blink := int(lifetime * 4.0) % 2
		if blink == 0:
			modulate.a = 0.4
		else:
			modulate.a = 1.0
