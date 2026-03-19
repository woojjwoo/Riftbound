extends Node2D

## Portal that appears after clearing a world (all rifts closed).
## Walk into it to advance to the next world or return to the hub.

var time: float = 0.0
var active: bool = false
var portal_radius: float = 40.0
var next_world_id: int = 0
var portal_color: Color = Color(0.4, 0.8, 1.0)

func setup(next_world: int) -> void:
	next_world_id = next_world
	if next_world < WorldData.get_world_count():
		var config := WorldData.get_config(next_world)
		portal_color = config.get("rift_color", Color(0.4, 0.8, 1.0))

func _ready() -> void:
	add_to_group("world_portal")
	# Spawn animation
	scale = Vector2(0.01, 0.01)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_callback(func(): active = true)
	Game.request_shake(10.0)
	Audio.play_phase_change()

func _process(delta: float) -> void:
	time += delta
	if not active:
		queue_redraw()
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		var dist := global_position.distance_to(player.global_position)
		if dist < portal_radius:
			_enter_portal()

	queue_redraw()

func _enter_portal() -> void:
	active = false
	# Prevent game over from firing after portal entry
	Game.is_game_over = true
	Game.hit_freeze(0.1)
	Game.request_shake(15.0)
	Audio.play_victory()

	# Save progress (guard against double-counting in trigger_game_over)
	SaveData.complete_world(Game.current_world)
	SaveData.total_runs += 1
	SaveData.total_kills += Game.kill_count
	SaveData.save_game()

	if next_world_id >= WorldData.get_world_count():
		# Beat the final world — show ultimate victory
		Game.current_world = 0
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return

	# Show sacrifice/story screen before transitioning
	var sacrifice := Node2D.new()
	sacrifice.set_script(preload("res://scripts/sacrifice_screen.gd"))
	sacrifice.z_index = 100
	sacrifice.setup(next_world_id, Game.thrall_count)
	get_tree().current_scene.add_child(sacrifice)

func _draw() -> void:
	var t := time

	# Background glow
	var glow := 40.0 + sin(t * 1.5) * 8.0
	draw_circle(Vector2.ZERO, glow, Color(portal_color.r, portal_color.g, portal_color.b, 0.1))

	# Swirling arcs
	for i in range(4):
		var angle_offset := t * (1.0 + float(i) * 0.5)
		var radius := 15.0 + float(i) * 8.0
		var alpha := 0.5 - float(i) * 0.08
		draw_arc(Vector2.ZERO, radius, angle_offset, angle_offset + PI * 1.5, 20,
			Color(portal_color.r, portal_color.g, portal_color.b, alpha), 2.5)

	# Reverse arcs
	for i in range(2):
		var angle_offset := -t * (1.3 + float(i) * 0.6)
		var radius := 20.0 + float(i) * 7.0
		draw_arc(Vector2.ZERO, radius, angle_offset, angle_offset + PI, 16,
			Color(1.0, 1.0, 1.0, 0.2), 1.5)

	# Core
	var core_pulse := 0.6 + 0.4 * sin(t * 3.0)
	draw_circle(Vector2.ZERO, 10.0, Color(portal_color.r, portal_color.g, portal_color.b, 0.7 * core_pulse))
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 1.0, 0.5 * core_pulse))

	# Particles
	for i in range(8):
		var angle := float(i) / 8.0 * TAU + t * 2.0
		var dist := 28.0 + 8.0 * sin(t * 2.5 + float(i))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		draw_circle(pos, 2.0, Color(portal_color.r, portal_color.g, portal_color.b, 0.4))

	# Label
	if active:
		var font := ThemeDB.fallback_font
		var label_text := "ENTER PORTAL"
		if next_world_id < WorldData.get_world_count():
			label_text = "NEXT: " + WorldData.get_config(next_world_id)["name"].to_upper()
		var blink := 0.5 + 0.5 * sin(t * 4.0)
		draw_string(font, Vector2(-50, -55), label_text,
			HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color(portal_color.r, portal_color.g, portal_color.b, blink))
