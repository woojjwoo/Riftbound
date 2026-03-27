extends Node

## Rune system. Autoloaded as "Runes".
## Runes are socketable items that can be slotted into equipment for bonus effects.
## Runes drop from enemies (rune fragments) and can be combined into full runes.

enum RuneType { FIRE, ICE, SHADOW, HOLY, VOID, NATURE }

const RUNE_INFO: Array[Dictionary] = [
	{"type": 0, "name": "Fire Rune", "desc": "+8% damage per level", "color": Color(1.0, 0.4, 0.1),
	 "stat": "damage", "value_per_level": 0.08},
	{"type": 1, "name": "Ice Rune", "desc": "+6% slow on hit per level", "color": Color(0.3, 0.7, 1.0),
	 "stat": "slow_chance", "value_per_level": 0.06},
	{"type": 2, "name": "Shadow Rune", "desc": "+5% crit chance per level", "color": Color(0.5, 0.2, 0.8),
	 "stat": "crit_chance", "value_per_level": 0.05},
	{"type": 3, "name": "Holy Rune", "desc": "+10 max HP per level", "color": Color(1.0, 0.9, 0.4),
	 "stat": "max_hp", "value_per_level": 10.0},
	{"type": 4, "name": "Void Rune", "desc": "+4% cooldown reduction per level", "color": Color(0.6, 0.1, 0.9),
	 "stat": "cdr", "value_per_level": 0.04},
	{"type": 5, "name": "Nature Rune", "desc": "+1 HP regen/sec per level", "color": Color(0.3, 0.9, 0.3),
	 "stat": "regen", "value_per_level": 1.0},
]

## Player's rune inventory: Array of {type: int, level: int}
var rune_inventory: Array[Dictionary] = []

## Rune fragments collected (need 3 of same type to forge a rune)
var rune_fragments: Dictionary = {}  # {type_int: count}

const FRAGMENTS_TO_FORGE: int = 3
const MAX_RUNE_LEVEL: int = 5
const MAX_RUNE_INVENTORY: int = 20

func _ready() -> void:
	_load_runes()

## Drop a rune fragment (called from enemy death)
func add_fragment(type: int) -> void:
	rune_fragments[type] = rune_fragments.get(type, 0) + 1
	_save_runes()

## Check if we can forge a rune of this type
func can_forge(type: int) -> bool:
	return rune_fragments.get(type, 0) >= FRAGMENTS_TO_FORGE and rune_inventory.size() < MAX_RUNE_INVENTORY

## Forge a rune from fragments
func forge_rune(type: int) -> Dictionary:
	if not can_forge(type):
		return {}
	rune_fragments[type] -= FRAGMENTS_TO_FORGE
	var rune := {"type": type, "level": 1}
	rune_inventory.append(rune)
	_save_runes()
	return rune

## Combine two runes of same type to level up (max level 5)
func combine_runes(idx_a: int, idx_b: int) -> bool:
	if idx_a == idx_b or idx_a < 0 or idx_b < 0:
		return false
	if idx_a >= rune_inventory.size() or idx_b >= rune_inventory.size():
		return false
	var a := rune_inventory[idx_a]
	var b := rune_inventory[idx_b]
	if a["type"] != b["type"]:
		return false
	if a["level"] >= MAX_RUNE_LEVEL:
		return false
	# Level up rune A, remove rune B
	rune_inventory[idx_a]["level"] = mini(a["level"] + b["level"], MAX_RUNE_LEVEL)
	rune_inventory.remove_at(idx_b)
	_save_runes()
	return true

## Socket a rune into an equipment piece
func socket_rune(rune_idx: int, equip_slot: int) -> bool:
	if rune_idx < 0 or rune_idx >= rune_inventory.size():
		return false
	if equip_slot < 0 or equip_slot >= SaveData.equipped.size():
		return false
	var item := SaveData.equipped[equip_slot]
	if item.is_empty():
		return false
	# Remove old rune if exists
	if item.has("rune"):
		rune_inventory.append(item["rune"])
	item["rune"] = rune_inventory[rune_idx]
	rune_inventory.remove_at(rune_idx)
	SaveData.equipment_changed.emit()
	_save_runes()
	SaveData.save_game()
	return true

## Remove a rune from equipment back to inventory
func unsocket_rune(equip_slot: int) -> bool:
	if equip_slot < 0 or equip_slot >= SaveData.equipped.size():
		return false
	var item := SaveData.equipped[equip_slot]
	if item.is_empty() or not item.has("rune"):
		return false
	if rune_inventory.size() >= MAX_RUNE_INVENTORY:
		return false
	rune_inventory.append(item["rune"])
	item.erase("rune")
	SaveData.equipment_changed.emit()
	_save_runes()
	SaveData.save_game()
	return true

## Get total rune bonuses from all equipped items
func get_equipped_rune_bonuses() -> Dictionary:
	var bonuses := {"damage": 0.0, "slow_chance": 0.0, "crit_chance": 0.0,
		"max_hp": 0.0, "cdr": 0.0, "regen": 0.0}
	for item in SaveData.equipped:
		if item.is_empty() or not item.has("rune"):
			continue
		var rune: Dictionary = item["rune"]
		var info := get_rune_info(rune["type"])
		var stat: String = info["stat"]
		var value: float = info["value_per_level"] * rune["level"]
		bonuses[stat] += value
	return bonuses

func get_rune_info(type: int) -> Dictionary:
	if type >= 0 and type < RUNE_INFO.size():
		return RUNE_INFO[type]
	return RUNE_INFO[0]

func get_rune_name(rune: Dictionary) -> String:
	var info := get_rune_info(rune["type"])
	return "%s Lv.%d" % [info["name"], rune["level"]]

func get_rune_color(rune: Dictionary) -> Color:
	return get_rune_info(rune["type"])["color"]

## Roll a random rune fragment drop (called from enemy death, ~10% chance)
func try_drop_fragment() -> void:
	if randf() < 0.10:
		var type := randi() % RUNE_INFO.size()
		add_fragment(type)

func _save_runes() -> void:
	# Runes are saved alongside main save data
	var file := FileAccess.open("user://riftbound_runes.dat", FileAccess.WRITE)
	if file:
		var data := {"inventory": rune_inventory, "fragments": rune_fragments}
		file.store_string(JSON.stringify(data))

func _load_runes() -> void:
	if not FileAccess.file_exists("user://riftbound_runes.dat"):
		return
	var file := FileAccess.open("user://riftbound_runes.dat", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return
	var inv = data.get("inventory", [])
	rune_inventory = []
	if inv is Array:
		for r in inv:
			if r is Dictionary:
				rune_inventory.append(r)
	var frags = data.get("fragments", {})
	rune_fragments = {}
	if frags is Dictionary:
		for key in frags:
			rune_fragments[int(key)] = int(frags[key])
