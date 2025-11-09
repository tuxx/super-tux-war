extends Node
class_name SoundGenerator

## Generates procedural sound effects with variation using AudioStreamGenerator.
##
## Creates retro-style game sounds dynamically with randomized parameters
## to ensure each playback sounds slightly different, avoiding repetition.

const SAMPLE_RATE := 44100

## Generates a jump sound with rising pitch and variation.
func generate_jump() -> AudioStreamWAV:
	var base_freq := randf_range(280.0, 350.0)
	var end_freq := base_freq * randf_range(2.2, 2.8)
	var duration := randf_range(0.07, 0.11)
	
	var samples := _generate_chirp(base_freq, end_freq, duration, "square")
	return _create_wav_stream(samples)

## Generates a death sound with descending pitch.
func generate_death() -> AudioStreamWAV:
	var base_freq := randf_range(700.0, 900.0)
	var end_freq := randf_range(80.0, 120.0)
	var duration := randf_range(0.35, 0.50)
	
	# Mix sine wave with noise for texture
	var sine_samples := _generate_chirp(base_freq, end_freq, duration, "sine")
	var noise_samples := _generate_noise(duration, 0.15)
	var mixed := _mix_samples(sine_samples, noise_samples, 0.8, 0.2)
	
	return _create_wav_stream(mixed)

## Generates a stomp/landing impact sound.
func generate_stomp() -> AudioStreamWAV:
	var base_freq := randf_range(80.0, 150.0)
	var duration := randf_range(0.08, 0.12)
	
	# Short percussive burst with noise
	var tone := _generate_tone(base_freq, duration, "triangle")
	var noise := _generate_noise(duration * 0.5, 0.4)
	var mixed := _mix_samples(tone, noise, 0.6, 0.4)
	
	# Apply sharp decay envelope
	_apply_percussive_envelope(mixed)
	
	return _create_wav_stream(mixed)

## Generates a footstep sound (short noise burst).
func generate_footstep() -> AudioStreamWAV:
	var duration := randf_range(0.03, 0.05)
	var samples := _generate_noise(duration, randf_range(0.15, 0.25))
	
	# Quick attack and release
	_apply_percussive_envelope(samples)
	
	return _create_wav_stream(samples)

## Generates a spawn/respawn shimmer effect.
func generate_spawn() -> AudioStreamWAV:
	var duration := 0.4
	var freqs := [400.0, 600.0, 800.0, 1000.0, 1200.0]
	
	var sample_count := int(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	
	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		
		# Layered arpeggiated tones
		var value := 0.0
		for freq_idx in range(freqs.size()):
			var freq: float = freqs[freq_idx]
			var delay := freq_idx * 0.05
			if t > delay:
				var amp := _envelope_adsr(progress, 0.05, 0.1, 0.7, 0.15)
				value += sin((t - delay) * freq * TAU) * amp * 0.15
		
		# Add vibrato
		value *= 1.0 + sin(t * 8.0) * 0.1
		
		_write_sample(samples, i, value)
	
	return _create_wav_stream(samples)

## Generates a chirp (frequency sweep) sound.
func _generate_chirp(start_hz: float, end_hz: float, duration: float, waveform: String) -> PackedByteArray:
	var sample_count := int(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	
	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		var freq: float = lerp(start_hz, end_hz, progress)
		var amplitude := _envelope_simple(progress)
		
		var value := _get_waveform(t, freq, waveform) * amplitude
		_write_sample(samples, i, value)
	
	return samples

## Generates a constant tone with envelope.
func _generate_tone(freq: float, duration: float, waveform: String) -> PackedByteArray:
	var sample_count := int(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	
	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		var amplitude := _envelope_simple(progress)
		
		var value := _get_waveform(t, freq, waveform) * amplitude
		_write_sample(samples, i, value)
	
	return samples

## Generates white noise.
func _generate_noise(duration: float, amplitude: float) -> PackedByteArray:
	var sample_count := int(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	
	for i in range(sample_count):
		var value := randf_range(-1.0, 1.0) * amplitude
		_write_sample(samples, i, value)
	
	return samples

## Returns waveform value at time t for given frequency.
func _get_waveform(t: float, freq: float, waveform: String) -> float:
	var phase := fmod(t * freq, 1.0)
	
	match waveform:
		"sine":
			return sin(t * freq * TAU)
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"triangle":
			return abs(phase * 4.0 - 2.0) - 1.0
		"sawtooth":
			return phase * 2.0 - 1.0
		_:
			return sin(t * freq * TAU)

## Simple envelope: quick attack, exponential decay.
func _envelope_simple(progress: float) -> float:
	var attack_time := 0.08
	if progress < attack_time:
		return progress / attack_time
	else:
		return exp(-(progress - attack_time) * 6.0)

## ADSR envelope.
func _envelope_adsr(progress: float, attack: float, decay: float, sustain: float, release: float) -> float:
	if progress < attack:
		return progress / attack
	elif progress < attack + decay:
		var decay_progress := (progress - attack) / decay
		return lerp(1.0, sustain, decay_progress)
	elif progress < 1.0 - release:
		return sustain
	else:
		var release_progress := (progress - (1.0 - release)) / release
		return sustain * (1.0 - release_progress)

## Applies sharp percussive envelope to samples (modifies in place).
func _apply_percussive_envelope(samples: PackedByteArray) -> void:
	var sample_count := samples.size() / 2
	
	for i in range(sample_count):
		var progress := float(i) / float(sample_count)
		var envelope := exp(-progress * 12.0)  # Sharp decay
		
		var idx := i * 2
		var value := _read_sample(samples, i)
		value *= envelope
		_write_sample(samples, i, value)

## Mixes two sample arrays with given weights.
func _mix_samples(samples_a: PackedByteArray, samples_b: PackedByteArray, weight_a: float, weight_b: float) -> PackedByteArray:
	var count_a := samples_a.size() / 2
	var count_b := samples_b.size() / 2
	var max_count: int = max(count_a, count_b)
	
	var result := PackedByteArray()
	result.resize(max_count * 2)
	
	for i in range(max_count):
		var value_a := _read_sample(samples_a, i) if i < count_a else 0.0
		var value_b := _read_sample(samples_b, i) if i < count_b else 0.0
		var mixed := value_a * weight_a + value_b * weight_b
		_write_sample(result, i, mixed)
	
	return result

## Writes a float sample (-1.0 to 1.0) to byte array as 16-bit PCM.
func _write_sample(samples: PackedByteArray, index: int, value: float) -> void:
	var clamped := clampf(value, -1.0, 1.0)
	var sample_int := int(clamped * 32767.0)
	var idx := index * 2
	
	if idx + 1 < samples.size():
		samples[idx] = sample_int & 0xFF
		samples[idx + 1] = (sample_int >> 8) & 0xFF

## Reads a 16-bit PCM sample from byte array as float.
func _read_sample(samples: PackedByteArray, index: int) -> float:
	var idx := index * 2
	if idx + 1 >= samples.size():
		return 0.0
	
	var low := samples[idx]
	var high := samples[idx + 1]
	var sample_int := low | (high << 8)
	
	# Convert from unsigned to signed
	if sample_int >= 32768:
		sample_int -= 65536
	
	return float(sample_int) / 32767.0

## Creates an AudioStreamWAV from sample data.
func _create_wav_stream(samples: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.data = samples
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	return stream

