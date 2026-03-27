extends Node2D

## Procedural map prop/obstacle generator. Attached to the main scene.
## Spawns world-themed obstacles that create varied layouts each run.
## Props are static bodies that block movement and projectiles.

const PROP_RADIUS: float = 800.0  # Area around spawn to place props
const MIN_SPACING: float = 80.0   # Minimum distance between props
const PLAYER_SAFE_ZONE: float = 120.0  # No props within this range of center

var props: Array[Dictionary] = []
var _world_id: int = 0

# World-specific prop templates: {type, size, color, block_movement}
const WORLD_PROPS: Dictionary = {
	0: [  # Dark Realm — tombstones, bone piles
		{"type": "tombstone", "w": 16.0, "h": 24.0, "color": Color(0.25, 0.2, 0.3, 0.9), "blocks": true},
		{"type": "bone_pile", "w": 20.0, "h": 12.0, "color": Color(0.5, 0.45, 0.35, 0.7), "blocks": false},
		{"type": "pillar", "w": 12.0, "h": 30.0, "color": Color(0.3, 0.25, 0.35, 0.85), "blocks": true},
	],
	1: [  # Desert — sandstone pillars, cacti, ruins
		{"type": "pillar", "w": 14.0, "h": 28.0, "color": Color(0.6, 0.45, 0.25, 0.9), "blocks": true},
		{"type": "rock", "w": 22.0, "h": 16.0, "color": Color(0.5, 0.4, 0.2, 0.8), "blocks": true},
		{"type": "cactus", "w": 8.0, "h": 20.0, "color": Color(0.3, 0.5, 0.2, 0.7), "blocks": false},
	],
	2: [  # Ice — ice pillars, frozen rocks, snow mounds
		{"type": "ice_pillar", "w": 14.0, "h": 32.0, "color": Color(0.5, 0.7, 0.9, 0.85), "blocks": true},
		{"type": "snow_mound", "w": 24.0, "h": 14.0, "color": Color(0.8, 0.85, 0.95, 0.6), "blocks": false},
		{"type": "frozen_rock", "w": 18.0, "h": 18.0, "color": Color(0.4, 0.5, 0.65, 0.8), "blocks": true},
	],
	3: [  # Swamp — mushrooms, tree stumps, mud pools
		{"type": "mushroom", "w": 12.0, "h": 18.0, "color": Color(0.5, 0.3, 0.6, 0.8), "blocks": false},
		{"type": "stump", "w": 20.0, "h": 16.0, "color": Color(0.35, 0.3, 0.2, 0.85), "blocks": true},
		{"type": "mud_pool", "w": 28.0, "h": 10.0, "color": Color(0.3, 0.35, 0.15, 0.5), "blocks": false},
	],
	4: [  # Void — floating shards, distortion pillars
		{"type": "void_shard", "w": 10.0, "h": 26.0, "color": Color(0.5, 0.2, 0.8, 0.8), "blocks": true},
		{"type": "distortion", "w": 22.0, "h": 22.0, "color": Color(0.3, 0.1, 0.6, 0.4), "blocks": false},
		{"type": "crystal", "w": 8.0, "h": 20.0, "color": Color(0.7, 0.3, 1.0, 0.7), "blocks": true},
	],
	5: [  # Celestial — golden pillars, light wells, star fragments
		{"type": "gold_pillar", "w": 14.0, "h": 34.0, "color": Color(0.8, 0.7, 0.3, 0.9), "blocks": true},
		{"type": "light_well", "w": 20.0, "h": 20.0, "color": Color(1.0, 0.95, 0.7, 0.3), "blocks": false},
		{"type": "star_frag", "w": 12.0, "h": 14.0, "color": Color(0.9, 0.85, 0.5, 0.75), "blocks": true},
	],
}

# Layout patterns for variety
enum Layout { RANDOM, RING, CORRIDORS, SCATTERED, CLUSTERED }

var _layout: Layout = Layout.RANDOM
var _time: float = 0.0

func _ready() -> void:
	_world_id = Game.current_world
	_layout = [Layout.RANDOM, Layout.RING, Layout.CORRIDORS, Layout.SCATTERED, Layout.CLUSTERED][randi() % 5]
	_generate_props()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _generate_props() -> void:
	props.clear()
	var templates: Array = WORLD_PROPS.get(_world_id, WORLD_PROPS[0])
	if templates.is_empty():
		return

	var count := randi_range(12, 22)

	match _layout:
		Layout.RANDOM:
			_gen_random(templates, count)
		Layout.RING:
			_gen_ring(templates, count)
		Layout.CORRIDORS:
			_gen_corridors(templates, count)
		Layout.SCATTERED:
			_gen_scattered(templates, count)
		Layout.CLUSTERED:
			_gen_clustered(templates, count)

func _gen_random(templates: Array, count: int) -> void:
	for i in range(count):
		var pos := _random_pos()
		if pos == Vector2.ZERO:
			continue
		var tmpl: Dictionary = templates[randi() % templates.size()]
		_add_prop(pos, tmpl)

func _gen_ring(templates: Array, count: int) -> void:
	# Props in a ring around center
	var ring_radius := randf_range(250.0, 450.0)
	for i in range(count):
		var angle := float(i) / float(count) * TAU + randf_range(-0.1, 0.1)
		var r := ring_radius + randf_range(-40.0, 40.0)
		var pos := Vector2(cos(angle), sin(angle)) * r
		var tmpl: Dictionary = templates[randi() % templates.size()]
		_add_prop(pos, tmpl)

func _gen_corridors(templates: Array, count: int) -> void:
	# Create corridor walls along 2-3 axes
	var num_corridors := randi_range(2, 3)
	var per_corridor := count / num_corridors
	for c in range(num_corridors):
		var angle := float(c) / float(num_corridors) * PI + randf_range(-0.2, 0.2)
		var perp := Vector2(cos(angle), sin(angle))
		var side := Vector2(-perp.y, perp.x)
		var gap := randf_range(60.0, 100.0)
		for i in range(per_corridor):
			var along := (float(i) - per_corridor / 2.0) * 50.0
			var sign_val = 1.0 if i % 2 == 0 else -1.0
			var pos: Vector2 = perp * along + side * (gap * sign_val)
			if pos.length() < PLAYER_SAFE_ZONE:
				continue
			var tmpl: Dictionary = templates[randi() % templates.size()]
			_add_prop(pos, tmpl)

func _gen_scattered(templates: Array, count: int) -> void:
	# Widely scattered with large gaps
	for i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(200.0, PROP_RADIUS)
		var pos := Vector2(cos(angle), sin(angle)) * dist
		if pos.length() < PLAYER_SAFE_ZONE:
			continue
		var tmpl: Dictionary = templates[randi() % templates.size()]
		_add_prop(pos, tmpl)

func _gen_clustered(templates: Array, count: int) -> void:
	# 3-5 clusters of props
	var num_clusters := randi_range(3, 5)
	var per_cluster := count / num_clusters
	for c in range(num_clusters):
		var center_angle := randf() * TAU
		var center_dist := randf_range(150.0, 500.0)
		var cluster_center := Vector2(cos(center_angle), sin(center_angle)) * center_dist
		for i in range(per_cluster):
			var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
			var pos := cluster_center + offset
			if pos.length() < PLAYER_SAFE_ZONE:
				continue
			var tmpl: Dictionary = templates[randi() % templates.size()]
			_add_prop(pos, tmpl)

func _add_prop(pos: Vector2, tmpl: Dictionary) -> void:
	# Check spacing
	for existing in props:
		if pos.distance_to(existing["pos"]) < MIN_SPACING:
			return
	props.append({
		"pos": pos,
		"type": tmpl["type"],
		"w": tmpl["w"],
		"h": tmpl["h"],
		"color": tmpl["color"],
		"blocks": tmpl["blocks"],
		"angle": randf_range(-0.15, 0.15),
	})

func _random_pos() -> Vector2:
	for _attempt in range(10):
		var angle := randf() * TAU
		var dist := randf_range(PLAYER_SAFE_ZONE + 20.0, PROP_RADIUS)
		var pos := Vector2(cos(angle), sin(angle)) * dist
		if pos.length() >= PLAYER_SAFE_ZONE:
			return pos
	return Vector2.ZERO

func _draw() -> void:
	for prop in props:
		var pos: Vector2 = prop["pos"]
		var w: float = prop["w"]
		var h: float = prop["h"]
		var color: Color = prop["color"]
		var ptype: String = prop["type"]

		match ptype:
			"tombstone", "pillar", "ice_pillar", "gold_pillar":
				# Vertical rectangle with highlight
				draw_rect(Rect2(pos.x - w / 2, pos.y - h, w, h), color)
				draw_rect(Rect2(pos.x - w / 2 + 1, pos.y - h + 1, 3, h - 2),
					Color(color.r + 0.1, color.g + 0.1, color.b + 0.1, color.a * 0.5))
			"bone_pile", "snow_mound", "mud_pool":
				# Flat ellipse
				draw_circle(pos, w / 2.0, color)
				draw_circle(pos + Vector2(w * 0.15, 0), w / 3.0,
					Color(color.r + 0.05, color.g + 0.05, color.b + 0.05, color.a * 0.6))
			"rock", "frozen_rock", "stump":
				# Blocky shape
				draw_rect(Rect2(pos.x - w / 2, pos.y - h / 2, w, h), color)
				draw_rect(Rect2(pos.x - w / 2, pos.y - h / 2, w, h), Color(1, 1, 1, 0.05), false, 1.0)
			"cactus", "mushroom":
				# Stem + top
				draw_rect(Rect2(pos.x - 2, pos.y - h, 4, h), color)
				draw_circle(Vector2(pos.x, pos.y - h), w / 2.0,
					Color(color.r, color.g + 0.1, color.b, color.a))
			"void_shard", "crystal", "star_frag":
				# Diamond/crystal shape
				var pts := PackedVector2Array([
					Vector2(pos.x, pos.y - h / 2),
					Vector2(pos.x + w / 2, pos.y),
					Vector2(pos.x, pos.y + h / 2),
					Vector2(pos.x - w / 2, pos.y),
				])
				draw_colored_polygon(pts, color)
				# Inner glow
				var inner_color := Color(color.r + 0.2, color.g + 0.1, color.b + 0.2, color.a * 0.4)
				var inner := PackedVector2Array([
					Vector2(pos.x, pos.y - h / 4),
					Vector2(pos.x + w / 4, pos.y),
					Vector2(pos.x, pos.y + h / 4),
					Vector2(pos.x - w / 4, pos.y),
				])
				draw_colored_polygon(inner, inner_color)
			"distortion", "light_well":
				# Pulsing circle
				var pulse := 0.7 + 0.3 * sin(_time * 2.0 + pos.x * 0.1)
				draw_circle(pos, w / 2.0 * pulse, color)
				draw_arc(pos, w / 2.0 * pulse, 0, TAU, 16,
					Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, color.a * 0.3), 1.0)

## Check if a position collides with a blocking prop. Returns true if blocked.
func is_blocked(pos: Vector2, radius: float = 8.0) -> bool:
	for prop in props:
		if not prop["blocks"]:
			continue
		var ppos: Vector2 = prop["pos"]
		var pw: float = prop["w"]
		var ph: float = prop["h"]
		# Simple AABB + radius check
		var half_w := pw / 2.0 + radius
		var half_h := ph / 2.0 + radius
		if abs(pos.x - ppos.x) < half_w and abs(pos.y - ppos.y) < half_h:
			return true
	return false

## Get push-out vector if colliding with a blocking prop
func get_push_out(pos: Vector2, radius: float = 8.0) -> Vector2:
	var push := Vector2.ZERO
	for prop in props:
		if not prop["blocks"]:
			continue
		var ppos: Vector2 = prop["pos"]
		var pw: float = prop["w"]
		var ph: float = prop["h"]
		var half_w := pw / 2.0 + radius
		var half_h := ph / 2.0 + radius
		var dx := pos.x - ppos.x
		var dy := pos.y - ppos.y
		if abs(dx) < half_w and abs(dy) < half_h:
			# Push out along shortest axis
			var overlap_x: float = half_w - abs(dx)
			var overlap_y: float = half_h - abs(dy)
			if overlap_x < overlap_y:
				push.x += sign(dx) * overlap_x
			else:
				push.y += sign(dy) * overlap_y
	return push
