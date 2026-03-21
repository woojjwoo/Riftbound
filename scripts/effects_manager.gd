extends Node

## EffectsManager: Spawns particle effects at world positions.
## Autoloaded as "Effects". All visual juice funnels through here.

# Enemy type -> color mapping for death explosions
const ENEMY_COLORS: Dictionary = {
	"melee": Color(0.9, 0.3, 0.2),       # red-orange
	"ranged": Color(0.3, 0.5, 1.0),      # blue
	"tank": Color(0.6, 0.4, 0.2),        # brown
	"flying": Color(0.7, 0.3, 0.9),      # purple
	"exploder": Color(1.0, 0.6, 0.1),    # orange
	"charger": Color(1.0, 0.3, 0.1),     # bright red
	"shielded": Color(0.3, 0.6, 1.0),    # steel blue
	"splitter": Color(0.5, 0.9, 0.3),    # lime green
	"summoner": Color(0.3, 0.9, 0.2),    # dark green
	"poisoner": Color(0.4, 0.8, 0.1),    # toxic green
	"teleporter": Color(0.9, 0.2, 0.9),  # magenta
	"voidcaller": Color(0.6, 0.1, 0.9),  # dark purple
}

const DEFAULT_COLOR: Color = Color(1.0, 0.5, 0.2)

## Spawn hit sparks at a position (when an enemy takes damage).
func spawn_hit_sparks(pos: Vector2, color: Color = Color.WHITE) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.25
	particles.speed_scale = 2.0

	# Shape: emit outward from center
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2.ZERO
	particles.damping_min = 200.0
	particles.damping_max = 300.0

	# Size: small sparks that shrink
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.scale_amount_curve = _create_fadeout_curve()

	# Color: bright flash that fades
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0))
	gradient.set_color(1, color)
	gradient.add_point(0.7, Color(color.r, color.g, color.b, 0.3))
	particles.color_ramp = gradient
	particles.color = color

	scene.add_child(particles)
	# Auto-cleanup after particles finish
	_auto_free(particles, 0.5)

## Spawn death explosion particles at a position (when an enemy dies).
## Color-coded by enemy type.
func spawn_death_explosion(pos: Vector2, enemy_type_or_color = "") -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var color: Color
	if enemy_type_or_color is Color:
		color = enemy_type_or_color
	else:
		color = ENEMY_COLORS.get(enemy_type_or_color, DEFAULT_COLOR)

	# Outer burst particles
	var burst := CPUParticles2D.new()
	burst.global_position = pos
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.4
	burst.speed_scale = 1.5

	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 6.0
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 180.0
	burst.gravity = Vector2(0, 40.0)
	burst.damping_min = 100.0
	burst.damping_max = 200.0

	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.5
	burst.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.3, color)
	burst.color_ramp = gradient

	scene.add_child(burst)

	# Inner flash — bright white circle that fades fast
	var flash := CPUParticles2D.new()
	flash.global_position = pos
	flash.emitting = true
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.amount = 6
	flash.lifetime = 0.2
	flash.speed_scale = 2.0

	flash.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flash.emission_sphere_radius = 2.0
	flash.direction = Vector2.ZERO
	flash.spread = 180.0
	flash.initial_velocity_min = 20.0
	flash.initial_velocity_max = 50.0
	flash.gravity = Vector2.ZERO
	flash.damping_min = 200.0
	flash.damping_max = 300.0

	flash.scale_amount_min = 3.0
	flash.scale_amount_max = 6.0
	flash.scale_amount_curve = _create_fadeout_curve()
	flash.color = Color(1.0, 1.0, 0.9)

	var flash_gradient := Gradient.new()
	flash_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	flash_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	flash.color_ramp = flash_gradient

	scene.add_child(flash)

	_auto_free(burst, 0.8)
	_auto_free(flash, 0.5)

## Spawn a level-up burst effect centered on a node.
func spawn_level_up_burst(pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	# Ring of golden particles expanding outward
	var ring := CPUParticles2D.new()
	ring.global_position = pos
	ring.emitting = true
	ring.one_shot = true
	ring.explosiveness = 1.0
	ring.amount = 24
	ring.lifetime = 0.6
	ring.speed_scale = 1.0

	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ring.emission_sphere_radius = 8.0
	ring.direction = Vector2.ZERO
	ring.spread = 180.0
	ring.initial_velocity_min = 100.0
	ring.initial_velocity_max = 200.0
	ring.gravity = Vector2.ZERO
	ring.damping_min = 150.0
	ring.damping_max = 250.0

	ring.scale_amount_min = 2.0
	ring.scale_amount_max = 4.0
	ring.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.5, 1.0))  # bright yellow
	gradient.set_color(1, Color(1.0, 0.8, 0.2, 0.0))   # golden fade
	gradient.add_point(0.4, Color(1.0, 0.9, 0.3, 1.0))
	ring.color_ramp = gradient

	scene.add_child(ring)

	# Upward sparkles — ascending particles for that "power up" feel
	var sparkles := CPUParticles2D.new()
	sparkles.global_position = pos
	sparkles.emitting = true
	sparkles.one_shot = true
	sparkles.explosiveness = 0.6
	sparkles.amount = 12
	sparkles.lifetime = 0.8
	sparkles.speed_scale = 1.0

	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(20.0, 5.0)
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 30.0
	sparkles.initial_velocity_min = 60.0
	sparkles.initial_velocity_max = 140.0
	sparkles.gravity = Vector2(0, -20.0)  # float upward
	sparkles.damping_min = 30.0
	sparkles.damping_max = 60.0

	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.0
	sparkles.scale_amount_curve = _create_fadeout_curve()

	var sparkle_gradient := Gradient.new()
	sparkle_gradient.set_color(0, Color(1.0, 1.0, 0.8, 1.0))
	sparkle_gradient.set_color(1, Color(0.9, 0.7, 0.2, 0.0))
	sparkles.color_ramp = sparkle_gradient

	scene.add_child(sparkles)

	_auto_free(ring, 1.0)
	_auto_free(sparkles, 1.2)

## Spawn a dramatic boss entrance effect at a position.
## Large shockwave ring + dark energy particles + screen shake.
func spawn_boss_entrance(pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	# Dark energy shockwave — large expanding ring
	var shockwave := CPUParticles2D.new()
	shockwave.global_position = pos
	shockwave.emitting = true
	shockwave.one_shot = true
	shockwave.explosiveness = 1.0
	shockwave.amount = 32
	shockwave.lifetime = 0.8
	shockwave.speed_scale = 1.0

	shockwave.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	shockwave.emission_sphere_radius = 10.0
	shockwave.direction = Vector2.ZERO
	shockwave.spread = 180.0
	shockwave.initial_velocity_min = 120.0
	shockwave.initial_velocity_max = 280.0
	shockwave.gravity = Vector2.ZERO
	shockwave.damping_min = 80.0
	shockwave.damping_max = 150.0

	shockwave.scale_amount_min = 3.0
	shockwave.scale_amount_max = 6.0
	shockwave.scale_amount_curve = _create_fadeout_curve()

	var shockwave_grad := Gradient.new()
	shockwave_grad.set_color(0, Color(0.8, 0.1, 0.1, 1.0))  # deep red
	shockwave_grad.set_color(1, Color(0.3, 0.0, 0.0, 0.0))
	shockwave_grad.add_point(0.3, Color(1.0, 0.2, 0.1, 0.9))
	shockwave.color_ramp = shockwave_grad

	scene.add_child(shockwave)

	# Dark swirling particles — ominous feel
	var dark := CPUParticles2D.new()
	dark.global_position = pos
	dark.emitting = true
	dark.one_shot = true
	dark.explosiveness = 0.4
	dark.amount = 20
	dark.lifetime = 1.2
	dark.speed_scale = 1.0

	dark.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dark.emission_sphere_radius = 20.0
	dark.direction = Vector2(0, -1)
	dark.spread = 60.0
	dark.initial_velocity_min = 30.0
	dark.initial_velocity_max = 80.0
	dark.gravity = Vector2(0, -30.0)
	dark.damping_min = 20.0
	dark.damping_max = 40.0

	dark.scale_amount_min = 2.0
	dark.scale_amount_max = 5.0
	dark.scale_amount_curve = _create_fadeout_curve()

	var dark_grad := Gradient.new()
	dark_grad.set_color(0, Color(0.4, 0.0, 0.1, 0.8))
	dark_grad.set_color(1, Color(0.1, 0.0, 0.05, 0.0))
	dark_grad.add_point(0.5, Color(0.6, 0.1, 0.2, 0.5))
	dark.color_ramp = dark_grad

	scene.add_child(dark)

	# Ground cracks — horizontal burst
	var cracks := CPUParticles2D.new()
	cracks.global_position = pos
	cracks.emitting = true
	cracks.one_shot = true
	cracks.explosiveness = 0.9
	cracks.amount = 12
	cracks.lifetime = 0.6
	cracks.speed_scale = 1.0

	cracks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cracks.emission_rect_extents = Vector2(5.0, 2.0)
	cracks.direction = Vector2(0, 0)
	cracks.spread = 180.0
	cracks.initial_velocity_min = 150.0
	cracks.initial_velocity_max = 300.0
	cracks.gravity = Vector2.ZERO
	cracks.damping_min = 200.0
	cracks.damping_max = 400.0

	# Flatten: mostly horizontal movement
	cracks.scale_amount_min = 1.5
	cracks.scale_amount_max = 3.0
	cracks.scale_amount_curve = _create_fadeout_curve()

	var crack_grad := Gradient.new()
	crack_grad.set_color(0, Color(1.0, 0.4, 0.1, 1.0))
	crack_grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	cracks.color_ramp = crack_grad

	scene.add_child(cracks)

	_auto_free(shockwave, 1.2)
	_auto_free(dark, 1.8)
	_auto_free(cracks, 1.0)

	# Screen shake for boss entrance
	Game.request_shake(12.0)

## Spawn generic particles at a position with given color.
func spawn_particles(pos: Vector2, color: Color, count: int = 10, lifetime: float = 0.4) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = count
	particles.lifetime = lifetime

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0, 30.0)
	particles.damping_min = 80.0
	particles.damping_max = 150.0

	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.3, color)
	particles.color_ramp = gradient

	scene.add_child(particles)
	_auto_free(particles, lifetime + 0.5)

## World-specific ambient particle colors and styles
const WORLD_PARTICLE_CONFIG: Dictionary = {
	0: {"color": Color(0.6, 0.2, 0.8), "color2": Color(0.3, 0.1, 0.5), "name": "dark_wisps"},
	1: {"color": Color(1.0, 0.6, 0.1), "color2": Color(0.9, 0.3, 0.0), "name": "ember_sparks"},
	2: {"color": Color(0.5, 0.8, 1.0), "color2": Color(0.2, 0.4, 0.9), "name": "ice_crystals"},
	3: {"color": Color(0.3, 0.9, 0.2), "color2": Color(0.5, 0.7, 0.1), "name": "toxic_bubbles"},
	4: {"color": Color(0.7, 0.3, 1.0), "color2": Color(0.4, 0.0, 0.8), "name": "void_tears"},
	5: {"color": Color(1.0, 0.95, 0.6), "color2": Color(1.0, 0.8, 0.3), "name": "holy_motes"},
}

## Spawn world-themed ambient particles around a position (e.g. player).
func spawn_world_ambient(pos: Vector2, world_id: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var config: Dictionary = WORLD_PARTICLE_CONFIG.get(world_id, WORLD_PARTICLE_CONFIG[0])
	var c1: Color = config["color"]
	var c2: Color = config["color2"]

	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.3
	particles.amount = 6
	particles.lifetime = 1.2
	particles.speed_scale = 1.0

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 40.0
	particles.direction = Vector2(0, -1)
	particles.spread = 90.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2(0, -15.0) if world_id != 3 else Vector2(0, 10.0)
	particles.damping_min = 10.0
	particles.damping_max = 30.0

	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(c1.r, c1.g, c1.b, 0.6))
	gradient.set_color(1, Color(c2.r, c2.g, c2.b, 0.0))
	gradient.add_point(0.4, Color(c1.r, c1.g, c1.b, 0.4))
	particles.color_ramp = gradient

	scene.add_child(particles)
	_auto_free(particles, 1.8)

## World-themed death explosion — replaces generic death for flavor.
func spawn_world_death(pos: Vector2, world_id: int, enemy_type: String = "") -> void:
	# Base death explosion
	spawn_death_explosion(pos, enemy_type)

	var scene := get_tree().current_scene
	if scene == null:
		return
	var config: Dictionary = WORLD_PARTICLE_CONFIG.get(world_id, WORLD_PARTICLE_CONFIG[0])
	var c1: Color = config["color"]

	# Extra world-flavored particles on death
	var extra := CPUParticles2D.new()
	extra.global_position = pos
	extra.emitting = true
	extra.one_shot = true
	extra.explosiveness = 0.9
	extra.lifetime = 0.5

	match world_id:
		1:  # Desert — upward ember shower
			extra.amount = 10
			extra.direction = Vector2(0, -1)
			extra.spread = 40.0
			extra.initial_velocity_min = 60.0
			extra.initial_velocity_max = 140.0
			extra.gravity = Vector2(0, -20.0)
		2:  # Ice — outward ice shard burst
			extra.amount = 8
			extra.direction = Vector2.ZERO
			extra.spread = 180.0
			extra.initial_velocity_min = 80.0
			extra.initial_velocity_max = 200.0
			extra.gravity = Vector2(0, 60.0)
		3:  # Swamp — slow rising poison cloud
			extra.amount = 12
			extra.direction = Vector2(0, -1)
			extra.spread = 60.0
			extra.initial_velocity_min = 20.0
			extra.initial_velocity_max = 50.0
			extra.gravity = Vector2(0, -10.0)
			extra.lifetime = 0.8
		4:  # Void — imploding particles
			extra.amount = 10
			extra.direction = Vector2.ZERO
			extra.spread = 180.0
			extra.initial_velocity_min = -60.0
			extra.initial_velocity_max = -20.0
			extra.gravity = Vector2.ZERO
		5:  # Celestial — golden sparkle burst
			extra.amount = 14
			extra.direction = Vector2(0, -1)
			extra.spread = 90.0
			extra.initial_velocity_min = 50.0
			extra.initial_velocity_max = 120.0
			extra.gravity = Vector2(0, -30.0)
		_:  # Dark realm — default dark wisps
			extra.amount = 8
			extra.direction = Vector2(0, -1)
			extra.spread = 120.0
			extra.initial_velocity_min = 30.0
			extra.initial_velocity_max = 80.0
			extra.gravity = Vector2.ZERO

	extra.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	extra.emission_sphere_radius = 8.0
	extra.damping_min = 40.0
	extra.damping_max = 80.0
	extra.scale_amount_min = 1.5
	extra.scale_amount_max = 3.5
	extra.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(c1.r, c1.g, c1.b, 0.9))
	gradient.set_color(1, Color(c1.r * 0.5, c1.g * 0.5, c1.b * 0.5, 0.0))
	extra.color_ramp = gradient

	scene.add_child(extra)
	_auto_free(extra, 1.2)

## Spawn extraction VFX — soul rising from corpse to player
func spawn_extraction_vfx(from_pos: Vector2, to_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dir := (to_pos - from_pos).normalized()
	var particles := CPUParticles2D.new()
	particles.global_position = from_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.amount = 10
	particles.lifetime = 0.6

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = dir
	particles.spread = 25.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, -40.0)
	particles.damping_min = 50.0
	particles.damping_max = 100.0

	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 1.0, 0.5, 1.0))
	gradient.set_color(1, Color(0.1, 0.6, 0.3, 0.0))
	particles.color_ramp = gradient

	scene.add_child(particles)
	_auto_free(particles, 1.0)

## Spawn rift closing VFX — swirling vortex effect
func spawn_rift_close_vfx(pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	# Implosion ring
	var implode := CPUParticles2D.new()
	implode.global_position = pos
	implode.emitting = true
	implode.one_shot = true
	implode.explosiveness = 0.6
	implode.amount = 20
	implode.lifetime = 0.7

	implode.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	implode.emission_sphere_radius = 50.0
	implode.direction = Vector2.ZERO
	implode.spread = 180.0
	implode.initial_velocity_min = -100.0
	implode.initial_velocity_max = -30.0
	implode.gravity = Vector2.ZERO
	implode.damping_min = 20.0
	implode.damping_max = 40.0

	implode.scale_amount_min = 2.0
	implode.scale_amount_max = 5.0
	implode.scale_amount_curve = _create_fadeout_curve()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.8, 0.3, 1.0, 1.0))
	gradient.set_color(1, Color(0.2, 0.0, 0.4, 0.0))
	gradient.add_point(0.5, Color(0.6, 0.2, 0.9, 0.7))
	implode.color_ramp = gradient

	scene.add_child(implode)
	_auto_free(implode, 1.2)
	Game.request_shake(6.0)

## Create a curve that fades from 1 -> 0 (used for scale_amount_curve).
func _create_fadeout_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.5, 0.6))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

## Auto-free a node after a delay.
func _auto_free(node: Node, delay: float) -> void:
	if not is_instance_valid(node):
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)
