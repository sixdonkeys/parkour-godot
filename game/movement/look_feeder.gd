class_name LookFeeder
extends Node
## Hands mouse and trackpad motion to a player's DeviceInput as look, in
## radians, so the body can take it once per tick. The pointer has to be
## captured (it is only during play in a focused window; window rules),
## unless `require_capture` is turned off for a test harness.

## Radians of turn per pixel of pointer travel.
var sensitivity := 0.0022
var require_capture := true
var input: DeviceInput


func _init(device_input: DeviceInput = null) -> void:
	input = device_input


func _input(event: InputEvent) -> void:
	if input == null or not (event is InputEventMouseMotion):
		return
	if require_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	input.add_look((event as InputEventMouseMotion).screen_relative * sensitivity)
