extends Area2D

## Simple projectile with trail effect. Moves in a direction, damages targets in a group.

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: float = 10.0
var target_group: String = "player"

# Trail
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 8
var trail_color: Color = Color(1.0, 0.6, 0.2, 0.8)

func setup(dir: Vector2, dmg: float, group: String) -> void:
	direction = dir.normalized()
	damage = dmg
	target_group = group
	# Different trail colors based on who shot it
	if group == "enemies":
		trail_color = Color(0.3, 0.8, 1.0, 0.8)  # cyan for friendly
	else:
		trail_color = Color(1.0, 0.4, 0.1, 0.8)  # orange for enemy

func _ready() -> void:
	# Auto-destroy after 3 seconds
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Store trail position before moving
	trail_points.push_front(global_position)
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_back()

	position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	# Draw trail circles behind projectile
	for i in range(trail_points.size()):
		var alpha := 1.0 - float(i) / float(MAX_TRAIL_POINTS)
		var radius := 4.0 * alpha
		var local_pos := trail_points[i] - global_position
		var col := trail_color
		col.a = alpha * 0.6
		draw_circle(local_pos, radius, col)
	# Draw projectile glow
	draw_circle(Vector2.ZERO, 5.0, trail_color)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.8))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		if target_group == "player":
			body.take_damage(damage, global_position)
		else:
			body.take_damage(damage)
		Game.spawn_damage_number(damage, body.global_position, Color(1.0, 0.6, 0.2))
		queue_free()
