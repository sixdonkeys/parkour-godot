extends RefCounted
## Sound instrument: an AudioEffectCapture on the Master bus copies every
## sample the game outputs; written as 32-bit float WAV so clipping above
## full scale is measured, not lost (decision sound).

var _capture: AudioEffectCapture
var _effect_idx := -1
var samples := PackedVector2Array()
var mix_rate := 44100.0
var sounds: Array[Dictionary] = []


func start() -> void:
	mix_rate = AudioServer.get_mix_rate()
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(bus, _capture)
	_effect_idx = AudioServer.get_bus_effect_count(bus) - 1


func drain() -> void:
	if _capture == null:
		return
	var n := _capture.get_frames_available()
	if n > 0:
		samples.append_array(_capture.get_buffer(n))


func stop() -> void:
	drain()
	if _effect_idx >= 0:
		AudioServer.remove_bus_effect(AudioServer.get_bus_index("Master"), _effect_idx)
	_effect_idx = -1
	_capture = null


## The game's sound system calls Verify.note_sound(); recorded here.
func note(sound_name: String, peak_db: float) -> void:
	sounds.append({"name": sound_name, "peak_db": peak_db, "usec": Time.get_ticks_usec()})


func analyse() -> Dictionary:
	var peak := 0.0
	var sumsq := 0.0
	var clips := 0
	for s in samples:
		var a := absf(s.x)
		var b := absf(s.y)
		peak = maxf(peak, maxf(a, b))
		sumsq += s.x * s.x + s.y * s.y
		if a >= 1.0:
			clips += 1
		if b >= 1.0:
			clips += 1
	var n := samples.size() * 2
	var rms := sqrt(sumsq / n) if n > 0 else 0.0
	return {
		"mix_rate": mix_rate,
		"frames": samples.size(),
		"seconds": samples.size() / mix_rate,
		"peak_dbfs": _db(peak),
		"rms_dbfs": _db(rms),
		"clipped_samples": clips,
		"driver": AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else ProjectSettings.get_setting("audio/driver/driver", ""),
		"sounds": sounds,
	}


static func _db(x: float) -> float:
	return 20.0 * log(x) / log(10.0) if x > 0.0 else -INF


func write_wav(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var channels := 2
	var bits := 32
	var data_bytes := samples.size() * channels * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_bytes)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)  # IEEE float
	f.store_16(channels)
	f.store_32(int(mix_rate))
	f.store_32(int(mix_rate) * channels * 4)
	f.store_16(channels * 4)
	f.store_16(bits)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_bytes)
	for s in samples:
		f.store_float(s.x)
		f.store_float(s.y)
	f.close()
	return OK
