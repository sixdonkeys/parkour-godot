class_name InputSource
extends RefCounted
## Where a body's actions come from, sampled once per physics tick.
## Subclasses: DeviceInput (the engine input map), RecordingInput (a recorded
## run; movement module), and later a network source.

## Action name -> strength (0..1) for this tick; look deltas under "look_x"/"look_y".
func sample(_tick: int) -> Dictionary:
	return {}
