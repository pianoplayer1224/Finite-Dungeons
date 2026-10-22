class_name DroneState
extends RefCounted
## Python section 2: Drone. RAY-24 state: four upgrade tracks (stage 0-DRONE_STAGES each),
## DRONE_SLOTS shared slots.

var atk := 0
var stages: Array[int] = [0, 0, 0, 0]
var slots_used := 0
