extends Node

## Equipment system. Autoloaded as "Equipment".
## Manages equipment definitions, drop rates, upgrade success rates, and thrall sacrifice.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }
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
}

## Boss guaranteed drops
const BOSS_DROP_RATES: Array[float] = [0.0, 0.60, 0.30, 0.10]

## Create a new equipment item
func create_equipment(slot_id: int, rarity: int) -> Dictionary:
	var slot_data := SLOT_INFO[slot_id]
	var rarity_data: Dictionary = RARITY_INFO[rarity]
	return {
		"slot": slot_id,
		"rarity": rarity,
		"level": 0,
		"name": _generate_name(slot_id, rarity),
	}

## Generate a thematic name based on slot and rarity
func _generate_name(slot_id: int, rarity: int) -> String:
	var prefixes: Dictionary = {
		Rarity.COMMON: ["Old", "Worn", "Simple", "Crude", "Faded"],
		Rarity.UNCOMMON: ["Sturdy", "Keen", "Dark", "Bound", "Carved"],
		Rarity.RARE: ["Ancient", "Cursed", "Shadow", "Bone", "Spectral"],
		Rarity.EPIC: ["Abyssal", "Dread", "Eternal", "Void-Touched", "Soul-Forged"],
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

	# World-gated rarity: Rare requires world 2+, Epic requires world 4+
	var max_rarity := Rarity.UNCOMMON
	if world_id >= 4:
		max_rarity = Rarity.EPIC
	elif world_id >= 2:
		max_rarity = Rarity.RARE

	# Effective rates: inject rare/epic chances only when world-gated threshold is met
	var effective_rates: Array[float] = [rates[0], rates[1], 0.0, 0.0]
	if max_rarity >= Rarity.RARE:
		effective_rates[Rarity.RARE] = 0.002 + world_id * 0.001
	if max_rarity >= Rarity.EPIC:
		effective_rates[Rarity.EPIC] = 0.001

	# Roll from epic down to common (higher rarity checked first)
	for rarity_idx in range(Rarity.EPIC, -1, -1):
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
	if roll < BOSS_DROP_RATES[Rarity.EPIC]:
		rarity = Rarity.EPIC
	elif roll < BOSS_DROP_RATES[Rarity.EPIC] + BOSS_DROP_RATES[Rarity.RARE]:
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

## Get display color for a rarity
func get_rarity_color(rarity: int) -> Color:
	return RARITY_INFO[rarity]["color"]

## Get rarity name
func get_rarity_name(rarity: int) -> String:
	return RARITY_INFO[rarity]["name"]

## Get slot name
func get_slot_name(slot_id: int) -> String:
	return SLOT_INFO[slot_id]["name"]

## Serialize equipment for save
func equip_to_dict(equip: Dictionary) -> Dictionary:
	return {"slot": equip["slot"], "rarity": equip["rarity"],
			"level": equip["level"], "name": equip.get("name", "")}

## Deserialize equipment from save
func dict_to_equip(data: Dictionary) -> Dictionary:
	return {
		"slot": clampi(int(data.get("slot", 0)), 0, SLOT_INFO.size() - 1),
		"rarity": clampi(int(data.get("rarity", 0)), 0, Rarity.EPIC),
		"level": clampi(int(data.get("level", 0)), 0, MAX_LEVEL),
		"name": str(data.get("name", "Unknown")),
	}
