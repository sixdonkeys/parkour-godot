class_name ManualInput
extends InputSource
## An input source whose state another script sets directly: the test pilot
## for the movement instrument, which has to press jump at a measured spot.

var forward := 0.0
var right := 0.0
var jump := false
## A one-tick turn, radians, positive to the right; cleared once sampled.
var look_once := 0.0


func release() -> void:
	forward = 0.0
	right = 0.0
	jump = false
	look_once = 0.0


func sample(_tick: int) -> Dictionary:
	var d := {
		MovementActions.MOVE_FORWARD: maxf(forward, 0.0), MovementActions.MOVE_BACK: maxf(-forward, 0.0),
		MovementActions.MOVE_RIGHT: maxf(right, 0.0), MovementActions.MOVE_LEFT: maxf(-right, 0.0),
		MovementActions.JUMP: 1.0 if jump else 0.0, "look_x": look_once, "look_y": 0.0,
	}
	look_once = 0.0
	return d
