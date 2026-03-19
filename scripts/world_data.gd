extends Node

## World/stage definitions. Each world has unique environment theme,
## enemy scaling, rift count, and a boss. Autoloaded as "WorldData".

enum WorldID {
	DARK_REALM,    # World 1 — tutorial/intro (current)
	DESERT,        # World 2 — scorched sands
	ICE,           # World 3 — frozen wastes
	SWAMP,         # World 4 — toxic marshes
	VOID,          # World 5 — the void between worlds
	SPACE,         # World 6 — celestial realm, fight the gods
}

const WORLD_CONFIGS: Array[Dictionary] = [
	{
		"id": 0, "name": "The Dark Realm",
		"subtitle": "Where the dead stir...",
		"rifts": 3, "enemy_mult": 1.0, "hp_mult": 1.0, "dmg_mult": 1.0,
		"boss_name": "Rift Guardian", "boss_hp": 300.0, "boss_dmg": 20.0,
		"bg_color": Color(0.08, 0.06, 0.1), "grid_color": Color(0.15, 0.12, 0.18, 0.3),
		"accent_color": Color(0.2, 0.15, 0.25, 0.15),
		"rift_color": Color(0.6, 0.2, 0.9),
		"coin_mult": 1.0, "exp_mult": 1.0,
	},
	{
		"id": 1, "name": "Scorched Sands",
		"subtitle": "The desert devours all...",
		"rifts": 4, "enemy_mult": 1.3, "hp_mult": 1.4, "dmg_mult": 1.2,
		"boss_name": "Sand Colossus", "boss_hp": 500.0, "boss_dmg": 28.0,
		"bg_color": Color(0.14, 0.10, 0.05), "grid_color": Color(0.22, 0.18, 0.10, 0.3),
		"accent_color": Color(0.3, 0.25, 0.1, 0.15),
		"rift_color": Color(0.9, 0.6, 0.2),
		"coin_mult": 1.5, "exp_mult": 1.3,
	},
	{
		"id": 2, "name": "Frozen Wastes",
		"subtitle": "Even death can freeze...",
		"rifts": 4, "enemy_mult": 1.5, "hp_mult": 1.8, "dmg_mult": 1.4,
		"boss_name": "Frost Wyrm", "boss_hp": 700.0, "boss_dmg": 35.0,
		"bg_color": Color(0.06, 0.08, 0.14), "grid_color": Color(0.12, 0.16, 0.24, 0.3),
		"accent_color": Color(0.15, 0.2, 0.35, 0.15),
		"rift_color": Color(0.3, 0.7, 1.0),
		"coin_mult": 2.0, "exp_mult": 1.6,
	},
	{
		"id": 3, "name": "Toxic Marshes",
		"subtitle": "Poison seeps through the rifts...",
		"rifts": 5, "enemy_mult": 1.8, "hp_mult": 2.2, "dmg_mult": 1.6,
		"boss_name": "Swamp Horror", "boss_hp": 900.0, "boss_dmg": 40.0,
		"bg_color": Color(0.05, 0.10, 0.05), "grid_color": Color(0.10, 0.18, 0.08, 0.3),
		"accent_color": Color(0.15, 0.25, 0.1, 0.2),
		"rift_color": Color(0.3, 0.9, 0.2),
		"coin_mult": 2.5, "exp_mult": 2.0,
	},
	{
		"id": 4, "name": "The Void",
		"subtitle": "Between worlds, nothing is real...",
		"rifts": 5, "enemy_mult": 2.2, "hp_mult": 2.8, "dmg_mult": 2.0,
		"boss_name": "Void Sovereign", "boss_hp": 1200.0, "boss_dmg": 50.0,
		"bg_color": Color(0.02, 0.01, 0.04), "grid_color": Color(0.08, 0.04, 0.12, 0.4),
		"accent_color": Color(0.12, 0.06, 0.2, 0.2),
		"rift_color": Color(0.8, 0.2, 1.0),
		"coin_mult": 3.0, "exp_mult": 2.5,
	},
	{
		"id": 5, "name": "Celestial Realm",
		"subtitle": "The gods await...",
		"rifts": 6, "enemy_mult": 3.0, "hp_mult": 3.5, "dmg_mult": 2.5,
		"boss_name": "The Eternal One", "boss_hp": 2000.0, "boss_dmg": 60.0,
		"bg_color": Color(0.02, 0.02, 0.06), "grid_color": Color(0.06, 0.06, 0.15, 0.3),
		"accent_color": Color(0.1, 0.1, 0.3, 0.2),
		"rift_color": Color(1.0, 0.9, 0.4),
		"coin_mult": 5.0, "exp_mult": 3.0,
	},
]

func get_config(world_id: int) -> Dictionary:
	if world_id >= 0 and world_id < WORLD_CONFIGS.size():
		return WORLD_CONFIGS[world_id]
	return WORLD_CONFIGS[0]

func get_world_count() -> int:
	return WORLD_CONFIGS.size()
