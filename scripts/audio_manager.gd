extends Node

## Procedural sound effects and music. Autoloaded as "Audio".

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 8
var next_player: int = 0
var music_player: AudioStreamPlayer = null
var music_playing: bool = false

func _ready() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_players.append(player)

func _get_player() -> AudioStreamPlayer:
	var p := sfx_players[next_player]
	next_player = (next_player + 1) % MAX_SFX_PLAYERS
	return p

# --- Music ---

func start_music() -> void:
	if music_playing:
		return
	music_playing = true

	var sample_rate := 22050
	var duration := 4.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var sample := 0.0
		# Low drone — A1 (55 Hz)
		sample += sin(t * 55.0 * TAU) * 0.25
		# Fifth — E2 (82.5 Hz)
		sample += sin(t * 82.407 * TAU) * 0.12
		# Octave whisper — A2 (110 Hz)
		sample += sin(t * 110.0 * TAU) * 0.06
		# Slow LFO amplitude modulation
		var lfo := 0.6 + 0.4 * sin(t * 0.25 * TAU)
		sample *= lfo
		# Subtle dark texture
		sample += sin(t * 41.2 * TAU) * 0.04
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

	music_player = AudioStreamPlayer.new()
	music_player.stream = stream
	music_player.volume_db = -20.0
	add_child(music_player)
	music_player.play()

func stop_music() -> void:
	if music_player:
		music_player.stop()
		music_playing = false

# --- SFX ---

func play_hit() -> void:
	_play_tone(220.0, 0.06, -6.0, "square")

func play_hit_heavy() -> void:
	_play_tone(120.0, 0.1, -4.0, "square")

func play_kill() -> void:
	_play_sweep(400.0, 200.0, 0.12, -6.0)

func play_dash() -> void:
	_play_sweep(200.0, 600.0, 0.1, -8.0)

func play_arise() -> void:
	_play_sweep(200.0, 800.0, 0.25, -4.0)

func play_boss_enter() -> void:
	_play_tone(80.0, 0.3, -2.0, "square")

func play_boss_enrage() -> void:
	_play_sweep(100.0, 400.0, 0.3, -2.0)

func play_explode() -> void:
	_play_noise(0.15, -4.0)

func play_shield_break() -> void:
	_play_sweep(600.0, 100.0, 0.15, -4.0)

func play_upgrade() -> void:
	_play_sweep(300.0, 900.0, 0.2, -4.0)

func play_victory() -> void:
	_play_sweep(400.0, 1200.0, 0.4, -3.0)

func play_shoot() -> void:
	_play_sweep(800.0, 400.0, 0.05, -10.0)

func play_phase_change() -> void:
	_play_sweep(200.0, 500.0, 0.2, -5.0)

func play_thrall_death() -> void:
	_play_sweep(300.0, 80.0, 0.2, -5.0)

func play_recall() -> void:
	_play_sweep(600.0, 400.0, 0.1, -8.0)

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
