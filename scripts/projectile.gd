extends Area2D

## Simple projectile. Moves in a direction, damages targets in a group.

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: float = 10.0
var target_group: String = "player"

func setup(dir: Vector2, dmg: float, group: String) -> void:
	direction = dir.normalized()
	damage = dmg
	target_group = group

func _ready() -> void:
	# Auto-destroy after 3 seconds
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
