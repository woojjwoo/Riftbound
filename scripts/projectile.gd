extends Area2D

## Simple projectile with trail effect. Moves in a direction, damages targets in a group.
## Spawns hit VFX on impact.

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: float = 10.0
var target_group: String = "player"

# Trail
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 8
var trail_color: Color = Color(1.0, 0.6, 0.2, 0.8)

var HitVFX: GDScript = preload("res://scripts/hit_vfx.gd")

func setup(dir: Vector2, dmg: float, group: String) -> void:
	direction = dir.normalized()
	damage = dmg
	target_group = group
	if group == "enemies":
		trail_color = Color(0.3, 0.8, 1.0, 0.8)  # cyan for player/thrall shots
	else:
		trail_color = Color(1.0, 0.4, 0.1, 0.8)  # orange for enemy shots

func _ready() -> void:
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	trail_points.push_front(global_position)
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_back()
	position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	for i in range(trail_points.size()):
		var alpha := 1.0 - float(i) / float(MAX_TRAIL_POINTS)
		var radius := 4.0 * alpha
		var local_pos := trail_points[i] - global_position
		var col := trail_color
		col.a = alpha * 0.6
		draw_circle(local_pos, radius, col)
	draw_circle(Vector2.ZERO, 5.0, trail_color)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.8))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		if target_group == "player":
			body.take_damage(damage, global_position)
		elif target_group == "thralls":
			body.take_damage(damage, global_position)
		else:
			body.take_damage(damage)
			# Hit freeze on enemy impact — brief pause sells the hit
			Game.hit_freeze(0.04)
			# Trigger legendary proc effects on enemy hit (player bolts only)
			if target_group == "enemies":
				_trigger_procs(body)
		Game.spawn_damage_number(damage, body.global_position, Color(1.0, 0.6, 0.2))
		_spawn_hit_vfx(body.global_position)
		queue_free()

func _trigger_procs(enemy: Node2D) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node = players[0]
	if p.proc_handler:
		p.proc_handler.on_hit(enemy, damage)

func _spawn_hit_vfx(pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var vfx := Node2D.new()
	vfx.set_script(HitVFX)
	vfx.global_position = pos
	vfx.setup(trail_color)
	scene.add_child(vfx)
