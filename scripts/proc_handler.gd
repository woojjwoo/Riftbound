extends Node

## Handles legendary equipment proc effects during combat.
## Attached to the player at runtime, reads procs from equipped items.

var player: CharacterBody2D = null
var active_procs: Array[Dictionary] = []

func setup(p: CharacterBody2D) -> void:
	player = p
	active_procs = Equipment.get_equipped_procs(SaveData.equipped)

## Called when the player's bolt hits an enemy. Returns bonus damage to deal.
func on_hit(enemy: Node2D, damage_dealt: float) -> void:
	for proc in active_procs:
		match proc["key"]:
			"chain_lightning":
				if randf() < proc["chance"]:
					_proc_chain_lightning(enemy, proc)
			"lifesteal":
				_proc_lifesteal(damage_dealt, proc)
			"frost_slow":
				if randf() < proc["chance"]:
					_proc_frost_slow(enemy, proc)
			"burning":
				if randf() < proc["chance"]:
					_proc_burning(enemy, proc)

## Called when the player takes damage. Returns damage to reflect.
func on_hit_taken(damage: float, attacker: Node2D) -> void:
	for proc in active_procs:
		if proc["key"] == "thorns" and attacker != null and is_instance_valid(attacker):
			var reflect := damage * proc["percent"]
			if attacker.has_method("take_damage"):
				attacker.take_damage(reflect)
				Effects.spawn_hit_sparks(attacker.global_position, Color(0.8, 0.4, 1.0))

## Called when the player kills an enemy.
func on_kill(enemy: Node2D) -> void:
	for proc in active_procs:
		if proc["key"] == "soul_explosion":
			if randf() < proc["chance"]:
				_proc_soul_explosion(enemy, proc)

func _proc_chain_lightning(source_enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(source_enemy):
		return
	var pos := source_enemy.global_position
	var targets_hit := 0
	var max_targets: int = proc["targets"]
	var dmg: float = proc["damage"]
	var last_pos := pos

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == source_enemy or not is_instance_valid(enemy):
			continue
		if enemy.get("is_dying"):
			continue
		if enemy.global_position.distance_to(last_pos) > 150.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
		Effects.spawn_hit_sparks(enemy.global_position, Color(0.4, 0.7, 1.0))
		# Draw lightning line effect
		_spawn_lightning_line(last_pos, enemy.global_position)
		last_pos = enemy.global_position
		targets_hit += 1
		if targets_hit >= max_targets:
			break

func _proc_lifesteal(damage_dealt: float, proc: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var heal_amount := damage_dealt * proc["percent"]
	if heal_amount >= 1.0:
		player.heal(heal_amount)

func _proc_frost_slow(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_slow"):
		return
	enemy.apply_slow(proc["slow_amount"], proc["duration"])
	Effects.spawn_hit_sparks(enemy.global_position, Color(0.4, 0.7, 1.0))

func _proc_burning(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
		return
	enemy.apply_burn(proc["dps"], proc["duration"])
	Effects.spawn_hit_sparks(enemy.global_position, Color(1.0, 0.5, 0.1))

func _proc_soul_explosion(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	var radius: float = proc["radius"]
	var dmg: float = proc["damage"]
	Effects.spawn_death_explosion(pos, Color(0.6, 0.2, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == enemy or not is_instance_valid(e):
			continue
		if e.get("is_dying"):
			continue
		if e.global_position.distance_to(pos) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)

func _spawn_lightning_line(from: Vector2, to: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.4, 0.7, 1.0, 0.8)
	# Jagged lightning segments
	var segments := 6
	var dir := (to - from) / float(segments)
	line.add_point(from)
	for i in range(1, segments):
		var pt := from + dir * float(i)
		pt += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		line.add_point(pt)
	line.add_point(to)
	scene.add_child(line)
	# Fade and remove
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
