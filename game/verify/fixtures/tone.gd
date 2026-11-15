extends AudioStreamPlayer
## Known-answer fixture for the sound instrument: a sine of known amplitude.
## Peak should read 20*log10(amplitude) dBFS; RMS 3.01 dB below that.

var amplitude := 0.5
var frequency := 440.0
var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback
var _noted := false


func configure_fixture(cfg: Dictionary) -> void:
	amplitude = float(cfg.get("amplitude", amplitude))
	frequency = float(cfg.get("frequency", frequency))


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = AudioServer.get_mix_rate()
	gen.buffer_length = 0.25
	stream = gen
	play()
	_playback = get_stream_playback()
	# No fill here: the preset's amplitude arrives through configure_fixture()
	# right after _ready, and the first fill must already use it (critic
	# round 1 found 0.4 s at the default level).


func _process(_delta: float) -> void:
	_fill()


func _fill() -> void:
	if _playback == null:
		return
	var rate := AudioServer.get_mix_rate()
	var n := _playback.get_frames_available()
	for i in n:
		var v := amplitude * sin(_phase)
		_playback.push_frame(Vector2(v, v))
		_phase = fmod(_phase + TAU * frequency / rate, TAU)
	if not _noted and has_node("/root/Verify") and n > 0:
		_noted = true
		get_node("/root/Verify").note_sound("fixture_tone", 20.0 * log(amplitude) / log(10.0))
