class_name PlayerSlot
extends RefCounted
## Everything that belongs to one player: body, input, camera, rules state,
## look. World state lives in the level (decision multiplayer-readiness).

var player_id := 0
## Network authority id; 1 (this machine) until multiplayer exists.
var authority := 1
var input: InputSource
var body: Node3D
var camera_rig: Node3D
## RunRules node (rules module): timer, checkpoint, collectibles.
var rules: Node
var look: Dictionary = {}
var is_ghost := false
