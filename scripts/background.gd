extends Node2D

## Draws a themed ground grid pattern that follows the camera.
## Colors adapt to the current world. Adds animated weather/particle effects per world.

var grid_size: float = 40.0
var grid_color := Color(0.15, 0.12, 0.18, 0.3)
var bg_color := Color(0.08, 0.06, 0.1, 1.0)
var accent_color := Color(0.2, 0.15, 0.25, 0.15)

# How many cells to draw beyond the viewport
var padding: int = 3

# Weather / animated effect state
var time: float = 0.0
var weather_particles: Array[Dictionary] = []
const MAX_WEATHER_PARTICLES: int = 60

func _ready() -> void:
	_apply_world_theme()
	_init_weather_particles()

func _apply_world_theme() -> void:
	var config := Game.get_world_config()
	bg_color = config.get("bg_color", bg_color)
	grid_color = config.get("grid_color", grid_color)
	accent_color = config.get("accent_color", accent_color)

func _init_weather_particles() -> void:
	weather_particles.clear()
	for i in range(MAX_WEATHER_PARTICLES):
		weather_particles.append(_new_weather_particle(true))

func _new_weather_particle(randomize_y: bool) -> Dictionary:
	return {
		"x": randf_range(-800, 800),
		"y": randf_range(-500, 500) if randomize_y else -500.0,
		"speed": randf_range(30, 120),
		"size": randf_range(1.0, 3.5),
		"alpha": randf_range(0.1, 0.4),
		"drift": randf_range(-20, 20),
		"phase": randf() * TAU,
	}

func _process(delta: float) -> void:
	time += delta
	_update_weather(delta)
	queue_redraw()

func _update_weather(delta: float) -> void:
	var world_id := Game.current_world
	for i in range(weather_particles.size()):
		var p: Dictionary = weather_particles[i]
		match world_id:
			0:  # Dark Realm — rising soul wisps
				p["y"] -= p["speed"] * delta
				p["x"] += sin(time * 1.5 + p["phase"]) * 15.0 * delta
				if p["y"] < -550:
					weather_particles[i] = _new_weather_particle(false)
					weather_particles[i]["y"] = 500.0
			1:  # Scorched Sands — blowing sand
				p["x"] += p["speed"] * 1.8 * delta
				p["y"] += sin(time * 2.0 + p["phase"]) * 8.0 * delta
				if p["x"] > 850:
					weather_particles[i] = _new_weather_particle(true)
					weather_particles[i]["x"] = -800.0
			2:  # Frozen Wastes — falling snow
				p["y"] += p["speed"] * 0.7 * delta
				p["x"] += sin(time * 0.8 + p["phase"]) * 20.0 * delta + p["drift"] * delta
				if p["y"] > 550:
					weather_particles[i] = _new_weather_particle(false)
					weather_particles[i]["y"] = -500.0
			3:  # Toxic Marshes — rising poison bubbles
				p["y"] -= p["speed"] * 0.4 * delta
				p["x"] += sin(time * 1.2 + p["phase"]) * 10.0 * delta
				p["size"] = max(0.5, p["size"] - delta * 0.2)
				if p["y"] < -550 or p["size"] <= 0.5:
					weather_particles[i] = _new_weather_particle(false)
					weather_particles[i]["y"] = 500.0
					weather_particles[i]["size"] = randf_range(2.0, 4.0)
			4:  # The Void — drifting void shards
				p["x"] += cos(time * 0.5 + p["phase"]) * 30.0 * delta
				p["y"] += sin(time * 0.5 + p["phase"] * 1.3) * 30.0 * delta
				p["alpha"] = 0.15 + 0.15 * sin(time * 2.0 + p["phase"])
			5:  # Celestial Realm — twinkling stars / rising motes
				p["y"] -= p["speed"] * 0.3 * delta
				p["x"] += cos(time + p["phase"]) * 5.0 * delta
				p["alpha"] = 0.1 + 0.25 * abs(sin(time * 3.0 + p["phase"]))
				if p["y"] < -550:
					weather_particles[i] = _new_weather_particle(false)
					weather_particles[i]["y"] = 500.0

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var zoom := camera.zoom
	var cam_pos := camera.global_position
	var viewport_size := get_viewport_rect().size / zoom

	# Background fill (large rect)
	var bg_rect := Rect2(cam_pos - viewport_size, viewport_size * 2.0)
	draw_rect(bg_rect, bg_color)

	# Atmosphere layer — subtle gradient overlay per world
	_draw_atmosphere(cam_pos, viewport_size)

	# Grid lines
	var start_x: float = snapped(cam_pos.x - viewport_size.x, grid_size) - grid_size * padding
	var end_x := cam_pos.x + viewport_size.x + grid_size * padding
	var start_y: float = snapped(cam_pos.y - viewport_size.y, grid_size) - grid_size * padding
	var end_y := cam_pos.y + viewport_size.y + grid_size * padding

	# Vertical lines
	var x := start_x
	while x <= end_x:
		draw_line(Vector2(x, start_y), Vector2(x, end_y), grid_color, 1.0)
		x += grid_size

	# Horizontal lines
	var y := start_y
	while y <= end_y:
		draw_line(Vector2(start_x, y), Vector2(end_x, y), grid_color, 1.0)
		y += grid_size

	# Accent diamonds at grid intersections (sparse)
	x = start_x
	while x <= end_x:
		y = start_y
		while y <= end_y:
			var hash_val := int(x * 73.0 + y * 137.0) % 7
			if hash_val == 0:
				var diamond_size := 3.0
				var pts := PackedVector2Array([
					Vector2(x, y - diamond_size),
					Vector2(x + diamond_size, y),
					Vector2(x, y + diamond_size),
					Vector2(x - diamond_size, y),
				])
				draw_colored_polygon(pts, accent_color)
			y += grid_size
		x += grid_size

	# World-specific environmental decoration (static)
	var world_id := Game.current_world
	x = start_x
	while x <= end_x:
		y = start_y
		while y <= end_y:
			var hash_val := int(x * 31.0 + y * 97.0) % 13
			if hash_val == 0:
				_draw_world_detail(Vector2(x, y), world_id)
			y += grid_size
		x += grid_size

	# Animated weather particles
	_draw_weather(cam_pos)

func _draw_atmosphere(cam_pos: Vector2, viewport_size: Vector2) -> void:
	var world_id := Game.current_world
	var half := viewport_size
	match world_id:
		1:  # Desert heat shimmer — pulsing warm overlay at bottom
			var shimmer_alpha := 0.03 + 0.02 * sin(time * 1.5)
			var shimmer_rect := Rect2(cam_pos.x - half.x, cam_pos.y + half.y * 0.3,
				half.x * 2.0, half.y * 0.7)
			draw_rect(shimmer_rect, Color(0.4, 0.2, 0.05, shimmer_alpha))
		2:  # Frozen mist at bottom
			var mist_alpha := 0.04 + 0.02 * sin(time * 0.8)
			var mist_rect := Rect2(cam_pos.x - half.x, cam_pos.y + half.y * 0.4,
				half.x * 2.0, half.y * 0.6)
			draw_rect(mist_rect, Color(0.3, 0.4, 0.6, mist_alpha))
		3:  # Poison fog overlay
			var fog_alpha := 0.03 + 0.015 * sin(time * 1.0)
			var fog_rect := Rect2(cam_pos - half, half * 2.0)
			draw_rect(fog_rect, Color(0.15, 0.3, 0.05, fog_alpha))
		4:  # Void pulsing darkness
			var void_alpha := 0.02 + 0.02 * sin(time * 0.6)
			var void_rect := Rect2(cam_pos - half, half * 2.0)
			draw_rect(void_rect, Color(0.2, 0.0, 0.3, void_alpha))
		5:  # Celestial aurora bands
			for i in range(3):
				var band_y := cam_pos.y - half.y * 0.5 + float(i) * 80.0
				var band_alpha := 0.015 + 0.01 * sin(time * 0.5 + float(i) * 1.5)
				var hue := fmod(0.55 + float(i) * 0.15 + time * 0.02, 1.0)
				var aurora_color := Color.from_hsv(hue, 0.6, 0.8, band_alpha)
				var band_rect := Rect2(cam_pos.x - half.x, band_y, half.x * 2.0, 40.0)
				draw_rect(band_rect, aurora_color)

func _draw_weather(cam_pos: Vector2) -> void:
	var world_id := Game.current_world
	for p in weather_particles:
		var pos := Vector2(p["x"], p["y"]) + cam_pos
		var sz: float = p["size"]
		var alpha: float = p["alpha"]
		match world_id:
			0:  # Soul wisps — small glowing dots
				draw_circle(pos, sz, Color(0.5, 0.2, 0.8, alpha))
				draw_circle(pos, sz * 0.5, Color(0.7, 0.4, 1.0, alpha * 0.6))
			1:  # Sand particles — tiny warm dots
				draw_circle(pos, sz * 0.7, Color(0.7, 0.5, 0.2, alpha * 0.8))
			2:  # Snowflakes — white dots
				draw_circle(pos, sz, Color(0.8, 0.85, 1.0, alpha))
			3:  # Poison bubbles — green circles with outline
				draw_circle(pos, sz * 1.2, Color(0.3, 0.7, 0.1, alpha * 0.5))
				draw_arc(pos, sz * 1.2, 0, TAU, 8, Color(0.4, 0.9, 0.2, alpha * 0.3), 0.8)
			4:  # Void shards — small purple diamonds
				var d := sz * 1.5
				var pts := PackedVector2Array([
					pos + Vector2(0, -d), pos + Vector2(d * 0.6, 0),
					pos + Vector2(0, d), pos + Vector2(-d * 0.6, 0),
				])
				draw_colored_polygon(pts, Color(0.5, 0.15, 0.8, alpha))
			5:  # Celestial motes — golden sparkles
				draw_circle(pos, sz * 0.8, Color(1.0, 0.9, 0.5, alpha))
				if sz > 2.0:
					# Cross sparkle for bigger motes
					var arm := sz * 1.5
					draw_line(pos - Vector2(arm, 0), pos + Vector2(arm, 0),
						Color(1.0, 0.95, 0.7, alpha * 0.4), 0.5)
					draw_line(pos - Vector2(0, arm), pos + Vector2(0, arm),
						Color(1.0, 0.95, 0.7, alpha * 0.4), 0.5)

func _draw_world_detail(pos: Vector2, world_id: int) -> void:
	match world_id:
		0:  # Dark Realm — tombstones and bone fragments
			var h := int(pos.x * 53.0 + pos.y * 79.0) % 3
			if h == 0:
				# Tombstone silhouette
				draw_rect(Rect2(pos.x - 2, pos.y - 6, 4, 6), Color(0.2, 0.15, 0.25, 0.15))
				draw_rect(Rect2(pos.x - 3, pos.y - 6, 6, 2), Color(0.2, 0.15, 0.25, 0.12))
			else:
				# Bone fragment
				draw_line(pos, pos + Vector2(4, 1), Color(0.4, 0.35, 0.3, 0.12), 1.5)
		1:  # Desert — sand dunes
			draw_circle(pos, 5.0, Color(0.4, 0.3, 0.15, 0.2))
			draw_circle(pos + Vector2(3, 2), 3.0, Color(0.5, 0.35, 0.1, 0.15))
		2:  # Ice — snowflakes
			for i in range(3):
				var a := float(i) / 3.0 * PI
				var p1 := pos + Vector2(cos(a), sin(a)) * 4.0
				var p2 := pos - Vector2(cos(a), sin(a)) * 4.0
				draw_line(p1, p2, Color(0.5, 0.7, 1.0, 0.2), 1.0)
		3:  # Swamp — puddles
			draw_circle(pos, 6.0, Color(0.2, 0.4, 0.15, 0.18))
			draw_circle(pos + Vector2(2, -1), 3.0, Color(0.3, 0.5, 0.1, 0.12))
		4:  # Void — void cracks
			draw_line(pos, pos + Vector2(8, 3), Color(0.5, 0.2, 0.8, 0.2), 1.5)
			draw_line(pos, pos + Vector2(-5, 6), Color(0.4, 0.1, 0.7, 0.15), 1.5)
		5:  # Space — stars
			draw_circle(pos, 1.5, Color(1.0, 1.0, 0.8, 0.25))
			if int(pos.x * 17.0 + pos.y * 41.0) % 3 == 0:
				draw_circle(pos, 2.5, Color(0.8, 0.9, 1.0, 0.18))
