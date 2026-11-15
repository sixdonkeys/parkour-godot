# Survey: sound

## AudioEffectRecord class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AudioEffectRecord.xml

> Allows the user to record the sound from an audio bus into an [AudioStreamWAV]. When used on the Master audio bus, this includes all audio output by Godot.
> Unlike [AudioEffectCapture], this effect encodes the recording with the given format (8-bit, 16-bit, or compressed) instead of giving access to the raw audio samples.

## AudioEffectCapture class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AudioEffectCapture.xml

> Copies all audio frames, also known as "samples" or "audio samples", from the attached audio bus into its internal ring buffer. This effect does not alter the audio.

> Unlike [AudioEffectRecord], this effect only returns the raw audio samples instead of encoding them into an [AudioStream].

## Creating movies — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/animation/creating_movies.rst

> PNG image sequence for video and WAV for audio. Features lossless video

## Engine class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Engine.xml

> [b]Note:[/b] This does not affect audio playback speed. Use [member AudioServer.playback_speed_scale] to adjust audio playback speed independently of [member Engine.time_scale].
