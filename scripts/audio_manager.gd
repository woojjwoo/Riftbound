extends Node

## Procedural sound effects manager. Autoloaded as "Audio".
## Generates retro-style sounds using AudioStreamWAV.

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 8
var next_player: int = 0

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

func _play_tone(freq: float, duration: float, volume_db: float, wave_type: String = "square") -> void:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 - (float(i) / float(num_samples))  # linear decay
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
