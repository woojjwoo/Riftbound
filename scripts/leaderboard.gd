extends Node

## Local leaderboard system. Autoloaded as "Leaderboard".
## Tracks high scores for arena, daily challenges, speedruns, and overall.

const MAX_ENTRIES: int = 10

## Leaderboard categories
var boards: Dictionary = {
	"arena": [],       # {wave: int, kills: int, date: String}
	"daily": [],       # {score: int, seed: String, date: String}
	"speedrun": [],    # {time_sec: float, world: int, date: String}
	"overall": [],     # {score: int, kills: int, worlds: int, date: String}
}

func _ready() -> void:
	_load_boards()

## Submit an arena score
func submit_arena(wave: int, kills: int) -> int:
	var entry := {"wave": wave, "kills": kills, "date": _get_date_str()}
	return _insert_sorted("arena", entry, "wave", true)

## Submit a daily challenge score
func submit_daily(score: int, seed_str: String) -> int:
	var entry := {"score": score, "seed": seed_str, "date": _get_date_str()}
	return _insert_sorted("daily", entry, "score", true)

## Submit a speedrun time (lower is better)
func submit_speedrun(time_sec: float, world: int) -> int:
	var entry := {"time_sec": time_sec, "world": world, "date": _get_date_str()}
	return _insert_sorted("speedrun", entry, "time_sec", false)  # Lower is better

## Submit an overall run score
func submit_overall(kills: int, worlds: int, bosses: int) -> int:
	var score := kills + worlds * 100 + bosses * 250
	var entry := {"score": score, "kills": kills, "worlds": worlds, "date": _get_date_str()}
	return _insert_sorted("overall", entry, "score", true)

## Get top entries for a category
func get_board(category: String) -> Array:
	return boards.get(category, [])

## Get rank of a score in a category (-1 if not ranked)
func get_rank(category: String, key: String, value) -> int:
	var board: Array = boards.get(category, [])
	for i in range(board.size()):
		if board[i].get(key) == value:
			return i + 1
	return -1

func _insert_sorted(category: String, entry: Dictionary, sort_key: String, descending: bool) -> int:
	var board: Array = boards.get(category, [])
	var rank := -1

	# Find insertion point
	for i in range(board.size()):
		var val = board[i].get(sort_key, 0)
		if descending:
			if entry[sort_key] > val:
				board.insert(i, entry)
				rank = i + 1
				break
		else:
			if entry[sort_key] < val:
				board.insert(i, entry)
				rank = i + 1
				break

	if rank == -1 and board.size() < MAX_ENTRIES:
		board.append(entry)
		rank = board.size()

	# Trim to max
	if board.size() > MAX_ENTRIES:
		board.resize(MAX_ENTRIES)
		if rank > MAX_ENTRIES:
			rank = -1

	boards[category] = board
	_save_boards()
	return rank

func _get_date_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func _save_boards() -> void:
	var file := FileAccess.open("user://riftbound_leaderboard.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(boards))

func _load_boards() -> void:
	if not FileAccess.file_exists("user://riftbound_leaderboard.dat"):
		return
	var file := FileAccess.open("user://riftbound_leaderboard.dat", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary:
		for key in boards.keys():
			if data.has(key) and data[key] is Array:
				boards[key] = data[key]
