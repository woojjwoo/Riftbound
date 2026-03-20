extends Node

## Codex/Lore system. Autoloaded as "Codex".
## Collectible lore entries unlocked by gameplay events.

const LORE_ENTRIES: Array[Dictionary] = [
	# World Lore
	{"id": "dark_realm", "category": "Worlds", "title": "The Dark Realm",
	 "text": "Where the Necromancer first stirred. The rifts tore through this cursed domain, awakening the dead from their eternal slumber. Here, the art of soul extraction was born from desperation."},
	{"id": "scorched_sands", "category": "Worlds", "title": "Scorched Sands",
	 "text": "An endless desert where ancient civilizations crumbled to dust. The rifts here burn with scorching intensity, and the sand itself seems to hunger for the living. Only the strongest thralls survive the transition."},
	{"id": "frozen_wastes", "category": "Worlds", "title": "Frozen Wastes",
	 "text": "A world locked in eternal winter. The cold preserves everything — including the hatred of those who fell here. The ice holds memories of a civilization that froze mid-scream."},
	{"id": "toxic_marshes", "category": "Worlds", "title": "Toxic Marshes",
	 "text": "Where corruption took root and spread. The marsh is alive — a single organism of rot and hunger. Every step feeds it, every death makes it stronger. The rifts here weep poison."},
	{"id": "the_void", "category": "Worlds", "title": "The Void",
	 "text": "Between all worlds lies nothing. The Void is where rifts are born — tears in the fabric of reality itself. Here, even thoughts have weight, and silence has teeth."},
	{"id": "celestial_realm", "category": "Worlds", "title": "Celestial Realm",
	 "text": "The domain of gods. They opened the rifts as a test of mortal ambition. They did not expect a Necromancer to ascend. The golden light burns the undead, but the Necromancer's will burns brighter."},

	# Enemy Lore
	{"id": "enemy_melee", "category": "Enemies", "title": "The Shambling Dead",
	 "text": "Basic thralls of the rift — mindless husks drawn to the living. They attack with feral desperation, clawing at anything warm. In death, they can be turned to serve a new master."},
	{"id": "enemy_charger", "category": "Enemies", "title": "Rift Chargers",
	 "text": "Corrupted beasts that have absorbed rift energy. They build momentum before lunging with devastating force. Their rage makes them predictable — but no less deadly."},
	{"id": "enemy_summoner", "category": "Enemies", "title": "Rift Summoners",
	 "text": "Former mages who opened the first rifts. Now they serve as conduits, pulling more horrors through. Destroying them disrupts the flow of reinforcements."},
	{"id": "enemy_voidcaller", "category": "Enemies", "title": "Voidcallers",
	 "text": "Entities born in the space between worlds. They warp gravity around themselves, pulling the unwary into crushing embrace. Their essence is particularly valuable for necromantic arts."},

	# Mechanics Lore
	{"id": "extraction", "category": "Mechanics", "title": "Soul Extraction",
	 "text": "The Necromancer's gift — pulling the lingering soul from a fresh corpse and binding it to service. The closer you are to the kill, the stronger the binding. Some souls resist, but persistence overcomes all."},
	{"id": "thrall_evolution", "category": "Mechanics", "title": "Thrall Evolution",
	 "text": "Thralls that witness enough death grow stronger, evolving through tiers. Veteran thralls hit harder and endure more. Elite thralls are nearly as powerful as their living counterparts."},
	{"id": "rift_sealing", "category": "Mechanics", "title": "Sealing the Rifts",
	 "text": "Rifts can only be closed by overwhelming them with necromantic energy — commanding thralls to channel their essence into the tear. Each sealed rift weakens the world's corruption."},
	{"id": "world_transition", "category": "Mechanics", "title": "Between Worlds",
	 "text": "Thralls cannot survive the transition between worlds. Their essence is consumed by the crossing, but it strengthens the Necromancer's equipment. Loss fuels power — the fundamental law of necromancy."},

	# Character Lore
	{"id": "necromancer", "category": "Characters", "title": "The Necromancer",
	 "text": "Once a scholar of death magic, now the only one who can seal the rifts. Not by sword or spell, but by commanding the dead themselves. The rifts fear what commands their own creations."},
	{"id": "rift_guardian", "category": "Characters", "title": "Rift Guardian",
	 "text": "The first boss encountered. A construct of rift energy given form. It exists solely to protect the tears in reality. Defeating it proves the Necromancer's worth."},
	{"id": "eternal_one", "category": "Characters", "title": "The Eternal One",
	 "text": "The god who created the rifts as a test. It watches with cold amusement as mortals struggle against its design. It did not account for one who commands death itself."},
]

var unlocked_entries: Array[String] = []

func _ready() -> void:
	_load_codex()

func unlock_entry(id: String) -> bool:
	if id in unlocked_entries:
		return false
	unlocked_entries.append(id)
	_save_codex()
	return true

func is_unlocked(id: String) -> bool:
	return id in unlocked_entries

func get_entries_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in LORE_ENTRIES:
		if entry["category"] == category:
			result.append(entry)
	return result

func get_categories() -> Array[String]:
	var cats: Array[String] = []
	for entry in LORE_ENTRIES:
		if entry["category"] not in cats:
			cats.append(entry["category"])
	return cats

func get_unlock_count() -> int:
	return unlocked_entries.size()

func get_total_count() -> int:
	return LORE_ENTRIES.size()

## Auto-unlock lore based on gameplay events
func check_auto_unlocks() -> void:
	# World entries unlock when you enter them
	var world_map := {0: "dark_realm", 1: "scorched_sands", 2: "frozen_wastes",
		3: "toxic_marshes", 4: "the_void", 5: "celestial_realm"}
	for w_id in SaveData.worlds_completed:
		if world_map.has(w_id):
			unlock_entry(world_map[w_id])
	# Always unlock dark realm and necromancer
	unlock_entry("dark_realm")
	unlock_entry("necromancer")
	# Unlock enemy entries based on bestiary
	var enemy_map := {"melee": "enemy_melee", "charger": "enemy_charger",
		"summoner": "enemy_summoner", "voidcaller": "enemy_voidcaller"}
	for etype in SaveData.bestiary:
		if enemy_map.has(etype) and int(SaveData.bestiary[etype]) >= 10:
			unlock_entry(enemy_map[etype])
	# Mechanics unlock with progression
	if SaveData.total_kills > 0:
		unlock_entry("extraction")
	if SaveData.total_runs >= 3:
		unlock_entry("rift_sealing")
	if SaveData.total_bosses_killed >= 1:
		unlock_entry("rift_guardian")
	if SaveData.highest_world_unlocked >= 2:
		unlock_entry("world_transition")
	if SaveData.total_bosses_killed >= 6:
		unlock_entry("eternal_one")

func _save_codex() -> void:
	var file := FileAccess.open("user://riftbound_codex.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocked": unlocked_entries}))

func _load_codex() -> void:
	if not FileAccess.file_exists("user://riftbound_codex.dat"):
		return
	var file := FileAccess.open("user://riftbound_codex.dat", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is not Dictionary:
		return
	var saved = data.get("unlocked", [])
	unlocked_entries = []
	if saved is Array:
		for s in saved:
			if s is String:
				unlocked_entries.append(s)
