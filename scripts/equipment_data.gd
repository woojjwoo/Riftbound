extends Node

## Equipment system. Autoloaded as "Equipment".
## Manages equipment definitions, drop rates, upgrade success rates, and thrall sacrifice.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum Slot { GRIMOIRE, ROBES, AMULET, RING, BOOTS, CROWN }

## Equipment slot definitions — what each slot affects
const SLOT_INFO: Array[Dictionary] = [
	{"slot": Slot.GRIMOIRE, "name": "Grimoire", "stat": "Soul Bolt Damage", "per_level": 0.05},
	{"slot": Slot.ROBES, "name": "Robes", "stat": "Max Health", "per_level": 8.0},
	{"slot": Slot.AMULET, "name": "Amulet", "stat": "Extraction Chance", "per_level": 0.02},
	{"slot": Slot.RING, "name": "Ring", "stat": "Thrall Damage", "per_level": 0.04},
	{"slot": Slot.BOOTS, "name": "Boots", "stat": "Move Speed", "per_level": 0.03},
	{"slot": Slot.CROWN, "name": "Crown", "stat": "Cooldown Reduction", "per_level": 0.03},
]

## Rarity multipliers: stat bonus, upgrade cost, drop weight
const RARITY_INFO: Dictionary = {
	Rarity.COMMON: {"name": "Common", "color": Color(0.7, 0.7, 0.7), "stat_mult": 1.0, "cost_mult": 1.0},
	Rarity.UNCOMMON: {"name": "Uncommon", "color": Color(0.3, 0.8, 0.3), "stat_mult": 1.3, "cost_mult": 1.5},
	Rarity.RARE: {"name": "Rare", "color": Color(0.3, 0.5, 1.0), "stat_mult": 1.7, "cost_mult": 2.0},
	Rarity.EPIC: {"name": "Epic", "color": Color(0.7, 0.3, 1.0), "stat_mult": 2.2, "cost_mult": 3.0},
	Rarity.LEGENDARY: {"name": "Legendary", "color": Color(1.0, 0.65, 0.0), "stat_mult": 3.0, "cost_mult": 5.0},
}

## Upgrade success rates by target level (+1 means upgrading from +0 to +1)
## Designed Korean MMO-style: easy early, punishing late
const UPGRADE_RATES: Array[float] = [
	1.00,  # +0 → +1
	1.00,  # +1 → +2
	1.00,  # +2 → +3
	0.90,  # +3 → +4
	0.85,  # +4 → +5
	0.75,  # +5 → +6
	0.65,  # +6 → +7
	0.55,  # +7 → +8
	0.45,  # +8 → +9
	0.35,  # +9 → +10
	0.25,  # +10 → +11
	0.18,  # +11 → +12
	0.12,  # +12 → +13
	0.08,  # +13 → +14
	0.05,  # +14 → +15
]
const MAX_LEVEL: int = 15

## Thrall sacrifice bonus: +3% success rate per thrall (max +30% from 10 thralls)
const SACRIFICE_BONUS_PER_THRALL: float = 0.03
const MAX_SACRIFICE_BONUS: float = 0.30

## Upgrade cost formula: base_cost * (level+1)^1.5 * rarity_cost_mult
## Scales aggressively so early upgrades stay cheap but late upgrades are a real investment.
const BASE_UPGRADE_COST: int = 25

## Enemy drop rates by rarity [common, uncommon, rare, epic]
## ---------------------------------------------------------------
## Design intent:
##   - Melee enemies are the most common enemy type, so they have the
##     highest base common/uncommon rates to keep loot flowing.
##   - Rare and Epic base rates are 0.0 for ALL enemy types. These
##     rarities are unlocked via the world gate in roll_enemy_drop():
##     Rare requires world 2+, Epic requires world 4+. This prevents
##     early-game players from lucking into gear they should earn.
##   - The world_bonus multiplier (1.0 + world_id * 0.15) scales all
##     rates upward in later worlds, rewarding progression.
##   - Tanks have the highest overall rates as a reward for the extra
##     effort required to kill them.
## ---------------------------------------------------------------
const DROP_RATES: Dictionary = {
	"melee": [0.05, 0.008, 0.0, 0.0],
	"ranged": [0.04, 0.008, 0.0, 0.0],
	"tank": [0.05, 0.01, 0.0, 0.0],
	"flying": [0.04, 0.008, 0.0, 0.0],
	"exploder": [0.04, 0.008, 0.0, 0.0],
	"charger": [0.04, 0.008, 0.0, 0.0],
	"shielded": [0.05, 0.012, 0.0, 0.0],
	"splitter": [0.03, 0.006, 0.0, 0.0],
	"summoner": [0.06, 0.015, 0.0, 0.0],
	"poisoner": [0.04, 0.010, 0.0, 0.0],
	"teleporter": [0.05, 0.012, 0.0, 0.0],
	"voidcaller": [0.06, 0.015, 0.0, 0.0],
}

## Boss guaranteed drops [common, uncommon, rare, epic, legendary]
const BOSS_DROP_RATES: Array[float] = [0.0, 0.50, 0.30, 0.15, 0.05]

## Legendary proc effect definitions — each legendary item gets a random proc
## Proc keys: "chain_lightning", "lifesteal", "thorns", "soul_explosion",
##            "frost_slow", "burning"
const LEGENDARY_PROCS: Array[Dictionary] = [
	{"key": "chain_lightning", "name": "Chain Lightning",
	 "desc": "15% chance on hit: arc lightning to 3 nearby enemies for 20 dmg",
	 "chance": 0.15, "damage": 20.0, "targets": 3},
	{"key": "lifesteal", "name": "Soul Drain",
	 "desc": "On hit: heal 8% of damage dealt",
	 "chance": 1.0, "percent": 0.08},
	{"key": "thorns", "name": "Soul Thorns",
	 "desc": "When hit: reflect 30% damage back to attacker",
	 "chance": 1.0, "percent": 0.30},
	{"key": "soul_explosion", "name": "Soul Explosion",
	 "desc": "10% chance on kill: explode for 40 AOE damage",
	 "chance": 0.10, "damage": 40.0, "radius": 80.0},
	{"key": "frost_slow", "name": "Frozen Touch",
	 "desc": "20% chance on hit: slow enemy by 50% for 2s",
	 "chance": 0.20, "slow_amount": 0.5, "duration": 2.0},
	{"key": "burning", "name": "Soulfire",
	 "desc": "25% chance on hit: burn enemy for 5 dmg/sec for 3s",
	 "chance": 0.25, "dps": 5.0, "duration": 3.0},
]

## Create a new equipment item
func create_equipment(slot_id: int, rarity: int) -> Dictionary:
	var slot_data := SLOT_INFO[slot_id]
	var rarity_data: Dictionary = RARITY_INFO[rarity]
	var item := {
		"slot": slot_id,
		"rarity": rarity,
		"level": 0,
		"name": _generate_name(slot_id, rarity),
	}
	# Legendary items get a proc effect
	if rarity == Rarity.LEGENDARY:
		var proc := LEGENDARY_PROCS[randi() % LEGENDARY_PROCS.size()]
		item["proc"] = proc["key"]
		item["proc_name"] = proc["name"]
		item["proc_desc"] = proc["desc"]
	return item

## Generate a thematic name based on slot and rarity
func _generate_name(slot_id: int, rarity: int) -> String:
	var prefixes: Dictionary = {
		Rarity.COMMON: ["Old", "Worn", "Simple", "Crude", "Faded"],
		Rarity.UNCOMMON: ["Sturdy", "Keen", "Dark", "Bound", "Carved"],
		Rarity.RARE: ["Ancient", "Cursed", "Shadow", "Bone", "Spectral"],
		Rarity.EPIC: ["Abyssal", "Dread", "Eternal", "Void-Touched", "Soul-Forged"],
		Rarity.LEGENDARY: ["Godslayer's", "Riftborn", "Ascendant", "Primordial", "Mythic"],
	}
	var slot_names: Array[String] = ["Grimoire", "Robes", "Amulet", "Ring", "Boots", "Crown"]
	var prefix_list: Array = prefixes[rarity]
	var prefix: String = prefix_list[randi() % prefix_list.size()]
	return "%s %s" % [prefix, slot_names[slot_id]]

## Get the stat bonus for a piece of equipment
func get_stat_bonus(equip: Dictionary) -> float:
	var slot_data := SLOT_INFO[equip["slot"]]
	var rarity_data: Dictionary = RARITY_INFO[equip["rarity"]]
	var per_level: float = slot_data["per_level"]
	var stat_mult: float = rarity_data["stat_mult"]
	# Base bonus from rarity + bonus per upgrade level
	return per_level * stat_mult * (1 + equip["level"])

## Get upgrade cost for an equipment piece at its current level
func get_upgrade_cost(equip: Dictionary) -> int:
	var rarity_data: Dictionary = RARITY_INFO[equip["rarity"]]
	var cost_mult: float = rarity_data["cost_mult"]
	return int(BASE_UPGRADE_COST * pow(equip["level"] + 1, 1.5) * cost_mult)

## Get base success rate for upgrading to the next level
func get_base_success_rate(current_level: int) -> float:
	if current_level >= MAX_LEVEL:
		return 0.0
	if current_level < 0 or current_level >= UPGRADE_RATES.size():
		return 0.0
	return UPGRADE_RATES[current_level]

## Get total success rate including thrall sacrifice bonus
func get_success_rate(current_level: int, thrall_count: int) -> float:
	var base := get_base_success_rate(current_level)
	if base <= 0.0:
		return 0.0
	var sacrifice_bonus := minf(thrall_count * SACRIFICE_BONUS_PER_THRALL, MAX_SACRIFICE_BONUS)
	return minf(base + sacrifice_bonus, 0.95)  # Cap at 95%

## Attempt to upgrade equipment. Returns true on success.
func try_upgrade(equip: Dictionary, thrall_count: int) -> bool:
	if equip["level"] >= MAX_LEVEL:
		return false
	var rate := get_success_rate(equip["level"], thrall_count)
	return randf() <= rate

## Roll for equipment drop from an enemy kill
func roll_enemy_drop(enemy_type: String, world_id: int) -> Dictionary:
	var rates: Array = DROP_RATES.get(enemy_type, DROP_RATES["melee"])
	# Later worlds increase drop rates
	var world_bonus := 1.0 + world_id * 0.15

	# World-gated rarity: Rare requires world 2+, Epic requires world 4+, Legendary requires world 5
	var max_rarity := Rarity.UNCOMMON
	if world_id >= 5:
		max_rarity = Rarity.LEGENDARY
	elif world_id >= 4:
		max_rarity = Rarity.EPIC
	elif world_id >= 2:
		max_rarity = Rarity.RARE

	# Effective rates: inject rare/epic/legendary chances only when world-gated threshold is met
	var effective_rates: Array[float] = [rates[0], rates[1], 0.0, 0.0, 0.0]
	if max_rarity >= Rarity.RARE:
		effective_rates[Rarity.RARE] = 0.002 + world_id * 0.001
	if max_rarity >= Rarity.EPIC:
		effective_rates[Rarity.EPIC] = 0.001
	if max_rarity >= Rarity.LEGENDARY:
		effective_rates[Rarity.LEGENDARY] = 0.0003

	# Roll from legendary down to common (higher rarity checked first)
	for rarity_idx in range(Rarity.LEGENDARY, -1, -1):
		var rate: float = effective_rates[rarity_idx] * world_bonus
		if rate > 0.0 and randf() < rate:
			var slot := randi() % SLOT_INFO.size()
			return create_equipment(slot, rarity_idx)
	return {}  # No drop

## Roll for equipment drop from a boss kill.
## Minimum rarity scales with world: Uncommon (default), Rare (world 3+), Epic (world 5).
func roll_boss_drop(world_id: int) -> Dictionary:
	var roll := randf()
	var rarity := Rarity.UNCOMMON  # Default minimum
	var cumulative := 0.0
	cumulative += BOSS_DROP_RATES[Rarity.LEGENDARY]
	if roll < cumulative:
		rarity = Rarity.LEGENDARY
	else:
		cumulative += BOSS_DROP_RATES[Rarity.EPIC]
		if roll < cumulative:
			rarity = Rarity.EPIC
		else:
			cumulative += BOSS_DROP_RATES[Rarity.RARE]
			if roll < cumulative:
				rarity = Rarity.RARE

	# Enforce world-based minimum rarity floors
	if world_id >= 5:
		if rarity < Rarity.EPIC:
			rarity = Rarity.EPIC
	elif world_id >= 3:
		if rarity < Rarity.RARE:
			rarity = Rarity.RARE

	var slot := randi() % SLOT_INFO.size()
	return create_equipment(slot, rarity)

## Set bonus: wearing 3+ items of the same rarity grants a bonus
## wearing all 6 grants an even bigger bonus
func get_set_bonuses(equipped_items: Array[Dictionary]) -> Dictionary:
	# Count items per rarity
	var rarity_counts: Dictionary = {}
	for item in equipped_items:
		if item.is_empty():
			continue
		var r: int = item["rarity"]
		rarity_counts[r] = rarity_counts.get(r, 0) + 1

	var bonuses := {"damage_mult": 0.0, "health_bonus": 0.0, "speed_mult": 0.0, "cdr": 0.0}
	for rarity_id in rarity_counts:
		var count: int = rarity_counts[rarity_id]
		if count >= 3:
			# 3-piece set bonus
			match rarity_id:
				Rarity.COMMON:
					bonuses["health_bonus"] += 10.0
				Rarity.UNCOMMON:
					bonuses["damage_mult"] += 0.08
					bonuses["health_bonus"] += 15.0
				Rarity.RARE:
					bonuses["damage_mult"] += 0.15
					bonuses["health_bonus"] += 25.0
					bonuses["speed_mult"] += 0.05
				Rarity.EPIC:
					bonuses["damage_mult"] += 0.25
					bonuses["health_bonus"] += 40.0
					bonuses["speed_mult"] += 0.10
					bonuses["cdr"] += 0.10
				Rarity.LEGENDARY:
					bonuses["damage_mult"] += 0.40
					bonuses["health_bonus"] += 60.0
					bonuses["speed_mult"] += 0.15
					bonuses["cdr"] += 0.15
		if count >= 6:
			# 6-piece bonus (stacks with 3-piece)
			match rarity_id:
				Rarity.UNCOMMON:
					bonuses["damage_mult"] += 0.10
					bonuses["health_bonus"] += 20.0
				Rarity.RARE:
					bonuses["damage_mult"] += 0.20
					bonuses["health_bonus"] += 40.0
					bonuses["speed_mult"] += 0.08
				Rarity.EPIC:
					bonuses["damage_mult"] += 0.35
					bonuses["health_bonus"] += 60.0
					bonuses["speed_mult"] += 0.15
					bonuses["cdr"] += 0.15
				Rarity.LEGENDARY:
					bonuses["damage_mult"] += 0.60
					bonuses["health_bonus"] += 100.0
					bonuses["speed_mult"] += 0.20
					bonuses["cdr"] += 0.20
	return bonuses

## Get all active proc effects from equipped items
func get_equipped_procs(equipped_items: Array[Dictionary]) -> Array[Dictionary]:
	var procs: Array[Dictionary] = []
	for item in equipped_items:
		if item.is_empty():
			continue
		if item.has("proc"):
			var proc_key: String = item["proc"]
			for proc_def in LEGENDARY_PROCS:
				if proc_def["key"] == proc_key:
					procs.append(proc_def)
					break
	return procs

## Get display color for a rarity
func get_rarity_color(rarity: int) -> Color:
	return RARITY_INFO[rarity]["color"]

## Get rarity name
func get_rarity_name(rarity: int) -> String:
	return RARITY_INFO[rarity]["name"]

## Get slot name
func get_slot_name(slot_id: int) -> String:
	return SLOT_INFO[slot_id]["name"]

## Crafting: combine 3 items of same rarity into 1 item of next rarity
## Returns the crafted item, or {} if invalid
func craft_upgrade(items: Array[Dictionary]) -> Dictionary:
	if items.size() != 3:
		return {}
	var rarity: int = items[0]["rarity"]
	for item in items:
		if item["rarity"] != rarity:
			return {}
	if rarity >= Rarity.LEGENDARY:
		return {}
	var new_rarity: int = rarity + 1
	var slot := randi() % SLOT_INFO.size()
	return create_equipment(slot, new_rarity)

## Get coin cost for crafting 3 items of a given rarity
func get_craft_cost(rarity: int) -> int:
	match rarity:
		Rarity.COMMON: return 50
		Rarity.UNCOMMON: return 150
		Rarity.RARE: return 400
		Rarity.EPIC: return 1000
	return 0

## Serialize equipment for save
func equip_to_dict(equip: Dictionary) -> Dictionary:
	var d := {"slot": equip["slot"], "rarity": equip["rarity"],
			"level": equip["level"], "name": equip.get("name", "")}
	if equip.has("proc"):
		d["proc"] = equip["proc"]
		d["proc_name"] = equip.get("proc_name", "")
		d["proc_desc"] = equip.get("proc_desc", "")
	return d

## Deserialize equipment from save
func dict_to_equip(data: Dictionary) -> Dictionary:
	var item := {
		"slot": clampi(int(data.get("slot", 0)), 0, SLOT_INFO.size() - 1),
		"rarity": clampi(int(data.get("rarity", 0)), 0, Rarity.LEGENDARY),
		"level": clampi(int(data.get("level", 0)), 0, MAX_LEVEL),
		"name": str(data.get("name", "Unknown")),
	}
	# Restore proc fields for legendary items
	if data.has("proc"):
		item["proc"] = str(data["proc"])
		item["proc_name"] = str(data.get("proc_name", ""))
		item["proc_desc"] = str(data.get("proc_desc", ""))
	return item
