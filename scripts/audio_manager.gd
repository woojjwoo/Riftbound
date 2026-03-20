extends Node

## Sound and music manager. Autoloaded as "Audio".
##
## Manages all game audio through Godot's audio bus system:
##   - Master bus: overall volume
##   - SFX bus: all sound effects (pooled AudioStreamPlayers)
##   - Music bus: background music with crossfading between worlds
##
## Volume settings persist in SaveData. All sounds are procedurally
## generated (placeholder tones/sweeps) with clear hooks for replacing
## with real audio files later.

# ---------------------------------------------------------------------------
# Audio bus names — created programmatically in _ready()
# ---------------------------------------------------------------------------
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

# ---------------------------------------------------------------------------
# SFX player pool
# ---------------------------------------------------------------------------
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 16
var next_player: int = 0

# ---------------------------------------------------------------------------
# Music system — two players for crossfading
# ---------------------------------------------------------------------------
var music_player_a: AudioStreamPlayer = null
var music_player_b: AudioStreamPlayer = null
var active_music_player: AudioStreamPlayer = null  # which one is currently "live"
var music_playing: bool = false
var current_music_id: int = -1  # world ID of currently playing music
const CROSSFADE_DURATION: float = 1.5
var _crossfade_tween: Tween = null

# ---------------------------------------------------------------------------
# Volume settings (linear 0.0–1.0, converted to dB for buses)
# ---------------------------------------------------------------------------
var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.6

# Signals for UI sliders / settings screens
signal volume_changed(bus_name: String, linear_value: float)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_audio_buses()
	_create_sfx_pool()
	_create_music_players()
	_load_volume_settings()
	_apply_all_volumes()

func _ensure_audio_buses() -> void:
	# Make sure SFX and Music buses exist. If not, create them.
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func _create_sfx_pool() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		sfx_players.append(player)

func _create_music_players() -> void:
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = BUS_MUSIC
	music_player_a.volume_db = -80.0  # start silent
	add_child(music_player_a)

	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = BUS_MUSIC
	music_player_b.volume_db = -80.0
	add_child(music_player_b)

	active_music_player = music_player_a

# ---------------------------------------------------------------------------
# Volume control API
# ---------------------------------------------------------------------------

## Set master volume (0.0–1.0). Persists to save data.
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MASTER, master_volume)
	_save_volume_settings()
	volume_changed.emit(BUS_MASTER, master_volume)

## Set SFX volume (0.0–1.0). Persists to save data.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_save_volume_settings()
	volume_changed.emit(BUS_SFX, sfx_volume)

## Set music volume (0.0–1.0). Persists to save data.
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_save_volume_settings()
	volume_changed.emit(BUS_MUSIC, music_volume)

## Get current volume for a bus (linear 0.0–1.0).
func get_volume(bus_name: String) -> float:
	match bus_name:
		BUS_MASTER: return master_volume
		BUS_SFX: return sfx_volume
		BUS_MUSIC: return music_volume
	return 1.0

## Mute/unmute a bus.
func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if linear <= 0.001:
			AudioServer.set_bus_volume_db(idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _apply_all_volumes() -> void:
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)

func _save_volume_settings() -> void:
	# SaveData handles persistence; we just push our values there.
	if SaveData:
		SaveData.audio_master_volume = master_volume
		SaveData.audio_sfx_volume = sfx_volume
		SaveData.audio_music_volume = music_volume
		SaveData.save_game()

func _load_volume_settings() -> void:
	if SaveData:
		master_volume = SaveData.audio_master_volume
		sfx_volume = SaveData.audio_sfx_volume
		music_volume = SaveData.audio_music_volume

# =========================================================================
# MUSIC SYSTEM
# =========================================================================

## Start music (defaults to world 0 / title screen). Called from title_screen
## and game_ui. If music for the same world is already playing, does nothing.
func start_music(world_id: int = -1) -> void:
	if world_id < 0:
		# Default: use current_world from Game, or 0 if we're on title
		if Game:
			world_id = Game.current_world
		else:
			world_id = 0

	if music_playing and current_music_id == world_id:
		return

	var stream := _generate_world_music(world_id)
	if music_playing:
		_crossfade_to(stream, world_id)
	else:
		_start_fresh(stream, world_id)

## Stop all music.
func stop_music() -> void:
	music_playing = false
	current_music_id = -1
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	music_player_a.stop()
	music_player_b.stop()
	music_player_a.volume_db = -80.0
	music_player_b.volume_db = -80.0

## Change music for a new world with crossfade.
func change_world_music(world_id: int) -> void:
	start_music(world_id)

func _start_fresh(stream: AudioStream, world_id: int) -> void:
	music_playing = true
	current_music_id = world_id
	active_music_player = music_player_a
	active_music_player.stream = stream
	active_music_player.volume_db = -6.0
	active_music_player.play()

func _crossfade_to(stream: AudioStream, world_id: int) -> void:
	current_music_id = world_id
	# Determine which player is inactive
	var outgoing := active_music_player
	var incoming: AudioStreamPlayer
	if active_music_player == music_player_a:
		incoming = music_player_b
	else:
		incoming = music_player_a
	active_music_player = incoming

	# Start incoming at silent, then fade
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(incoming, "volume_db", -6.0, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_DURATION)
	_crossfade_tween.set_parallel(false)
	_crossfade_tween.tween_callback(outgoing.stop)

# ---------------------------------------------------------------------------
# Per-world procedural music generation
# ---------------------------------------------------------------------------
# Each world gets a unique drone/ambient track with different frequencies,
# textures, and moods. Replace these with real audio files by loading an
# AudioStream resource and returning it from _generate_world_music().
# ---------------------------------------------------------------------------

func _generate_world_music(world_id: int) -> AudioStream:
	var sample_rate := 22050
	var duration := 4.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	# Get mood parameters per world
	var params := _get_world_music_params(world_id)
	var base_freq: float = params["base_freq"]
	var fifth_freq: float = params["fifth_freq"]
	var octave_freq: float = params["octave_freq"]
	var texture_freq: float = params["texture_freq"]
	var lfo_speed: float = params["lfo_speed"]
	var brightness: float = params["brightness"]

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var sample := 0.0
		# Base drone
		sample += sin(t * base_freq * TAU) * 0.25
		# Fifth harmony
		sample += sin(t * fifth_freq * TAU) * 0.12
		# Octave whisper
		sample += sin(t * octave_freq * TAU) * 0.06 * brightness
		# LFO amplitude modulation
		var lfo := 0.6 + 0.4 * sin(t * lfo_speed * TAU)
		sample *= lfo
		# Dark/world texture
		sample += sin(t * texture_freq * TAU) * 0.04
		# Optional higher harmonic for brighter worlds
		if brightness > 0.5:
			sample += sin(t * base_freq * 3.0 * TAU) * 0.02 * brightness
		# Clamp
		sample = clampf(sample * 0.6, -0.5, 0.5)
		data[i] = int((sample + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream

func _get_world_music_params(world_id: int) -> Dictionary:
	# Each world has a unique tonal identity.
	# To replace with real music: load an AudioStreamOggVorbis/MP3 instead.
	match world_id:
		0:  # Dark Realm — ominous low drone
			return {"base_freq": 55.0, "fifth_freq": 82.4, "octave_freq": 110.0,
					"texture_freq": 41.2, "lfo_speed": 0.25, "brightness": 0.3}
		1:  # Scorched Sands — slightly higher, arid feel
			return {"base_freq": 65.4, "fifth_freq": 98.0, "octave_freq": 130.8,
					"texture_freq": 49.0, "lfo_speed": 0.35, "brightness": 0.5}
		2:  # Frozen Wastes — cold, crystalline, sparse
			return {"base_freq": 73.4, "fifth_freq": 110.0, "octave_freq": 146.8,
					"texture_freq": 55.0, "lfo_speed": 0.15, "brightness": 0.7}
		3:  # Toxic Marshes — murky, unsettling detuned
			return {"base_freq": 49.0, "fifth_freq": 73.4, "octave_freq": 98.0,
					"texture_freq": 37.0, "lfo_speed": 0.4, "brightness": 0.2}
		4:  # The Void — very low, sparse, alien
			return {"base_freq": 36.7, "fifth_freq": 55.0, "octave_freq": 73.4,
					"texture_freq": 27.5, "lfo_speed": 0.1, "brightness": 0.1}
		5:  # Celestial Realm — bright, ethereal, higher register
			return {"base_freq": 82.4, "fifth_freq": 123.5, "octave_freq": 164.8,
					"texture_freq": 61.7, "lfo_speed": 0.3, "brightness": 0.9}
		_:  # Fallback
			return {"base_freq": 55.0, "fifth_freq": 82.4, "octave_freq": 110.0,
					"texture_freq": 41.2, "lfo_speed": 0.25, "brightness": 0.3}

# =========================================================================
# SFX — PUBLIC API
# =========================================================================
# All play_* methods are the public interface. Game scripts call these.
# To replace a placeholder with a real sound file, change the method body
# to load and play an AudioStream resource instead of calling _play_tone().
#
# Example replacement:
#   func play_hit() -> void:
#       _play_stream(preload("res://audio/sfx/hit.ogg"), -6.0)
# =========================================================================

# --- Combat ---

## Player melee/bolt attack connects with enemy.
func play_hit() -> void:
	_play_tone(220.0, 0.06, -6.0, "square")

## Heavy hit (boss taking damage, critical strike).
func play_hit_heavy() -> void:
	_play_tone(120.0, 0.1, -4.0, "square")

## Player attack firing (soul bolt).
func play_shoot() -> void:
	_play_sweep(800.0, 400.0, 0.05, -10.0)

## Enemy dies.
func play_kill() -> void:
	_play_sweep(400.0, 200.0, 0.12, -6.0)

## Thrall dies.
func play_thrall_death() -> void:
	_play_sweep(300.0, 80.0, 0.2, -5.0)

## Explosion (exploder enemy, boss slam).
func play_explode() -> void:
	_play_noise(0.15, -4.0)

## Shield breaks on shielded enemy.
func play_shield_break() -> void:
	_play_sweep(600.0, 100.0, 0.15, -4.0)

# --- Player Actions ---

## Player dashes.
func play_dash() -> void:
	_play_sweep(200.0, 600.0, 0.1, -8.0)

## Player recalls thralls.
func play_recall() -> void:
	_play_sweep(600.0, 400.0, 0.1, -8.0)

## Thrall extracted from enemy corpse (ARISE!).
func play_arise() -> void:
	_play_sweep(200.0, 800.0, 0.25, -4.0)

# --- Boss ---

## Boss appears on the battlefield.
func play_boss_enter() -> void:
	_play_tone(80.0, 0.3, -2.0, "square")

## Boss enrages or performs a special attack.
func play_boss_enrage() -> void:
	_play_sweep(100.0, 400.0, 0.3, -2.0)

## Boss spawns from spawner (distinct from boss_enter for spawner trigger).
func play_boss_spawn() -> void:
	# Deep rumble followed by rising tone
	_play_tone(60.0, 0.25, -2.0, "square")
	# Schedule a follow-up rising sweep
	get_tree().create_timer(0.2).timeout.connect(
		func(): _play_sweep(80.0, 300.0, 0.3, -3.0))

# --- Pickups ---

## Coin collected.
func play_pickup_coin() -> void:
	_play_sweep(600.0, 900.0, 0.06, -8.0)

## EXP orb collected.
func play_pickup_exp() -> void:
	_play_sweep(500.0, 800.0, 0.08, -8.0)

## Equipment drop collected.
func play_pickup_equip() -> void:
	# Brighter, more dramatic pickup sound
	_play_sweep(400.0, 1200.0, 0.15, -5.0)

## Health orb collected.
func play_pickup_health() -> void:
	_play_sweep(500.0, 700.0, 0.1, -7.0)

# --- Progression ---

## Rift upgrade available / equipment upgrade notification.
func play_upgrade() -> void:
	_play_sweep(300.0, 900.0, 0.2, -4.0)

## Player levels up.
func play_level_up() -> void:
	# Two-tone ascending fanfare
	_play_sweep(400.0, 800.0, 0.15, -4.0)
	get_tree().create_timer(0.12).timeout.connect(
		func(): _play_sweep(600.0, 1200.0, 0.2, -3.0))

## World cleared / victory.
func play_victory() -> void:
	_play_sweep(400.0, 1200.0, 0.4, -3.0)

## Phase/process change (mid-game, boss fight begins).
func play_phase_change() -> void:
	_play_sweep(200.0, 500.0, 0.2, -5.0)

# --- UI ---

## Generic UI click (buttons, menu navigation).
func play_ui_click() -> void:
	_play_tone(800.0, 0.03, -12.0, "square")

## UI confirm / select.
func play_ui_confirm() -> void:
	_play_sweep(600.0, 900.0, 0.06, -10.0)

## UI cancel / back.
func play_ui_cancel() -> void:
	_play_sweep(500.0, 300.0, 0.06, -10.0)

## UI error / cannot afford.
func play_ui_error() -> void:
	_play_tone(200.0, 0.08, -8.0, "square")

# =========================================================================
# SFX — INTERNAL GENERATION
# =========================================================================

func _get_player() -> AudioStreamPlayer:
	var p := sfx_players[next_player]
	next_player = (next_player + 1) % MAX_SFX_PLAYERS
	return p

## Play a pre-loaded AudioStream resource (for when real audio files are added).
## Usage: _play_stream(preload("res://audio/sfx/hit.ogg"), -6.0)
func _play_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func _play_tone(freq: float, duration: float, volume_db: float, wave_type: String = "square") -> void:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 - (float(i) / float(num_samples))
		var sample: float
		if wave_type == "square":
			sample = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		else:
			sample = sin(t * freq * TAU)
		sample *= envelope
		data[i] = int((sample * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data

	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func _play_sweep(freq_start: float, freq_end: float, duration: float, volume_db: float) -> void:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var envelope := 1.0 - t
		var freq := lerp(freq_start, freq_end, t)
		phase += freq / float(sample_rate)
		var sample := sin(phase * TAU) * envelope
		data[i] = int((sample * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data

	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func _play_noise(duration: float, volume_db: float) -> void:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var envelope := 1.0 - (float(i) / float(num_samples))
		var sample := randf_range(-1.0, 1.0) * envelope
		data[i] = int((sample * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data

	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()
