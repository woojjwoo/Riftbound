extends Node

## Per-run milestones/mini-achievements. Autoloaded as "Milestones".
## Tracks goals within a single run and shows popup notifications.
## Resets each run. Separate from persistent Achievements.

signal milestone_reached(title: String, desc: String, color: Color)

const MILESTONES: Array[Dictionary] = [
	{"key": "first_blood", "title": "First Blood", "desc": "Kill your first enemy",
	 "check": "kills", "threshold": 1, "color": Color(1.0, 0.3, 0.3)},
	{"key": "slayer_10", "title": "Slayer", "desc": "Kill 10 enemies",
	 "check": "kills", "threshold": 10, "color": Color(1.0, 0.5, 0.2)},
	{"key": "massacre", "title": "Massacre", "desc": "Kill 50 enemies",
	 "check": "kills", "threshold": 50, "color": Color(1.0, 0.2, 0.1)},
	{"key": "hecatomb", "title": "Hecatomb", "desc": "Kill 100 enemies",
	 "check": "kills", "threshold": 100, "color": Color(0.8, 0.1, 0.1)},
	{"key": "army_of_two", "title": "Army of Two", "desc": "Have 2 thralls at once",
	 "check": "thralls", "threshold": 2, "color": Color(0.3, 0.8, 0.5)},
	{"key": "undead_army", "title": "Undead Army", "desc": "Have 5 thralls at once",
	 "check": "thralls", "threshold": 5, "color": Color(0.2, 1.0, 0.4)},
	{"key": "legion", "title": "Legion of the Damned", "desc": "Have 8 thralls at once",
	 "check": "thralls", "threshold": 8, "color": Color(0.1, 0.9, 0.3)},
	{"key": "first_rift", "title": "Rift Sealed", "desc": "Close your first rift",
	 "check": "rifts", "threshold": 1, "color": Color(0.6, 0.3, 1.0)},
	{"key": "rift_master", "title": "Rift Master", "desc": "Close all rifts in a world",
	 "check": "rifts_all", "threshold": 1, "color": Color(0.8, 0.4, 1.0)},
	{"key": "combo_10", "title": "Combo Starter", "desc": "Reach a 10-hit combo",
	 "check": "combo", "threshold": 10, "color": Color(1.0, 0.9, 0.3)},
	{"key": "combo_25", "title": "Combo Master", "desc": "Reach a 25-hit combo",
	 "check": "combo", "threshold": 25, "color": Color(1.0, 0.85, 0.1)},
	{"key": "combo_50", "title": "Unstoppable", "desc": "Reach a 50-hit combo",
	 "check": "combo", "threshold": 50, "color": Color(1.0, 0.7, 0.0)},
	{"key": "level_5", "title": "Growing Power", "desc": "Reach level 5",
	 "check": "level", "threshold": 5, "color": Color(0.3, 0.6, 1.0)},
	{"key": "level_10", "title": "Empowered", "desc": "Reach level 10",
	 "check": "level", "threshold": 10, "color": Color(0.2, 0.5, 1.0)},
	{"key": "boss_slayer", "title": "Boss Slayer", "desc": "Defeat a boss",
	 "check": "bosses", "threshold": 1, "color": Color(1.0, 0.4, 0.2)},
	{"key": "untouched", "title": "Untouched", "desc": "Kill 20 enemies without taking damage",
	 "check": "no_damage_kills", "threshold": 20, "color": Color(1.0, 1.0, 0.5)},
	{"key": "speed_demon", "title": "Speed Demon", "desc": "Close a rift in under 60 seconds",
	 "check": "fast_rift", "threshold": 1, "color": Color(0.3, 1.0, 0.8)},
]

# Run state — reset each run
var unlocked: Array[String] = []
var no_damage_kill_streak: int = 0
var run_start_time: float = 0.0
var last_rift_time: float = 0.0

# Pending popup queue
var _popup_queue: Array[Dictionary] = []
var _popup_timer: float = 0.0
var _popup_visible: bool = false
var _current_popup: Dictionary = {}

func _ready() -> void:
	Game.enemy_killed.connect(_on_kill)
	Game.thrall_gained.connect(_on_thrall_change)
	Game.rift_closed_signal.connect(_on_rift_closed)
	Game.combo_changed.connect(_on_combo)
	Game.level_up.connect(_on_level_up)
	Game.victory.connect(_on_victory)
	reset_run()

func reset_run() -> void:
	unlocked = []
	no_damage_kill_streak = 0
	run_start_time = Time.get_ticks_msec() / 1000.0
	last_rift_time = run_start_time
	_popup_queue = []
	_popup_timer = 0.0
	_popup_visible = false
	_current_popup = {}

func _process(delta: float) -> void:
	if _popup_visible:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup_visible = false
			_current_popup = {}
	elif not _popup_queue.is_empty():
		_current_popup = _popup_queue.pop_front()
		_popup_visible = true
		_popup_timer = 2.5

func _on_kill() -> void:
	no_damage_kill_streak += 1
	_check("kills", Game.kill_count)
	_check("no_damage_kills", no_damage_kill_streak)

func on_player_damaged() -> void:
	no_damage_kill_streak = 0

func _on_thrall_change() -> void:
	_check("thralls", Game.thrall_count)

func _on_rift_closed(rift_number: int) -> void:
	_check("rifts", Game.rifts_closed)
	var now := Time.get_ticks_msec() / 1000.0
	var elapsed := now - last_rift_time
	last_rift_time = now
	if elapsed < 60.0:
		_check("fast_rift", 1)
	if Game.rifts_closed >= Game.total_rifts:
		_check("rifts_all", 1)

func _on_combo(count: int) -> void:
	_check("combo", count)

func _on_level_up(new_level: int) -> void:
	_check("level", new_level)

func _on_victory() -> void:
	_check("bosses", Game.run_bosses_killed)

func _check(check_type: String, value: int) -> void:
	for m in MILESTONES:
		if m["key"] in unlocked:
			continue
		if m["check"] == check_type and value >= m["threshold"]:
			_unlock(m)

func _unlock(m: Dictionary) -> void:
	unlocked.append(m["key"])
	var title: String = m["title"]
	var desc: String = m["desc"]
	var color: Color = m["color"]
	_popup_queue.append({"title": title, "desc": desc, "color": color})
	milestone_reached.emit(title, desc, color)
	# Bonus rewards for milestones
	Game.add_xp(3)

## Get current popup data for HUD rendering (empty if no popup active)
func get_popup() -> Dictionary:
	if _popup_visible:
		return _current_popup
	return {}

## Get progress ratio for the popup animation (1.0 = just appeared, 0.0 = about to hide)
func get_popup_progress() -> float:
	if not _popup_visible:
		return 0.0
	return clampf(_popup_timer / 2.5, 0.0, 1.0)
