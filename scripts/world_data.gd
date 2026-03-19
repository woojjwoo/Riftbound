extends Node

## World/stage definitions. Each world has unique environment theme,
## enemy scaling, rift count, boss, and narrative text. Autoloaded as "WorldData".

enum WorldID {
	DARK_REALM,
	DESERT,
	ICE,
	SWAMP,
	VOID,
	SPACE,
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
		# Narrative
		"intro": "The rifts have torn through your domain.\nSeal them before the dead world consumes the living.",
		"mid_text": "The rifts grow unstable... something stirs within.",
		"boss_intro": "The Guardian rises to protect its rift.",
		"victory_text": "The Dark Realm is sealed. A portal shimmers ahead...\nBut the rifts have spread to other worlds.",
		"boss_taunt": "You dare disturb the rift? Return to your grave, Necromancer.",
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
		"intro": "Burning sands stretch endlessly.\nThe rifts have scorched this land beyond recognition.",
		"mid_text": "The heat intensifies... the sand itself attacks.",
		"boss_intro": "The dunes collapse. Something ancient rises from beneath.",
		"victory_text": "The Colossus crumbles to dust.\nThrough the swirling sands, a frozen light beckons.",
		"boss_taunt": "I have slept beneath these sands for a thousand years.\nYou will join the bones buried below.",
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
		"intro": "A deathless cold grips this world.\nYour thralls move slower here, but so do your enemies.",
		"mid_text": "The ice cracks beneath your feet... something moves below.",
		"boss_intro": "A shadow passes overhead. The Wyrm descends.",
		"victory_text": "The Wyrm's frozen heart shatters.\nWarm, toxic air seeps through the next portal.",
		"boss_taunt": "The cold preserves everything. Even your defeat will last forever.",
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
		"intro": "The air itself is poison.\nThe rifts here have corrupted everything they touch.",
		"mid_text": "The marsh bubbles and writhes... it is alive.",
		"boss_intro": "The swamp converges into a single, terrible form.",
		"victory_text": "The Horror dissolves into the mire.\nAhead, reality itself begins to unravel.",
		"boss_taunt": "I am the marsh. Every step you take feeds me.\nYour thralls will rot and become mine.",
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
		"intro": "This is the space between worlds.\nThe rifts here are the source. Close them, and the others weaken.",
		"mid_text": "Reality bends... your senses cannot be trusted.",
		"boss_intro": "A presence fills the void. The Sovereign manifests.",
		"victory_text": "The Sovereign's crown dissolves into nothing.\nAbove, golden light pierces the void. The gods have noticed you.",
		"boss_taunt": "I am the emptiness between all things.\nYou cannot kill nothing, Necromancer.",
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
		"intro": "You stand among the stars.\nThe gods opened these rifts to test mortal ambition.\nProve them wrong.",
		"mid_text": "The heavens tremble at your defiance.",
		"boss_intro": "The sky splits open. The Eternal One descends.",
		"victory_text": "The Eternal One falls. The rifts across all worlds seal shut.\nYou have done what no mortal should.\nThe dead rest. For now.",
		"boss_taunt": "We created the rifts. We created death itself.\nAnd you — a mere Necromancer — dare challenge eternity?",
	},
]

func get_config(world_id: int) -> Dictionary:
	if world_id >= 0 and world_id < WORLD_CONFIGS.size():
		return WORLD_CONFIGS[world_id]
	return WORLD_CONFIGS[0]

func get_world_count() -> int:
	return WORLD_CONFIGS.size()
