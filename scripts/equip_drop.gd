extends Node2D

## Equipment drop pickup. Attracted to player, auto-equips or adds to inventory.

var equip_data: Dictionary = {}
var float_time: float = 0.0
var lifetime: float = 0.0
const MAX_LIFETIME: float = 20.0
const PICKUP_RANGE: float = 40.0
const ATTRACT_RANGE: float = 100.0
var collected: bool = false
var initial_velocity: Vector2 = Vector2.ZERO
var rarity_color: Color = Color.WHITE

func setup(data: Dictionary) -> void:
	equip_data = data
	rarity_color = Equipment.get_rarity_color(data["rarity"])
	initial_velocity = Vector2(randf_range(-70, 70), randf_range(-90, -30))

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

	var player := players[0]
	var dist := global_position.distance_to(player.global_position)

	if dist < ATTRACT_RANGE:
		var dir := global_position.direction_to(player.global_position)
		var speed := 250.0 * (1.0 - dist / ATTRACT_RANGE)
		global_position += dir * speed * delta

	if dist < PICKUP_RANGE:
		collected = true
		var result := SaveData.try_auto_equip(equip_data)
		Audio.play_upgrade()
		# Show pickup notification
		var rarity_name := Equipment.get_rarity_name(equip_data["rarity"])
		var slot_name := Equipment.get_slot_name(equip_data["slot"])
		var notify_text := "%s %s" % [rarity_name, slot_name]
		Game.spawn_damage_number(0, global_position + Vector2(0, -20), rarity_color)
		# Dramatic pickup: scale up + flash white then fade
		_dramatic_pickup()
		return

	queue_redraw()

func _dramatic_pickup() -> void:
	# Scale up + flash white, then shrink and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.08)
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector2(0.01, 0.01), 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var bob := sin(float_time * 3.0) * 3.0
	var pos := Vector2(0, bob)
	var pulse := 0.6 + 0.4 * sin(float_time * 4.0)

	# Glow
	draw_circle(pos, 12.0, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.12 * pulse))
	# Body (diamond shape)
	var size := 6.0
	var pts := PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size * 0.7, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size * 0.7, 0),
	])
	draw_colored_polygon(pts, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.85))
	# Highlight
	draw_circle(pos + Vector2(-1, -2), 2.5, Color(1.0, 1.0, 1.0, 0.5))
	# Sparkle particles
	for i in range(3):
		var angle := float(i) / 3.0 * TAU + float_time * 2.0
		var dist := 8.0 + 3.0 * sin(float_time * 3.0 + float(i))
		var spark_pos := pos + Vector2(cos(angle), sin(angle)) * dist
		draw_circle(spark_pos, 1.0, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.4 * pulse))

	# Blink near end of life
	if not collected and lifetime > MAX_LIFETIME - 3.0:
		var blink := int(lifetime * 4.0) % 2
		if blink == 0:
			modulate.a = 0.4
		else:
			modulate.a = 1.0
