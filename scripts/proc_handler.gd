extends Node

## Handles legendary equipment proc effects during combat.
## Attached to the player at runtime, reads procs from equipped items.

var player: CharacterBody2D = null
var active_procs: Array[Dictionary] = []

func setup(p: CharacterBody2D) -> void:
	player = p
	active_procs = _get_all_equipped_procs(SaveData.equipped)

## Get all procs including world-specific ones from equipped legendary items
func _get_all_equipped_procs(equipped_items: Array[Dictionary]) -> Array[Dictionary]:
	var procs: Array[Dictionary] = []
	for item in equipped_items:
		if item.is_empty() or not item.has("proc"):
			continue
		var proc_key: String = item["proc"]
		var found := false
		# Check standard procs
		for proc_def in Equipment.LEGENDARY_PROCS:
			if proc_def["key"] == proc_key:
				procs.append(proc_def)
				found = true
				break
		if found:
			continue
		# Check world-specific procs
		for proc_def in Equipment.WORLD_PROCS:
			if proc_def["key"] == proc_key:
				procs.append(proc_def)
				break
	return procs

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
			"sand_storm":
				if randf() < proc["chance"]:
					_proc_sand_storm(enemy, proc)
			"frostbite":
				if randf() < proc["chance"]:
					_proc_frostbite(enemy, proc)
			"void_rift":
				if randf() < proc["chance"]:
					_proc_void_rift(enemy, proc)
			"divine_smite":
				if randf() < proc["chance"]:
					_proc_divine_smite(enemy, proc)

## Called when the player takes damage. Returns damage to reflect.
func on_hit_taken(damage: float, attacker: Node2D) -> void:
	for proc in active_procs:
		if proc["key"] == "thorns" and attacker != null and is_instance_valid(attacker):
			var reflect: float = damage * proc["percent"]
			if attacker.has_method("take_damage"):
				attacker.take_damage(reflect)
				Effects.spawn_hit_sparks(attacker.global_position, Color(0.8, 0.4, 1.0))
				Audio.play_proc_thorns()

## Called when the player kills an enemy.
func on_kill(enemy: Node2D) -> void:
	for proc in active_procs:
		match proc["key"]:
			"soul_explosion":
				if randf() < proc["chance"]:
					_proc_soul_explosion(enemy, proc)
			"toxic_burst":
				_proc_toxic_burst(enemy, proc)

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
		_spawn_lightning_line(last_pos, enemy.global_position)
		last_pos = enemy.global_position
		targets_hit += 1
		if targets_hit >= max_targets:
			break
	if targets_hit > 0:
		Audio.play_proc_chain_lightning()

func _proc_lifesteal(damage_dealt: float, proc: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var heal_amount: float = damage_dealt * proc["percent"]
	if heal_amount >= 1.0:
		player.heal(heal_amount)
		Audio.play_proc_lifesteal()

func _proc_frost_slow(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_slow"):
		return
	enemy.apply_slow(proc["slow_amount"], proc["duration"])
	Effects.spawn_hit_sparks(enemy.global_position, Color(0.4, 0.7, 1.0))
	Audio.play_proc_frost_slow()

func _proc_burning(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
		return
	enemy.apply_burn(proc["dps"], proc["duration"])
	Effects.spawn_hit_sparks(enemy.global_position, Color(1.0, 0.5, 0.1))
	Audio.play_proc_burning()

func _proc_soul_explosion(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	var radius: float = proc["radius"]
	var dmg: float = proc["damage"]
	Effects.spawn_death_explosion(pos, Color(0.6, 0.2, 1.0))
	Audio.play_proc_soul_explosion()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == enemy or not is_instance_valid(e):
			continue
		if e.get("is_dying"):
			continue
		if e.global_position.distance_to(pos) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)

## Sand Storm: slow all nearby enemies (blind effect)
func _proc_sand_storm(source_enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(source_enemy):
		return
	var pos := source_enemy.global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dying"):
			continue
		if enemy.global_position.distance_to(pos) <= 120.0:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(proc["slow_amount"], proc["duration"])
	Effects.spawn_particles(pos, Color(0.9, 0.7, 0.2), 12, 0.4)
	Audio.play_proc_sand_storm()

## Frostbite: completely freeze enemy (100% slow for duration)
func _proc_frostbite(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_slow"):
		return
	enemy.apply_slow(1.0, proc["duration"])
	Effects.spawn_particles(enemy.global_position, Color(0.3, 0.7, 1.0), 10, 0.3)
	Audio.play_proc_frostbite()

## Toxic Burst: on kill, spawn poison cloud at enemy position
func _proc_toxic_burst(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pool := Node2D.new()
	pool.global_position = pos
	pool.set_script(preload("res://scripts/poison_pool.gd"))
	pool.setup(proc.get("radius", 60.0), proc["dps"], proc["duration"])
	scene.add_child(pool)
	Effects.spawn_particles(pos, Color(0.3, 0.9, 0.2), 10, 0.4)
	Audio.play_proc_toxic_burst()

## Void Rift: spawn a mini gravity rift that pulls enemies
func _proc_void_rift(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	var pull_strength: float = proc.get("pull", 80.0)
	var duration: float = proc["duration"]
	# Pull enemies over time
	var ticks := int(duration * 10)
	for i in range(ticks):
		get_tree().create_timer(float(i) * 0.1).timeout.connect(func():
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or e.get("is_dying"):
					continue
				var dist: float = e.global_position.distance_to(pos)
				if dist < 150.0 and dist > 10.0:
					var dir: Vector2 = e.global_position.direction_to(pos)
					e.knockback_velocity += dir * pull_strength * 0.1
		)
	Effects.spawn_particles(pos, Color(0.6, 0.1, 0.9), 16, 0.6)
	Audio.play_proc_void_rift()

## Divine Smite: holy AOE damage at enemy position
func _proc_divine_smite(enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	var radius: float = proc.get("radius", 90.0)
	var dmg: float = proc["damage"]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dying"):
			continue
		if e.global_position.distance_to(pos) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
	Effects.spawn_particles(pos, Color(1.0, 0.9, 0.4), 20, 0.5)
	# Visual: bright flash at impact
	var scene := get_tree().current_scene
	if scene:
		var vfx := Node2D.new()
		vfx.global_position = pos
		vfx.set_script(preload("res://scripts/explosion_vfx.gd"))
		vfx.set("max_radius", radius)
		scene.add_child(vfx)
	Audio.play_proc_divine_smite()

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
