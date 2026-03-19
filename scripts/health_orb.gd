extends Node2D

## Health pickup dropped by enemies. Floats toward player when close.

var heal_amount: float = 15.0
var float_time: float = 0.0
var lifetime: float = 0.0
const MAX_LIFETIME: float = 8.0
const PICKUP_RANGE: float = 30.0
const ATTRACT_RANGE: float = 80.0
var collected: bool = false

func _process(delta: float) -> void:
	if collected:
		return

	float_time += delta
	lifetime += delta

	if lifetime > MAX_LIFETIME:
		_fade_out()
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	var player := players[0]
	var dist := global_position.distance_to(player.global_position)

	# Attract toward player when close
	if dist < ATTRACT_RANGE:
		var dir := global_position.direction_to(player.global_position)
		var speed := 200.0 * (1.0 - dist / ATTRACT_RANGE)
		global_position += dir * speed * delta

	# Pickup
	if dist < PICKUP_RANGE:
		collected = true
		if player.has_method("heal"):
			player.heal(heal_amount)
		_fade_out()
		return

	queue_redraw()

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Bobbing green orb
	var bob := sin(float_time * 3.0) * 3.0
	var pos := Vector2(0, bob)

	# Glow
	draw_circle(pos, 7.0, Color(0.2, 0.8, 0.3, 0.2))
	# Core
	draw_circle(pos, 4.0, Color(0.3, 1.0, 0.4, 0.8))
	# Highlight
	draw_circle(pos + Vector2(-1, -1), 2.0, Color(0.7, 1.0, 0.7, 0.6))

	# Fade pulse near end of life
	if lifetime > MAX_LIFETIME - 2.0:
		var blink := int(lifetime * 4.0) % 2
		if blink == 0:
			modulate.a = 0.4
		else:
			modulate.a = 1.0
