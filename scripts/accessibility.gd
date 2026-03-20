extends Node

## Accessibility helpers. Autoloaded as "A11y".
## Provides colorblind-safe color remapping and font scaling utilities.

## Remap a color based on the active colorblind mode.
## Adjusts hue/saturation to improve distinguishability for common types.
func cb_color(color: Color) -> Color:
	var mode: int = SaveData.colorblind_mode
	if mode == 0:
		return color

	var r := color.r
	var g := color.g
	var b := color.b
	var a := color.a

	match mode:
		1:  # Deuteranopia (green-blind): shift greens toward blue
			var new_r := r * 0.625 + g * 0.375
			var new_g := r * 0.7 + g * 0.3
			var new_b := b * 0.3 + g * 0.7
			return Color(new_r, new_g, new_b, a)
		2:  # Protanopia (red-blind): shift reds toward yellow
			var new_r := r * 0.567 + g * 0.433
			var new_g := r * 0.558 + g * 0.442
			var new_b := b * 0.242 + g * 0.758
			return Color(new_r, new_g, new_b, a)
		3:  # Tritanopia (blue-blind): shift blues toward cyan
			var new_r := r * 0.95 + g * 0.05
			var new_g := g * 0.433 + b * 0.567
			var new_b := g * 0.475 + b * 0.525
			return Color(new_r, new_g, new_b, a)
	return color

## Get colorblind-safe enemy health bar color
func enemy_health_color() -> Color:
	return cb_color(Color(0.9, 0.2, 0.2))

## Get colorblind-safe friendly health bar color
func friendly_health_color() -> Color:
	return cb_color(Color(0.2, 0.9, 0.3))

## Get colorblind-safe warning color
func warning_color() -> Color:
	return cb_color(Color(1.0, 0.8, 0.2))

## Get scaled font size based on accessibility settings.
func font_size(base_size: int) -> int:
	return int(base_size * SaveData.font_size_scale)

## Find the nearest enemy to a given position within a max angle from a facing direction.
## Used for auto-aim assist.
func find_auto_aim_target(from_pos: Vector2, aim_dir: Vector2, max_range: float = 400.0) -> Node2D:
	if not SaveData.auto_aim_enabled:
		return null

	var enemies := Engine.get_main_loop().root.get_tree().get_nodes_in_group("enemies")
	var best_target: Node2D = null
	var best_score := 999999.0
	var strength: float = SaveData.auto_aim_strength

	# Auto-aim cone: wider cone at higher strength
	var max_angle := lerp(PI * 0.15, PI * 0.5, strength)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - from_pos
		var dist := to_enemy.length()
		if dist > max_range or dist < 10.0:
			continue
		var angle := aim_dir.angle_to(to_enemy)
		if abs(angle) > max_angle:
			continue
		# Score: prefer closer enemies and those nearer to center of aim
		var score := dist * 0.5 + abs(angle) * 200.0
		if score < best_score:
			best_score = score
			best_target = enemy

	return best_target

## Adjust an aim direction toward the auto-aim target.
## Returns the adjusted direction.
func apply_auto_aim(from_pos: Vector2, aim_dir: Vector2) -> Vector2:
	if not SaveData.auto_aim_enabled:
		return aim_dir

	var target := find_auto_aim_target(from_pos, aim_dir)
	if target == null:
		return aim_dir

	var to_target: Vector2 = (target.global_position - from_pos).normalized()
	var strength: float = SaveData.auto_aim_strength * 0.6  # Scale down for subtlety
	return aim_dir.lerp(to_target, strength).normalized()
